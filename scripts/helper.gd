class_name Helper
extends Node

enum ELEMENT_TYPE {
	GOAL = 1,
	CRATE = 2,
	WALL = 3,
	HERO = 4,
}

const LENGTH: int = 64
@warning_ignore("integer_division")
const HALF_LENGTH: int = LENGTH / 2
const MARGIN_1: int = 2
@warning_ignore("integer_division")
const MARGIN_2: int = LENGTH / 4
const RADIAL_LIGHT = preload("res://resources/lights/radial_light.tres")

#region SOUNDS
## Crate on goal.
const FORCE_FIELD_001 = preload("uid://bjav7rlibej4q")
## Door revealed.
const IMPACT_BELL_HEAVY_001 = preload("uid://233in7fel5ws")
## Teleport.
const LASER_LARGE_004 = preload("uid://bojat5bcaoa58")

#endregion

#region MUSICS
const FOREBODING_THEME = preload("uid://bvidkrp2c22ub")

#endregion

#region ITEMS
const TORCH = preload("uid://tcihe7kj34wp")
const SWORD = preload("uid://fgb6up4u4dbg")
const GOLD = preload("uid://ciij5gesrk4xp")

#endregion


static func has_property(target: Node, property: String) -> bool:
	if not target:
		return false
	var _properties: Array[Dictionary] = target.get_property_list()
	if not _properties or _properties.is_empty():
		return false
	for i in _properties.size():
		var _p = _properties[i].get("name")
		if _p and _p is String:
			if _p == property:
				return true
	return false


static func find_control(_parent: Node, _class_name: String, _name: StringName = &"") -> Node:
	if not _parent:
		print("not _parent")
		return null
	if not _class_name:
		print("not _class_name")
		return null
	for child: Node in _parent.find_children("*"):
		# Try to match by the built-in class name first, then by the 
		# user-authored class_name.
		# TODO: I don't know if this is bug-prone! Must review in the future.
		if child.get_class() == _class_name:
			if _name:
				if child.name == _name:
					return child
			else:
				return child
		var _script = child.get_script()
		if _script:
			var _global_name = _script.get_global_name()
			if _global_name:
				if _global_name == _class_name:
					if _name:
						if child.name == _name:
							return child
					else:
						return child
	return null
