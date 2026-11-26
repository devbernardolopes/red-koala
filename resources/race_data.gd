class_name RaceData
extends BaseData

@export var body: Array[AnatomyData] = []
@export var diet: DietData = null
@export var corpse_visual: PackedScene = null
## Starting scores for abilities of an entity of this race at level 1.
@export var base_abilities: Array[AbilityScoreData] = []
