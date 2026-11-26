class_name ClassData
extends BaseData

@export var distribution: Array[AbilityData] = []
## Level 1 hit points. Every level after the first adds [member hit_die_count]
## dice of [member hit_die_sides] plus the Constitution modifier.
@export var base_hit_points: int = 1
## Level 1 mana points. Every level after the first adds [member mana_die_count]
## dice of [member mana_die_sides] plus the Wisdom modifier.
@export var base_mana_points: int = 1
@export var hit_die_count: int = 1
@export var hit_die_sides: int = 6
## Zero mana die sides means the class gains no mana when levelling up.
@export var mana_die_count: int = 0
@export var mana_die_sides: int = 0
## Resistances and properties that an entity of this class acquires at certain
## levels.
@export var feats: Array[FeatData] = []
## Skills an entity of this class starts with.
@export var skills: Array[SkillData] = []
#@export var base_abilities: Array[]
