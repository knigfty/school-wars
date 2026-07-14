class_name TeamDefinition
extends Resource

@export var team_id: StringName
@export var display_name: String
@export var color: Color = Color.WHITE


func is_configured() -> bool:
	return not team_id.is_empty() and not display_name.is_empty()
