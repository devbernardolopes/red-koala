@tool
extends EntityConditionTask

## Succeeds when this CPU entity has been provoked into hostile behavior.


func _generate_name() -> String:
	return "Is foe"


func _tick(_delta: float) -> Status:
	var entity: Entity = _entity()
	if entity and entity.team == Helper.EntityTeam.FOE:
		return SUCCESS
	return FAILURE
