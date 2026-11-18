class_name ItemSlot
extends MarginContainer

var item: Item = null
var visual: Polygon2D = null
var name_label: Label = null


func _init(_item: Item) -> void:
	if not _item:
		print("No item!")
		return
	if not _item.data:
		print("No item.data!")
		return
	item = _item
	_set_visual(item.polygon)
	_set_name(_item.data.name)


func _set_visual(polygon: Polygon2D) -> void:
	if not polygon:
		print("No polygon!")
		return
	#add_child(item)
	visual = Helper.find_control(self, "Polygon2D", &"Visual")
	if not visual:
		visual = Polygon2D.new()
		add_child(visual)
	visual.polygon = polygon.polygon


func _set_name(_name: String) -> void:
	if not _name:
		return
	name_label = Helper.find_control(self, "Label", &"NameLabel")
	if not name_label:
		name_label = Label.new()
		add_child(name_label)
	name_label.text = _name
