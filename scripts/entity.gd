@tool
class_name Entity
extends Base

## Attack rolls, damage and armor class are implemented by [Combat]. The action
## layer ([EntityActions]) is the only place that applies them to the world:
## melee attacks use the first equipped weapon (or an unarmed strike), and a
## player bumps into a visible hostile to attack it.
##
## Damage and death are handled by [method take_damage]. Reaching zero hit
## points sets [member is_dead] and emits [signal died]; the universe then
## removes the entity and leaves a [Corpse] behind.

enum EquipResult {
	EQUIPPED,
	UNEQUIPPED,
	REFUSED_CURSED,
	NO_BODY_PART,
	INVALID,
}

## Kilograms an entity can carry per point of Strength.
const CARRY_KG_PER_STRENGTH: float = 7.5

@export_category("Basic")
@export var entity_class: ClassData = null
## Optional name used by the journal; falls back to the node name when empty.
@export var display_name: String = ""
@export_category("Abilities")
@export_range(1, 30) var strength: int = 10
@export_range(1, 30) var dexterity: int = 10
@export_range(1, 30) var constitution: int = 10
@export_range(1, 30) var charisma: int = 10
@export_range(1, 30) var wisdom: int = 10
@export_range(1, 30) var intelligence: int = 10
@export_category("Points")
@export var level: int = 1
@export var xp: int = 0
@export var max_hit_points: int = 1
@export var hit_points: int = 1
@export var max_mana_points: int = 1
@export var mana_points: int = 1
## Field-of view which is a square with size in tiles starting at the entity's
## center.
@export var fov: int = 4
@export_category("In-Game")
@export var inventory: Array[Item] = []
## Items currently worn or wielded by this entity, keyed by body part. Equipment
## is per entity even though [RaceData.body] is a shared resource.
var equipment: Dictionary[AnatomyData, Item] = {}
## Items that this entity will auto-take when entering the same tile.
@export var auto_take: Array[ItemData] = []
## These are properties that can be added via equipped items or spells or other
## stuff.
@export var added_properties: Array[PropertyData] = []
@export var is_invisible: bool = false:
	set(v):
		is_invisible = v
		_toggle_invisible(v)
@export var is_phasing: bool = false:
	set(v):
		is_phasing = v
		_toggle_phasing(v)
@export var is_flying: bool = false:
	set(v):
		is_flying = v
		_toggle_flying(v)
@export var can_see_invisible: bool = false
@export_category("Mechanics")
## TODO: Must implement a facing mechanic flipping the entity's visuals left and
## right when needed and also having effects in the field of view if the field
## of view is not a square or a circle (this field of view specifics is not 
## implemented yet).
#@export var facing: 
## This should be relative to the turn-based mechanic. Albeit I am not sure if
## it should be called `energy` instead.
@export var speed: float = 10.0
@export var team: Helper.EntityTeam = Helper.EntityTeam.NEUTRAL

## Action points left in the current round. Starts empty and accumulates from
## [member speed] at the start of every round; the turn manager spends one
## action's cost per action taken.
var energy: int = 0
## Cached encumbrance band, recomputed whenever the inventory or the stats
## change.
var encumbrance_level: Encumbrance.Level = Encumbrance.Level.NONE
var _updating_encumbrance: bool = false
## Set once hit points reach zero. Dead entities are ignored by perception and
## cannot act or be attacked.
var is_dead: bool = false
var phasing_tween: Tween = null
var flying_tween: Tween = null
var visible_notifier: VisibleOnScreenNotifier2D = null
var is_playable: bool = false:
	set(v):
		is_playable = v
		visible_notifier = Helper.find_control(self, "VisibleOnScreenNotifier2D")
		if is_playable:
			if not visible_notifier:
				visible_notifier = VisibleOnScreenNotifier2D.new()
				add_child(visible_notifier)
		else:
			if visible_notifier:
				visible_notifier.queue_free()
var current_inventory_item: Item = null
## Cached [BrainComponent], set by the brain itself when it becomes ready. Kept
## untyped to avoid a dependency cycle between Entity and BrainComponent.
var brain: Node = null

signal inventory_changed
signal damaged(amount: int, source: Entity)
signal died(source: Entity)
signal leveled_up(new_level: int)
signal encumbrance_changed(level: Encumbrance.Level)
signal stats_changed


func _ready() -> void:
	super._ready()
	collision_layer = PhysicsLayer.HERO
	collision_mask = PhysicsLayer.WALLS | PhysicsLayer.CRATES | PhysicsLayer.HERO
	inventory_changed.connect(_update_encumbrance)
	stats_changed.connect(_update_encumbrance)
	_update_encumbrance()
	if is_playable and not visible_notifier:
		visible_notifier = Helper.find_control(self, "VisibleOnScreenNotifier2D")
		if not visible_notifier:
			visible_notifier = VisibleOnScreenNotifier2D.new()
			add_child(visible_notifier)
		push_warning(name, " = No visible_notifier!")
	if not data:
		push_warning(name, " = No data!")
		return
	if not data.race:
		push_warning(name, " = No race!")
	if not entity_class:
		push_warning(name, " = No entity class!")
	_toggle_invisible(is_invisible)
	_toggle_phasing(is_phasing)
	_toggle_flying(is_flying)
	_update_properties()
	_init_values()


func _init_values() -> void:
	max_hit_points = (entity_class as ClassData).base_hit_points
	hit_points = max_hit_points
	max_mana_points = (entity_class as ClassData).base_mana_points
	mana_points = max_mana_points


## Adds [param amount] experience and applies every level-up it unlocks.
## Returns how many levels were gained.
func gain_xp(amount: int) -> int:
	if amount <= 0:
		return 0
	xp += amount
	var gained: int = 0
	while level < Helper.level_for_xp(xp):
		_level_up()
		gained += 1
	stats_changed.emit()
	return gained


## Rises one level, rolling the class's hit and mana dice. The Constitution
## modifier is added to the hit points; the Wisdom modifier to the mana.
func _level_up() -> void:
	level += 1
	if entity_class:
		var gained_hit_points: int = maxi(1, Dice.roll(
				entity_class.hit_die_count,
				entity_class.hit_die_sides) + get_ability_modifier(&"CON"))
		max_hit_points += gained_hit_points
		hit_points += gained_hit_points
		if entity_class.mana_die_sides > 0:
			var gained_mana: int = maxi(0, Dice.roll(
					entity_class.mana_die_count,
					entity_class.mana_die_sides) + get_ability_modifier(&"WIS"))
			max_mana_points += gained_mana
			mana_points += gained_mana
	leveled_up.emit(level)


func get_move_mode() -> Helper.MoveMode:
	if is_phasing:
		return Helper.MoveMode.PHASE
	if is_flying:
		return Helper.MoveMode.FLY
	return Helper.MoveMode.WALK


## Speed after encumbrance and, later, any other multiplier such as haste or
## slow. The exported [member speed] stays the base value; this is the single
## place every speed modifier is applied.
func get_effective_speed() -> float:
	return speed * Encumbrance.speed_multiplier(encumbrance_level)


func get_display_name() -> String:
	if display_name.is_empty():
		return name
	return display_name


## Applies [param amount] damage from [param source]. Dead entities ignore
## further damage, and hit points never leave the [code][0, max_hit_points][/code]
## range. Returns how much damage was actually dealt.
func take_damage(amount: int, source: Entity = null) -> int:
	if is_dead or amount <= 0:
		return 0
	var previous: int = hit_points
	hit_points = clampi(hit_points - amount, 0, max_hit_points)
	var dealt: int = previous - hit_points
	damaged.emit(dealt, source)
	stats_changed.emit()
	if hit_points == 0:
		is_dead = true
		died.emit(source)
	return dealt


## Ability modifier for [param code] ([code]STR[/code], [code]DEX[/code],
## [code]CON[/code], [code]INT[/code], [code]WIS[/code] or [code]CHA[/code]).
func get_ability_modifier(code: StringName) -> int:
	match code:
		&"STR":
			return Combat.ability_modifier(strength)
		&"DEX":
			return Combat.ability_modifier(dexterity)
		&"CON":
			return Combat.ability_modifier(constitution)
		&"INT":
			return Combat.ability_modifier(intelligence)
		&"WIS":
			return Combat.ability_modifier(wisdom)
		&"CHA":
			return Combat.ability_modifier(charisma)
	return 0


func get_armor_class() -> int:
	return Combat.armor_class(self)


func get_proficiency_bonus() -> int:
	return Combat.proficiency_bonus(level)


## Extra Strength granted by items and other effects. Nothing feeds it yet;
## carry capacity and Strength-based rules read it once they exist.
func get_strength_bonus() -> int:
	return 0


## Kilograms this entity can carry before being encumbered.
func get_carry_capacity() -> float:
	return float(strength + get_strength_bonus()) * CARRY_KG_PER_STRENGTH


## Total weight in kilograms of every carried item. Equipped items count even
## when they are not listed in [member inventory].
func get_carried_weight() -> float:
	var total: float = 0.0
	var counted: Dictionary[Item, bool] = {}
	var items: Array[Item] = []
	items.append_array(inventory)
	items.append_array(get_equipped_items())
	for item: Item in items:
		if not item or counted.has(item):
			continue
		counted[item] = true
		if item.data is ItemData:
			total += (item.data as ItemData).weight
	return total


func _toggle_invisible(toggle: bool) -> void:
	if not polygon:
		return
	if toggle:
		polygon.self_modulate.a = 0.5
	else:
		polygon.self_modulate.a = 1.0


func _toggle_phasing(toggle: bool) -> void:
	if not polygon:
		return
	if toggle:
		if not phasing_tween:
			phasing_tween = create_tween()
			phasing_tween.tween_property(polygon, "position", Vector2(-1, 0), 0.15).set_ease(Tween.EASE_IN)
			phasing_tween.tween_property(polygon, "position", Vector2(1, 0), 0.15)
			phasing_tween.set_loops()
		else:
			phasing_tween.play()
	else:
		if phasing_tween:
			phasing_tween.stop()


func _toggle_flying(toggle: bool) -> void:
	if not polygon:
		return
	if toggle:
		if not flying_tween:
			flying_tween = create_tween()
			flying_tween.tween_property(polygon, "position", Vector2(0, -4.0), 0.15).set_ease(Tween.EASE_IN)
			flying_tween.tween_property(polygon, "position", Vector2(0, 4.0), 0.15)
			flying_tween.set_loops()
		else:
			flying_tween.play()
	else:
		if flying_tween:
			flying_tween.stop()

## The item worn on [param part], or [code]null[/code] when the slot is empty.
func get_equipped_item(part: AnatomyData) -> Item:
	return equipment.get(part) as Item


## Every item currently equipped by this entity, in no particular order.
func get_equipped_items() -> Array[Item]:
	var result: Array[Item] = []
	for value: Variant in equipment.values():
		if value is Item and not result.has(value as Item):
			result.append(value as Item)
	return result


## Every property granted to this entity, deduplicated by [member BaseData.id].
## The order of precedence is [member EntityData.properties], the properties of
## every equipped item and finally [member added_properties]. Always returns a
## new array, so callers may modify their copy without touching the shared data
## resources.
func get_properties() -> Array[PropertyData]:
	var result: Array[PropertyData] = []
	var seen: Dictionary[StringName, bool] = {}
	if data is EntityData:
		_collect_properties((data as EntityData).properties, result, seen)
	for item: Item in get_equipped_items():
		_collect_properties(item.properties, result, seen)
	_collect_properties(added_properties, result, seen)
	return result


## Appends the properties of [param source] that have not been seen yet.
func _collect_properties(
		source: Array[PropertyData],
		result: Array[PropertyData],
		seen: Dictionary[StringName, bool]) -> void:
	for property: PropertyData in source:
		if not property or seen.has(property.id):
			continue
		seen[property.id] = true
		result.append(property)


## Whether any of this entity's properties has [param property_id].
func has_property_id(property_id: StringName) -> bool:
	for property: PropertyData in get_properties():
		if property.id == property_id:
			return true
	return false


## Grants [param property] to this entity at runtime, such as through a spell.
func add_property(property: PropertyData) -> void:
	if not property or added_properties.has(property):
		return
	added_properties.append(property)
	_update_properties()
	stats_changed.emit()


## Revokes a property previously granted through [method add_property].
func remove_property(property: PropertyData) -> void:
	if not property or not added_properties.has(property):
		return
	added_properties.erase(property)
	_update_properties()
	stats_changed.emit()


## Also acts as the unequip action.
## If an item is [Helper.MysticModifier.CURSED] then it can't be unequiped.
func equip(item: Item) -> EquipResult:
	if not data:
		return EquipResult.INVALID
	if not (data as EntityData).race:
		return EquipResult.INVALID
	if not (data as EntityData).race.body:
		return EquipResult.INVALID
	if not item:
		return EquipResult.INVALID
	if not item.data:
		return EquipResult.INVALID
	if not inventory.has(item):
		return EquipResult.INVALID
	if not polygon:
		return EquipResult.INVALID
	var result: EquipResult = EquipResult.INVALID
	# Unequip item.
	if item.is_equipped:
		if item.mystic_modifier == Helper.MysticModifier.CURSED:
			# Can't unequip a cursed item.
			result = EquipResult.REFUSED_CURSED
		elif force_unequip(item):
			result = EquipResult.UNEQUIPPED
	else:
		if not (item.data as ItemData).equipped_on:
			return EquipResult.INVALID
		for bodypart: AnatomyData in (item.data as ItemData).equipped_on:
			var bp: AnatomyData = _find_body_part(bodypart)
			if not bp:
				continue
			if equipment.has(bp):
				continue
			equipment[bp] = item
			item.is_equipped = true
			item.position = Vector2.ZERO + bp.equipped_offset
			polygon.add_child(item)
			result = EquipResult.EQUIPPED
			break
		if result == EquipResult.INVALID:
			result = EquipResult.NO_BODY_PART
	_update_properties()
	inventory_changed.emit()
	_sort_equipped_items()
	return result


func _update_properties() -> void:
	is_flying = false
	is_phasing = false
	is_invisible = false
	for property: PropertyData in get_properties():
		if property.id == &"flight":
			is_flying = true
		elif property.id == &"phasing":
			is_phasing = true
		elif property.id == &"invisibility":
			is_invisible = true


## Recomputes the encumbrance band and reports a change only when it moves.
## Called from [signal inventory_changed] and [signal stats_changed]; the guard
## keeps a listener that changes either signal from looping back in.
func _update_encumbrance() -> void:
	if _updating_encumbrance:
		return
	_updating_encumbrance = true
	var _level: Encumbrance.Level = Encumbrance.level_for(self)
	_updating_encumbrance = false
	if _level == encumbrance_level:
		return
	encumbrance_level = _level
	encumbrance_changed.emit(_level)


## TODO: Must implement this function that will sort the equipped items
## visually so that items equipped on some bodyparts such as hands will be
## rendered on top of other items.
func _sort_equipped_items() -> void:
	if not equipment or equipment.is_empty():
		return


## Clears the slot holding [param item] regardless of its mystic modifier.
## Returns whether the item was equipped. Used by [method drop] on death, where
## the cursed rule no longer applies.
func force_unequip(item: Item) -> bool:
	if not item:
		return false
	var slot: AnatomyData = null
	for part: AnatomyData in equipment:
		if equipment[part] == item:
			slot = part
			break
	if not slot:
		return false
	equipment.erase(slot)
	item.is_equipped = false
	if polygon and item.get_parent() == polygon:
		polygon.remove_child(item)
	return true


func _find_body_part(bodypart: AnatomyData) -> AnatomyData:
	if not data or not (data is EntityData):
		return null
	var race: RaceData = (data as EntityData).race
	if not race:
		return null
	for candidate: AnatomyData in race.body:
		if candidate == bodypart:
			return candidate
	return null


func take(item: Item) -> bool:
	if not item:
		return false
	item.get_parent().remove_child(item)
	inventory.append(item)
	inventory_changed.emit()
	return true


## Removes [param item] from the inventory. An equipped item is unequipped
## through the same slot-clearing path as [method equip]. Cursed items are
## refused unless [param _ignore_cursed] is set, which the universe uses when
## the entity dies.
func drop(item: Item, _ignore_cursed: bool = false) -> bool:
	if not item:
		return false
	if item.is_equipped:
		if item.mystic_modifier == Helper.MysticModifier.CURSED and not _ignore_cursed:
			return false
		if _ignore_cursed:
			force_unequip(item)
			item.is_equipped = false
		elif equip(item) != EquipResult.UNEQUIPPED:
			return false
	inventory.erase(item)
	item.position = position
	inventory_changed.emit()
	return true
