class_name Encumbrance
extends RefCounted

## Encumbrance bands derived from the ratio between the weight an entity carries
## and its carry capacity.
##
## Nothing here touches the world: [method level_for] only observes an entity,
## and [Entity] caches the result in [member Entity.encumbrance_level]. All
## balance numbers live in the constants below so they are easy to retune.

enum Level {
	NONE,
	BURDENED,
	STRAINED,
	OVERLOADED,
}

## Ratios of carried weight to carry capacity. Up to [constant NONE_MAX_RATIO]
## there is no penalty, up to [constant BURDENED_MAX_RATIO] the entity is
## burdened, up to [constant STRAINED_MAX_RATIO] it is strained and beyond that
## it is overloaded.
const NONE_MAX_RATIO: float = 1.0
const BURDENED_MAX_RATIO: float = 1.5
const STRAINED_MAX_RATIO: float = 2.0

## Speed multipliers per band.
const BURDENED_SPEED_MULTIPLIER: float = 0.75
const STRAINED_SPEED_MULTIPLIER: float = 0.5
const OVERLOADED_SPEED_MULTIPLIER: float = 0.5

## Combat penalties per band.
const STRAINED_ATTACK_PENALTY: int = 2
const OVERLOADED_ATTACK_PENALTY: int = 2
const STRAINED_DEFENSE_PENALTY: int = 2
const OVERLOADED_DEFENSE_PENALTY: int = 2


## The band [param entity] falls into right now. Entities with no capacity at
## all are treated as unencumbered.
static func level_for(entity: Entity) -> Level:
	if not is_instance_valid(entity):
		return Level.NONE
	var capacity: float = entity.get_carry_capacity()
	if capacity <= 0.0:
		return Level.NONE
	var ratio: float = entity.get_carried_weight() / capacity
	if ratio <= NONE_MAX_RATIO:
		return Level.NONE
	if ratio <= BURDENED_MAX_RATIO:
		return Level.BURDENED
	if ratio <= STRAINED_MAX_RATIO:
		return Level.STRAINED
	return Level.OVERLOADED


static func speed_multiplier(level: Level) -> float:
	match level:
		Level.BURDENED:
			return BURDENED_SPEED_MULTIPLIER
		Level.STRAINED:
			return STRAINED_SPEED_MULTIPLIER
		Level.OVERLOADED:
			return OVERLOADED_SPEED_MULTIPLIER
	return 1.0


static func attack_penalty(level: Level) -> int:
	match level:
		Level.STRAINED:
			return STRAINED_ATTACK_PENALTY
		Level.OVERLOADED:
			return OVERLOADED_ATTACK_PENALTY
	return 0


static func defense_penalty(level: Level) -> int:
	match level:
		Level.STRAINED:
			return STRAINED_DEFENSE_PENALTY
		Level.OVERLOADED:
			return OVERLOADED_DEFENSE_PENALTY
	return 0


static func blocks_movement(level: Level) -> bool:
	return level == Level.OVERLOADED


static func display_name(level: Level) -> String:
	match level:
		Level.BURDENED:
			return "Burdened"
		Level.STRAINED:
			return "Strained"
		Level.OVERLOADED:
			return "Overloaded"
	return "Unencumbered"
