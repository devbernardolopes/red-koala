@tool
class_name Item
extends Base


func _ready() -> void:
	super._ready()
	collision_layer = PhysicsLayer.ITEMS
	collision_mask = 0
