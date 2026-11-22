class_name Perception
extends RefCounted

## Answers "what can this entity see?" using the board index.
##
## Sight uses the same square field of view as the fog of war. Walls and closed
## doors block line of sight; items, goals and entities do not. Invisible
## targets are only visible to observers with [member Entity.can_see_invisible].

var board: Board = null


func _init(_board: Board = null) -> void:
	board = _board


## Every other entity the observer can currently see.
func visible_entities(observer: Entity) -> Array[Entity]:
	var result: Array[Entity] = []
	if not board or not is_instance_valid(observer):
		return result
	for target: Entity in board.get_entities():
		if target == observer or target.is_dead:
			continue
		if can_see(observer, target):
			result.append(target)
	return result


## Visible entities that belong to an opposing team.
func visible_hostiles(observer: Entity) -> Array[Entity]:
	var result: Array[Entity] = []
	for target: Entity in visible_entities(observer):
		if Helper.are_hostile(observer, target):
			result.append(target)
	return result


## Closest visible hostile, or null when there is none.
func nearest_hostile(observer: Entity) -> Entity:
	var nearest: Entity = null
	var nearest_distance: int = 0
	for target: Entity in visible_hostiles(observer):
		var distance: int = _distance(observer, target)
		if not nearest or distance < nearest_distance:
			nearest = target
			nearest_distance = distance
	return nearest


func can_see(observer: Entity, target: Entity) -> bool:
	if not board or not is_instance_valid(observer) or not is_instance_valid(target):
		return false
	if target == observer:
		return false
	if target.is_invisible and not observer.can_see_invisible:
		return false
	if _distance(observer, target) > observer.fov:
		return false
	# Sight starts at the observer's centre tile and succeeds when any cell of
	# the target's footprint is visible. Single-tile entities behave as before.
	var observer_center: Vector2i = Board.footprint_center(
			board.get_origin(observer), observer.tile_size)
	var target_origin: Vector2i = board.get_origin(target)
	for cell: Vector2i in Board.footprint_cells(target_origin, target.tile_size):
		if board.has_line_of_sight(observer_center, cell):
			return true
	return false


## Tiles the observer can currently see, in field of view and line of sight.
func visible_tiles(observer: Entity) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not board or not is_instance_valid(observer):
		return result
	var center: Vector2i = board.get_origin(observer)
	var size: int = maxi(observer.fov, 1)
	for x: int in range(center.x - size, center.x + size + 1):
		for y: int in range(center.y - size, center.y + size + 1):
			var tile: Vector2i = Vector2i(x, y)
			if board.has_line_of_sight(center, tile) and not board.blocks_sight(tile):
				result.append(tile)
	return result


func _distance(observer: Entity, target: Entity) -> int:
	return Board.footprint_distance(board.get_origin(observer), observer.tile_size,
			board.get_origin(target), target.tile_size)
