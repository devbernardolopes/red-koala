extends Node2D

const LEVELS_DIR: String = "res://resources/levels/"
const WALL_SCENE = preload("res://scenes/wall.tscn")

@export var current_player_entity: Entity = null:
	set(v):
		current_player_entity = v
		if current_player_entity:
			if follow_camera:
				follow_camera.target = current_player_entity
			player_entity_changed.emit()
@export var party: Array[Entity] = []

var follow_camera: FollowCamera = null
var decals_node: Node2D = null
var goals_node: Node2D = null
var items_node: Node2D = null
var crates_node: Node2D = null
var entities_node: Node2D = null
var walls_node: TileMapLayer = null
## Walls synthesised from [member walls_node]; they are not scene-tree nodes.
var wall_proxies: Array[Wall] = []
var journal_label: Label = null
var ground_label: Label = null
var inventory_control: Control = null

var current_filter: Control = null
var filter_list: Array[Control] = []

#var current_inventory_item: Node2D = null

var inventory_toggled: bool = false

@onready var canvas_modulate: CanvasModulate = $CanvasModulate
@onready var fog_of_war: Node2D = $FogOfWar
@onready var filters: CanvasLayer = $Filters
@onready var board: Board = $Board
@onready var board_debug_overlay: Node2D = $Board/BoardDebugOverlay

signal player_entity_changed


func _ready() -> void:
	if not decals_node:
		decals_node = find_child("Decals")
	if not goals_node:
		goals_node = find_child("Goals")
	if not items_node:
		items_node = find_child("Items")
	if not crates_node:
		crates_node = find_child("Crates")
	if not walls_node:
		walls_node = find_child("Walls")
	if not entities_node:
		entities_node = find_child("Entities")
	if not current_player_entity:
		push_warning("No player entity!")
	if not party or party.is_empty():
		push_warning("No player party!")
	follow_camera = Helper.find_control(self, "FollowCamera")
	if not follow_camera:
		push_warning("No FollowCamera!")
	journal_label = Helper.find_control(self, "Label", &"Journal")
	ground_label = Helper.find_control(self, "Label", &"Ground")
	inventory_control = Helper.find_control(self, "VBoxContainer", &"InventoryContainer")
	#inventory_control = Helper.find_control(self, "MarginContainer", &"InventoryContainer")
	_load_elements()
	AudioManager.set_listener_target(current_player_entity)
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
	for entity in party:
		entity.is_playable = true
		entity.inventory_changed.connect(_update_inventory)
	follow_camera.target = current_player_entity
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
		if current_filter is Control:
			current_filter.visible = false
		var filter_index: int = filter_list.find(current_filter)
		if filter_index < filter_list.size() - 1:
			current_filter = filter_list.get(filter_index + 1)
		else:
			current_filter = filter_list.front()
		if current_filter:
			current_filter.visible = true
	if event.is_action_pressed("debug_toggle_board"):
		if not board_debug_overlay:
			return
		board_debug_overlay.visible = not board_debug_overlay.visible
		if board_debug_overlay.visible:
			board_debug_overlay.queue_redraw()


func _process(_delta: float) -> void:
	inventory_toggled = false
	if Input.is_action_pressed("inventory_modifier"):
		inventory_toggled = true


func _drop(item: Item) -> void:
	if not item:
		return
	if not items_node:
		return
	current_player_entity.drop(current_player_entity.current_inventory_item)
	items_node.add_child(item)
	board.register(item)
	for e: Base in board.get_elements_at(board.get_origin(item)):
		if e is TeleportPad:
			(e as TeleportPad).teleport(item)
	board.sync_from_position(item)
	_update_ground_label()


func _unhandled_input(event: InputEvent) -> void:
	if not current_player_entity:
		return
	if event.is_action_pressed("switch_player_entity"):
		if not party or party.is_empty() or party.size() == 1:
			return
		var index: int = party.find(current_player_entity)
		if index + 1 < party.size():
			current_player_entity = party.get(index + 1)
		else:
			current_player_entity = party.front()
		_update_inventory()
		_update_ground_label()
		get_viewport().set_input_as_handled()
		return
	if inventory_toggled:
		if not current_player_entity.current_inventory_item:
			return
		var index: int = current_player_entity.inventory.find(current_player_entity.current_inventory_item)
		if event.is_action_pressed("up"):
			if index - 1 < 0:
				current_player_entity.current_inventory_item = current_player_entity.inventory.back()
			else:
				current_player_entity.current_inventory_item = current_player_entity.inventory[index - 1]
			_update_inventory()
		elif event.is_action_pressed("down"):
			if index + 1 > current_player_entity.inventory.size() - 1:
				current_player_entity.current_inventory_item = current_player_entity.inventory.front()
			else:
				current_player_entity.current_inventory_item = current_player_entity.inventory[index + 1]
			_update_inventory()
		# The action "take" is being used here as an alternative for "equip".
		elif event.is_action_pressed("take"):
			if not current_player_entity.current_inventory_item:
				return
			current_player_entity.equip(current_player_entity.current_inventory_item)
		return
	
	if event.is_action_pressed("take"):
		_take_item()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("drop"):
		_drop(current_player_entity.current_inventory_item)
		get_viewport().set_input_as_handled()
		return
	# The action "equip" also unequips.
	if event.is_action_pressed("equip"):
		if not current_player_entity.current_inventory_item:
			return
		current_player_entity.equip(current_player_entity.current_inventory_item)
		get_viewport().set_input_as_handled()
		return
	
	var direction: Vector2 = Vector2.ZERO
	if event.is_action_pressed("up"):
		direction = Vector2.UP
	elif event.is_action_pressed("up_right"):
		direction = Vector2.UP + Vector2.RIGHT
	elif event.is_action_pressed("down"):
		direction = Vector2.DOWN
	elif event.is_action_pressed("down_right"):
		direction = Vector2.DOWN + Vector2.RIGHT
	elif event.is_action_pressed("left"):
		direction = Vector2.LEFT
	elif event.is_action_pressed("down_left"):
		direction = Vector2.DOWN + Vector2.LEFT
	elif event.is_action_pressed("right"):
		direction = Vector2.RIGHT
	elif event.is_action_pressed("up_left"):
		direction = Vector2.UP + Vector2.LEFT
	if direction == Vector2.ZERO:
		return
	_try_move(direction)
	get_viewport().set_input_as_handled()


func _update_journal() -> void:
	if not journal_label:
		return
	if not current_player_entity:
		return
	journal_label.text = ""


func _update_inventory() -> void:
	if not inventory_control:
		return
	if not current_player_entity:
		return
	for child in inventory_control.get_children():
		child.queue_free()
	if not current_player_entity.inventory:
		current_player_entity.current_inventory_item = null
		return
	for item in current_player_entity.inventory:
		if not item:
			continue
		if not current_player_entity.current_inventory_item or not current_player_entity.inventory.has(current_player_entity.current_inventory_item):
			current_player_entity.current_inventory_item = item
		
		var item_slot: ItemSlot = ItemSlot.new(item)
		inventory_control.add_child(item_slot)

		#var l: Label = Label.new()
		#l.text = item.name
		#if Helper.has_property(item, "data"):
			#if not item.data:
				#push_warning(item, " has no data!")
			#else:
				#l.text = item.data.name
		#if item.is_equipped:
			#l.text = "(e) " + l.text
		#if current_player_entity.current_inventory_item == item:
			##l.text = "-> " + l.text
			#l.add_theme_color_override("font_outline_color", Color.RED)
			#l.add_theme_constant_override("outline_size", 2)
		#inventory_control.add_child(l)


func _update_ground_label() -> void:
	if not ground_label:
		return
	ground_label.text = ""
	var tiles_at: Array[Base] = board.get_elements_at(board.get_origin(current_player_entity))
	for t: Base in tiles_at:
		if not t is Item:
			continue
		var item: Item = t
		if item.data is ItemData:
			ground_label.text += item.data.name + ", "
	ground_label.text = ground_label.text.trim_suffix(", ")


func _dispel_fog_of_war() -> void:
	if not current_player_entity:
		return
	if not fog_of_war:
		return
	var fog_layer: TileMapLayer = Helper.find_control(fog_of_war, "TileMapLayer", &"FogFull")
	if not fog_layer:
		return
	var center_pos: Vector2i = board.get_origin(current_player_entity)
	for i in range(center_pos.x - current_player_entity.fov, center_pos.x + current_player_entity.fov + 1):
		for j in range(center_pos.y - current_player_entity.fov, center_pos.y + current_player_entity.fov + 1):
			fog_layer.set_cell(Vector2i(i, j))
	#var fl_x: int = fog_layer.get_used_rect().size.x
	#var fl_y: int = fog_layer.get_used_rect().size.y
	#print(fog_layer.get_used_rect().position.x)
	

func _take_item() -> void:
	var tiles_at: Array[Base] = board.get_elements_at(board.get_origin(current_player_entity))
	for t: Base in tiles_at:
		if not t is Item:
			continue
		var item: Item = t
		if item.data is ItemData and current_player_entity.take(item):
			board.unregister(item)
			_update_ground_label()
		return


func _try_move(direction: Vector2) -> void:
	var dir: Vector2i = Vector2i(direction)
	if dir == Vector2i.ZERO:
		return
	var mode: Helper.MoveMode = current_player_entity.get_move_mode()
	var move_to: Vector2i = board.get_origin(current_player_entity) + dir
	var tiles_at: Array[Base] = board.get_elements_at(move_to)
	for t: Base in tiles_at:
		if t.walkable:
			continue
		if t.pushable:
			_try_push(tiles_at, move_to, dir)
			return
		if mode != Helper.MoveMode.PHASE:
			return
		break
	if not board.can_occupy(current_player_entity, move_to, mode):
		return
	_move(current_player_entity, dir)


func _try_push(tiles_at: Array[Base], move_to: Vector2i, direction: Vector2i) -> void:
	# TODO: Refactor this because not everything that is pushable is a Crate.
	var crate: Crate = null
	for t: Base in tiles_at:
		if t.pushable:
			crate = t as Crate
			break
	if not crate:
		return
	# The hero takes the crate's former tile, so it must be free for everything
	# else on it (e.g. a closed door under the crate).
	for t: Base in tiles_at:
		if t != crate and not t.walkable:
			return
	if not _can_push_crate_to(board.get_elements_at(move_to + direction)):
		return
	_move(current_player_entity, direction)
	## TODO: Add a sound for crate moving?
	_move(crate, direction)


func _can_push_crate_to(tiles_at: Array[Base]) -> bool:
	if tiles_at.is_empty():
		return true
	for tile: Base in tiles_at:
		if not tile.walkable:
			return false
	return true
	#if tiles_at.size() != 1:
		#return false
	#var target: Node2D = tiles_at[0]
	#if target is Goal:
		#return true
	#return target is Door and (target as Door).walkable


func _load_elements() -> void:
	var children: Array[Node] = find_children("*")
	if children and not children.is_empty():
		for child: Node in children:
			if child.is_queued_for_deletion():
				continue
			if child.is_in_group(&"Elements"):
				if child is Base:
					board.register(child as Base)
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
	# Walls live in a TileMapLayer, so they are not scene-tree elements.
	if walls_node:
		for cell: Vector2i in walls_node.get_used_cells():
			var w: Wall = Wall.new()
			w.walkable = false
			w.blocks_sight = true
			board.place(w, cell)
			wall_proxies.append(w)

## @deprecated It is being used when loading levels from file but there will be
## no more file loading in the future.
func _create_element_at(type: Helper.ElementType, pos: Vector2i) -> void:
	match type:
		Helper.ElementType.GOAL:
			var g: Goal = Goal.new()
			goals_node.add_child(g)
			board.place(g, pos)
		Helper.ElementType.CRATE:
			var c: Crate = Crate.new()
			crates_node.add_child(c)
			board.place(c, pos)
		Helper.ElementType.ENTITY:
			var e: Entity = Entity.new()
			add_child(e)
			board.place(e, pos)
			current_player_entity = e

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
							_create_element_at(Helper.ElementType.ENTITY, Vector2(col, row))
						"@":
							_create_element_at(Helper.ElementType.ENTITY, Vector2(col, row))
						"P":
							_create_element_at(Helper.ElementType.GOAL, Vector2(col, row))
							_create_element_at(Helper.ElementType.ENTITY, Vector2(col, row))
						"+":
							_create_element_at(Helper.ElementType.GOAL, Vector2(col, row))
							_create_element_at(Helper.ElementType.ENTITY, Vector2(col, row))
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
		for child: Node in children:
			if child.is_in_group(&"Elements"):
				if child is Base:
					board.unregister(child as Base)
				child.queue_free()
	for w: Wall in wall_proxies:
		board.unregister(w)
		w.free()
	wall_proxies.clear()


func _move(element: Base, dir: Vector2i = Vector2i.ZERO) -> void:
	if not element:
		return
	if dir == Vector2i.ZERO:
		return
	board.move_element(element, board.get_origin(element) + dir)
	_update_ground_label()
	for e: Base in board.get_elements_at(board.get_origin(element)):
		if e is TeleportPad:
			## @TODO: Should I check if destination is active too as condition
			## to teleport? Also, if destination tile has non-walkable element
			## what should I do?
			(e as TeleportPad).teleport(element)
	# Teleporting sets position directly, so the index must catch up.
	board.sync_from_position(element)
	_dispel_fog_of_war()
