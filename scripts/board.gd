class_name Board
extends Node

## Single source of truth for which elements occupy which tiles.
##
## Elements register themselves with their [member Base.tile_size] footprint.
## The index (not [member Node2D.position]) is authoritative for logical
## position; call [method sync_from_position] when something set the position
## directly (e.g. a teleport).

signal element_registered(element: Base)
signal element_unregistered(element: Base)
signal element_moved(element: Base, from_origin: Vector2i, to_origin: Vector2i)
## Occupancy, walkability or sight-blocking changed.
signal tile_changed(tile: Vector2i)

## Cell index. Values are `Array[Base]`; Godot does not support nested typed
## collections, so the value type itself has to stay untyped.
var _cells: Dictionary[Vector2i, Array] = {}
var _origins: Dictionary[Base, Vector2i] = {}
var _bounds: Rect2i = Rect2i()
var _has_bounds: bool = false


## Converts an origin tile to the world position of the centre of the
## footprint.
static func tile_to_world(origin: Vector2i, size: int = 1) -> Vector2:
	var _size: int = maxi(size, 1)
	return (Vector2(origin) + (Vector2(_size, _size) * 0.5)) * Helper.LENGTH


## Converts a world position to the origin tile of a footprint. The result is
## rounded to tolerate float error.
static func world_to_origin(pos: Vector2, size: int = 1) -> Vector2i:
	var _size: int = maxi(size, 1)
	return Vector2i(((pos / Helper.LENGTH) - (Vector2(_size, _size) * 0.5)).round())


## Returns every tile covered by a footprint whose top-left cell is
## [param origin].
static func footprint_cells(origin: Vector2i, size: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var _size: int = maxi(size, 1)
	for x: int in _size:
		for y: int in _size:
			cells.append(origin + Vector2i(x, y))
	return cells


func register(element: Base) -> void:
	if not element:
		return
	if _origins.has(element):
		sync_from_position(element)
		return
	var origin: Vector2i = world_to_origin(element.position, element.tile_size)
	_origins[element] = origin
	_update_cells(element, origin)
	var state_changed: Callable = _on_element_state_changed.bind(element)
	if not element.walkability_changed.is_connected(state_changed):
		element.walkability_changed.connect(state_changed)
	if not element.blocks_sight_changed.is_connected(state_changed):
		element.blocks_sight_changed.connect(state_changed)
	for tile: Vector2i in footprint_cells(origin, element.tile_size):
		tile_changed.emit(tile)
	element_registered.emit(element)


func unregister(element: Base) -> void:
	if not element:
		return
	if not _origins.has(element):
		return
	var origin: Vector2i = _origins[element]
	_origins.erase(element)
	_remove_cells(element, origin)
	var state_changed: Callable = _on_element_state_changed.bind(element)
	if element.walkability_changed.is_connected(state_changed):
		element.walkability_changed.disconnect(state_changed)
	if element.blocks_sight_changed.is_connected(state_changed):
		element.blocks_sight_changed.disconnect(state_changed)
	for tile: Vector2i in footprint_cells(origin, element.tile_size):
		tile_changed.emit(tile)
	element_unregistered.emit(element)


## Re-derives the origin from [member Node2D.position]. Use after something
## moved the element without going through [method move_element].
func sync_from_position(element: Base) -> void:
	if not element:
		return
	if not _origins.has(element):
		register(element)
		return
	var origin: Vector2i = world_to_origin(element.position, element.tile_size)
	move_element(element, origin)


## Sets both the index and the position. Intended for initial placement.
func place(element: Base, origin: Vector2i) -> void:
	if not element:
		return
	if not _origins.has(element):
		element.position = tile_to_world(origin, element.tile_size)
		register(element)
		return
	move_element(element, origin)


func move_element(element: Base, to_origin: Vector2i) -> void:
	if not element:
		return
	if not _origins.has(element):
		place(element, to_origin)
		return
	var from_origin: Vector2i = _origins[element]
	if from_origin == to_origin:
		return
	_remove_cells(element, from_origin)
	_origins[element] = to_origin
	element.position = tile_to_world(to_origin, element.tile_size)
	_update_cells(element, to_origin)
	element_moved.emit(element, from_origin, to_origin)
	for tile: Vector2i in footprint_cells(from_origin, element.tile_size):
		tile_changed.emit(tile)
	for tile: Vector2i in footprint_cells(to_origin, element.tile_size):
		tile_changed.emit(tile)


func get_origin(element: Base) -> Vector2i:
	if not element:
		return Vector2i.ZERO
	if not _origins.has(element):
		return Vector2i.ZERO
	return _origins[element]


func get_elements_at(tile: Vector2i) -> Array[Base]:
	var result: Array[Base] = []
	if not _cells.has(tile):
		return result
	result.assign(_cells[tile])
	return result


## Grow-only bounds of all footprints ever registered.
func get_bounds() -> Rect2i:
	return _bounds


func is_tile_blocked(tile: Vector2i, mover: Base = null, mode: Helper.MoveMode = Helper.MoveMode.WALK) -> bool:
	for element: Base in get_elements_at(tile):
		if element == mover:
			continue
		if element.walkable:
			continue
		# Phasing passes through terrain (walls, closed doors) but it cannot
		# share a tile with another entity, unless that entity is walkable.
		# It still has to deal with pushable elements (crates).
		if mode == Helper.MoveMode.PHASE:
			if element is Entity:
				return true
			if not element.pushable:
				continue
		return true
	return false


func can_occupy(mover: Base, origin: Vector2i, mode: Helper.MoveMode = Helper.MoveMode.WALK) -> bool:
	if not mover:
		return false
	for tile: Vector2i in footprint_cells(origin, mover.tile_size):
		if is_tile_blocked(tile, mover, mode):
			return false
	return true


## 8-way movement without corner-cutting. Pushable elements are reported as
## blocking; pushing is the job of the action that performs the move.
func can_step(mover: Base, dir: Vector2i, mode: Helper.MoveMode = Helper.MoveMode.WALK) -> bool:
	if not mover or dir == Vector2i.ZERO:
		return false
	var origin: Vector2i = get_origin(mover)
	if dir.x != 0 and dir.y != 0:
		return can_occupy(mover, origin + Vector2i(dir.x, 0), mode) \
				and can_occupy(mover, origin + Vector2i(0, dir.y), mode) \
				and can_occupy(mover, origin + dir, mode)
	return can_occupy(mover, origin + dir, mode)


func blocks_sight(tile: Vector2i) -> bool:
	for element: Base in get_elements_at(tile):
		if element.blocks_sight:
			return true
	return false


func _update_cells(element: Base, origin: Vector2i) -> void:
	for tile: Vector2i in footprint_cells(origin, element.tile_size):
		var elements: Array[Base]
		if _cells.has(tile):
			elements = _cells[tile]
		else:
			elements = []
			_cells[tile] = elements
		if not elements.has(element):
			elements.append(element)
		_grow_bounds(tile)


func _remove_cells(element: Base, origin: Vector2i) -> void:
	for tile: Vector2i in footprint_cells(origin, element.tile_size):
		if not _cells.has(tile):
			continue
		var elements: Array[Base] = _cells[tile]
		elements.erase(element)
		if elements.is_empty():
			_cells.erase(tile)
		else:
			_cells[tile] = elements


func _grow_bounds(tile: Vector2i) -> void:
	if not _has_bounds:
		_bounds = Rect2i(tile, Vector2i.ONE)
		_has_bounds = true
		return
	_bounds = _bounds.expand(tile)


func _on_element_state_changed(element: Base) -> void:
	if not _origins.has(element):
		return
	for tile: Vector2i in footprint_cells(_origins[element], element.tile_size):
		tile_changed.emit(tile)
