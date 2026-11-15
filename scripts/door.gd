@tool
class_name Door
extends Base

@export var requires: Array[Goal] = []
@export var dispels: TileMapLayer = null
## When the requirements are met, how much time until showing the door.
@export var delay: float = 0.75

var has_been_revealed: bool = false
var delay_timer: Timer = null

@onready var wall: Wall = $Wall


func _ready() -> void:
	super._ready()
	collision_layer = 0
	collision_mask = 0
	delay_timer = Timer.new()
	delay_timer.one_shot = true
	delay_timer.wait_time = delay
	delay_timer.timeout.connect(_reveal_door)
	add_child(delay_timer)
	for goal in requires:
		if is_instance_valid(goal):
			goal.crated.connect(_on_crated)
	_refresh()


func _all_requirements_met() -> bool:
	if requires.is_empty():
		return false
	for goal in requires:
		if not is_instance_valid(goal) or not goal.is_crated():
			return false
	return true


func _on_crated(_has_crate: bool) -> void:
	_refresh()


## Applies the current requirement state. The door closes as soon as a crate is
## removed, and opens again after [member delay] once every goal is crated.
func _refresh() -> void:
	if _all_requirements_met():
		if wall.visible and delay_timer.is_stopped():
			delay_timer.start()
		return
	delay_timer.stop()
	_set_wall_visible(true)


func _reveal_door() -> void:
	if not _all_requirements_met():
		return
	_set_wall_visible(false)
	if has_been_revealed:
		return
	has_been_revealed = true
	AudioManager.play(Helper.IMPACT_BELL_HEAVY_001)
	if dispels:
		dispels.visible = false


func _set_wall_visible(_visible: bool) -> void:
	wall.visible = _visible
	wall.set_deferred("monitorable", _visible)
	wall.set_deferred("monitoring", _visible)
	walkable = not _visible
