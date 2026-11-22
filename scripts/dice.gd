class_name Dice
extends Node

## Shared random source for every roll. Tests can make results deterministic
## with [method seed_rng] without touching any other code.
static var rng: RandomNumberGenerator = RandomNumberGenerator.new()


static func seed_rng(seed_value: int) -> void:
	rng.seed = seed_value


## Sum of [param count] dice with [param sides] sides. [param bonus] is added
## once after the dice, never per die.
static func roll(count: int, sides: int, bonus: int = 0) -> int:
	var total: int = bonus
	var _sides: int = maxi(sides, 1)
	for _die: int in maxi(count, 0):
		total += rng.randi_range(1, _sides)
	return total


## Rolls a d20 with an optional modifier and advantage/disadvantage. The
## modifier is added once to the kept natural value.
static func roll_d20(modifier: int = 0,
		advantage: Helper.DiceAdvantage = Helper.DiceAdvantage.NONE) -> Dictionary:
	var natural: int = rng.randi_range(1, 20)
	if advantage != Helper.DiceAdvantage.NONE:
		var other: int = rng.randi_range(1, 20)
		if advantage == Helper.DiceAdvantage.ADVANTAGE:
			natural = maxi(natural, other)
		else:
			natural = mini(natural, other)
	return {"natural": natural, "total": natural + modifier}


## Legacy entry point kept for existing callers. With no advantage this is a
## sum of [param _how_many] dice and [param _modifier] is added to every die,
## matching the old behaviour. Advantage/disadvantage keeps the highest or
## lowest die before the modifier is added.
static func d(_sides: int = 6,
		_how_many: int = 1,
		_modifier: int = 0,
		_advantage: Helper.DiceAdvantage = Helper.DiceAdvantage.NONE) -> int:
	var _count: int = maxi(_how_many, 0)
	if _count == 0:
		return 0
	if _advantage == Helper.DiceAdvantage.NONE:
		return roll(_count, _sides, _modifier * _count)
	var best: int = 0
	var worst: int = 0
	for i: int in _count:
		var natural: int = rng.randi_range(1, maxi(_sides, 1))
		if i == 0:
			best = natural
			worst = natural
		else:
			best = maxi(best, natural)
			worst = mini(worst, natural)
	if _advantage == Helper.DiceAdvantage.ADVANTAGE:
		return best + _modifier
	return worst + _modifier
