@tool
class_name Base
extends Area2D

signal walkability_changed
signal blocks_sight_changed

@export var data: BaseData:
	set(v):
		data = v
@export var tile_size: int = 1
@export var walkable: bool = true:
	set(v):
		if v == walkable:
			return
		walkable = v
		walkability_changed.emit()
@export var blocks_sight: bool = false:
	set(v):
		if v == blocks_sight:
			return
		blocks_sight = v
		blocks_sight_changed.emit()
@export var pushable: bool = false
## Whether this node takes part in the board logic (the "Elements" group).
## Purely visual children of other elements should opt out.
@export var in_board: bool = true
@export var color: Color = Color.DARK_KHAKI:
	set(v):
		color = v
		if polygon:
			polygon.color = color

var collision: CollisionShape2D = null
var polygon: Polygon2D = null
var light: PointLight2D = null


func _ready() -> void:
	if in_board:
		add_to_group(&"Elements")
	collision = Helper.find_control(self, "CollisionShape2D")
	if not collision:
		collision = CollisionShape2D.new()
		var collision_shape: RectangleShape2D = RectangleShape2D.new()
		collision_shape.size = ((Vector2.ONE * tile_size) * Helper.LENGTH) - (Vector2.ONE * Helper.MARGIN_1)
		collision.shape = collision_shape
		add_child(collision)
	polygon = Helper.find_control(self, "Polygon2D")
	if not polygon:
		polygon = Polygon2D.new()
		polygon.polygon = [(Vector2.UP + Vector2.LEFT) * Helper.HALF_LENGTH, 
				(Vector2.UP + Vector2.RIGHT) * Helper.HALF_LENGTH, 
				(Vector2.DOWN + Vector2.RIGHT) * Helper.HALF_LENGTH, 
				(Vector2.DOWN + Vector2.LEFT) * Helper.HALF_LENGTH] 
		polygon.color = color
		add_child(polygon)
	light = Helper.find_control(self, "PointLight2D")
	if not light:
		light = PointLight2D.new()
		light.texture = Helper.RADIAL_LIGHT
		add_child(light)
	toggle_light(false)


func toggle_light(toggle: bool) -> void:
	if not light:
		return
	light.enabled = toggle
