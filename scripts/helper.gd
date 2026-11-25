class_name Helper
extends Node

enum DiceAdvantage {
	DISADVANTAGE = -1,
	NONE = 0,
	ADVANTAGE = 1,
}

enum AnatomySide {
	LEFT = -1, 
	CENTER = 0,
	RIGHT = 1, 
}

enum AnatomyPosition {
	BACK = -1, 
	CENTER = 0,
	FRONT = 1, 
}

enum MysticModifier {
	CURSED = -1,
	NONE = 0,
	BLESSED = 1,
}

enum SkillCategory {
	DEFENSIVE = 1,
	OFFENSIVE = 2,
	MYSTICAL = 3,
	UTILITY = 4,
}

enum ElementType {
	GOAL = 1,
	CRATE = 2,
	WALL = 3,
	ENTITY = 4,
}

enum EntityTeam {
	NEUTRAL = 1,
	FRIEND = 2,
	FOE = 3,
}

## Eight logical directions. Visuals only distinguish their horizontal side.
enum Facing {
	NORTH,
	NORTH_EAST,
	EAST,
	SOUTH_EAST,
	SOUTH,
	SOUTH_WEST,
	WEST,
	NORTH_WEST,
}

enum MoveMode {
	WALK = 1,
	FLY = 2,
	PHASE = 3,
}

const LENGTH: int = 64
@warning_ignore("integer_division")
const HALF_LENGTH: int = LENGTH / 2
@warning_ignore("integer_division")
const QUARTER_LENGTH: int = HALF_LENGTH / 2
const MARGIN_1: int = 2
@warning_ignore("integer_division")
const MARGIN_2: int = LENGTH / 4
const RADIAL_LIGHT = preload("res://resources/lights/radial_light.tres")

const EQUIPPED_OFFSET_RIGHT: Vector2 = Vector2(QUARTER_LENGTH, 0.0)
const EQUIPPED_OFFSET_LEFT: Vector2 = Vector2(-QUARTER_LENGTH, 0.0)

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
const HUMANOID_CORPSE = preload("uid://bslwnv8q4raki")

#region CORPSES


#endregion

## Key = Level, Value = XP.
const LEVEL_CHART: Dictionary = {
	1: 0,
	2: 25,
	3: 50,
	4: 100,
	5: 200,
	6: 500,
	7: 1000,
	8: 5000,
	9: 10000,
	10: 25000,
	11: 50000,
	12: 100000,
	13: 150000,
	14: 200000,
	15: 250000,
	16: 300000,
	17: 350000,
	18: 400000,
	19: 450000,
	20: 500000,
	21: 550000,
	22: 600000,
	23: 650000,
	24: 700000,
	25: 750000,
	26: 800000,
	27: 850000,
	28: 900000,
	29: 950000,
	30: 1000000,
	31: 1100000,
	32: 1200000,
	33: 1300000,
	34: 1400000,
	35: 1500000,
	36: 1600000,
	37: 1700000,
	38: 1800000,
	39: 1900000,
	40: 2000000,
}


## Highest level whose threshold in [constant LEVEL_CHART] is at most
## [param xp]. Never exceeds the chart's maximum level.
static func level_for_xp(xp: int) -> int:
	var best: int = 1
	for level: int in LEVEL_CHART:
		if LEVEL_CHART[level] <= xp and level > best:
			best = level
	return best


## Whether [param a] considers [param b] an enemy. Neutral entities never
## initiate hostilities, but they can still be attacked by a foe.
static func are_hostile(a: Entity, b: Entity) -> bool:
	if not a or not b or a == b:
		return false
	return ((a.team == EntityTeam.FOE and b.team == EntityTeam.FRIEND) 
			or (a.team == EntityTeam.FRIEND and b.team == EntityTeam.FOE))


static func facing_from_direction(direction: Vector2i) -> Facing:
	var dir: Vector2i = Vector2i(signi(direction.x), signi(direction.y))
	match dir:
		Vector2i.UP:
			return Facing.NORTH
		Vector2i(1, -1):
			return Facing.NORTH_EAST
		Vector2i.RIGHT:
			return Facing.EAST
		Vector2i(1, 1):
			return Facing.SOUTH_EAST
		Vector2i.DOWN:
			return Facing.SOUTH
		Vector2i(-1, 1):
			return Facing.SOUTH_WEST
		Vector2i.LEFT:
			return Facing.WEST
		_:
			return Facing.NORTH_WEST


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
