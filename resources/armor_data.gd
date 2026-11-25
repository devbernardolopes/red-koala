class_name ArmorData
extends ItemData

@export var defense: int = 1
## Category here indicates which skill is needed to wear this armor without 
## penalty.
@export var category: SkillData = null
## Which damage types, if any, this armor has defense bonus against.
@export var bonus_against: Array[DamageData] = []
