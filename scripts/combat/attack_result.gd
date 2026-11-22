class_name AttackResult
extends RefCounted

## Outcome of one attack roll. [Combat] only resolves it; the action layer
## applies [member damage] and fills [member killed].

var attacker: Entity = null
var target: Entity = null
var natural: int = 0
var total: int = 0
var target_ac: int = 0
var hit: bool = false
var critical: bool = false
var fumble: bool = false
var damage: int = 0
## Set by the caller after applying damage, never by [Combat].
var killed: bool = false
