class_name SpellSkillLevel
extends BaseData

@export var skill_level: SkillLevelData = null
@export var target_kind: Helper.SpellTarget = Helper.SpellTarget.SELF
## Range in tiles for this spell at this level.
## If [member target_kind] is SELF, then it doesn't matter.
## If [member target_kind] is AREA, then it will be a square of length between 
## [member spell_range_min] and [member spell_range_max] in tiles with the 
## caster as its center.
## If [member target_kind] is DIRECTION, then it will be a line of length 
## between [member spell_range_min] and [member spell_range_max] in tiles with 
## the caster as its origin.
@export var spell_range_min: int = 1
@export var spell_range_max: int = 1
@export var dice: int = 1
@export var sides: int = 2
## Duration in turns of this spell at this level. This isn't relevant to all
## spells.
@export var duration: int = 0
