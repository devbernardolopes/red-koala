class_name FollowCamera
extends Camera2D

enum FollowType {
	CENTERED = 1,
	STATIC = 2,
}

@export var target: Entity = null:
	set(v):
		target = v
		if not target:
			return
		target_last_postition = target.position
		_snap_to_target()
@export var follow_type: FollowType = FollowType.CENTERED
@export var max_zoom_in: float = 1.5
@export var max_zoom_out: float = 0.5
@export var zoom_factor: float = 0.25

var target_last_postition: Vector2 = Vector2.ZERO


func _ready() -> void:
	if not target:
		return
	_snap_to_target()
	#target.visible_notifier.connect("screen_exited", _snap_to_target)
	#target.visible_notifier.connect("screen_exited", _snap_to_target)


func _process(_delta: float) -> void:
	if not target:
		return
	if target_last_postition != target.position:
		target_last_postition = target.position
		if follow_type == FollowType.CENTERED:
			_snap_to_target()


func _snap_to_target() -> void:
	if not target:
		return
	global_position = target.global_position
