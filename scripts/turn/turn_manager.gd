class_name TurnManager
extends Node

## Rounds, action points and input gating.
##
## Every round each actor accumulates [member Entity.energy] from its speed, up
## to [constant MAX_ENERGY]. The actors are sorted by speed and take turns in
## passes; a pass gives every actor with enough energy exactly one action.
## Playable actors wait for the player, everyone else is asked for an action
## through an optional [BrainComponent]. An actor that produces no action
## waits, so the loop can never spin forever.

enum State {
	IDLE,
	PLAYER,
	CPU,
}

## Energy a standard action costs. With the default speed of 10 an actor gets
## one action per round; speed 20 gives two, and so on.
const ACTION_COST: int = 10
## Upper bound for the energy pool, so a fast actor cannot bank an unbounded
## number of actions across rounds.
const MAX_ENERGY: int = ACTION_COST * 20
## Safety valve for a game where no actor can ever afford another action.
const MAX_EMPTY_ROUNDS: int = 1000

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
## Actors registered while a round is running. They join at the next round.
var _pending_actors: Array[Entity] = []
var _pass: int = 0
var _index: int = 0
var _max_passes: int = 1
var _empty_rounds: int = 0
var _cpu_timer: float = 0.0
var _preferred_actor: Entity = null

## True while the player chooses the order in which the party acts in this pass.
var _party_phase: bool = false
## Playable actors that can still act in this pass, the current one included.
var _party_pending: Array[Entity] = []
## Playable actors that already acted in this pass.
var _party_done: Array[Entity] = []


func setup(the_universe: Universe) -> void:
	universe = the_universe
	actions = EntityActions.new()
	actions.name = "EntityActions"
	actions.board = universe.board
	actions.universe = universe
	add_child(actions)
	perception = Perception.new(universe.board)
	actions.perception = perception


func start() -> void:
	actors.clear()
	if universe.entities_node:
		for child: Node in universe.entities_node.get_children():
			if child is Entity:
				actors.append(child as Entity)
	_preferred_actor = universe.current_player_entity
	_order = actors.duplicate()
	_order.sort_custom(_compare_actors)
	_pending_actors.clear()
	_empty_rounds = 0
	round_number = 0
	_pass = 0
	_index = 0
	# Force the first call to _advance() to start a round.
	_max_passes = 0
	_party_phase = false
	_party_pending.clear()
	_party_done.clear()
	for actor: Entity in _order:
		var brain: BrainComponent = universe.get_brain(actor)
		if brain:
			brain.configure(actions, perception)
	_advance()


func is_player_turn() -> bool:
	return (state == State.PLAYER 
			and is_instance_valid(current_actor) 
			and current_actor.is_playable)


func get_current_actor() -> Entity:
	return current_actor


## Adds an actor spawned at runtime. It joins the order from the next round, so
## the current round is not disturbed.
func register_actor(actor: Entity) -> void:
	if not actor or actors.has(actor):
		return
	actors.append(actor)
	if universe and actions and perception:
		var brain: BrainComponent = universe.get_brain(actor)
		if brain:
			brain.configure(actions, perception)
	if round_number == 0:
		# No round is running yet, so the actor can join immediately.
		if not _order.has(actor):
			_order.append(actor)
		_order.sort_custom(_compare_actors)
		return
	if not _order.has(actor) and not _pending_actors.has(actor):
		_pending_actors.append(actor)


## Removes an actor killed or despawned at runtime.
func unregister_actor(actor: Entity) -> void:
	if not actor:
		return
	var was_current: bool = actor == current_actor
	actors.erase(actor)
	var order_index: int = _order.find(actor)
	if order_index >= 0:
		_order.remove_at(order_index)
		# Keep _index pointing at the same next actor.
		if order_index < _index:
			_index -= 1
	_pending_actors.erase(actor)
	_party_pending.erase(actor)
	_party_done.erase(actor)
	# A current actor that leaves the world (death) must not leave the loop
	# waiting for an action that can never come.
	if was_current and (state == State.PLAYER or state == State.CPU):
		_resolve_action()
		_advance()


## Called by the universe after the player attempted an action. The action
## layer decides whether anything actually happened, so blocked moves keep the
## player's turn.
func on_player_action() -> void:
	if state != State.PLAYER or not actions.has_acted():
		return
	_resolve_action()
	_advance()


## Spends the player's action without doing anything.
func request_wait() -> bool:
	if state != State.PLAYER or not is_instance_valid(current_actor):
		return false
	var waiter: Entity = current_actor
	if not actions.wait(waiter):
		return false
	Journal.waited(waiter)
	_resolve_action()
	_advance()
	return true


func _process(delta: float) -> void:
	if state != State.CPU:
		return
	_cpu_timer -= delta
	if _cpu_timer > 0.0:
		return
	set_process(false)
	_run_cpu()
	_advance()


## Refills energy, recomputes the passes for this round and reports whether the
## round can start. Returns false when nobody can ever act again.
func _start_round() -> bool:
	_merge_pending_actors()
	_prune_order()
	if _order.is_empty():
		return false
	round_number += 1
	var max_energy: int = 0
	for actor: Entity in _order:
		actor.energy = mini(actor.energy + roundi(actor.get_effective_speed()),
				MAX_ENERGY)
		max_energy = maxi(max_energy, actor.energy)
	_max_passes = maxi(1, floori(float(max_energy) / ACTION_COST))
	_pass = 0
	_index = 0
	if max_energy < ACTION_COST:
		# Nobody can act yet; slow actors simply need more rounds to save up.
		_empty_rounds += 1
		if _empty_rounds >= MAX_EMPTY_ROUNDS:
			push_warning("TurnManager: no actor can act; stopping rounds.")
			return false
	else:
		_empty_rounds = 0
	print("ROUND %d passes=%d" % [round_number, _max_passes])
	for actor: Entity in _order:
		print("  %s speed=%s energy=%d"
				% [actor.name, actor.get_effective_speed(), actor.energy])
	return true


## Drives the turn loop. Instant CPU turns are resolved inline; the function
## only returns when the player must act or a CPU turn is being paced.
func _advance() -> void:
	set_process(false)
	while true:
		if _order.is_empty() and _pending_actors.is_empty():
			_go_idle()
			return
		if not _has_playable_actor():
			_go_idle()
			return
		# The player is still choosing who acts next in this pass.
		if _party_phase:
			_prune_party_pending()
			if not _party_pending.is_empty():
				_begin_party_member(_party_pending.front())
				return
			_party_phase = false
		if _pass >= _max_passes:
			if not _start_round():
				_go_idle()
				return
			continue
		if _index >= _order.size():
			_pass += 1
			_index = 0
			_party_done.clear()
			continue
		var actor: Entity = _order[_index]
		_index += 1
		if not _can_act_now(actor):
			continue
		if actor.is_playable:
			if _party_done.has(actor):
				continue
			_start_party_phase()
			_begin_party_member(actor)
			return
		_begin_actor(actor)
		if state != State.IDLE:
			return


## CPU actors only; playable actors go through [method _begin_party_member].
func _begin_actor(actor: Entity) -> void:
	current_actor = actor
	actions.begin_turn(actor)
	state = State.CPU
	var brain: BrainComponent = universe.get_brain(actor)
	if instant or not brain or not _is_visible_to_player(actor):
		_run_cpu()
		return
	_cpu_timer = action_delay
	set_process(true)


func _begin_party_member(member: Entity) -> void:
	current_actor = member
	actions.begin_turn(member)
	state = State.PLAYER
	set_process(false)
	universe.set_active_player(member)


func _start_party_phase() -> void:
	_party_phase = true
	_party_pending.clear()
	for member: Entity in _order:
		if _can_act_now(member) and member.is_playable and not _party_done.has(member):
			_party_pending.append(member)


func _prune_party_pending() -> void:
	for i: int in range(_party_pending.size() - 1, -1, -1):
		if not _can_act_now(_party_pending[i]):
			_party_pending.remove_at(i)


func _can_act_now(actor: Entity) -> bool:
	return (is_instance_valid(actor)
			and not actor.is_queued_for_deletion()
			and not actor.is_dead
			and actor.energy >= ACTION_COST)


func _run_cpu() -> void:
	var actor: Entity = current_actor
	if not is_instance_valid(actor):
		state = State.IDLE
		return
	var brain: BrainComponent = universe.get_brain(actor)
	if brain:
		if not brain.actions or not brain.perception:
			# The brain became ready after registration (runtime spawns).
			brain.configure(actions, perception)
		brain.take_turn()
	if universe.board_debug_overlay and universe.board_debug_overlay.visible:
		(universe.board_debug_overlay as BoardDebugOverlay).set_visible_tiles(
				perception.visible_tiles(actor))
	if not actions.has_acted():
		# A brain that could not act still spends the action, otherwise the
		# same actor would be asked again forever.
		if not actions.wait(actor):
			# Not even a wait is possible (e.g. the actor left the board), so
			# drop its energy to keep the loop from selecting it forever.
			actor.energy = 0
	_resolve_action()


func _resolve_action() -> void:
	var actor: Entity = current_actor
	var acted: bool = actions.end_turn()
	if is_instance_valid(actor) and acted:
		actor.energy = maxi(0, actor.energy - actions.last_cost)
		if actor.is_playable:
			_party_done.append(actor)
	_party_pending.erase(actor)
	current_actor = null
	state = State.IDLE


func _go_idle() -> void:
	state = State.IDLE
	current_actor = null
	set_process(false)


func _merge_pending_actors() -> void:
	for actor: Entity in _pending_actors:
		if is_instance_valid(actor) and not _order.has(actor):
			_order.append(actor)
	_pending_actors.clear()


func _prune_order() -> void:
	for i: int in range(_order.size() - 1, -1, -1):
		var actor: Entity = _order[i]
		if not is_instance_valid(actor) or actor.is_queued_for_deletion() or actor.is_dead:
			_order.remove_at(i)
	# Speed can change (haste, slow), so the order is refreshed every round.
	_order.sort_custom(_compare_actors)


## Whether at least one living playable actor is still registered. Pending
## actors count because they join at the next round.
func _has_playable_actor() -> bool:
	for actor: Entity in _order:
		if (is_instance_valid(actor) 
				and not actor.is_queued_for_deletion() 
				and not actor.is_dead 
				and actor.is_playable):
			return true
	for actor: Entity in _pending_actors:
		if (is_instance_valid(actor) 
				and not actor.is_queued_for_deletion() 
				and not actor.is_dead 
				and actor.is_playable):
			return true
	return false


func _is_visible_to_player(actor: Entity) -> bool:
	if not universe or not perception or not is_instance_valid(actor):
		return false
	var player: Entity = universe.current_player_entity
	if not is_instance_valid(player):
		return false
	return perception.visible_tiles(player).has(universe.board.get_origin(actor))


func _compare_actors(a: Entity, b: Entity) -> bool:
	if a == b:
		return false
	var a_speed: float = a.get_effective_speed()
	var b_speed: float = b.get_effective_speed()
	if not is_equal_approx(a_speed, b_speed):
		return a_speed > b_speed
	# Ties go to the entity that was active when the game started, then to the
	# order the entities appear in the scene.
	if a == _preferred_actor:
		return true
	if b == _preferred_actor:
		return false
	return actors.find(a) < actors.find(b)


## Hands the player turn to the next party member that can still act in this
## pass. It costs nothing and does not end anybody's turn.
func cycle_player(step: int = 1) -> bool:
	if state != State.PLAYER or not _party_phase or _party_pending.size() < 2:
		return false
	var index: int = _party_pending.find(current_actor)
	if index < 0:
		return false
	var next: Entity = _party_pending[posmod(index + step, _party_pending.size())]
	_begin_party_member(next)
	Journal.took_the_lead(next)
	return true
