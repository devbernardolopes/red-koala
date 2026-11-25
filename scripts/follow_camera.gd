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
		_snap_to_target()
@export var follow_type: FollowType = FollowType.CENTERED
@export var max_zoom_in: float = 1.5
@export var max_zoom_out: float = 0.5
@export var zoom_factor: float = 0.25


func _ready() -> void:
	if not target:
		return
	_snap_to_target()
	#target.visible_notifier.connect("screen_exited", _snap_to_target)


func _process(_delta: float) -> void:
	if not target:
		return
	if follow_type == FollowType.CENTERED:
		# Follow the visual slide, not the instant logical position.
		global_position = target.get_camera_anchor()


func _snap_to_target() -> void:
	if not target:
		return
	global_position = target.get_camera_anchor()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("zoom_in"):
		_step_zoom(zoom.x + zoom_factor)
	elif event.is_action_pressed("zoom_out"):
		_step_zoom(zoom.x - zoom_factor)


func _step_zoom(value: float) -> void:
	var _value: float = clampf(value, max_zoom_out, max_zoom_in)
	zoom = Vector2(_value, _value)
