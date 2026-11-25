class_name MaterialData
extends BaseData

@export var flammable: bool = false
@export var damage_weakness: Array[DamageData] = []
## ResistanceData here is being used as a synonym for elemental damage.
@export var weakness: Array[ResistanceData] = []
