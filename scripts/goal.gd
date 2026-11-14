@tool
class_name Goal
extends Base

func _ready() -> void:
	super._ready()
	#collision_layer = PhysicsLayer.GOALS
	#collision_mask = PhysicsLayer.WALLS | PhysicsLayer.CRATES | PhysicsLayer.HERO
	connect("area_entered", _on_area_entered)
	connect("area_exited", _on_area_exited)


func _on_area_entered(area: Area2D) -> void:
	if area is Crate:
		var c: Crate = area
		c.toggle_light(true)
		AudioManager.play(Helper.FORCE_FIELD_001)


func _on_area_exited(area: Area2D) -> void:
	if area is Crate:
		var c: Crate = area
		c.toggle_light(false)
