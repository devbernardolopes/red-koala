@tool
class_name Corpse
extends Base

## What an entity leaves behind when it dies. Corpses are walkable, do not block
## sight and cannot be pushed, so they never change movement or perception
## rules. They persist for the whole session.

@export var display_name: String = ""

## Markers for code that wants to tell corpses apart from other board elements.
var is_corpse: bool = true
var corpse_visual: CorpseVisual = null


func _init() -> void:
	walkable = true
	blocks_sight = false
	pushable = false


func _ready() -> void:
	super._ready()
	collision_layer = 0
	collision_mask = 0
	add_to_group(&"Corpses")


## Builds a corpse at the dead entity's position, with its footprint and a
## dimmed version of its colour.
static func create_from(entity: Entity) -> Corpse:
	var corpse: Corpse = Corpse.new()
	if not is_instance_valid(entity):
		return corpse
	corpse.create_polygon = false
	if not (entity.data as EntityData).race.corpse_visual:
		var _color: Color = entity.color
		if entity.polygon:
			_color = entity.polygon.color
		corpse.color = _color.darkened(0.4)
		corpse.create_polygon = true
	corpse.position = entity.position
	corpse.tile_size = entity.tile_size
	corpse.display_name = "Corpse of %s" % entity.get_display_name()
	return corpse


func get_display_name() -> String:
	if display_name.is_empty():
		return "Corpse"
	return display_name
