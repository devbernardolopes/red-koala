class_name HudItemVisual
extends Control

## Draws a scaled-down preview of an [Item] by duplicating its [Polygon2D]
## children. Items author their looks as polygons (sometimes several, sometimes
## nested), so a copy is the most faithful and cheapest way to render them in
## the HUD.

const CELL_SIZE: float = 24.0
const PREVIEW_MARGIN: float = 3.0

var _preview: Node2D = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Replaces the current preview with the polygons of [param item]. Passing
## [code]null[/code] only clears it.
func setup(item: Item) -> void:
	clear()
	if not item:
		return
	var polygons: Array[Polygon2D] = []
	var min_point: Vector2 = Vector2.INF
	var max_point: Vector2 = -Vector2.INF
	var has_points: bool = false
	for child: Node in item.get_children():
		if not child is Polygon2D:
			continue
		var polygon: Polygon2D = child as Polygon2D
		var _duplicate: Polygon2D = polygon.duplicate() as Polygon2D
		polygons.append(_duplicate)
		for point: Vector2 in polygon.polygon:
			var local: Vector2 = polygon.position + (point + polygon.offset).rotated(polygon.rotation) * polygon.scale
			min_point = min_point.min(local)
			max_point = max_point.max(local)
			has_points = true
	if polygons.is_empty() or not has_points:
		return
	_preview = Node2D.new()
	add_child(_preview)
	for polygon: Polygon2D in polygons:
		_preview.add_child(polygon)
	var extent: Vector2 = max_point - min_point
	var longest: float = maxf(extent.x, extent.y)
	var available: float = CELL_SIZE - PREVIEW_MARGIN * 2.0
	var preview_scale: float = available / longest if longest > 0.0 else 1.0
	_preview.scale = Vector2.ONE * preview_scale
	_preview.position = Vector2(CELL_SIZE, CELL_SIZE) * 0.5 - ((min_point + max_point) * 0.5) * preview_scale


## Removes the current preview, if any.
func clear() -> void:
	if not _preview:
		return
	remove_child(_preview)
	_preview.queue_free()
	_preview = null
