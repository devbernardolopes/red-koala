class_name ItemData
extends BaseData

## Weight always in kilograms (Kg).
@export var weight: float = 1.0
@export var material: MaterialData = null
@export var equipped_on: Array[AnatomyData] = []
## If true then this item can only be equipped if all [param equipped_on] of an
## entity exists for the entity and are currently free. Then it will use all
## the required slots.
@export var requires_all_slots: bool = false
## Properties this item can grant when equipped.
@export var properties: Array[PropertyData] = []
## TODO: Yet to implement this rarity mechanic.
## The value must be between 0.01 (rarest) and 1.00 (commonest).
@export_range(0.01, 1.0, 0.01) var rarity: float = 1.0
## TODO: Yet to implement this durability mechanic.
## The value must be between 0.00 (destroyed) and 1.00 (pristine, mint 
## condition).
@export_range(0.0, 1.0, 0.01) var durability: float = 1.0
