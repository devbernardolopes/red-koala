class_name EntityData
extends BaseData

@export var playable: bool = false
@export var race: RaceData = null
@export var resistances: Array[ResistanceData] = []
@export var properties: Array[PropertyData] = []
## Experience awarded to whoever lands the killing blow on this entity. Heroes
## stay at zero: playable entities gain XP by killing, they are not worth XP.
@export var xp_reward: int = 0
