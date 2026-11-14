@tool
class_name Entity
extends Base

@export var data: EntityData:
	set(v):
		data = v
@export var hit_points: int = 1
@export var max_hit_points: int = 1
@export var inventory: Array[ItemData] = []

var visible_notifier: VisibleOnScreenNotifier2D = null


func _ready() -> void:
	super._ready()
	collision_layer = PhysicsLayer.HERO
	collision_mask = PhysicsLayer.WALLS | PhysicsLayer.CRATES | PhysicsLayer.HERO
	visible_notifier = Helper.find_control(self, "VisibleOnScreenNotifier2D")
	if not visible_notifier:
		push_warning("No visible_notifier!")
	equip()


func equip() -> void:
	var torch = Helper.TORCH.instantiate()
	torch.scale = Vector2.ONE * 1.25
	add_child(torch)
	#get_parent().add_child.call_deferred(torch)
	#torch.position = position
