@tool
extends EntityActionTask

## Attacks the current target through the action layer.


func _generate_name() -> String:
	return "Attack target"


func _tick(_delta: float) -> Status:
	var entity: Entity = _entity()
	var actions: EntityActions = _actions()
	var target: Entity = blackboard.get_var(BrainBlackboard.TARGET, null, false) as Entity
	if not entity or not actions or not is_instance_valid(target):
		return FAILURE
	return SUCCESS if actions.attack(entity, target) else FAILURE
