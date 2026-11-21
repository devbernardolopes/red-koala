class_name Dice
extends Node


## Dice roll where [param _sides] is the kind of dice, [param _how_many] is how
## many throws it will be made, and [param _modifier] is the optional positive
## or negative bonus added to each throw. 
static func d(_sides: int = 6, _how_many: int = 1, _modifier: int = 0) -> int:
	var result: int = 0
	for die in range(_how_many):
		result += (randi() % _sides + 1) + _modifier
	return result
