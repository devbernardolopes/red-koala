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
		_explore_observer_square(observer, newly_explored)
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
	mark_dirty()


func _on_board_element_unregistered(_element: Base) -> void:
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


func _explore_observer_square(observer: Entity,
		newly_explored: Dictionary[Vector2i, bool]) -> void:
	var center: Vector2i = _board.get_origin(observer)
	for x: int in range(center.x - observer.fov, center.x + observer.fov + 1):
		for y: int in range(center.y - observer.fov, center.y + observer.fov + 1):
			var tile: Vector2i = Vector2i(x, y)
			if _fog_full.get_cell_source_id(tile) == -1:
				continue
			_fog_full.erase_cell(tile)
			if not _explored.has(tile):
				_explored[tile] = true
				newly_explored[tile] = true


func _update_memory_tile(tile: Vector2i, visible_tiles: Dictionary[Vector2i, bool]) -> void:
	if _explored.has(tile) and not visible_tiles.has(tile):
		if _fog_source_id != -1:
			_fog_memory.set_cell(tile, _fog_source_id, _fog_atlas_coords, _fog_alternative)
	else:
		_fog_memory.erase_cell(tile)


func _apply_memory_opacity() -> void:
	if _fog_memory:
		_fog_memory.modulate = Color(1.0, 1.0, 1.0, memory_opacity)
