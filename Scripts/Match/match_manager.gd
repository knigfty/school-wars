class_name MatchManager
extends Node

signal team_eliminated(team: TeamDefinition)
signal match_ended(player_won: bool, winner: TeamDefinition)

@export_range(0.1, 3.0, 0.1) var evaluation_interval: float = 0.5

var player_team: TeamDefinition
var _evaluation_elapsed: float = 0.0
var _has_ended: bool = false
var _active_team_ids: Dictionary = {}


func configure_player_team(team: TeamDefinition) -> void:
	player_team = team
	_evaluation_elapsed = 0.0
	_has_ended = false
	_active_team_ids.clear()
	for node: Node in get_tree().get_nodes_in_group(TeamSpawnPoint.SPAWN_POINT_GROUP):
		var spawn_point: TeamSpawnPoint = node as TeamSpawnPoint
		if spawn_point != null and spawn_point.team != null:
			_active_team_ids[spawn_point.team.team_id] = true


func _process(delta: float) -> void:
	if player_team == null or _has_ended:
		return
	_evaluation_elapsed += delta
	if _evaluation_elapsed < evaluation_interval:
		return
	_evaluation_elapsed = 0.0
	evaluate_match()


func evaluate_match() -> void:
	if player_team == null or _has_ended:
		return
	var active_ids: Array[Variant] = _active_team_ids.keys()
	for team_id: Variant in active_ids:
		var typed_team_id: StringName = StringName(team_id)
		if _get_student_count(typed_team_id) == 0:
			_eliminate_team(typed_team_id)

	if is_team_eliminated(player_team.team_id):
		_finish_match(_get_first_active_team())
		return
	if _active_team_ids.size() == 1:
		_finish_match(player_team)


func has_ended() -> bool:
	return _has_ended


func is_team_eliminated(team_id: StringName) -> bool:
	return not _active_team_ids.has(team_id)


func _eliminate_team(team_id: StringName) -> void:
	if is_team_eliminated(team_id):
		return
	_active_team_ids.erase(team_id)
	var team: TeamDefinition = _get_team_definition(team_id)
	var spawner: TeamReinforcementSpawner = get_parent().get_node_or_null(
		"ReinforcementSpawner"
	) as TeamReinforcementSpawner
	if spawner != null:
		spawner.eliminate_team(team_id)
	team_eliminated.emit(team)


func _finish_match(winner: TeamDefinition) -> void:
	_has_ended = true
	var player_won: bool = winner != null and winner.team_id == player_team.team_id
	match_ended.emit(player_won, winner)


func _get_first_active_team() -> TeamDefinition:
	for team_id: Variant in _active_team_ids:
		return _get_team_definition(StringName(team_id))
	return null


func _get_student_count(team_id: StringName) -> int:
	var count: int = 0
	for node: Node in get_tree().get_nodes_in_group(StudentController.STUDENT_GROUP):
		var student: StudentController = node as StudentController
		if student != null and student.get_team_id() == team_id:
			count += 1
	return count


func _get_team_definition(team_id: StringName) -> TeamDefinition:
	for node: Node in get_tree().get_nodes_in_group(TeamSpawnPoint.SPAWN_POINT_GROUP):
		var spawn_point: TeamSpawnPoint = node as TeamSpawnPoint
		if spawn_point != null and spawn_point.team != null:
			if spawn_point.team.team_id == team_id:
				return spawn_point.team
	return null
