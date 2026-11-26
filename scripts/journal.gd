extends Node

## Session log shown in the Journal panel.
##
## Gameplay code calls the typed helpers (or [method add] for arbitrary text)
## from anywhere. The HUD is a pure view: it listens to [signal entry_added]
## and seeds itself from [member entries].
##
## Nothing is written while editing, so [code]@tool[/code] classes can call the
## journal without polluting it from the editor.

signal entry_added(text: String)
signal cleared

const MAX_ENTRIES: int = 200

## Entity whose point of view the entries are written from. The universe keeps
## this in sync whenever the playable entity changes.
var speaker: Entity = null
## Oldest entry first.
var entries: Array[String] = []


## Appends [param text] as a sentence. Callers can pass a bare phrase; the
## leading letter is capitalised and a period is added when missing.
func add(text: String) -> void:
	if Engine.is_editor_hint():
		return
	var line: String = _sentence(text)
	if line.is_empty():
		return
	entries.append(line)
	while entries.size() > MAX_ENTRIES:
		entries.pop_front()
	entry_added.emit(line)


func took(item: Item, actor: Entity = null) -> void:
	add("%s took %s" % [_actor_name(actor), _item_name(item)])


func dropped(item: Item, actor: Entity = null) -> void:
	add("%s dropped %s" % [_actor_name(actor), _item_name(item)])


func equipped(item: Item, actor: Entity = null) -> void:
	add("%s equipped %s" % [_actor_name(actor), _item_name(item)])


func unequipped(item: Item, actor: Entity = null) -> void:
	add("%s unequipped %s" % [_actor_name(actor), _item_name(item)])


func refused_removal(item: Item, actor: Entity = null) -> void:
	add("%s could not remove %s" % [_actor_name(actor), _item_name(item)])


## Reveals a newly learned mystic modifier. The entity is named when it is not
## the speaker. The item is named without the modifier, which is announced by
## the sentence itself.
func sensed_mystic_modifier(item: Item, actor: Entity = null) -> void:
	if not is_instance_valid(item):
		return
	var modifier: String = _mystic_modifier_word(item.mystic_modifier)
	if modifier.is_empty():
		return
	var item_name: String = _item_name(item, true, false)
	if not actor or actor == speaker:
		add("You sense %s is %s" % [item_name, modifier])
	else:
		add("%s senses %s is %s" % [_actor_name(actor), item_name, modifier])


## One line for the attack roll and, on a hit, its damage.
func attack_result(result: AttackResult, profile: AttackProfile = null) -> void:
	if not result:
		return
	var attacker_name: String = _actor_name(result.attacker)
	var target_name: String = _actor_name(result.target)
	var roll: String = _roll_text(result)
	if not result.hit:
		add("%s misses %s (%s)" % [attacker_name, target_name, roll])
		return
	var weapon: String = _weapon_phrase(profile)
	if result.critical:
		add("%s scores a critical hit on %s%s for %d damage (%s)"
				% [attacker_name, target_name, weapon, result.damage, roll])
	else:
		add("%s hits %s%s for %d damage (%s)"
				% [attacker_name, target_name, weapon, result.damage, roll])


func slain(attacker: Entity, target: Entity) -> void:
	add("%s slays %s" % [_actor_name(attacker), _actor_name(target)])


func gained_xp(actor: Entity, amount: int) -> void:
	add("%s gains %d XP" % [_actor_name(actor), amount])


func leveled_up(actor: Entity, level: int) -> void:
	add("%s reaches level %d" % [_actor_name(actor), level])


func too_heavy(actor: Entity = null) -> void:
	add("%s is too heavily laden to move" % _actor_name(actor))


func encumbrance_changed(actor: Entity, level: Encumbrance.Level) -> void:
	if level == Encumbrance.Level.NONE:
		add("%s is no longer encumbered" % _actor_name(actor))
		return
	add("%s is %s" % [_actor_name(actor), Encumbrance.display_name(level).to_lower()])


func died(actor: Entity = null) -> void:
	add("%s dies" % _actor_name(actor))


func waited(actor: Entity = null) -> void:
	add("%s waits" % _actor_name(actor))


func door_revealed() -> void:
	add("A door was revealed")


func teleported(actor: Entity = null) -> void:
	add("%s stepped through a portal" % _actor_name(actor))


func entered_dungeon(actor: Entity = null) -> void:
	add("%s entered the dungeon" % _actor_name(actor))


func took_the_lead(actor: Entity = null) -> void:
	add("%s took the lead" % _actor_name(actor))


func clear() -> void:
	if entries.is_empty():
		return
	entries.clear()
	cleared.emit()


func _actor_name(actor: Entity) -> String:
	var who: Entity = actor if actor else speaker
	if not is_instance_valid(who):
		return "Someone"
	var who_name: String = who.get_display_name()
	return who_name if not who_name.is_empty() else "Someone"


func _item_name(item: Item, with_article: bool = true,
		with_modifier: bool = true) -> String:
	if not is_instance_valid(item):
		return "something"
	var item_name: String = item.get_display_name()
	if item_name.is_empty():
		return "something"
	if with_modifier and item.mystic_known:
		var modifier: String = _mystic_modifier_word(item.mystic_modifier)
		if not modifier.is_empty():
			item_name = modifier + " " + item_name
	return "the " + item_name if with_article else item_name


func _mystic_modifier_word(modifier: Helper.MysticModifier) -> String:
	match modifier:
		Helper.MysticModifier.CURSED:
			return "cursed"
		Helper.MysticModifier.BLESSED:
			return "blessed"
	return ""


## The roll is shown as the natural die, the total modifier, the final total and
## the target's armor class, e.g. [code]d20 14 + 4 = 18 vs AC 12[/code].
func _roll_text(result: AttackResult) -> String:
	var bonus: int = result.total - result.natural
	var bonus_text: String = "+ %d" % bonus
	if bonus < 0:
		bonus_text = "- %d" % absi(bonus)
	return ("d20 %d %s = %d vs AC %d"
			% [result.natural, bonus_text, result.total, result.target_ac])


func _weapon_phrase(profile: AttackProfile) -> String:
	if not profile or not is_instance_valid(profile.weapon):
		return ""
	return " with the " + _item_name(profile.weapon, false)


func _sentence(text: String) -> String:
	var line: String = text.strip_edges()
	if line.is_empty():
		return ""
	line = line.substr(0, 1).to_upper() + line.substr(1)
	if not [".", "!", "?"].has(line.substr(line.length() - 1)):
		line += "."
	return line
