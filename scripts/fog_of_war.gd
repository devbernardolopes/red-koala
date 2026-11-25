class_name FogOfWar
extends Node2D

@export_range(0.0, 1.0) var memory_opacity: float = 0.5:
	set(value):
		memory_opacity = clampf(value, 0.0, 1.0)
		_apply_memory_opacity()
@export var hide_unseen_entities: bool = true:
	set(value):
		hide_unseen_entities = value
		mark_dirty()
@export var hide_unseen_items: bool = true:
	set(value):
		hide_unseen_items = value
		mark_dirty()
## Extra tiles of fog beyond what the widest camera view needs.
@export var extra_margin_tiles: int = 0

var _universe: Universe = null
var _board: Board = null
var _perception: Perception = null
var _fog_full: TileMapLayer = null
var _fog_memory: TileMapLayer = null
var _explored: Dictionary[Vector2i, bool] = {}
var _visible: Dictionary[Vector2i, bool] = {}
var _fog_source_id: int = -1
var _fog_atlas_coords: Vector2i = Vector2i.ZERO
var _fog_alternative: int = 0
var _dirty: bool = false
var _reveal_all: bool = false


func _process(_delta: float) -> void:
	if _dirty:
		refresh()


func setup(the_universe: Universe, the_board: Board) -> void:
	_universe = the_universe
	_board = the_board
	_fog_full = get_node_or_null("FogFull") as TileMapLayer
	if not _fog_full:
		push_warning("FogOfWar requires a FogFull TileMapLayer.")
		return
	_capture_fog_tile()
	_fill_fog_bounds()
	_build_memory_layer()
	_perception = Perception.new(_board)
	_connect_dirty_signals()
	mark_dirty()


func mark_dirty() -> void:
	_dirty = true


func refresh() -> void:
	_dirty = false
	if not _universe or not _board or not _fog_full or not _fog_memory or not _perception:
		return
	var new_visible: Dictionary[Vector2i, bool] = {}
	var newly_explored: Dictionary[Vector2i, bool] = {}
	var observers: Array[Entity] = []
	for observer: Entity in _universe.party:
		if not is_instance_valid(observer) or observer.is_dead:
			continue
		observers.append(observer)
		for tile: Vector2i in _perception.lit_tiles(observer):
			new_visible[tile] = true
			_fog_full.erase_cell(tile)
			if not _explored.has(tile):
				_explored[tile] = true
				newly_explored[tile] = true
	var changed_tiles: Dictionary[Vector2i, bool] = newly_explored.duplicate()
	for tile: Vector2i in _visible:
		if not new_visible.has(tile):
			changed_tiles[tile] = true
	for tile: Vector2i in new_visible:
		if not _visible.has(tile):
			changed_tiles[tile] = true
	for tile: Vector2i in changed_tiles:
		_update_memory_tile(tile, new_visible)
	_visible = new_visible
	_update_entity_visibility(observers)
	_update_item_visibility()


func is_tile_visible(tile: Vector2i) -> bool:
	return _visible.has(tile)


func is_tile_explored(tile: Vector2i) -> bool:
	return _explored.has(tile)


func get_explored_tiles() -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for tile: Vector2i in _explored:
		tiles.append(tile)
	return tiles


func set_explored_tiles(tiles: Array[Vector2i]) -> void:
	var changed_tiles: Dictionary[Vector2i, bool] = _explored.duplicate()
	_explored.clear()
	for tile: Vector2i in tiles:
		_explored[tile] = true
		changed_tiles[tile] = true
	for tile: Vector2i in changed_tiles:
		_update_memory_tile(tile, _visible)


func set_reveal_all(enabled: bool) -> void:
	_reveal_all = enabled
	_update_entity_visibility([])
	_update_item_visibility()
	mark_dirty()


func _capture_fog_tile() -> void:
	var used_cells: Array[Vector2i] = _fog_full.get_used_cells()
	if used_cells.is_empty():
		push_warning("FogFull has no tiles from which to copy its fog tile.")
		return
	var tile: Vector2i = used_cells.front()
	_fog_source_id = _fog_full.get_cell_source_id(tile)
	_fog_atlas_coords = _fog_full.get_cell_atlas_coords(tile)
	_fog_alternative = _fog_full.get_cell_alternative_tile(tile)


## Covers every tile the camera could show at the widest zoom, so zooming out
## never reveals unfogged map outside the painted area.
func _fill_fog_bounds() -> void:
	if _fog_source_id == -1:
		return
	var ground: TileMapLayer = null
	var walls: TileMapLayer = null
	if _universe:
		ground = _universe.get_node_or_null("Ground") as TileMapLayer
		walls = _universe.walls_node
		if not walls:
			walls = _universe.get_node_or_null("Walls") as TileMapLayer
	var rect: Rect2i = Rect2i()
	var has_rect: bool = false
	if ground:
		var ground_rect: Rect2i = ground.get_used_rect()
		if ground_rect.size != Vector2i.ZERO:
			rect = ground_rect
			has_rect = true
	if walls:
		var walls_rect: Rect2i = walls.get_used_rect()
		if walls_rect.size != Vector2i.ZERO:
			rect = walls_rect if not has_rect else rect.merge(walls_rect)
			has_rect = true
	if not has_rect:
		push_warning("FogOfWar found no Ground or Walls from which to size its fog.")
		return
	var viewport_size: Vector2 = _get_viewport_size()
	var margin: int = ceili(maxf(viewport_size.x, viewport_size.y)
			/ (Helper.LENGTH * _get_max_zoom_out())) + 2 + extra_margin_tiles
	rect = rect.grow(margin)
	for x: int in range(rect.position.x, rect.end.x):
		for y: int in range(rect.position.y, rect.end.y):
			var tile: Vector2i = Vector2i(x, y)
			if _explored.has(tile):
				continue
			if _fog_full.get_cell_source_id(tile) != -1:
				continue
			_fog_full.set_cell(tile, _fog_source_id, _fog_atlas_coords,
					_fog_alternative)


func _get_viewport_size() -> Vector2:
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x > 0.0 and viewport_size.y > 0.0:
		return viewport_size
	return Vector2(
			ProjectSettings.get_setting("display/window/size/viewport_width", 1152),
			ProjectSettings.get_setting("display/window/size/viewport_height", 648))


func _get_max_zoom_out() -> float:
	if _universe and _universe.follow_camera:
		return maxf(_universe.follow_camera.max_zoom_out, 0.01)
	return 0.5


func _build_memory_layer() -> void:
	_fog_memory = get_node_or_null("FogMemory") as TileMapLayer
	if not _fog_memory:
		_fog_memory = TileMapLayer.new()
		_fog_memory.name = &"FogMemory"
		add_child(_fog_memory)
		move_child(_fog_memory, _fog_full.get_index() + 1)
	_fog_memory.tile_set = _fog_full.tile_set
	_fog_memory.z_index = 1
	_fog_memory.collision_enabled = false
	_fog_memory.navigation_enabled = false
	_fog_memory.occlusion_enabled = false
	_apply_memory_opacity()


func _connect_dirty_signals() -> void:
	if not _board.element_moved.is_connected(_on_board_element_moved):
		_board.element_moved.connect(_on_board_element_moved)
	if not _board.tile_changed.is_connected(_on_board_tile_changed):
		_board.tile_changed.connect(_on_board_tile_changed)
	if not _board.element_registered.is_connected(_on_board_element_registered):
		_board.element_registered.connect(_on_board_element_registered)
	if not _board.element_unregistered.is_connected(_on_board_element_unregistered):
		_board.element_unregistered.connect(_on_board_element_unregistered)
	if not _universe.player_entity_changed.is_connected(mark_dirty):
		_universe.player_entity_changed.connect(mark_dirty)


func _on_board_element_moved(_element: Base, _from_origin: Vector2i,
		_to_origin: Vector2i) -> void:
	mark_dirty()


func _on_board_tile_changed(_tile: Vector2i) -> void:
	mark_dirty()


func _on_board_element_registered(element: Base) -> void:
	if element is Entity:
		var entity: Entity = element as Entity
		if (hide_unseen_entities and not _reveal_all and not entity.is_playable
				and not _universe.party.has(entity) and entity.visible):
			entity.visible = false
	elif element is Item or element is Corpse:
		_update_board_element_visibility(element)
	mark_dirty()


func _on_board_element_unregistered(element: Base) -> void:
	# A carried item leaves the board while it may still be hidden by fog; it
	# must be visible again when equipped.
	if is_instance_valid(element) and element is Item:
		element.visible = true
	mark_dirty()


func _update_entity_visibility(observers: Array[Entity]) -> void:
	if not _board or not _universe or not _perception:
		return
	var largest_fov: int = 0
	for observer: Entity in observers:
		largest_fov = maxi(largest_fov, observer.fov)
	for entity: Entity in _board.get_entities():
		if (not is_instance_valid(entity) or entity.is_queued_for_deletion()
				or entity.is_dead):
			continue
		var should_show: bool = (
				_reveal_all
				or not hide_unseen_entities
				or entity.is_playable
				or _universe.party.has(entity))
		if not should_show and _is_within_party_fov(entity, observers, largest_fov):
			for observer: Entity in observers:
				if _perception.can_see(observer, entity):
					should_show = true
					break
		if entity.visible != should_show:
			entity.visible = should_show


func _is_within_party_fov(entity: Entity, observers: Array[Entity], largest_fov: int) -> bool:
	if observers.is_empty():
		return false
	var entity_origin: Vector2i = _board.get_origin(entity)
	for observer: Entity in observers:
		if Board.footprint_distance(
				_board.get_origin(observer), observer.tile_size,
				entity_origin, entity.tile_size) <= largest_fov:
			return true
	return false


## Items and corpses only show while a party member can see their footprint.
func _update_item_visibility() -> void:
	if not _board:
		return
	for element: Base in _board.get_all_elements():
		if element is Item or element is Corpse:
			_update_board_element_visibility(element)


func _update_board_element_visibility(element: Base) -> void:
	if not is_instance_valid(element) or element.is_queued_for_deletion():
		return
	if element is Item and (element as Item).is_equipped:
		return
	var should_show: bool = _reveal_all or not hide_unseen_items
	if not should_show:
		should_show = _is_element_in_sight(element)
	if element.visible != should_show:
		element.visible = should_show
	if element is Corpse:
		var corpse: Corpse = element as Corpse
		if is_instance_valid(corpse.corpse_visual):
			corpse.corpse_visual.visible = should_show


func _is_element_in_sight(element: Base) -> bool:
	if not _board:
		return false
	var origin: Vector2i = _board.get_origin(element)
	for cell: Vector2i in Board.footprint_cells(origin, element.tile_size):
		if _visible.has(cell):
			return true
	return false


func _update_memory_tile(tile: Vector2i, visible_tiles: Dictionary[Vector2i, bool]) -> void:
	if _explored.has(tile) and not visible_tiles.has(tile):
		if _fog_source_id != -1:
			_fog_memory.set_cell(tile, _fog_source_id, _fog_atlas_coords, _fog_alternative)
	else:
		_fog_memory.erase_cell(tile)


func _apply_memory_opacity() -> void:
	if _fog_memory:
		_fog_memory.modulate = Color(1.0, 1.0, 1.0, memory_opacity)
