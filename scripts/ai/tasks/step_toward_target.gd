@tool
extends EntityActionTask

## Takes one pathfinding step toward the target, or toward the tile it was last
## seen on. The path is recomputed every tick so doors, crates and moving
## entities are always taken into account.


func _generate_name() -> String:
	return "Step toward target"


func _tick(_delta: float) -> Status:
	var entity: Entity = _entity()
	var board: Board = _board()
	var actions: EntityActions = _actions()
	if not entity or not board or not actions:
		return FAILURE
	var target: Entity = blackboard.get_var(BrainBlackboard.TARGET, null, false) as Entity
	var path: Array[Vector2i] = []
	if is_instance_valid(target) and target != entity:
		if board.is_footprints_adjacent(entity, target):
			return FAILURE
		path = board.find_path_to_adjacent(entity, target, entity.get_move_mode())
	if path.is_empty():
		var last_known: Vector2i = blackboard.get_var(
				BrainBlackboard.LAST_KNOWN_TARGET_POS, Vector2i(-1, -1), false)
		if last_known.x < 0:
			return FAILURE
		var origin: Vector2i = board.get_origin(entity)
		if origin == last_known:
			# Searched the last known position and found nothing.
			blackboard.set_var(BrainBlackboard.LAST_KNOWN_TARGET_POS, Vector2i(-1, -1))
			return FAILURE
		path = board.find_path(entity, last_known, entity.get_move_mode())
		if path.is_empty():
			return FAILURE
	var direction: Vector2i = path.front() - board.get_origin(entity)
	return SUCCESS if actions.move(entity, direction) else FAILURE
