extends Node2D

enum ELEMENT_TYPE {
	GOAL = 1,
	CRATE = 2,
	WALL = 3,
	HERO = 4,
}

const LEVELS_DIR: String = "res://resources/levels/"
const WALL_SCENE = preload("res://scenes/wall.tscn")


@export var hero: Hero = null

var goals_node: Node2D = null
var crates_node: Node2D = null
var walls_node: Node2D = null
var elements: Array[Node2D] = []


func _ready() -> void:
	if not hero:
		push_warning("No Hero!")
	if not goals_node:
		goals_node = find_child("Goals")
	if not crates_node:
		crates_node = find_child("Crates")
	if not walls_node:
		walls_node = find_child("Walls")
	#_clear_universe()
	#_load_level(2)
	_load_elements()
	AudioManager.set_listener_target(hero)

func _input(event: InputEvent) -> void:
	if event.is_echo():
		return
	# TODO: Is this called two times? Like, on pressed down and on release?
	if event.is_action("reset"):
		_clear_universe()
		_load_elements()
		return
	if not hero:
		return
	var direction: Vector2 = Input.get_vector("left", "right", "up", "down")
	if not direction:
		return
	direction = direction.normalized()
	var move_to: Vector2 = Vector2.ZERO
	var tiles_at: Array[Node2D] = []
	match direction:
		Vector2.UP:
			move_to = _get_tile(hero) + Vector2.UP
		Vector2.RIGHT:
			move_to = _get_tile(hero) + Vector2.RIGHT
		Vector2.DOWN:
			move_to = _get_tile(hero) + Vector2.DOWN
		Vector2.LEFT:
			move_to = _get_tile(hero) + Vector2.LEFT
		_:
			return
	tiles_at = _probe_tile(move_to)
	if not tiles_at or tiles_at.is_empty() or (tiles_at.size() == 1 and tiles_at[0] is Goal):
		_move(hero, direction)
	else:
		var c: Crate = null
		for t in tiles_at:
			if t is Crate:
				c = t
				break
		if c:
			var crate_tiles_at: Array[Node2D] = _probe_tile(move_to + direction)
			if not crate_tiles_at or crate_tiles_at.is_empty() or (crate_tiles_at.size() == 1 and crate_tiles_at[0] is Goal):
				_move(hero, direction)
				_move(c, direction)


func _load_elements() -> void:
	var children: Array[Node] = find_children("*")
	if children and not children.is_empty():
		for child in children:
			if child.is_queued_for_deletion():
				#print(child, " is queued for deletion.")
				continue
			if child.is_in_group(&"Elements"):
				elements.append(child)
				#print(child)
			#else:
				#print(child, " NOT in group Elements.")
	#print(elements.size())


func _create_element_at(type: ELEMENT_TYPE, pos: Vector2i) -> void:
	match type:
		ELEMENT_TYPE.WALL:
			var w: Wall = Wall.new()
			walls_node.add_child(w)
			_position_element(w, pos)
			elements.append(w)
		ELEMENT_TYPE.GOAL:
			var g: Goal = Goal.new()
			goals_node.add_child(g)
			_position_element(g, pos)
			elements.append(g)
		ELEMENT_TYPE.CRATE:
			var c: Crate = Crate.new()
			crates_node.add_child(c)
			_position_element(c, pos)
			elements.append(c)
		ELEMENT_TYPE.HERO:
			var h: Hero = Hero.new()
			add_child(h)
			_position_element(h, pos)
			elements.append(h)
			hero = h


func _load_level(num: int = 0) -> void:
	var dir: DirAccess = DirAccess.open(LEVELS_DIR)
	if not dir:
		return
	var files: PackedStringArray = dir.get_files()
	if not files or files.is_empty():
		return
	for file in files:
		if file.get_extension() == "txt":
			if num and not file.get_basename().ends_with(type_convert(num, TYPE_STRING)):
				continue
			var fa: FileAccess = FileAccess.open(LEVELS_DIR + file, FileAccess.READ)
			if not fa:
				return
			_clear_universe()
			var row: int = 0
			while not fa.eof_reached():
				var line: String = fa.get_line()
				var col: int = 0
				for c in line:
					match c:
						"#":
							_create_element_at(ELEMENT_TYPE.WALL, Vector2(col, row))
						"p":
							_create_element_at(ELEMENT_TYPE.HERO, Vector2(col, row))
						"@":
							_create_element_at(ELEMENT_TYPE.HERO, Vector2(col, row))
						"P":
							_create_element_at(ELEMENT_TYPE.GOAL, Vector2(col, row))
							_create_element_at(ELEMENT_TYPE.HERO, Vector2(col, row))
						"+":
							_create_element_at(ELEMENT_TYPE.GOAL, Vector2(col, row))
							_create_element_at(ELEMENT_TYPE.HERO, Vector2(col, row))
						"b":
							_create_element_at(ELEMENT_TYPE.CRATE, Vector2(col, row))
						"$":
							_create_element_at(ELEMENT_TYPE.CRATE, Vector2(col, row))
						"B":
							_create_element_at(ELEMENT_TYPE.GOAL, Vector2(col, row))
							_create_element_at(ELEMENT_TYPE.CRATE, Vector2(col, row))
						"*":
							_create_element_at(ELEMENT_TYPE.GOAL, Vector2(col, row))
							_create_element_at(ELEMENT_TYPE.CRATE, Vector2(col, row))
						".":
							_create_element_at(ELEMENT_TYPE.GOAL, Vector2(col, row))
					col += 1
				row += 1
			return


func _clear_universe() -> void:
	var children: Array[Node] = find_children("*")
	if children and not children.is_empty():
		for child in children:
			if child.is_in_group(&"Elements"):
				child.queue_free()
	elements.clear()


func _move(element: Node2D, dir: Vector2 = Vector2.ZERO) -> void:
	if not element:
		return
	if not dir:
		return
	element.position += dir * Helper.LENGTH


func _get_tile(element: Node2D) -> Vector2:
	if not element:
		return Vector2.ZERO
	return Vector2((element.position.x - Helper.HALF_LENGTH) / Helper.LENGTH, 
			(element.position.y - Helper.HALF_LENGTH) / Helper.LENGTH)


func _probe_tile(tile: Vector2) -> Array[Node2D]:
	var result: Array[Node2D] = []
	if not tile:
		return result
	if not elements:
		return result
	if elements.is_empty():
		return result
	for element in elements:
		if tile == _get_tile(element):
			result.append(element)
	return result


func _position_element(element: Node2D, at: Vector2) -> void:
	if not element:
		return
	element.position.x = (at.x * Helper.LENGTH) + Helper.HALF_LENGTH
	element.position.y = (at.y * Helper.LENGTH) + Helper.HALF_LENGTH
