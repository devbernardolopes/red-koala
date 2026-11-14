@tool
class_name Crate
extends Base


func _ready() -> void:
	super._ready()
	collision_layer = PhysicsLayer.CRATES
	collision_mask = PhysicsLayer.WALLS | PhysicsLayer.CRATES | PhysicsLayer.HERO | PhysicsLayer.GOALS
