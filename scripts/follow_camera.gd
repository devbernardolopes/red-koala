class_name FollowCamera
extends Camera2D

@export var target: Hero = null:
	set(v):
		target = v
		_snap_to_target()


func _ready() -> void:
	if not target:
		return
	_snap_to_target()
	#target.visible_notifier.connect("screen_entered", _screen_entered)
	target.visible_notifier.connect("screen_exited", _snap_to_target)

#
#func _screen_exited() -> void:
	#print("ooo")


func _snap_to_target() -> void:
	if not target:
		return
	global_position = target.global_position
