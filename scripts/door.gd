@tool
class_name Door
extends Base

@export var requires: Array[Goal] = []
@export var dispels: TileMapLayer = null

var progress: int = 0

@onready var wall: Wall = $Wall

## When the requirements are met, how much time until showing the door.
var delay: float = 0.75
var delay_timer: Timer = null


func _ready() -> void:
	super._ready()
	collision_layer = 0
	collision_mask = 0
	if requires and not requires.is_empty():
		for goal in requires:
			goal.connect("crated", _on_crated)
		delay_timer = Timer.new()
		delay_timer.one_shot = true
		delay_timer.wait_time = delay
		delay_timer.timeout.connect(_reveal_door)
		add_child(delay_timer)
	walkable = not wall.visible


func _reveal_door() -> void:
	print("A secret is revealed.")
	AudioManager.play(Helper.IMPACT_BELL_HEAVY_001)
	wall.visible = false
	wall.set_deferred("monitorable", false)
	wall.set_deferred("monitoring", false)
	walkable = not wall.visible
	if dispels:
		dispels.visible = false


func _on_crated(has_crate: bool) -> void:
	if has_crate:
		progress += 1
	else:
		progress -= 1
	if progress == requires.size():
		if not wall:
			print("oops")
		delay_timer.start()
	else:
		wall.visible = true
		wall.set_deferred("monitorable", true)
		wall.set_deferred("monitoring", true)
		walkable = not wall.visible
