@tool
extends EntityActionTask

## Spends the action without doing anything.


func _generate_name() -> String:
	return "Wait"


func _tick(_delta: float) -> Status:
	var entity: Entity = _entity()
	var actions: EntityActions = _actions()
	if not entity or not actions:
		return FAILURE
	return SUCCESS if actions.wait(entity) else FAILURE
