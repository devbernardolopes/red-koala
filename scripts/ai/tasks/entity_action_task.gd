@tool
class_name EntityActionTask
extends BTAction

## Base for behavior-tree actions that act on the entity's world.
##
## Tasks never change the board themselves: they ask [EntityActions], which
## enforces one action per turn and all the movement/occupancy rules.


func _entity() -> Entity:
	return agent as Entity


func _actions() -> EntityActions:
	return blackboard.get_var(BrainBlackboard.ACTIONS, null, false) as EntityActions


func _board() -> Board:
	return blackboard.get_var(BrainBlackboard.BOARD, null, false) as Board


func _perception() -> Perception:
	return blackboard.get_var(BrainBlackboard.PERCEPTION, null, false) as Perception
