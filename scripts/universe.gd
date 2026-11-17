extends Node2D

const LEVELS_DIR: String = "res://resources/levels/"
const WALL_SCENE = preload("res://scenes/wall.tscn")

@export var hero: Hero = null

var decals_node: Node2D = null
var goals_node: Node2D = null
var items_node: Node2D = null
var crates_node: Node2D = null
var entities_node: Node2D = null
var walls_node: TileMapLayer = null
var elements: Array[Node] = []
var journal_label: Label = null
var ground_label: Label = null
var inventory_control: Control = null

var current_filter: Control = null
var filter_list: Array[Control] = []

var current_inventory_item: Node2D = null

var inventory_toggled: bool = false

@onready var canvas_modulate: CanvasModulate = $CanvasModulate
@onready var fog_of_war: Node2D = $FogOfWar
@onready var filters: CanvasLayer = $Filters


func _ready() -> void:
	if not decals_node:
		decals_node = find_child("Decals")
	if not goals_node:
		goals_node = find_child("Goals")
	if not items_node:
		items_node = find_child("Items")
	if not crates_node:
		crates_node = find_child("Crates")
	if not crates_node:
		crates_node = find_child("Crates")
	if not walls_node:
		walls_node = find_child("Walls")
	if not entities_node:
		entities_node = find_child("Entities")
	if not hero:
		push_warning("No Hero!")
	journal_label = Helper.find_control(self, "Label", &"Journal")
	ground_label = Helper.find_control(self, "Label", &"Ground")
	inventory_control = Helper.find_control(self, "VBoxContainer", &"InventoryContainer")
	_load_elements()
	hero.inventory_changed.connect(_update_inventory)
	AudioManager.set_listener_target(hero)
	if fog_of_war:
		fog_of_war.visible = true
	if canvas_modulate:
		canvas_modulate.visible = true
	if filters:
		filters.visible = true
		for filter in filters.get_children():
			filter_list.append(filter)
			if filter.visible:
				current_filter = filter
		filter_list.append(null)
	_update_journal()
	_update_inventory()
	_update_ground_label()
	_dispel_fog_of_war()
	MusicPlayer.play_music(Helper.FOREBODING_THEME, true)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_toggle_canvas_modulate"):
		if not canvas_modulate:
			return
		canvas_modulate.visible = !canvas_modulate.visible
	if event.is_action_pressed("debug_cycle_filters"):
		if not filters:
			return
		if not filter_list:
			return
		#print(filter_list)
		if current_filter is Control:
			current_filter.visible = false
		var filter_index: int = filter_list.find(current_filter)
		if filter_index < filter_list.size() - 1:
			current_filter = filter_list.get(filter_index + 1)
		else:
			current_filter = filter_list.front()
		if current_filter:
			current_filter.visible = true


func _process(_delta: float) -> void:
	inventory_toggled = false
	if Input.is_action_pressed("inventory_modifier"):
		inventory_toggled = true


func _drop(item: Item) -> void:
	if not item:
		return
	if not items_node:
		return
	hero.drop(current_inventory_item)
	items_node.add_child(item)
	elements.append(item)
	for tile in _probe_tile(_get_tile(item)):
		if tile is TeleportPad:
			(tile as TeleportPad).teleport(item)
	_update_ground_label()


func _unhandled_input(event: InputEvent) -> void:
	if not hero:
		return
	if event.is_action_pressed("take"):
		_take_item()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("drop"):
		_drop(current_inventory_item)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("equip"):
		if not current_inventory_item:
			return
		hero.equip(current_inventory_item)
		get_viewport().set_input_as_handled()
		return
	if inventory_toggled:
		if not current_inventory_item:
			return
		var index: int = hero.inventory.find(current_inventory_item)
		if event.is_action_pressed("up"):
			if index - 1 < 0:
				current_inventory_item = hero.inventory.back()
			else:
				current_inventory_item = hero.inventory[index - 1]
			_update_inventory()
		elif event.is_action_pressed("down"):
			if index + 1 > hero.inventory.size() - 1:
				current_inventory_item = hero.inventory.front()
			else:
				current_inventory_item = hero.inventory[index + 1]
			_update_inventory()
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


func _update_journal() -> void:
	if not journal_label:
		return
	if not hero:
		return
	journal_label.text = ""


func _update_inventory() -> void:
	if not inventory_control:
		return
	if not hero:
		return
	for child in inventory_control.get_children():
		child.queue_free()
	if not hero.inventory:
		current_inventory_item = null
		return
	for item in hero.inventory:
		if not item:
			continue
		if not current_inventory_item or not hero.inventory.has(current_inventory_item):
			current_inventory_item = item
		var l: Label = Label.new()
		l.text = item.name
		if Helper.has_property(item, "data"):
			if not item.data:
				push_warning(item, " has no data!")
			else:
				l.text = item.data.name
		if item.is_equipped:
			l.text = "(e) " + l.text
		if current_inventory_item == item:
			#l.text = "-> " + l.text
			l.add_theme_color_override("font_outline_color", Color.RED)
			l.add_theme_constant_override("outline_size", 2)
		inventory_control.add_child(l)


func _update_ground_label() -> void:
	if not ground_label:
		return
	ground_label.text = ""
	var tiles_at: Array[Node2D] = _probe_tile(_get_tile(hero))
	for t in tiles_at:
		if not t is Item:
			continue
		var item: Item = t
		if item.data is ItemData:
			ground_label.text += item.data.name + ", "
	ground_label.text = ground_label.text.trim_suffix(", ")


func _dispel_fog_of_war() -> void:
	if not hero:
		return
	if not fog_of_war:
		return
	var fog_layer: TileMapLayer = Helper.find_control(fog_of_war, "TileMapLayer", &"FogFull")
	if not fog_layer:
		return
	var center_pos: Vector2 = _get_tile(hero)
	for i in range(center_pos.x - hero.fov, center_pos.x + hero.fov):
		for j in range(center_pos.y - hero.fov, center_pos.y + hero.fov):
			fog_layer.set_cell(Vector2i(i, j))
	#var fl_x: int = fog_layer.get_used_rect().size.x
	#var fl_y: int = fog_layer.get_used_rect().size.y
	#print(fog_layer.get_used_rect().position.x)
	

func _take_item() -> void:
	var tiles_at: Array[Node2D] = _probe_tile(_get_tile(hero))
	for t in tiles_at:
		if not t is Item:
			continue
		var item: Item = t
		if item.data is ItemData and hero.take(item):
			elements.erase(item)
			_update_ground_label()
		return


func _try_move(direction: Vector2) -> void:
	var move_to: Vector2 = _get_tile(hero) + direction
	var tiles_at: Array[Node2D] = _probe_tile(move_to)
	for t in tiles_at:
		if t is Base:
			if not (t as Base).walkable:
				if (t as Base).pushable:
					_try_push(tiles_at, move_to, direction)
					return
				elif hero.is_phasing:
					_move(hero, direction)
					return
				return
	_move(hero, direction)


func _try_push(tiles_at: Array[Node2D], move_to: Vector2, direction: Vector2) -> void:
	# TODO: Refactor this because not everything that is pushable is a Crate.
	var crate: Crate = null
	for t in tiles_at:
		if t.pushable:
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
	## TODO: Add a sound for crate moving?
	_move(crate, direction)


func _can_push_crate_to(tiles_at: Array[Node2D]) -> bool:
	if tiles_at.is_empty():
		return true
	for tile in tiles_at:
		if not tile.walkable:
			return false
	return true
	#if tiles_at.size() != 1:
		#return false
	#var target: Node2D = tiles_at[0]
	#if target is Goal:
		#return true
	#return target is Door and (target as Door).walkable


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
				if child is Goal:
					if not child.walkable:
						push_warning(child.name, " isn't walkable!")
				if child is Door:
					if not child.requires or child.requires.is_empty():
						push_warning(child.name, " has no requirements!")
				if child is TeleportPad:
					if not child.destination:
						push_warning(child.name, " has no destination!")
				if Helper.has_property(child, "data") and child is Item:
					if not child.data:
						push_warning(child.name, " has no data!")
	# Now we deal with the tile maps.
	#if decals_node:
		#for x in range(decals_node.get_used_rect().position.x, decals_node.get_used_rect().size.x):
			#for y in range(decals_node.get_used_rect().position.y, decals_node.get_used_rect().size.y):
				#if not decals_node.get_cell_atlas_coords(Vector2i(x, y)) == Vector2i(-1, -1):
					#var w: Wall = Wall.new()
					#w.walkable = false
					#_position_element(w, Vector2(x, y))
					#elements.append(w)
	if walls_node:
		for x in range(walls_node.get_used_rect().position.x, walls_node.get_used_rect().size.x):
			for y in range(walls_node.get_used_rect().position.y, walls_node.get_used_rect().size.y):
				if not walls_node.get_cell_atlas_coords(Vector2i(x, y)) == Vector2i(-1, -1):
					var w: Wall = Wall.new()
					w.walkable = false
					_position_element(w, Vector2(x, y))
					elements.append(w)

## @deprecated It is being used when loading levels from file but there will be
## no more file loading in the future.
func _create_element_at(type: Helper.ElementType, pos: Vector2i) -> void:
	match type:
		# TODO: Refactor this because now walls live in a TileMapLayer
		#ElementType.WALL:
			#var w: Wall = Wall.new()
			#walls_node.add_child(w)
			#_position_element(w, pos)
			#elements.append(w)
		Helper.ElementType.GOAL:
			var g: Goal = Goal.new()
			goals_node.add_child(g)
			_position_element(g, pos)
			elements.append(g)
		Helper.ElementType.CRATE:
			var c: Crate = Crate.new()
			crates_node.add_child(c)
			_position_element(c, pos)
			elements.append(c)
		Helper.ElementType.HERO:
			var h: Hero = Hero.new()
			add_child(h)
			_position_element(h, pos)
			elements.append(h)
			hero = h

## @deprecated: There will be no more level loading from files in the future.
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
							_create_element_at(Helper.ElementType.WALL, Vector2(col, row))
						"p":
							_create_element_at(Helper.ElementType.HERO, Vector2(col, row))
						"@":
							_create_element_at(Helper.ElementType.HERO, Vector2(col, row))
						"P":
							_create_element_at(Helper.ElementType.GOAL, Vector2(col, row))
							_create_element_at(Helper.ElementType.HERO, Vector2(col, row))
						"+":
							_create_element_at(Helper.ElementType.GOAL, Vector2(col, row))
							_create_element_at(Helper.ElementType.HERO, Vector2(col, row))
						"b":
							_create_element_at(Helper.ElementType.CRATE, Vector2(col, row))
						"$":
							_create_element_at(Helper.ElementType.CRATE, Vector2(col, row))
						"B":
							_create_element_at(Helper.ElementType.GOAL, Vector2(col, row))
							_create_element_at(Helper.ElementType.CRATE, Vector2(col, row))
						"*":
							_create_element_at(Helper.ElementType.GOAL, Vector2(col, row))
							_create_element_at(Helper.ElementType.CRATE, Vector2(col, row))
						".":
							_create_element_at(Helper.ElementType.GOAL, Vector2(col, row))
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
	_update_ground_label()
	for e in _probe_tile(_get_tile(element)):
		if e is TeleportPad:
			## @TODO: Should I check if destination is active too as condition
			## to teleport? Also, if destination tile has non-walkable element
			## what should I do?
			e.teleport(element)
	_dispel_fog_of_war()


func _get_tile(element: Node2D) -> Vector2:
	if not element:
		return Vector2.ZERO
	return Vector2((element.position.x - Helper.HALF_LENGTH) / Helper.LENGTH, 
			(element.position.y - Helper.HALF_LENGTH) / Helper.LENGTH)


func _probe_tile(tile: Vector2) -> Array[Node2D]:
	var result: Array[Node2D] = []
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
