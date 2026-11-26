@tool
class_name Item
extends Base

signal mystic_changed

@export var mystic_modifier: Helper.MysticModifier = Helper.MysticModifier.NONE
## Whether the party has learned this item's [member mystic_modifier]. Once
## revealed it stays revealed for this item, even after it changes hands.
@export var mystic_known: bool = false
@export var properties: Array[PropertyData] = []
@export var is_equipped: bool = false


func _ready() -> void:
	super._ready()
	collision_layer = PhysicsLayer.ITEMS
	collision_mask = 0


func get_display_name() -> String:
	if data and not data.name.is_empty():
		return data.name
	return name


## Changes the true mystic modifier, for future bless and uncurse effects.
## Knowledge is unaffected: a known item keeps its known state and reports the
## new value, while an unknown item stays unknown. Emits [signal mystic_changed]
## so the holder can refresh the HUD.
func set_mystic_modifier(value: Helper.MysticModifier) -> void:
	if mystic_modifier == value:
		return
	mystic_modifier = value
	mystic_changed.emit()
