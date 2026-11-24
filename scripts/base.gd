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
@export var breakable: bool = false
@export var locked: bool = false
@export var pushable: bool = false
## Whether this node is concealed (not visible for an entity even if no fog of
## war tile obscures it).
@export var concealed: bool = false
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
var create_polygon: bool = true
## Lazily created visual-only animator. Null in the editor.
var visual: VisualAnimator = null
## Authored light position, so visual offsets can be added without drifting.
var light_base_position: Vector2 = Vector2.ZERO


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
		if create_polygon:
			if not Engine.is_editor_hint():
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
	light_base_position = light.position
	toggle_light(false)


## The visual-only animator, created on first use. Returns null in the editor
## and for elements without a polygon.
func get_visual() -> VisualAnimator:
	if Engine.is_editor_hint():
		return null
	if not polygon:
		return null
	if not is_instance_valid(visual):
		visual = VisualAnimator.new()
		visual.base = self
		add_child(visual)
	return visual


## World position the camera should follow: the logical position plus the slide
## offset only, so idle wobble and attacks never shake the camera.
func get_camera_anchor() -> Vector2:
	if is_instance_valid(visual):
		return global_position + visual.slide_offset
	return global_position


func toggle_light(toggle: bool) -> void:
	if not light:
		return
	light.enabled = toggle


func toggle_concealment(toggle: bool) -> void:
	concealed = toggle


## Name shown in the journal and other UI. Subclasses may override it.
func get_display_name() -> String:
	return name
