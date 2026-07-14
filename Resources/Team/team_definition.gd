class_name TeamDefinition
extends Resource

@export var team_id: StringName
@export var display_name: String
@export var color: Color = Color.WHITE
@export var trait_name: String
@export_multiline var trait_description: String
@export_range(1.0, 60.0, 1.0) var base_spawn_interval: float = 15.0
@export_range(0.0, 10.0, 0.5) var territory_spawn_reduction: float = 1.0
@export_range(1, 100, 1) var maximum_students: int = 10
@export_range(1.0, 1000.0, 1.0) var starting_health: float = 100.0
@export_range(0.1, 1000.0, 0.5) var damage_per_second: float = 10.0
@export_range(0.0, 100.0, 1.0) var takedown_max_health_gain: float = 0.0


func is_configured() -> bool:
	return not team_id.is_empty() and not display_name.is_empty()
