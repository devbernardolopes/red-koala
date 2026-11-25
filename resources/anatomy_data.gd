class_name AnatomyData
extends BaseData

@export var side: Helper.AnatomySide = Helper.AnatomySide.CENTER
@export var position: Helper.AnatomyPosition = Helper.AnatomyPosition.CENTER
@export var material: MaterialData = null
@export var equipped_offset: Vector2 = Vector2.ZERO
## Local render priority for an item occupying this body part. Negative values
## render behind the entity; non-negative values render over it.
@export var draw_order: int = 0
