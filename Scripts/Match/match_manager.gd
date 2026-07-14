class_name MatchManager
extends Node

signal team_eliminated(team: TeamDefinition)
signal match_ended(player_won: bool, winner: TeamDefinition)

@export_range(1, 40, 1) var victory_territory_count: int = 8
@export_range(0.1, 3.0, 0.1) var evaluation_interval: float = 0.5
@export_range(1.0, 10.0, 0.5) var result_delay_after_elimination: float = 4.0

var player_team: TeamDefinition
var _evaluation_elapsed: float = 0.0
var _has_ended: bool = false
var _active_team_ids: Dictionary = {}
var _pending_result: bool = false
var _pending_winner: TeamDefinition
var _result_delay_remaining: float = 0.0


func configure_player_team(team: TeamDefinition) -> void:
	player_team = team
	_evaluation_elapsed = 0.0
	_has_ended = false
	_pending_result = false
	_pending_winner = null
	_active_team_ids.clear()
	for node: Node in get_tree().get_nodes_in_group(TeamSpawnPoint.SPAWN_POINT_GROUP):
		var spawn_point: TeamSpawnPoint = node as TeamSpawnPoint
		if spawn_point != null and spawn_point.team != null:
			_active_team_ids[spawn_point.team.team_id] = true


func _process(delta: float) -> void:
	if player_team == null or _has_ended:
		return
	if _pending_result:
		_result_delay_remaining = maxf(_result_delay_remaining - delta, 0.0)
		if is_zero_approx(_result_delay_remaining):
			_finish_match(_pending_winner)
		return
	_evaluation_elapsed += delta
	if _evaluation_elapsed < evaluation_interval:
		return
	_evaluation_elapsed = 0.0
	evaluate_match()


func evaluate_match() -> void:
	if player_team == null or _has_ended or _pending_result:
		return
	var territory_counts: Dictionary = _get_territory_counts()
	var active_ids: Array[Variant] = _active_team_ids.keys()
	for team_id: Variant in active_ids:
		var typed_team_id: StringName = StringName(team_id)
		if _get_student_count(typed_team_id) == 0:
			_eliminate_team(typed_team_id, territory_counts)

	if _pending_result:
		return
	for team_id: Variant in territory_counts:
		var typed_team_id: StringName = StringName(team_id)
		if is_team_eliminated(typed_team_id):
			continue
		if int(territory_counts[team_id]) >= victory_territory_count:
			_finish_match(_get_team_definition(typed_team_id))
			return

	var remaining_ids: Array[Variant] = _active_team_ids.keys()
	if remaining_ids.size() == 1:
		_schedule_result(_get_team_definition(StringName(remaining_ids[0])))
	elif remaining_ids.is_empty():
		_schedule_result(null)


func has_ended() -> bool:
	return _has_ended


func has_pending_result() -> bool:
	return _pending_result


func is_team_eliminated(team_id: StringName) -> bool:
	return not _active_team_ids.has(team_id)


func resolve_pending_result_for_testing() -> void:
	if _pending_result:
		_finish_match(_pending_winner)


func _eliminate_team(team_id: StringName, territory_counts: Dictionary) -> void:
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
	if team_id == player_team.team_id:
		_schedule_result(_get_leading_opponent(territory_counts))


func _schedule_result(winner: TeamDefinition) -> void:
	if _pending_result or _has_ended:
		return
	_pending_result = true
	_pending_winner = winner
	_result_delay_remaining = result_delay_after_elimination


func _finish_match(winner: TeamDefinition) -> void:
	_has_ended = true
	_pending_result = false
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
	for team_id: Variant in _active_team_ids:
		var typed_team_id: StringName = StringName(team_id)
		if typed_team_id == player_team.team_id:
			continue
		var count: int = int(territory_counts.get(typed_team_id, 0))
		if count > leading_count:
			leader = _get_team_definition(typed_team_id)
			leading_count = count
	return leader
