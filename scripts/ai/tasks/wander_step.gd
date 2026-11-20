@tool
extends EntityActionTask

## Takes a random legal step. Useful for idle creatures and for brains that
## should search an area instead of standing still.


func _generate_name() -> String:
	return "Wander step"


func _tick(_delta: float) -> Status:
	var entity: Entity = _entity()
	var board: Board = _board()
	var actions: EntityActions = _actions()
	if not entity or not board or not actions:
		return FAILURE
	var directions: Array[Vector2i] = Board.NEIGHBOURS.duplicate()
	directions.shuffle()
	for direction: Vector2i in directions:
		if not board.can_step(entity, direction, entity.get_move_mode()):
			continue
		return SUCCESS if actions.move(entity, direction) else FAILURE
	return FAILURE
