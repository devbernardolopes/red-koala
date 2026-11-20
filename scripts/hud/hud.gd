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
##
## The journal is owned by the [code]Journal[/code] autoload; this node only
## renders it.

signal inventory_selection_changed(item: Item)

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
var _focused_panel: HudPanel = null


func _ready() -> void:
	journal_panel.selectable = false
	inventory_panel.selection_changed.connect(_on_inventory_selection_changed)
	Journal.entry_added.connect(_on_journal_entry_added)
	Journal.cleared.connect(_on_journal_cleared)
	_refresh_journal()
	_set_focus(inventory_panel)


## Replaces the inventory rows. Equipped items are listed first as their
## body-part slot; the remaining items are grouped into one row per stack.
## [param current_item] is the entity's selected item and drives the row
## selection, [param body_parts] maps equipped items to their body part.
func set_inventory(items: Array[Item], current_item: Item = null,
		body_parts: Array[AnatomyData] = []) -> void:
	_inventory_items.clear()
	_inventory_items.append_array(items)
	var rows: Array[Dictionary] = []
	var equipped: Array[Item] = []
	for body_part: AnatomyData in body_parts:
		var item: Item = body_part.equipped_item
		if not item or not item.is_equipped:
			continue
		if not _inventory_items.has(item) or equipped.has(item):
			continue
		rows.append(_make_equipped_row(item, body_part.name))
		equipped.append(item)
	# An equipped item missing from the anatomy still deserves a row, even if
	# that state should not happen.
	for item: Item in _inventory_items:
		if item.is_equipped and not equipped.has(item):
			rows.append(_make_equipped_row(item))
			equipped.append(item)
	for group: Dictionary in _group_items(equipped):
		rows.append(_make_group_row(group))
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
	var row_items: Array[Item] = [item]
	return {
		"text": item.get_display_name(),
		"suffix": _modifier_suffix(item),
		"meta": item,
		"items": row_items,
		"visual": item,
		"weight": _get_weight(item),
		"dim": false,
	}


## A body-part slot row: the body part is the title and the item name sits
## above it in a smaller font.
func _make_equipped_row(item: Item, body_part_name: String = "") -> Dictionary:
	var subtitle: String = ""
	var title: String = body_part_name
	if title.is_empty():
		title = item.get_display_name()
	else:
		subtitle = item.get_display_name()
	var row_items: Array[Item] = [item]
	return {
		"text": title,
		"subtitle": subtitle,
		"suffix": _modifier_suffix(item),
		"meta": item,
		"items": row_items,
		"visual": item,
		"weight": _get_weight(item),
		"dim": false,
	}


func _make_group_row(group: Dictionary) -> Dictionary:
	var items: Array[Item] = group.get("items")
	var representative: Item = group.get("item")
	var suffix: String = ""
	if items.size() > 1:
		suffix = "×%d" % items.size()
	var modifier: String = _modifier_suffix(representative)
	if not modifier.is_empty():
		suffix = (suffix + " " + modifier).strip_edges()
	return {
		"text": representative.get_display_name(),
		"suffix": suffix,
		"meta": representative,
		"items": items,
		"visual": representative,
		"weight": float(group.get("weight", 0.0)),
		"dim": false,
	}


## Groups the carried (non-equipped) items into stacks of equal items.
func _group_items(exclude: Array[Item]) -> Array[Dictionary]:
	var groups: Array[Dictionary] = []
	for item: Item in _inventory_items:
		if item.is_equipped or exclude.has(item):
			continue
		var group: Dictionary = {}
		for candidate: Dictionary in groups:
			if _is_same_stack(candidate, item):
				group = candidate
				break
		if group.is_empty():
			var group_items: Array[Item] = [item]
			groups.append({
				"item": item,
				"items": group_items,
				"weight": _get_weight(item),
			})
			continue
		var stack: Array[Item] = group.get("items")
		stack.append(item)
		group["weight"] = float(group.get("weight", 0.0)) + _get_weight(item)
	return groups


func _is_same_stack(group: Dictionary, item: Item) -> bool:
	var representative: Item = group.get("item")
	if representative.mystic_modifier != item.mystic_modifier:
		return false
	if representative.data != null and item.data != null:
		return representative.data == item.data
	return representative.get_display_name() == item.get_display_name()


func _get_weight(item: Item) -> float:
	if item.data is ItemData:
		return (item.data as ItemData).weight
	return 0.0


## Mystic modifiers are shown after the count, if the row has one.
func _modifier_suffix(item: Item) -> String:
	if item.mystic_modifier == Helper.MysticModifier.CURSED:
		return "[C]"
	return ""


func _sort_items_by_name(a: Item, b: Item) -> bool:
	return a.get_display_name().nocasecmp_to(b.get_display_name()) < 0


func _refresh_journal() -> void:
	var rows: Array[Dictionary] = []
	for message: String in Journal.entries:
		rows.append({
			"text": message,
			"suffix": "",
			"meta": null,
			"dim": false,
		})
	journal_panel.set_rows(rows)
	journal_panel.scroll_to_bottom()


func _on_journal_entry_added(_text: String) -> void:
	_refresh_journal()


func _on_journal_cleared() -> void:
	journal_panel.set_rows([])


func _on_inventory_selection_changed(_index: int, meta: Variant) -> void:
	if meta is Item:
		inventory_selection_changed.emit(meta as Item)
