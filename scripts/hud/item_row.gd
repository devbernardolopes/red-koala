class_name HudItemRow
extends PanelContainer

@onready var _marker: Label = %Marker
@onready var _visual: HudItemVisual = %Visual
@onready var _subtitle_label: Label = %SubtitleLabel
@onready var _name_label: Label = %NameLabel
@onready var _suffix_label: Label = %SuffixLabel
@onready var _weight_label: Label = %WeightLabel

var _selected: bool = false


func _ready() -> void:
	_apply_selection()


## Fills the row from the dictionary schema documented in [HudPanel].
func setup(data: Dictionary) -> void:
	_name_label.text = String(data.get("text", ""))
	var subtitle: String = String(data.get("subtitle", ""))
	_subtitle_label.text = subtitle
	_subtitle_label.visible = not subtitle.is_empty()
	var suffix: String = String(data.get("suffix", ""))
	_suffix_label.text = suffix
	_suffix_label.visible = not suffix.is_empty()
	var weight: float = data.get("weight", -1.0)
	_weight_label.visible = weight >= 0.0
	if _weight_label.visible:
		_weight_label.text = "%.1f kg" % weight
	var visual: Variant = data.get("visual")
	if visual is Item:
		_visual.setup(visual as Item)
	else:
		_visual.clear()
	_visual.visible = visual is Item
	modulate.a = 0.6 if bool(data.get("dim", false)) else 1.0
	_apply_selection()


func set_selected(selected: bool) -> void:
	_selected = selected
	_apply_selection()


func _apply_selection() -> void:
	if not is_node_ready():
		return
	theme_type_variation = &"HudRowSelected" if _selected else &"HudRow"
	_marker.text = ">" if _selected else ""
