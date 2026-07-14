class_name TeamReinforcementSpawner
extends Node

signal reinforcement_spawned(team: TeamDefinition, student: StudentController)

@export var student_scene: PackedScene
@export var units_parent_path: NodePath = NodePath("../Units")
@export_range(1.0, 60.0, 0.5) var base_spawn_interval: float = 14.0
@export_range(1.0, 60.0, 0.5) var minimum_spawn_interval: float = 3.0
@export_range(0.0, 2.0, 0.05) var territory_rate_bonus: float = 0.35
@export_range(1, 100, 1) var maximum_students_per_team: int = 30

var _elapsed_by_team: Dictionary = {}


func _ready() -> void:
	if student_scene == null:
		push_error("%s requires a student scene." % name)
		set_process(false)


func _process(delta: float) -> void:
	for node: Node in get_tree().get_nodes_in_group(TeamSpawnPoint.SPAWN_POINT_GROUP):
		var spawn_point: TeamSpawnPoint = node as TeamSpawnPoint
		if spawn_point == null or spawn_point.team == null:
			continue
		var team_id: StringName = spawn_point.team.team_id
		var elapsed: float = float(_elapsed_by_team.get(team_id, 0.0)) + delta
		var interval: float = get_spawn_interval(team_id)
		if elapsed >= interval and get_student_count(team_id) < maximum_students_per_team:
			spawn_reinforcement(spawn_point)
			elapsed = 0.0
		_elapsed_by_team[team_id] = elapsed


func calculate_spawn_interval(territory_count: int) -> float:
	var multiplier: float = 1.0 + maxf(float(territory_count), 0.0) * territory_rate_bonus
	return maxf(minimum_spawn_interval, base_spawn_interval / multiplier)


func get_spawn_interval(team_id: StringName) -> float:
	return calculate_spawn_interval(get_owned_territory_count(team_id))


func get_owned_territory_count(team_id: StringName) -> int:
	var count: int = 0
	for node: Node in get_tree().get_nodes_in_group(TerritoryTile.TERRITORY_GROUP):
		var territory: TerritoryTile = node as TerritoryTile
		if territory != null and territory.get_owner_team_id() == team_id:
			count += 1
	return count


func get_student_count(team_id: StringName) -> int:
	var count: int = 0
	for node: Node in get_tree().get_nodes_in_group(StudentController.STUDENT_GROUP):
		var student: StudentController = node as StudentController
		if student != null and student.get_team_id() == team_id:
			count += 1
	return count


func spawn_reinforcement(spawn_point: TeamSpawnPoint) -> StudentController:
	var units_parent: Node2D = get_node_or_null(units_parent_path) as Node2D
	if units_parent == null or student_scene == null or spawn_point.team == null:
		return null
	var student: StudentController = student_scene.instantiate() as StudentController
	if student == null:
		return null
	var team_id: StringName = spawn_point.team.team_id
	student.team = spawn_point.team
	units_parent.add_child(student)
	student.global_position = spawn_point.get_spawn_position(get_student_count(team_id) - 1)
	reinforcement_spawned.emit(spawn_point.team, student)
	return student
