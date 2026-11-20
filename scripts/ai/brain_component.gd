class_name BrainComponent
extends Node

## Pluggable CPU brain. Assign a [BehaviorTree] resource to give an entity a
## behavior; a different resource means a different brain.
##
## The node owns a [BTPlayer] in manual mode, so nothing ticks until
## [TurnManager] calls [method take_turn]. The turn manager injects the shared
## action layer and perception helper through [method configure].

@export var behavior_tree: BehaviorTree = null
@export var enabled: bool = true

var agent: Entity = null
var actions: EntityActions = null
var perception: Perception = null
var bt_player: BTPlayer = null


func _ready() -> void:
	agent = get_parent() as Entity
	if not agent:
		push_error("%s must be a child of an Entity." % name)
		return
	if not behavior_tree:
		push_warning("%s has no behavior tree." % name)
		return
	bt_player = BTPlayer.new()
	bt_player.name = "BTPlayer"
	# The player is a child of this component, which is a child of the entity.
	bt_player.agent_node = NodePath("../..")
	bt_player.behavior_tree = behavior_tree
	bt_player.update_mode = BTPlayer.MANUAL
	bt_player.set_scene_root_hint(_find_scene_root())
	add_child(bt_player)


func configure(_actions: EntityActions, _perception: Perception) -> void:
	actions = _actions
	perception = _perception


## Gives the brain one action opportunity. The action layer enforces that at
## most one world-mutating action happens per call.
func take_turn() -> void:
	if not enabled or not bt_player or not behavior_tree:
		return
	if not actions or not perception:
		push_warning("%s was not configured before its turn." % name)
		return
	if bt_player.get_bt_instance() == null:
		# BTPlayer initializes once the scene root is ready. Falling through
		# makes the turn manager spend a wait action, so this is safe.
		return
	var blackboard: Blackboard = bt_player.get_blackboard()
	blackboard.set_var(BrainBlackboard.ACTIONS, actions)
	blackboard.set_var(BrainBlackboard.PERCEPTION, perception)
	blackboard.set_var(BrainBlackboard.BOARD, perception.board)
	blackboard.set_var(BrainBlackboard.VISIBLE_HOSTILES, perception.visible_hostiles(agent))
	bt_player.update(0.0)


func _find_scene_root() -> Node:
	var scene_root: Node = get_tree().current_scene
	if scene_root:
		return scene_root
	var node: Node = self
	while node.get_parent() and node.get_parent() != get_tree().root:
		node = node.get_parent()
	return node
