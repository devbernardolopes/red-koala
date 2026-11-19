class_name Hud
extends CanvasLayer

## HUD root: owns the collapsible panels, their toggle/navigation input and the
## data shown in them.
##
## Gameplay input stays in [code]universe.gd[/code]. It calls
## [method handle_input] first and stops processing the event when the HUD
## consumed it. Inventory/ground actions ([code]take[/code], [code]drop[/code],
## [code]equip[/code]) are still handled by the universe; it queries the
## selection through [method get_selected_ground_item] and
## [method get_selected_inventory_item].

signal inventory_selection_changed(item: Item)

const JOURNAL_MAX_MESSAGES: int = 200
## Every action that moves the active entity. While the inventory modifier is
## held they are swallowed by the HUD so numpad diagonals cannot leak into
## gameplay.
const MOVE_ACTIONS: Array[StringName] = [
	&"up", &"down", &"left", &"right",
	&"up_left", &"up_right", &"down_left", &"down_right",
]

@onready var journal_panel: HudPanel = %JournalPanel
@onready var inventory_panel: HudPanel = %InventoryPanel
@onready var ground_panel: HudPanel = %GroundPanel

var _inventory_items: Array[Item] = []
var _ground_items: Array[Item] = []
var _journal_messages: Array[String] = []
var _focused_panel: HudPanel = null


func _ready() -> void:
	journal_panel.selectable = false
	inventory_panel.selection_changed.connect(_on_inventory_selection_changed)
	_set_focus(inventory_panel)


## Replaces the inventory rows. [param current_item] is the entity's selected
## item and drives the row selection.
func set_inventory(items: Array[Item], current_item: Item = null) -> void:
	_inventory_items.clear()
	_inventory_items.append_array(items)
	var rows: Array[Dictionary] = []
	for item: Item in _inventory_items:
		rows.append(_make_row(item))
	inventory_panel.set_rows(rows, current_item)


## Replaces the ground rows, keeping the current selection when that item is
## still on the ground.
func set_ground(items: Array[Item]) -> void:
	var previous: Item = get_selected_ground_item()
	_ground_items.clear()
	_ground_items.append_array(items)
	_ground_items.sort_custom(_sort_items_by_name)
	var rows: Array[Dictionary] = []
	for item: Item in _ground_items:
		rows.append(_make_row(item))
	ground_panel.set_rows(rows, previous)


func get_selected_ground_item() -> Item:
	return ground_panel.get_selected_meta() as Item


func get_selected_inventory_item() -> Item:
	return inventory_panel.get_selected_meta() as Item


## Consumes HUD-related input. Returns [code]true[/code] when the event must not
## reach gameplay.
func handle_input(event: InputEvent) -> bool:
	if event.is_action_pressed(&"toggle_inventory"):
		inventory_panel.toggle_collapsed()
		return true
	if event.is_action_pressed(&"toggle_ground"):
		ground_panel.toggle_collapsed()
		return true
	if event.is_action_pressed(&"toggle_journal"):
		journal_panel.toggle_collapsed()
		return true
	if not Input.is_action_pressed(&"inventory_modifier"):
		return false
	for action: StringName in MOVE_ACTIONS:
		if event.is_action_pressed(action):
			_handle_navigation(action)
			return true
	return false


## Appends one line to the journal and scrolls to it.
func add_message(message: String) -> void:
	if message.is_empty():
		return
	_journal_messages.append(message)
	_trim_journal()
	_refresh_journal()


## Replaces the whole journal.
func set_messages(messages: PackedStringArray) -> void:
	_journal_messages.clear()
	for message: String in messages:
		_journal_messages.append(message)
	_trim_journal()
	_refresh_journal()


func _handle_navigation(action: StringName) -> void:
	match action:
		&"up", &"down":
			if _focused_panel.is_collapsed():
				_focused_panel.set_collapsed(false)
			if action == &"up":
				_focused_panel.select_previous()
			else:
				_focused_panel.select_next()
		&"left", &"right":
			_set_focus(ground_panel if _focused_panel == inventory_panel else inventory_panel)


func _set_focus(panel: HudPanel) -> void:
	_focused_panel = panel
	inventory_panel.set_focused(panel == inventory_panel)
	ground_panel.set_focused(panel == ground_panel)


func _make_row(item: Item) -> Dictionary:
	var suffix: String = ""
	if item.is_equipped:
		suffix = "[E]"
	if item.mystic_modifier == Helper.MysticModifier.CURSED:
		suffix = (suffix + " [C]").strip_edges()
	return {
		"text": _item_name(item),
		"suffix": suffix,
		"meta": item,
		"dim": false,
	}


func _item_name(item: Item) -> String:
	if item.data and not item.data.name.is_empty():
		return item.data.name
	return item.name


func _sort_items_by_name(a: Item, b: Item) -> bool:
	return _item_name(a).nocasecmp_to(_item_name(b)) < 0


func _trim_journal() -> void:
	while _journal_messages.size() > JOURNAL_MAX_MESSAGES:
		_journal_messages.pop_front()


func _refresh_journal() -> void:
	var rows: Array[Dictionary] = []
	for message: String in _journal_messages:
		rows.append({
			"text": message,
			"suffix": "",
			"meta": null,
			"dim": false,
		})
	journal_panel.set_rows(rows)
	journal_panel.scroll_to_bottom()


func _on_inventory_selection_changed(_index: int, meta: Variant) -> void:
	if meta is Item:
		inventory_selection_changed.emit(meta as Item)
