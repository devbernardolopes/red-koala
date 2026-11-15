extends Node2D

const LEVELS_DIR: String = "res://resources/levels/"
const WALL_SCENE = preload("res://scenes/wall.tscn")

@export var hero: Hero = null

var goals_node: Node2D = null
var crates_node: Node2D = null
var walls_node: TileMapLayer = null
var elements: Array[Node] = []

@onready var canvas_modulate: CanvasModulate = $CanvasModulate
@onready var fog_of_war: Node2D = $FogOfWar
@onready var lightweight_crt: ColorRect = $Filters/LightweightCrt


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
	if canvas_modulate:
		canvas_modulate.visible = true
	if fog_of_war:
		fog_of_war.visible = true
	if lightweight_crt:
		lightweight_crt.visible = true
	#_dispel_fog_of_war()


func _unhandled_input(event: InputEvent) -> void:
	if not hero:
		return
	if event.is_action_pressed("take"):
		_take_item()
		get_viewport().set_input_as_handled()
		return
	var direction: Vector2 = Vector2.ZERO
	if event.is_action_pressed("up"):
		direction = Vector2.UP
	elif event.is_action_pressed("down"):
		direction = Vector2.DOWN
	elif event.is_action_pressed("left"):
		direction = Vector2.LEFT
	elif event.is_action_pressed("right"):
		direction = Vector2.RIGHT
	if direction == Vector2.ZERO:
		return
	_try_move(direction)
	get_viewport().set_input_as_handled()


func _take_item() -> void:
	var tiles_at: Array[Node2D] = _probe_tile(_get_tile(hero))
	for t in tiles_at:
		if not t is Item:
			continue
		var item: Item = t
		if item.data is ItemData and hero.take(item):
			elements.erase(item)
		return


func _try_move(direction: Vector2) -> void:
	var move_to: Vector2 = _get_tile(hero) + direction
	var tiles_at: Array[Node2D] = _probe_tile(move_to)
	for t in tiles_at:
		if t is Base and not (t as Base).walkable:
			_try_push(tiles_at, move_to, direction)
			return
	_move(hero, direction)


func _try_push(tiles_at: Array[Node2D], move_to: Vector2, direction: Vector2) -> void:
	var crate: Crate = null
	for t in tiles_at:
		if t is Crate:
			crate = t as Crate
			break
	if not crate:
		return
	# The hero takes the crate's former tile, so it must be free for everything
	# else on it (e.g. a closed door under the crate).
	for t in tiles_at:
		if t != crate and t is Base and not (t as Base).walkable:
			return
	if not _can_push_crate_to(_probe_tile(move_to + direction)):
		return
	_move(hero, direction)
	_move(crate, direction)


func _can_push_crate_to(tiles_at: Array[Node2D]) -> bool:
	if tiles_at.is_empty():
		return true
	if tiles_at.size() != 1:
		return false
	var target: Node2D = tiles_at[0]
	if target is Goal:
		return true
	return target is Door and (target as Door).walkable


#func _dispel_fog_of_war() -> void:
	#if not fog_of_war:
		#return
	#if not hero:
		#return
	#if not elements or elements.is_empty():
		#return
	#var walls: Array[Wall] = []
	#for element in elements:
		#if element is Wall:
			#var w: Wall = element
			#walls.append(w)
			##print(_get_tile(w))
	##print(walls)
	#fog_of_war.set_cell(_get_tile(hero))


func _load_elements() -> void:
	var children: Array[Node] = find_children("*")
	if children and not children.is_empty():
		for child in children:
			if child.is_queued_for_deletion():
				continue
			if child.is_in_group(&"Elements"):
				elements.append(child)
				if child is Door:
					if not child.requires or child.requires.is_empty():
						push_warning(child.name, " has no requirements!")
				if Helper.has_property(child, "data") and child is Item:
					if not child.data:
						push_warning(child.name, " has no data!")
	if walls_node:
		for x in range(walls_node.get_used_rect().position.x, walls_node.get_used_rect().size.x):
			for y in range(walls_node.get_used_rect().position.y, walls_node.get_used_rect().size.y):
				if not walls_node.get_cell_atlas_coords(Vector2i(x, y)) == Vector2i(-1, -1):
					var w: Wall = Wall.new()
					w.walkable = false
					_position_element(w, Vector2(x, y))
					elements.append(w)
	#print(elements.size())


func _create_element_at(type: Helper.ELEMENT_TYPE, pos: Vector2i) -> void:
	match type:
		# TODO: Refactor this because now walls live in a TileMapLayer
		#ELEMENT_TYPE.WALL:
			#var w: Wall = Wall.new()
			#walls_node.add_child(w)
			#_position_element(w, pos)
			#elements.append(w)
		Helper.ELEMENT_TYPE.GOAL:
			var g: Goal = Goal.new()
			goals_node.add_child(g)
			_position_element(g, pos)
			elements.append(g)
		Helper.ELEMENT_TYPE.CRATE:
			var c: Crate = Crate.new()
			crates_node.add_child(c)
			_position_element(c, pos)
			elements.append(c)
		Helper.ELEMENT_TYPE.HERO:
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
							_create_element_at(Helper.ELEMENT_TYPE.WALL, Vector2(col, row))
						"p":
							_create_element_at(Helper.ELEMENT_TYPE.HERO, Vector2(col, row))
						"@":
							_create_element_at(Helper.ELEMENT_TYPE.HERO, Vector2(col, row))
						"P":
							_create_element_at(Helper.ELEMENT_TYPE.GOAL, Vector2(col, row))
							_create_element_at(Helper.ELEMENT_TYPE.HERO, Vector2(col, row))
						"+":
							_create_element_at(Helper.ELEMENT_TYPE.GOAL, Vector2(col, row))
							_create_element_at(Helper.ELEMENT_TYPE.HERO, Vector2(col, row))
						"b":
							_create_element_at(Helper.ELEMENT_TYPE.CRATE, Vector2(col, row))
						"$":
							_create_element_at(Helper.ELEMENT_TYPE.CRATE, Vector2(col, row))
						"B":
							_create_element_at(Helper.ELEMENT_TYPE.GOAL, Vector2(col, row))
							_create_element_at(Helper.ELEMENT_TYPE.CRATE, Vector2(col, row))
						"*":
							_create_element_at(Helper.ELEMENT_TYPE.GOAL, Vector2(col, row))
							_create_element_at(Helper.ELEMENT_TYPE.CRATE, Vector2(col, row))
						".":
							_create_element_at(Helper.ELEMENT_TYPE.GOAL, Vector2(col, row))
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
	#_dispel_fog_of_war()


func _get_tile(element: Node2D) -> Vector2:
	if not element:
		return Vector2.ZERO
	return Vector2((element.position.x - Helper.HALF_LENGTH) / Helper.LENGTH, 
			(element.position.y - Helper.HALF_LENGTH) / Helper.LENGTH)


func _probe_tile(tile: Vector2) -> Array[Node2D]:
	var result: Array[Node2D] = []
	#if not tile:
		#return result
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
