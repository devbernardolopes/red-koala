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

## 8-way neighbours, cardinals first.
const NEIGHBOURS: Array[Vector2i] = [
	Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN,
	Vector2i(-1, -1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(1, 1),
]

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


## Every element currently registered with the board.
func get_all_elements() -> Array[Base]:
	var result: Array[Base] = []
	result.assign(_origins.keys())
	return result


## Returns the gap between two footprints in tiles. A gap of zero on both axes
## means the footprints touch (or overlap).
static func footprint_gap(a_origin: Vector2i, a_size: int, b_origin: Vector2i,
		b_size: int) -> Vector2i:
	var _a_size: int = maxi(a_size, 1)
	var _b_size: int = maxi(b_size, 1)
	return Vector2i(
			maxi(maxi(b_origin.x - a_origin.x - _a_size, a_origin.x - b_origin.x - _b_size), 0),
			maxi(maxi(b_origin.y - a_origin.y - _a_size, a_origin.y - b_origin.y - _b_size), 0))


static func footprints_overlap(a_origin: Vector2i, a_size: int, b_origin: Vector2i,
		b_size: int) -> bool:
	var _a_size: int = maxi(a_size, 1)
	var _b_size: int = maxi(b_size, 1)
	return a_origin.x < b_origin.x + _b_size and b_origin.x < a_origin.x + _a_size \
			and a_origin.y < b_origin.y + _b_size and b_origin.y < a_origin.y + _a_size


## Whether the two elements touch, including diagonally, without overlapping.
func is_footprints_adjacent(a: Base, b: Base) -> bool:
	if not a or not b:
		return false
	var a_origin: Vector2i = get_origin(a)
	var b_origin: Vector2i = get_origin(b)
	if footprints_overlap(a_origin, a.tile_size, b_origin, b.tile_size):
		return false
	return footprint_gap(a_origin, a.tile_size, b_origin, b.tile_size) == Vector2i.ZERO


## Distance in tiles between the closest cells of two footprints. Overlapping
## footprints have a distance of zero.
static func footprint_distance(a_origin: Vector2i, a_size: int, b_origin: Vector2i,
		b_size: int) -> int:
	var gap: Vector2i = footprint_gap(a_origin, a_size, b_origin, b_size)
	if footprints_overlap(a_origin, a_size, b_origin, b_size):
		return 0
	return maxi(gap.x, gap.y)


## Whether the straight line between two tile centres crosses a sight-blocking
## element. The endpoints themselves are ignored, so a wall the observer is
## standing on does not hide everything.
func has_line_of_sight(from_tile: Vector2i, to_tile: Vector2i) -> bool:
	var x: int = from_tile.x
	var y: int = from_tile.y
	var dx: int = absi(to_tile.x - x)
	var dy: int = -absi(to_tile.y - y)
	var sx: int = 1 if x < to_tile.x else -1
	var sy: int = 1 if y < to_tile.y else -1
	var err: int = dx + dy
	while true:
		var tile: Vector2i = Vector2i(x, y)
		if tile != from_tile and tile != to_tile and blocks_sight(tile):
			return false
		if x == to_tile.x and y == to_tile.y:
			break
		var e2: int = 2 * err
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy
	return true


## A* path between footprint origins. Returns the tiles to walk through,
## excluding the start and including the destination. An empty array means the
## destination is unreachable.
func find_path(mover: Base, destination: Vector2i,
		mode: Helper.MoveMode = Helper.MoveMode.WALK) -> Array[Vector2i]:
	if not mover:
		return []
	var start: Vector2i = get_origin(mover)
	if start == destination:
		return []
	return _find_path(mover, start, destination, mode, false, 1)


## A* path to any tile from which [param mover] is adjacent to [param target].
## Returns an empty array when the mover is already adjacent or no path exists.
func find_path_to_adjacent(mover: Base, target: Base,
		mode: Helper.MoveMode = Helper.MoveMode.WALK) -> Array[Vector2i]:
	if not mover or not target:
		return []
	var start: Vector2i = get_origin(mover)
	if is_footprints_adjacent(mover, target):
		return []
	return _find_path(mover, start, get_origin(target), mode, true, target.tile_size)


func _find_path(mover: Base, start: Vector2i, target: Vector2i, mode: Helper.MoveMode,
		stop_adjacent: bool, target_size: int) -> Array[Vector2i]:
	var open: Array[Vector2i] = [start]
	var closed: Dictionary[Vector2i, bool] = {}
	var came_from: Dictionary[Vector2i, Vector2i] = {}
	var g_score: Dictionary[Vector2i, float] = {start: 0.0}
	var f_score: Dictionary[Vector2i, float] = {start: _heuristic(start, target)}
	var bounds: Rect2i = get_bounds() if _has_bounds else Rect2i()
	var min_tile: Vector2i = Vector2i(maxi(bounds.position.x, 0), maxi(bounds.position.y, 0))
	var max_tile: Vector2i = Vector2i(maxi(bounds.end.x - 1, 0), maxi(bounds.end.y - 1, 0))
	if min_tile > max_tile:
		return []
	var found: Vector2i = start
	var has_found: bool = false
	var search_limit: int = 4096
	while not open.is_empty() and search_limit > 0:
		search_limit -= 1
		var best: int = 0
		for i: int in open.size():
			if f_score.get(open[i], INF) < f_score.get(open[best], INF):
				best = i
		var current: Vector2i = open[best]
		open.remove_at(best)
		if closed.has(current):
			continue
		closed[current] = true
		if stop_adjacent:
			if current != start and _is_adjacent_to(current, mover.tile_size, target,
					target_size):
				found = current
				has_found = true
				break
		elif current == target:
			found = current
			has_found = true
			break
		for dir: Vector2i in NEIGHBOURS:
			var next: Vector2i = current + dir
			if _has_bounds and (next.x < min_tile.x or next.x > max_tile.x
					or next.y < min_tile.y or next.y > max_tile.y):
				continue
			if not _can_step_from(mover, current, dir, mode):
				continue
			var step_cost: float = 1.4142135 if dir.x != 0 and dir.y != 0 else 1.0
			var tentative: float = g_score.get(current, INF) + step_cost
			if tentative >= g_score.get(next, INF):
				continue
			came_from[next] = current
			g_score[next] = tentative
			f_score[next] = tentative + _heuristic(next, target)
			open.append(next)
	if not has_found:
		return []
	var path: Array[Vector2i] = []
	var node: Vector2i = found
	while node != start:
		path.push_front(node)
		if not came_from.has(node):
			return []
		node = came_from[node]
	return path


func _can_step_from(mover: Base, from: Vector2i, dir: Vector2i,
		mode: Helper.MoveMode) -> bool:
	if dir == Vector2i.ZERO:
		return false
	if dir.x != 0 and dir.y != 0:
		return can_occupy(mover, from + Vector2i(dir.x, 0), mode) \
				and can_occupy(mover, from + Vector2i(0, dir.y), mode) \
				and can_occupy(mover, from + dir, mode)
	return can_occupy(mover, from + dir, mode)


func _is_adjacent_to(origin: Vector2i, size: int, target_origin: Vector2i,
		target_size: int) -> bool:
	if footprints_overlap(origin, size, target_origin, target_size):
		return false
	return footprint_gap(origin, size, target_origin, target_size) == Vector2i.ZERO


func _heuristic(from: Vector2i, to: Vector2i) -> float:
	var dx: int = absi(from.x - to.x)
	var dy: int = absi(from.y - to.y)
	return maxi(dx, dy) + (1.4142135 - 1.0) * mini(dx, dy)


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
