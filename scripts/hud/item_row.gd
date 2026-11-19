class_name HudItemRow
extends PanelContainer

@onready var _marker: Label = %Marker
@onready var _name_label: Label = %NameLabel
@onready var _suffix_label: Label = %SuffixLabel

var _selected: bool = false


func setup(text: String, suffix: String = "", dim: bool = false) -> void:
	_name_label.text = text
	_suffix_label.text = suffix
	_suffix_label.visible = not suffix.is_empty()
	modulate.a = 0.6 if dim else 1.0
	_apply_selection()


func set_selected(selected: bool) -> void:
	_selected = selected
	_apply_selection()


func _apply_selection() -> void:
	if not is_node_ready():
		return
	theme_type_variation = &"HudRowSelected" if _selected else &"HudRow"
	_marker.text = ">" if _selected else ""
