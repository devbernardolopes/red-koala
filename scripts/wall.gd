@tool
class_name Wall
extends Base


func _ready() -> void:
	super._ready()
	collision_layer = PhysicsLayer.WALLS
	collision_mask = PhysicsLayer.WALLS | PhysicsLayer.CRATES | PhysicsLayer.HERO
