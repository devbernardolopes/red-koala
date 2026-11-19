@tool
class_name Entity
extends Base

@export_category("Basic")
@export var entity_class: ClassData = null
#@export var entity_race: RaceData = null
@export_category("Abilities")
@export_range(1, 30) var stength: int = 10
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
@export var inventory: Array[Node2D] = []
## Items that this entity will auto-take when entering the same tile.
@export var auto_take: Array[Item] = []
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
#@export var facing: 
## This should be relative to the turn-based mechanic. Albeit I am not sure if
## it should be called `energy` instead.
@export var speed: float = 10.0
@export var team: Helper.EntityTeam = Helper.EntityTeam.NEUTRAL

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
var current_inventory_item: Node2D = null

signal inventory_changed


func _ready() -> void:
	super._ready()
	collision_layer = PhysicsLayer.HERO
	collision_mask = PhysicsLayer.WALLS | PhysicsLayer.CRATES | PhysicsLayer.HERO
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


func get_move_mode() -> Helper.MoveMode:
	if is_phasing:
		return Helper.MoveMode.PHASE
	if is_flying:
		return Helper.MoveMode.FLY
	return Helper.MoveMode.WALK


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

## Also acts as the unequip action.
## If an item is [Helper.MysticModifier.CURSED] then it can't be unequiped.
func equip(item: Item) -> void:
	if not data:
		return
	if not (data as EntityData).race:
		return
	if not (data as EntityData).race.body:
		return
	if not item:
		return
	if not item.data:
		return
	if not inventory.has(item):
		return
	# Unequip item.
	if item.is_equipped:
		if item.mystic_modifier == Helper.MysticModifier.CURSED:
			# Can't unequip a cursed item.
			# TODO: Must add some sort of message (in the Journal).
			pass
		else:
			# TODO: Must add some sort of message (in the Journal).
			for bodypart in (data as EntityData).race.body:
				if bodypart.equipped_item == item:
					bodypart.equipped_item = null
					item.is_equipped = false
					remove_child(item)
					break
	else:
		if not (item.data as ItemData).equipped_on:
			return
		var can_equip: bool = false
		for bodypart in (item.data as ItemData).equipped_on:
			if (data as EntityData).race.body.has(bodypart):
				var bp: AnatomyData = (data as EntityData).race.body.get((data as EntityData).race.body.find(bodypart))
				if not bp.equipped_item:
					bp.equipped_item = item
					can_equip = true
					break
		# TODO: Must add some sort of message (in the Journal).
		if can_equip:
			item.is_equipped = true
			item.position = Vector2.ZERO
			add_child(item)
	inventory_changed.emit()


func take(item: Item) -> bool:
	if not item:
		return false
	item.get_parent().remove_child(item)
	inventory.append(item)
	inventory_changed.emit()
	return true


func drop(item: Item) -> bool:
	if not item:
		return false
	if item.is_equipped:
		if item.mystic_modifier == Helper.MysticModifier.CURSED:
			return false
		else:
			# Unequip item.
			equip(item)
	inventory.erase(item)
	item.position = position
	inventory_changed.emit()
	return true
