class_name Dice
extends Node


## Dice roll where [param _sides] is the kind of dice, [param _how_many] is how
## many throws it will be made, [param _modifier] is the optional positive
## or negative bonus added to each throw, and [param _advantage] is the 
## advantage (takes only the highest result of the throws), disavantage (takes
## only the lowest result of the throws), or none. 
static func d(_sides: int = 6, 
		_how_many: int = 1, 
		_modifier: int = 0, 
		_advantage: Helper.DiceAdvantage = Helper.DiceAdvantage.NONE) -> int:
	var result: int = 0
	for die in range(_how_many):
		var r: int = (randi() % _sides + 1) + _modifier
		if _advantage == Helper.DiceAdvantage.DISADVANTAGE:
			if result == 0:
				result = 9999
			if r < result:
				result = r
		elif _advantage == Helper.DiceAdvantage.ADVANTAGE:
			if r > result:
				result = r
		else:
			result += r
	return result
