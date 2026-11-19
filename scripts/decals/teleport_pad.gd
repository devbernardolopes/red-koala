@tool
class_name TeleportPad
extends Base

@export var active: bool = true:
	set(v):
		active = v
		toggle_light(v)
@export var destination: TeleportPad = null
@export var dispels: TileMapLayer = null


func _ready() -> void:
	super._ready()


func teleport(element: Node2D) -> void:
	if not element:
		return
	if not active:
		return
	if not destination:
		return
	element.position = destination.position
	if element == Journal.speaker:
		Journal.teleported()
	if destination.dispels:
		destination.dispels.visible = false
	AudioManager.play(Helper.LASER_LARGE_004)
