@tool
class_name Door
extends Base

@export var requires: Array[Goal] = []
@export var dispels: TileMapLayer = null

var progress: int = 0

@onready var wall: Wall = $Wall


func _ready() -> void:
	super._ready()
	collision_layer = 0
	collision_mask = 0
	if requires and not requires.is_empty():
		for goal in requires:
			goal.connect("crated", _on_crated)


func _on_crated(has_crate: bool) -> void:
	if has_crate:
		progress += 1
	else:
		progress -= 1
	if progress == requires.size():
		if not wall:
			print("oops")
		print("A secret is revealed.")
		wall.visible = false
		wall.set_deferred("monitorable", false)
		wall.set_deferred("monitoring", false)
		if dispels:
			dispels.visible = false
	else:
		wall.visible = true
		wall.set_deferred("monitorable", true)
		wall.set_deferred("monitoring", true)
