class_name HudPanel
extends PanelContainer

## A collapsible HUD panel with a scrollable list of rows.
##
## Rows are plain dictionaries so the same panel can display items, journal
## messages or character stats:
## [codeblock]
## {"text": "Sword", "subtitle": "", "suffix": "×2", "meta": sword,
##  "items": [sword, other_sword], "visual": sword, "weight": 20.0,
##  "dim": false}
## [/codeblock]
## The [code]meta[/code] value is opaque to the panel and is handed back through
## [signal selection_changed] and [method get_selected_meta]. [code]items[/code]
## lists every value a row represents (a grouped stack has more than one), so
## the selection can be preserved even when a group's [code]meta[/code] changes.

signal selection_changed(index: int, meta: Variant)

const ROW_SCENE: PackedScene = preload("res://scenes/hud/item_row.tscn")

@export var title: String = "Panel":
	set(v):
		title = v
		if is_node_ready():
			_title_label.text = v.to_upper()

## Height of the scrollable body in pixels. The header is added on top.
@export var body_height: float = 132.0

## Whether rows can be selected and navigated. Journal-style panels turn this
## off so no selection marker is drawn.
@export var selectable: bool = true:
	set(v):
		selectable = v
		if is_node_ready():
			_apply_selection()

@onready var _title_label: Label = %TitleLabel
@onready var _count_label: Label = %CountLabel
@onready var _indicator: Label = %Indicator
@onready var _body: ScrollContainer = %Body
@onready var _rows_container: VBoxContainer = %Rows

var _rows: Array[Dictionary] = []
var _row_nodes: Array[Control] = []
var _selected_index: int = -1
var _collapsed: bool = false
var _focused: bool = false


func _ready() -> void:
	_title_label.text = title.to_upper()
	_body.custom_minimum_size.y = body_height
	_apply_collapsed()
	_apply_focus()
	_update_header()


## Replaces every row. [param selected_meta] is matched against the row
## [code]meta[/code] values to preserve the selection; when it is not found the
## first row is selected.
func set_rows(rows: Array[Dictionary], selected_meta: Variant = null) -> void:
	_rows = rows.duplicate()
	_rebuild(selected_meta)


func get_rows() -> Array[Dictionary]:
	return _rows


func get_selected_index() -> int:
	return _selected_index


func get_selected_meta() -> Variant:
	if _selected_index < 0 or _selected_index >= _rows.size():
		return null
	return _rows[_selected_index].get("meta")


func select(index: int) -> void:
	if not selectable or _row_nodes.is_empty():
		return
	_set_selected(clampi(index, 0, _row_nodes.size() - 1), true)


func select_next() -> void:
	if not selectable or _row_nodes.is_empty():
		return
	_set_selected((_selected_index + 1) % _row_nodes.size(), true)


func select_previous() -> void:
	if not selectable or _row_nodes.is_empty():
		return
	_set_selected((_selected_index - 1 + _row_nodes.size()) % _row_nodes.size(), true)


func set_collapsed(collapsed: bool) -> void:
	_collapsed = collapsed
	if is_node_ready():
		_apply_collapsed()


func toggle_collapsed() -> void:
	set_collapsed(not _collapsed)


func is_collapsed() -> bool:
	return _collapsed


func set_focused(focused: bool) -> void:
	_focused = focused
	if is_node_ready():
		_apply_focus()


func scroll_to_bottom() -> void:
	_scroll_to_bottom_async()


func _rebuild(selected_meta: Variant) -> void:
	for child: Node in _rows_container.get_children():
		_rows_container.remove_child(child)
		child.queue_free()
	_row_nodes.clear()
	if _rows.is_empty():
		_selected_index = -1
		_add_empty_label()
		_update_header()
		return
	for row_data: Dictionary in _rows:
		var row: Control = ROW_SCENE.instantiate()
		_rows_container.add_child(row)
		row.setup(row_data)
		_row_nodes.append(row)
	_selected_index = _find_index(selected_meta)
	if _selected_index < 0:
		_selected_index = 0
	_apply_selection()
	_update_header()
	_scroll_to_selection()


func _add_empty_label() -> void:
	var label: Label = Label.new()
	label.text = "(empty)"
	label.theme_type_variation = &"HudEmpty"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows_container.add_child(label)


func _find_index(meta: Variant) -> int:
	if meta == null:
		return -1
	for i: int in _rows.size():
		if _rows[i].get("meta") == meta:
			return i
	# A grouped row exposes one representative item as its meta, but the
	# selection may be any member of the group.
	for i: int in _rows.size():
		var items: Variant = _rows[i].get("items")
		if items is Array and (items as Array).has(meta):
			return i
	return -1


func _set_selected(index: int, notify: bool) -> void:
	if index == _selected_index:
		_apply_selection()
		_scroll_to_selection()
		return
	_selected_index = index
	_apply_selection()
	_scroll_to_selection()
	if notify:
		selection_changed.emit(_selected_index, get_selected_meta())


func _apply_selection() -> void:
	for i: int in _row_nodes.size():
		var row: HudItemRow = _row_nodes[i] as HudItemRow
		if row:
			row.set_selected(selectable and i == _selected_index)


func _apply_collapsed() -> void:
	_body.visible = not _collapsed
	_indicator.text = "+" if _collapsed else "-"


func _apply_focus() -> void:
	theme_type_variation = &"HudPanelFocused" if _focused else &"HudPanel"


func _update_header() -> void:
	# Grouped rows stand for several items, so count items rather than rows.
	var total: int = 0
	for row_data: Dictionary in _rows:
		var items: Variant = row_data.get("items")
		if items is Array:
			total += (items as Array).size()
		else:
			total += 1
	_count_label.text = str(total)


func _scroll_to_selection() -> void:
	call_deferred(&"_ensure_selection_visible")


func _ensure_selection_visible() -> void:
	if not is_inside_tree():
		return
	if not _body.visible:
		return
	if _selected_index < 0 or _selected_index >= _row_nodes.size():
		return
	_body.ensure_control_visible(_row_nodes[_selected_index])


func _scroll_to_bottom_async() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree():
		return
	_body.scroll_vertical = int(_body.get_v_scroll_bar().max_value)
