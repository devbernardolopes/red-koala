class_name Generator
extends Node


static func create_entity(entity_class: ClassData, entity_race: RaceData, level: int = 1) -> void:
	if not entity_class:
		return
	if not entity_race:
		return
	if not level:
		return
	var entity: Entity = Entity.new()
	entity.xp = Helper.LEVEL_CHART.get(level)
	entity.in_board = true
	entity.walkable = false
	entity.tile_size = 1
