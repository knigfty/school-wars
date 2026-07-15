class_name HelpToggleButton
extends Button

@export var instructions_path: NodePath = NodePath("../Instructions")

var _instructions: Control


func _ready() -> void:
	toggle_mode = true
	_instructions = get_node_or_null(instructions_path) as Control
	if _instructions == null:
		push_error("%s requires an instructions panel." % name)
		disabled = true
		return
	toggled.connect(set_help_visible)
	set_help_visible(false)


func set_help_visible(show_help: bool) -> void:
	if _instructions == null:
		return
	_instructions.visible = show_help
	set_pressed_no_signal(show_help)
	tooltip_text = "Hide controls" if show_help else "Show controls"
