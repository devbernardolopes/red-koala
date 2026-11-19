@tool
class_name Item
extends Base

@export var mystic_modifier: Helper.MysticModifier = Helper.MysticModifier.NONE
@export var is_equipped: bool = false


func _ready() -> void:
	super._ready()
	collision_layer = PhysicsLayer.ITEMS
	collision_mask = 0


func get_display_name() -> String:
	if data and not data.name.is_empty():
		return data.name
	return name
