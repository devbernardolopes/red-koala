class_name AttackProfile
extends RefCounted

## Everything an attack needs that does not depend on the target: the weapon (or
## an unarmed strike), which ability drives it and the dice it rolls.

var weapon: Item = null
## Ability code used for the attack and damage modifiers ([code]STR[/code] or
## [code]DEX[/code]).
var ability: StringName = &"STR"
## Bonus printed on the weapon itself. Proficiency and the ability modifier are
## added by [Combat].
var attack_bonus: int = 0
var damage_dice: int = 1
var damage_sides: int = 4
var damage_bonus: int = 0
var is_ranged: bool = false
## Reserved for future resistances; nothing reads it yet.
var damage_type: StringName = &"physical"
