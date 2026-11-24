class_name HeldMove
extends RefCounted

## State for a direction key the player is holding down.
##
## [Universe] owns one instance and drives it from [method Node._process]. This
## class only keeps the held action, the actor that started it and the repeat
## cooldown, so the turn loop stays in charge of what a step actually does.
## The actor's [signal Entity.damaged] is connected while the hold is active:
## taking a hit cancels the hold before the player can walk away from it.

## Delay before the first repeat, so a normal tap can never double-step.
const INITIAL_DELAY: float = 0.18
## Seconds between repeats. Must be at least the move slide duration, so one
## step finishes before the next one starts.
const REPEAT_INTERVAL: float = 0.1

var action: StringName = &""
var actor: Entity = null
var cooldown: float = 0.0
var active: bool = false


func start(new_action: StringName, new_actor: Entity) -> void:
	cancel()
	action = new_action
	actor = new_actor
	cooldown = INITIAL_DELAY
	active = is_instance_valid(actor)
	if active:
		actor.damaged.connect(_on_actor_damaged)


func cancel() -> void:
	if is_instance_valid(actor) and actor.damaged.is_connected(_on_actor_damaged):
		actor.damaged.disconnect(_on_actor_damaged)
	active = false
	action = &""
	actor = null
	cooldown = 0.0


func _on_actor_damaged(_amount: int, _source: Entity) -> void:
	cancel()
