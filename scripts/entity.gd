@tool
class_name Entity
extends Base

@export var hit_points: int = 1
@export var max_hit_points: int = 1
@export var inventory: Array[Node2D] = []
@export var flying: bool = false:
	set(v):
		flying = v
		if not polygon:
			return
		if flying:
			if not flying_tween:
				#print(polygon.is_node_ready())
				#if polygon.is_node_ready():
				flying_tween = create_tween()
				flying_tween.tween_property(polygon, "position", Vector2(0, -4.0), 0.15).set_ease(Tween.EASE_IN)
				flying_tween.tween_property(polygon, "position", Vector2(0, 4.0), 0.15)
				flying_tween.set_loops()
			else:
				flying_tween.play()
		else:
			if flying_tween:
				flying_tween.stop()

var flying_tween: Tween = null
var visible_notifier: VisibleOnScreenNotifier2D = null

signal inventory_changed


func _ready() -> void:
	super._ready()
	collision_layer = PhysicsLayer.HERO
	collision_mask = PhysicsLayer.WALLS | PhysicsLayer.CRATES | PhysicsLayer.HERO
	visible_notifier = Helper.find_control(self, "VisibleOnScreenNotifier2D")
	if not visible_notifier:
		push_warning("No visible_notifier!")


func equip(item: Node2D) -> void:
	if not item:
		return
	if not inventory.has(item):
		return
	
	#var torch = Helper.TORCH.instantiate()
	#torch.scale = Vector2.ONE * 1.25
	#add_child(torch)

	#get_parent().add_child.call_deferred(torch)
	#torch.position = position


func take(item: Node2D) -> bool:
	if not item:
		return false
	item.get_parent().remove_child(item)
	inventory.append(item)
	inventory_changed.emit()
	return true
