class_name BoardDebugOverlay
extends Node2D

## Debug view of the [Board] index. F3 toggles it from [Universe].
##
## Every occupied cell gets a translucent rect: red when it blocks a walking
## mover, yellow when it is occupied but walkable. Cells with more than one
## element show the element count.

const WALKABLE_COLOR: Color = Color(1.0, 1.0, 0.0, 0.25)
const BLOCKED_COLOR: Color = Color(1.0, 0.0, 0.0, 0.35)
const BORDER_COLOR: Color = Color(1.0, 1.0, 1.0, 0.2)

var board: Board = null


func _ready() -> void:
	board = get_parent() as Board
	if not board:
		return
	board.tile_changed.connect(_on_tile_changed)
	board.element_registered.connect(_on_element_registered)
	board.element_unregistered.connect(_on_element_unregistered)
	board.element_moved.connect(_on_element_moved)
	visible = false


func _draw() -> void:
	if not board:
		return
	var bounds: Rect2i = board.get_bounds()
	for x: int in range(bounds.position.x, bounds.end.x):
		for y: int in range(bounds.position.y, bounds.end.y):
			var tile: Vector2i = Vector2i(x, y)
			var elements: Array[Base] = board.get_elements_at(tile)
			if elements.is_empty():
				continue
			var color: Color = WALKABLE_COLOR
			if board.is_tile_blocked(tile, null, Helper.MoveMode.WALK):
				color = BLOCKED_COLOR
			var rect: Rect2 = Rect2(Vector2(tile) * Helper.LENGTH, Vector2.ONE * Helper.LENGTH)
			draw_rect(rect, color, true)
			draw_rect(rect, BORDER_COLOR, false, 1.0)
			if elements.size() > 1:
				draw_string(ThemeDB.fallback_font, rect.position + Vector2(4, 20), 
						str(elements.size()), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)


func _on_tile_changed(_tile: Vector2i) -> void:
	queue_redraw()


func _on_element_registered(_element: Base) -> void:
	queue_redraw()


func _on_element_unregistered(_element: Base) -> void:
	queue_redraw()


func _on_element_moved(_element: Base, _from_origin: Vector2i, _to_origin: Vector2i) -> void:
	queue_redraw()
