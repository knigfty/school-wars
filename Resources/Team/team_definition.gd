class_name TeamDefinition
extends Resource

@export var team_id: StringName
@export var display_name: String
@export var color: Color = Color.WHITE
@export var trait_name: String
@export_multiline var trait_description: String
@export_range(0.1, 3.0, 0.05) var spawn_rate_multiplier: float = 1.0
@export_range(0.1, 3.0, 0.05) var attack_damage_multiplier: float = 1.0
@export_range(0.1, 3.0, 0.05) var maximum_health_multiplier: float = 1.0
@export_range(0.0, 100.0, 1.0) var takedown_max_health_gain: float = 0.0


func is_configured() -> bool:
	return not team_id.is_empty() and not display_name.is_empty()
