@tool
class_name Goal
extends Area2D

@export var color: Color = Color.GOLDENROD:
	set(v):
		color = v
		if polygon:
			polygon.color = color

var collision: CollisionShape2D = null
var polygon: Polygon2D = null


func _ready() -> void:
	add_to_group(&"Elements")
	collision = CollisionShape2D.new()
	var collision_shape: RectangleShape2D = RectangleShape2D.new()
	collision_shape.size = (Vector2.ONE * Helper.LENGTH) - (Vector2.ONE * Helper.MARGIN_1)
	collision.shape = collision_shape
	collision_layer = PhysicsLayer.GOALS
	collision_mask = PhysicsLayer.WALLS | PhysicsLayer.CRATES | PhysicsLayer.HERO
	add_child(collision)
	polygon = Polygon2D.new()
	polygon.polygon = [
			(Vector2.UP + Vector2.ZERO) * Helper.HALF_LENGTH, 
			(Vector2.ZERO + Vector2.RIGHT) * Helper.HALF_LENGTH, 
			(Vector2.DOWN + Vector2.ZERO) * Helper.HALF_LENGTH, 
			(Vector2.ZERO + Vector2.LEFT) * Helper.HALF_LENGTH
			]
	polygon.color = color
	add_child(polygon)
	connect("area_entered", _on_area_entered)


func _on_area_entered(area: Area2D) -> void:
	if area is Crate:
		print(area.name)
	#pass
