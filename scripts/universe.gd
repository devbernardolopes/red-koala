class_name Universe
extends Node2D

const LEVELS_DIR: String = "res://resources/levels/"
const WALL_SCENE = preload("res://scenes/wall.tscn")

@export var current_player_entity: Entity = null:
	set(v):
		current_player_entity = v
		Journal.speaker = v
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

var current_filter: Control = null
var filter_list: Array[Control] = []
var _input_disabled: bool = false
## Entity whose [signal Entity.stats_changed] currently drives the inventory
## footer. Tracked so switching the active player reconnects exactly once.
var _stats_entity: Entity = null

@onready var canvas_modulate: CanvasModulate = $CanvasModulate
@onready var fog_of_war: Node2D = $FogOfWar
@onready var filters: CanvasLayer = $Filters
@onready var board: Board = $Board
@onready var board_debug_overlay: Node2D = $Board/BoardDebugOverlay
@onready var hud: Hud = $Hud
@onready var turn_manager: TurnManager = $TurnManager

signal player_entity_changed
signal no_player_left


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
	hud.inventory_selection_changed.connect(_on_inventory_selection_changed)
	Journal.speaker = current_player_entity
	board.element_registered.connect(_on_element_registered)
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
	_update_inventory()
	_update_ground()
	_update_character()
	_connect_stats(current_player_entity)
	_dispel_fog_of_war()
	for entity in party:
		entity.is_playable = true
		entity.team = Helper.EntityTeam.FRIEND
		entity.inventory_changed.connect(_on_inventory_changed.bind(entity))
		entity.encumbrance_changed.connect(_on_encumbrance_changed.bind(entity))
	follow_camera.target = current_player_entity
	MusicPlayer.play_music(Helper.FOREBODING_THEME, true)
	turn_manager.setup(self)
	# Let the scene finish becoming ready first: brains initialize their
	# behavior trees against the scene root when it is ready.
	turn_manager.start.call_deferred()
	for member: Entity in party:
		if is_instance_valid(member):
			Journal.entered_dungeon(member)


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
	if event.is_action_pressed("debug_toggle_turn_delay"):
		if not turn_manager:
			return
		turn_manager.instant = not turn_manager.instant


func _unhandled_input(event: InputEvent) -> void:
	if _input_disabled:
		return
	if hud.handle_input(event):
		get_viewport().set_input_as_handled()
		return
	if not current_player_entity:
		return
	if not turn_manager or not turn_manager.is_player_turn():
		return
	if event.is_action_pressed("switch_player_entity"):
		turn_manager.cycle_player()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("wait"):
		turn_manager.request_wait()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("take"):
		_take_item()
		turn_manager.on_player_action()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("drop"):
		var dropped: Item = current_player_entity.current_inventory_item
		if dropped:
			turn_manager.actions.drop(current_player_entity, dropped)
			turn_manager.on_player_action()
		get_viewport().set_input_as_handled()
		return
	# The action "equip" also unequips.
	if event.is_action_pressed("equip"):
		var item: Item = current_player_entity.current_inventory_item
		if not item:
			return
		turn_manager.actions.equip(current_player_entity, item)
		turn_manager.on_player_action()
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
	var dir: Vector2i = Vector2i(int(direction.x), int(direction.y))
	turn_manager.actions.bump(current_player_entity, dir)
	turn_manager.on_player_action()
	get_viewport().set_input_as_handled()


func _update_inventory() -> void:
	if not current_player_entity:
		hud.set_inventory([])
		return
	var current: Item = current_player_entity.current_inventory_item
	if not current or not current_player_entity.inventory.has(current):
		current = null
		if not current_player_entity.inventory.is_empty():
			current = current_player_entity.inventory.front()
	current_player_entity.current_inventory_item = current
	hud.set_inventory(current_player_entity.inventory, current, current_player_entity)


## Pushes the active entity's sheet to the HUD. Stats can change outside the
## inventory flow (combat, levelling), so callers refresh it when that happens.
func _update_character() -> void:
	hud.set_character(current_player_entity)


func _update_ground() -> void:
	if not current_player_entity:
		hud.set_ground([])
		return
	var items: Array[Item] = []
	for t: Base in board.get_elements_at(board.get_origin(current_player_entity)):
		if t is Item and (t as Item).data is ItemData:
			items.append(t as Item)
	hud.set_ground(items)


func _on_inventory_changed(entity: Entity) -> void:
	if entity == current_player_entity:
		_update_inventory()
		_update_character()


## Journal note for a party member crossing an encumbrance band.
func _on_encumbrance_changed(level: Encumbrance.Level, entity: Entity) -> void:
	Journal.encumbrance_changed(entity, level)


## Keeps the inventory footer up to date when the active entity's stats change,
## such as a future Strength buff changing the carry capacity.
func _connect_stats(entity: Entity) -> void:
	if _stats_entity == entity:
		return
	_disconnect_stats()
	if not is_instance_valid(entity):
		return
	_stats_entity = entity
	entity.stats_changed.connect(_on_active_stats_changed)


func _disconnect_stats() -> void:
	if is_instance_valid(_stats_entity):
		if _stats_entity.stats_changed.is_connected(_on_active_stats_changed):
			_stats_entity.stats_changed.disconnect(_on_active_stats_changed)
	_stats_entity = null


func _on_active_stats_changed() -> void:
	_update_inventory()


func _on_inventory_selection_changed(item: Item) -> void:
	if not current_player_entity:
		return
	current_player_entity.current_inventory_item = item


## Every entity that reaches the board is watched for death, whether it came
## from the scene or was spawned at runtime.
func _on_element_registered(element: Base) -> void:
	if element is Entity:
		_connect_entity(element as Entity)


func _connect_entity(entity: Entity) -> void:
	if not is_instance_valid(entity) or entity.has_meta(&"death_connected"):
		return
	entity.set_meta(&"death_connected", true)
	entity.died.connect(func(source: Entity) -> void: _on_entity_died(entity, source))
	entity.leveled_up.connect(
			func(new_level: int) -> void: Journal.leveled_up(entity, new_level))


## Single death path: drop the loot, leave a corpse, update the party and the
## turn order, then remove the entity.
func _on_entity_died(entity: Entity, _source: Entity) -> void:
	if not is_instance_valid(entity) or entity.has_meta(&"death_handled"):
		return
	entity.set_meta(&"death_handled", true)
	if entity == _stats_entity:
		_disconnect_stats()
	if turn_manager and turn_manager.actions:
		turn_manager.actions.drop_all_on_death(entity)
	var parent: Node = entity.get_parent()
	if parent:
		var cv: CorpseVisual = Helper.HUMANOID_CORPSE.instantiate()
		#decals_node.add_child(cv)
		#board.register(cv)
		var corpse: Corpse = Corpse.create_from(entity)
		cv.position = entity.position
		if not decals_node:
			parent.add_child(corpse)
			parent.add_child(cv)
		else:
			decals_node.add_child(corpse)
			decals_node.add_child(cv)
		board.register(corpse)
	Journal.died(entity)
	var was_player: bool = entity == current_player_entity
	var next_player: Entity = null
	if was_player:
		for member: Entity in party:
			if is_instance_valid(member) and member != entity and not member.is_dead:
				next_player = member
				break
	party.erase(entity)
	if was_player:
		if next_player:
			set_active_player(next_player)
		else:
			no_player_left.emit()
			Journal.add("All is lost")
			_disable_input()
			current_player_entity = null
			if follow_camera:
				follow_camera.target = null
			hud.set_character(null)
			hud.set_inventory([])
			hud.set_ground([])
	if turn_manager:
		turn_manager.unregister_actor(entity)
	board.unregister(entity)
	entity.queue_free()


func _disable_input() -> void:
	_input_disabled = true
	#set_process_unhandled_input(false)


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
	if not current_player_entity:
		return
	var tiles_at: Array[Base] = board.get_elements_at(board.get_origin(current_player_entity))
	var item: Item = hud.get_selected_ground_item()
	if not item or not tiles_at.has(item):
		item = null
		for t: Base in tiles_at:
			if t is Item and (t as Item).data is ItemData:
				item = t as Item
				break
	if not item:
		return
	turn_manager.actions.take(current_player_entity, item)


## Switches the entity the player controls. Called by [TurnManager] when a
## playable actor's turn begins.
func set_active_player(entity: Entity) -> void:
	if not entity:
		return
	current_player_entity = entity
	_connect_stats(entity)
	_update_inventory()
	_update_ground()
	_update_character()
	_dispel_fog_of_war()
	AudioManager.set_listener_target(entity)


## The brain attached to [param entity], if any.
func get_brain(entity: Entity) -> BrainComponent:
	if not entity:
		return null
	return entity.brain as BrainComponent


## Called by [EntityActions] after an element moved. Only the player reveals
## fog, so AI movement never uncovers the map.
func after_element_moved(element: Base) -> void:
	if element != current_player_entity:
		return
	_update_ground()
	_dispel_fog_of_war()


func after_item_change() -> void:
	_update_ground()


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
	# TODO: Refactor this in the future. I am doing this so that editor-authored
	# entities that start with items in their inventory have the items removed
	# from the board and equipped when possible.
	for entity in board.get_entities():
		if not entity.inventory:
			continue
		for item in entity.inventory:
			item.get_parent().remove_child(item)
			board.unregister(item)
			entity.equip(item)


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
