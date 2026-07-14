class_name MatchManager
extends Node

signal match_ended(player_won: bool, winner: TeamDefinition)

@export_range(1, 40, 1) var victory_territory_count: int = 8
@export_range(0.0, 30.0, 0.5) var defeat_grace_period: float = 6.0
@export_range(0.1, 3.0, 0.1) var evaluation_interval: float = 0.5

var player_team: TeamDefinition
var _match_elapsed: float = 0.0
var _evaluation_elapsed: float = 0.0
var _has_ended: bool = false


func configure_player_team(team: TeamDefinition) -> void:
	player_team = team
	_match_elapsed = 0.0
	_evaluation_elapsed = 0.0
	_has_ended = false


func _process(delta: float) -> void:
	if player_team == null or _has_ended:
		return
	_match_elapsed += delta
	_evaluation_elapsed += delta
	if _evaluation_elapsed < evaluation_interval:
		return
	_evaluation_elapsed = 0.0
	evaluate_match()


func evaluate_match() -> void:
	if player_team == null or _has_ended:
		return
	var territory_counts: Dictionary = _get_territory_counts()
	for team_id: Variant in territory_counts:
		if int(territory_counts[team_id]) >= victory_territory_count:
			_finish_match(_get_team_definition(StringName(team_id)))
			return

	if _match_elapsed < defeat_grace_period:
		return
	if _get_student_count(player_team.team_id) == 0:
		_finish_match(_get_leading_opponent(territory_counts))


func has_ended() -> bool:
	return _has_ended


func set_elapsed_for_testing(seconds: float) -> void:
	_match_elapsed = maxf(seconds, 0.0)


func _finish_match(winner: TeamDefinition) -> void:
	_has_ended = true
	var player_won: bool = winner != null and winner.team_id == player_team.team_id
	match_ended.emit(player_won, winner)


func _get_territory_counts() -> Dictionary:
	var counts: Dictionary = {}
	for node: Node in get_tree().get_nodes_in_group(TerritoryTile.TERRITORY_GROUP):
		var territory: TerritoryTile = node as TerritoryTile
		if territory == null or territory.get_owner_team_id().is_empty():
			continue
		var team_id: StringName = territory.get_owner_team_id()
		counts[team_id] = int(counts.get(team_id, 0)) + 1
	return counts


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


func _get_leading_opponent(territory_counts: Dictionary) -> TeamDefinition:
	var leader: TeamDefinition
	var leading_count: int = -1
	for node: Node in get_tree().get_nodes_in_group(TeamSpawnPoint.SPAWN_POINT_GROUP):
		var spawn_point: TeamSpawnPoint = node as TeamSpawnPoint
		if spawn_point == null or spawn_point.team == null:
			continue
		if spawn_point.team.team_id == player_team.team_id:
			continue
		var count: int = int(territory_counts.get(spawn_point.team.team_id, 0))
		if count > leading_count:
			leader = spawn_point.team
			leading_count = count
	return leader
