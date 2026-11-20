class_name TurnManager
extends Node

## Rounds, action points and input gating.
##
## Every round each actor refills [member Entity.energy] from its speed. The
## actors are sorted by speed and take turns in passes; a pass gives every
## actor with enough energy exactly one action. Playable actors wait for the
## player, everyone else is asked for an action through an optional
## [BrainComponent]. An actor that produces no action waits, so the loop can
## never spin forever.

enum State {
	IDLE,
	PLAYER,
	CPU,
}

## Energy a standard action costs. With the default speed of 10 an actor gets
## one action per round; speed 20 gives two, and so on.
const ACTION_COST: int = 10

## Seconds between CPU actions so the player can follow what is happening.
@export var action_delay: float = 0.1
## Resolve CPU turns without the pacing delay. Useful while debugging.
@export var instant: bool = false

var universe: Universe = null
var actions: EntityActions = null
var perception: Perception = null

var actors: Array[Entity] = []
var current_actor: Entity = null
var round_number: int = 0
var state: State = State.IDLE

var _order: Array[Entity] = []
var _pass: int = 0
var _index: int = 0
var _max_passes: int = 1
var _cpu_timer: float = 0.0
var _preferred_actor: Entity = null


func setup(the_universe: Universe) -> void:
	universe = the_universe
	actions = EntityActions.new()
	actions.name = "EntityActions"
	actions.board = universe.board
	actions.universe = universe
	add_child(actions)
	perception = Perception.new(universe.board)


func start() -> void:
	actors.clear()
	if universe.entities_node:
		for child: Node in universe.entities_node.get_children():
			if child is Entity:
				actors.append(child as Entity)
	_preferred_actor = universe.current_player_entity
	_order = actors.duplicate()
	_order.sort_custom(_compare_actors)
	var max_speed: float = 0.0
	for actor: Entity in _order:
		max_speed = maxf(max_speed, actor.speed)
		var brain: BrainComponent = universe.get_brain(actor)
		if brain:
			brain.configure(actions, perception)
	_max_passes = maxi(1, floori(max_speed / float(ACTION_COST)))
	round_number = 0
	_start_round()


func is_player_turn() -> bool:
	return state == State.PLAYER and is_instance_valid(current_actor) \
			and current_actor.is_playable


func get_current_actor() -> Entity:
	return current_actor


## Called by the universe after the player attempted an action. The action
## layer decides whether anything actually happened, so blocked moves keep the
## player's turn.
func on_player_action() -> void:
	if state != State.PLAYER:
		return
	_resolve_action()


## Spends the player's action without doing anything.
func request_wait() -> bool:
	if state != State.PLAYER or not is_instance_valid(current_actor):
		return false
	if not actions.wait(current_actor):
		return false
	_resolve_action()
	return true


func _process(delta: float) -> void:
	if state != State.CPU:
		return
	_cpu_timer -= delta
	if _cpu_timer > 0.0:
		return
	set_process(false)
	_run_cpu()


func _start_round() -> void:
	round_number += 1
	for actor: Entity in _order:
		if is_instance_valid(actor):
			# Everyone gets at least one action, even with a very low speed.
			actor.energy = maxi(roundi(actor.speed), ACTION_COST)
	_pass = 0
	_index = 0
	_advance()


func _advance() -> void:
	while true:
		if _order.is_empty():
			state = State.IDLE
			current_actor = null
			return
		if _pass >= _max_passes:
			_start_round()
			return
		if _index >= _order.size():
			_pass += 1
			_index = 0
			continue
		var actor: Entity = _order[_index]
		_index += 1
		if not is_instance_valid(actor) or actor.is_queued_for_deletion():
			continue
		if actor.energy < ACTION_COST:
			continue
		_begin_actor(actor)
		return


func _begin_actor(actor: Entity) -> void:
	current_actor = actor
	actions.begin_turn(actor)
	if actor.is_playable:
		state = State.PLAYER
		set_process(false)
		universe.set_active_player(actor)
		return
	state = State.CPU
	var brain: BrainComponent = universe.get_brain(actor)
	# Brainless actors only wait, so there is no reason to make the player sit
	# through a delay for them.
	if instant or not brain:
		_run_cpu()
		return
	_cpu_timer = action_delay
	set_process(true)


func _run_cpu() -> void:
	var actor: Entity = current_actor
	if not is_instance_valid(actor):
		state = State.IDLE
		return
	var brain: BrainComponent = universe.get_brain(actor)
	if brain:
		brain.take_turn()
	if universe.board_debug_overlay:
		(universe.board_debug_overlay as BoardDebugOverlay).set_visible_tiles(
				perception.visible_tiles(actor))
	if not actions.has_acted():
		# A brain that could not act still spends the action, otherwise the
		# same actor would be asked again forever.
		actions.wait(actor)
	_resolve_action()


func _resolve_action() -> void:
	var acted: bool = actions.end_turn()
	if is_instance_valid(current_actor) and acted:
		current_actor.energy = maxi(0, current_actor.energy - ACTION_COST)
	current_actor = null
	state = State.IDLE
	_advance()


func _compare_actors(a: Entity, b: Entity) -> bool:
	if not is_equal_approx(a.speed, b.speed):
		return a.speed > b.speed
	# Ties go to the entity that was active when the game started, then to the
	# order the entities appear in the scene.
	if a == _preferred_actor:
		return true
	if b == _preferred_actor:
		return false
	return actors.find(a) < actors.find(b)
