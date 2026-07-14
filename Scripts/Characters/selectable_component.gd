class_name SelectableComponent
extends Node

signal selection_changed(is_selected: bool)

const SELECTABLE_GROUP: StringName = "selectable_units"

@export var selection_indicator_path: NodePath = NodePath("../SelectionIndicator")

var _is_selected: bool = false
var _selection_indicator: CanvasItem


func _ready() -> void:
	if not get_parent() is Node2D:
		push_error("%s requires a Node2D parent." % name)
		return

	_selection_indicator = get_node_or_null(selection_indicator_path) as CanvasItem
	if _selection_indicator == null:
		push_error("%s requires a CanvasItem selection indicator." % name)
		return

	add_to_group(SELECTABLE_GROUP)
	set_selected(false)


func set_selected(value: bool) -> void:
	if _is_selected == value and _selection_indicator != null:
		_selection_indicator.visible = value
		return

	_is_selected = value
	if _selection_indicator != null:
		_selection_indicator.visible = value
	selection_changed.emit(_is_selected)


func is_selected() -> bool:
	return _is_selected


func get_screen_position() -> Vector2:
	var unit: Node2D = get_parent() as Node2D
	if unit == null:
		return Vector2.ZERO
	return unit.get_global_transform_with_canvas().origin


func get_student() -> StudentController:
	return get_parent() as StudentController
