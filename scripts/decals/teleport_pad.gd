@tool
class_name TeleportPad
extends Base

@export var active: bool = true
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
	if destination.dispels:
		destination.dispels.visible = false
