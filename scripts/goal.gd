@tool
class_name Goal
extends Base

signal crated(has_crate: bool)

## Crates currently overlapping this goal. Kept as a collection so multiple crates
## on the same goal don't emit duplicate enter/exit events.
var crates: Array[Crate] = []


func _ready() -> void:
	super._ready()
	collision_layer = PhysicsLayer.GOALS
	collision_mask = PhysicsLayer.WALLS | PhysicsLayer.CRATES | PhysicsLayer.HERO
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)


func is_crated() -> bool:
	for i: int in range(crates.size() - 1, -1, -1):
		if not is_instance_valid(crates[i]):
			crates.remove_at(i)
	return not crates.is_empty()


func _on_area_entered(area: Area2D) -> void:
	if not area is Crate or crates.has(area):
		return
	crates.append(area as Crate)
	if crates.size() != 1:
		return
	crated.emit(true)
	(area as Crate).toggle_light(true)
	AudioManager.play(Helper.FORCE_FIELD_001)


func _on_area_exited(area: Area2D) -> void:
	if not area is Crate or not crates.has(area):
		return
	crates.erase(area)
	if not crates.is_empty():
		return
	crated.emit(false)
	(area as Crate).toggle_light(false)
