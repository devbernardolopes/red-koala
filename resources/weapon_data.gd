class_name WeaponData
extends ItemData

@export var damage_dice: int = 1
@export var damage_sides: int = 4
@export var attack_bonus: int = 0
@export var damage_bonus: int = 0
## Finesse weapons use the higher of Strength and Dexterity.
@export var finesse: bool = false
## Ranged weapons use Dexterity. Ranged attacks are not implemented yet.
@export var ranged: bool = false
## Category here indicates which skill is needed to wield this weapon without 
## penalty.
@export var category: SkillData = null
@export var damage_type: DamageData = null
@export var damage_element: ResistanceData = null
