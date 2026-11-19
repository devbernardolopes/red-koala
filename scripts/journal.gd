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
	add("%s could not remove the cursed %s" % [_actor_name(actor), _item_name(item, false)])


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


func _item_name(item: Item, with_article: bool = true) -> String:
	if not is_instance_valid(item):
		return "something"
	var item_name: String = item.get_display_name()
	if item_name.is_empty():
		return "something"
	return "the " + item_name if with_article else item_name


func _sentence(text: String) -> String:
	var line: String = text.strip_edges()
	if line.is_empty():
		return ""
	line = line.substr(0, 1).to_upper() + line.substr(1)
	if not [".", "!", "?"].has(line.substr(line.length() - 1)):
		line += "."
	return line
