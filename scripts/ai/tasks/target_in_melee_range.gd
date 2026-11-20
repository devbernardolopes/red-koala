@tool
extends EntityConditionTask

## Succeeds when the current target is visible and stands next to the entity.


func _generate_name() -> String:
	return "Target in melee range"


func _tick(_delta: float) -> Status:
	var entity: Entity = _entity()
	var board: Board = _board()
	var perception: Perception = _perception()
	var target: Entity = blackboard.get_var(BrainBlackboard.TARGET, null, false) as Entity
	if not entity or not board or not perception:
		return FAILURE
	if not is_instance_valid(target) or target == entity:
		return FAILURE
	if not board.is_footprints_adjacent(entity, target):
		return FAILURE
	if not perception.can_see(entity, target):
		return FAILURE
	return SUCCESS
