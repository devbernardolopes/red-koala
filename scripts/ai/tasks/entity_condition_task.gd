@tool
class_name EntityConditionTask
extends BTCondition

## Base for behavior-tree conditions that inspect the entity's world.


func _entity() -> Entity:
	return agent as Entity


func _actions() -> EntityActions:
	return blackboard.get_var(BrainBlackboard.ACTIONS, null, false) as EntityActions


func _board() -> Board:
	return blackboard.get_var(BrainBlackboard.BOARD, null, false) as Board


func _perception() -> Perception:
	return blackboard.get_var(BrainBlackboard.PERCEPTION, null, false) as Perception
