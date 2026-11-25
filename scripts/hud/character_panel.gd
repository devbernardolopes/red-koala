class_name HudCharacterPanel
extends PanelContainer

## Collapsible panel showing the active playable entity's sheet.
##
## Unlike [HudPanel] the body is a fixed layout of stat cells rather than a list
## of rows. Only the properties section is variable-length: it lists
## [method Entity.get_properties] (the entity's data, equipped items and added
## properties) and is hidden when there are none. The helper flags such as
## [member Entity.is_phasing] are deliberately ignored; they drive gameplay and
## visuals, not the character sheet.

## Placeholder shown when there is no value to display.
const EMPTY_VALUE: String = "—"

@export var title: String = "Character":
	set(v):
		title = v
		if is_node_ready():
			_title_label.text = v.to_upper()

## Whether the panel starts collapsed. Only the initial state; toggling at
## runtime does not change it.
@export var start_collapsed: bool = false

@onready var _title_label: Label = %TitleLabel
@onready var _indicator: Label = %Indicator
@onready var _body: ScrollContainer = %Body
@onready var _name_label: Label = %NameLabel
@onready var _class_label: Label = %ClassLabel
@onready var _race_label: Label = %RaceLabel
@onready var _level_label: Label = %LevelLabel
@onready var _current_xp_label: Label = %CurrentXpLabel
@onready var _strength_label: Label = %StrengthLabel
@onready var _dexterity_label: Label = %DexterityLabel
@onready var _constitution_label: Label = %ConstitutionLabel
@onready var _wisdom_label: Label = %WisdomLabel
@onready var _intelligence_label: Label = %IntelligenceLabel
@onready var _charisma_label: Label = %CharismaLabel
@onready var _health_label: Label = %HealthLabel
@onready var _mana_label: Label = %ManaLabel
@onready var _attack_label: Label = %AttackLabel
@onready var _defense_label: Label = %DefenseLabel
@onready var _speed_label: Label = %SpeedLabel
@onready var _encumbrance_label: Label = %EncumbranceLabel
@onready var _properties: VBoxContainer = %Properties

var _entity: Entity = null
var _collapsed: bool = false


func _ready() -> void:
	_title_label.text = title.to_upper()
	_collapsed = start_collapsed
	_apply_collapsed()
	refresh()


## Shows [param entity]'s sheet. Passing [code]null[/code] clears every value.
func set_entity(entity: Entity) -> void:
	_disconnect_entity()
	_entity = entity
	if is_instance_valid(_entity):
		_entity.stats_changed.connect(refresh)
		_entity.inventory_changed.connect(refresh)
	refresh()


func _disconnect_entity() -> void:
	if not is_instance_valid(_entity):
		return
	if _entity.stats_changed.is_connected(refresh):
		_entity.stats_changed.disconnect(refresh)
	if _entity.inventory_changed.is_connected(refresh):
		_entity.inventory_changed.disconnect(refresh)


## Re-reads the current entity, for when its stats may have changed while the
## panel was already showing it.
func refresh() -> void:
	if not is_node_ready():
		return
	var entity: Entity = _entity if is_instance_valid(_entity) else null
	if not entity:
		_show_placeholder()
		return
	_name_label.text = _display_name(entity)
	_class_label.text = _data_name(entity.entity_class)
	_race_label.text = _data_name(_get_race(entity))
	_level_label.text = "Level %d" % entity.level
	_current_xp_label.text = "XP: %d" % entity.xp
	_strength_label.text = "STR %d" % entity.strength
	_dexterity_label.text = "DEX %d" % entity.dexterity
	_constitution_label.text = "CON %d" % entity.constitution
	_wisdom_label.text = "WIS %d" % entity.wisdom
	_intelligence_label.text = "INT %d" % entity.intelligence
	_charisma_label.text = "CHA %d" % entity.charisma
	_health_label.text = "Health: %d/%d" % [entity.hit_points, entity.max_hit_points]
	_mana_label.text = "Mana: %d/%d" % [entity.mana_points, entity.max_mana_points]
	var profile: AttackProfile = Combat.attack_profile(entity)
	_attack_label.text = "ATK: %+d" % Combat.attack_bonus(entity, profile)
	_defense_label.text = "DEF: %d" % entity.get_armor_class()
	_speed_label.text = "Speed: %0.2f" % entity.speed
	_encumbrance_label.text = Encumbrance.display_name(entity.encumbrance_level)
	_encumbrance_label.visible = entity.encumbrance_level != Encumbrance.Level.NONE
	_refresh_properties(entity)


func set_collapsed(collapsed: bool) -> void:
	_collapsed = collapsed
	if is_node_ready():
		_apply_collapsed()


func toggle_collapsed() -> void:
	set_collapsed(not _collapsed)
	if not _collapsed:
		refresh()


func is_collapsed() -> bool:
	return _collapsed


## TODO: Share the collapse handling with [HudPanel]; both duplicate the flag,
## the indicator and the body visibility.
func _apply_collapsed() -> void:
	_body.visible = not _collapsed
	_indicator.text = "+" if _collapsed else "-"


func _show_placeholder() -> void:
	_name_label.text = EMPTY_VALUE
	_class_label.text = EMPTY_VALUE
	_race_label.text = EMPTY_VALUE
	_level_label.text = EMPTY_VALUE
	_current_xp_label.text = "XP: " + EMPTY_VALUE
	_strength_label.text = "STR " + EMPTY_VALUE
	_dexterity_label.text = "DEX " + EMPTY_VALUE
	_constitution_label.text = "CON " + EMPTY_VALUE
	_wisdom_label.text = "WIS " + EMPTY_VALUE
	_intelligence_label.text = "INT " + EMPTY_VALUE
	_charisma_label.text = "CHA " + EMPTY_VALUE
	_health_label.text = "Health: " + EMPTY_VALUE
	_mana_label.text = "Mana: " + EMPTY_VALUE
	_attack_label.text = "ATK: " + EMPTY_VALUE
	_defense_label.text = "DEF: " + EMPTY_VALUE
	_encumbrance_label.visible = false
	_clear_properties()
	_properties.visible = false

func remove_duplicates_ordered(array: Array) -> Array:
	var seen := {}
	var output := []
	for element in array:
		if not element in seen:
			seen[element] = true
			output.append(element)
	return output


func _refresh_properties(entity: Entity) -> void:
	_clear_properties()
	var properties: Array[PropertyData] = entity.get_properties()
	_properties.visible = not properties.is_empty()
	for property: PropertyData in properties:
		var label: Label = Label.new()
		label.text = _data_name(property)
		label.theme_type_variation = &"HudCharacterProperty"
		_properties.add_child(label)


func _clear_properties() -> void:
	for child: Node in _properties.get_children():
		_properties.remove_child(child)
		child.queue_free()


func _get_race(entity: Entity) -> RaceData:
	if entity.data is EntityData:
		return (entity.data as EntityData).race
	return null


func _display_name(entity: Entity) -> String:
	var who: String = entity.get_display_name()
	return who if not who.is_empty() else "Someone"


## Data resources fall back to their id when they have no display name.
func _data_name(data: BaseData) -> String:
	if not data:
		return EMPTY_VALUE
	if not data.name.is_empty():
		return data.name
	if not String(data.id).is_empty():
		return String(data.id)
	return EMPTY_VALUE
