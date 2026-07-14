class_name TeamAIController
extends Node

@export_range(1.0, 15.0, 0.5) var order_interval: float = 4.0
@export_range(10.0, 80.0, 1.0) var formation_spacing: float = 32.0
@export_range(50.0, 600.0, 10.0) var black_engagement_range: float = 280.0

var player_team_id: StringName = &""
var _elapsed: float = 0.0


func configure_player_team(team_id: StringName) -> void:
	player_team_id = team_id
	_elapsed = order_interval * 0.5


func _process(delta: float) -> void:
	if player_team_id.is_empty():
		return
	_elapsed += delta
	if _elapsed < order_interval:
		return
	_elapsed = 0.0
	issue_orders()


func issue_orders() -> void:
	if player_team_id.is_empty():
		return
	for node: Node in get_tree().get_nodes_in_group(TeamSpawnPoint.SPAWN_POINT_GROUP):
		var spawn_point: TeamSpawnPoint = node as TeamSpawnPoint
		if spawn_point == null or spawn_point.team == null:
			continue
		var team_id: StringName = spawn_point.team.team_id
		if team_id == player_team_id:
			continue
		var students: Array[StudentController] = _get_team_students(team_id)
		if students.is_empty():
			continue
		match team_id:
			&"green":
				_order_green_expansion(students, team_id)
			&"purple":
				_order_aggressive(students, false)
			&"yellow":
				_order_aggressive(students, true)
			_:
				_order_black_balanced(students, team_id, spawn_point)


func get_strategy_name(team_id: StringName) -> StringName:
	match team_id:
		&"green":
			return &"expansion"
		&"purple":
			return &"aggression"
		&"yellow":
			return &"takedown_focus"
		_:
			return &"balanced"


func _get_team_students(team_id: StringName) -> Array[StudentController]:
	var result: Array[StudentController] = []
	for node: Node in get_tree().get_nodes_in_group(StudentController.STUDENT_GROUP):
		var student: StudentController = node as StudentController
		if student != null and student.get_team_id() == team_id:
			result.append(student)
	return result


func _order_green_expansion(
	students: Array[StudentController],
	team_id: StringName
) -> void:
	var candidates: Array[TerritoryTile] = _get_available_territories(team_id, true)
	if candidates.is_empty():
		candidates = _get_available_territories(team_id, false)
	if candidates.is_empty():
		return
	var spread_count: int = mini(candidates.size(), 3)
	for index: int in students.size():
		_order_student_to_position(
			students[index],
			candidates[index % spread_count].global_position
		)


func _order_aggressive(
	students: Array[StudentController],
	prefer_weakest: bool
) -> void:
	var target: StudentController
	if prefer_weakest:
		target = _find_weakest_enemy(students[0].get_team_id())
	else:
		target = _find_nearest_enemy(students)
	if target != null:
		_order_students_to_enemy(students, target)
		return
	var spawn_point: TeamSpawnPoint = _get_spawn_point(students[0].get_team_id())
	var territory: TerritoryTile = _choose_territory(
		students[0].get_team_id(), students, spawn_point
	)
	if territory != null:
		_order_students_to_territory(students, territory)


func _order_black_balanced(
	students: Array[StudentController],
	team_id: StringName,
	spawn_point: TeamSpawnPoint
) -> void:
	var enemy: StudentController = _find_nearest_enemy(students)
	var origin: Vector2 = _get_group_center(students)
	if enemy != null and origin.distance_to(enemy.global_position) <= black_engagement_range:
		_order_students_to_enemy(students, enemy)
		return
	var territory: TerritoryTile = _choose_territory(team_id, students, spawn_point)
	if territory != null:
		_order_students_to_territory(students, territory)


func _get_available_territories(
	team_id: StringName,
	neutral_only: bool
) -> Array[TerritoryTile]:
	var result: Array[TerritoryTile] = []
	for node: Node in get_tree().get_nodes_in_group(TerritoryTile.TERRITORY_GROUP):
		var tile: TerritoryTile = node as TerritoryTile
		if tile == null or tile.get_owner_team_id() == team_id:
			continue
		if neutral_only and not tile.get_owner_team_id().is_empty():
			continue
		result.append(tile)
	return result


func _choose_territory(
	team_id: StringName,
	students: Array[StudentController],
	spawn_point: TeamSpawnPoint
) -> TerritoryTile:
	var origin: Vector2 = spawn_point.global_position
	if not students.is_empty():
		origin = _get_group_center(students)
	var best_tile: TerritoryTile
	var best_score: float = INF
	for tile: TerritoryTile in _get_available_territories(team_id, false):
		var ownership_penalty: float = 180.0 if not tile.get_owner_team_id().is_empty() else 0.0
		var score: float = origin.distance_to(tile.global_position) + ownership_penalty
		if score < best_score:
			best_score = score
			best_tile = tile
	return best_tile


func _find_nearest_enemy(students: Array[StudentController]) -> StudentController:
	var team_id: StringName = students[0].get_team_id()
	var origin: Vector2 = _get_group_center(students)
	var nearest: StudentController
	var nearest_distance: float = INF
	for node: Node in get_tree().get_nodes_in_group(StudentController.STUDENT_GROUP):
		var candidate: StudentController = node as StudentController
		if candidate == null or candidate.get_team_id() == team_id:
			continue
		var distance: float = origin.distance_to(candidate.global_position)
		if distance < nearest_distance:
			nearest = candidate
			nearest_distance = distance
	return nearest


func _find_weakest_enemy(team_id: StringName) -> StudentController:
	var weakest: StudentController
	var weakest_ratio: float = INF
	for node: Node in get_tree().get_nodes_in_group(StudentController.STUDENT_GROUP):
		var candidate: StudentController = node as StudentController
		if candidate == null or candidate.get_team_id() == team_id:
			continue
		if candidate.get_health_ratio() < weakest_ratio:
			weakest = candidate
			weakest_ratio = candidate.get_health_ratio()
	return weakest


func _order_students_to_enemy(
	students: Array[StudentController],
	target: StudentController
) -> void:
	for student: StudentController in students:
		var move_order: StudentMoveOrderComponent = student.get_node_or_null(
			"MoveOrder"
		) as StudentMoveOrderComponent
		if move_order != null:
			move_order.cancel_order()
		student.set_attack_target(target)


func _order_students_to_territory(
	students: Array[StudentController],
	territory: TerritoryTile
) -> void:
	if students.is_empty():
		return
	var center_offset: float = float(students.size() - 1) * 0.5
	for index: int in students.size():
		var offset: Vector2 = Vector2(
			(float(index) - center_offset) * formation_spacing,
			0.0
		)
		_order_student_to_position(students[index], territory.global_position + offset)


func _order_student_to_position(student: StudentController, destination: Vector2) -> void:
	var move_order: StudentMoveOrderComponent = student.get_node_or_null(
		"MoveOrder"
	) as StudentMoveOrderComponent
	if move_order == null:
		return
	student.clear_attack_target()
	move_order.set_destination(destination)


func _get_group_center(students: Array[StudentController]) -> Vector2:
	var center: Vector2 = Vector2.ZERO
	for student: StudentController in students:
		center += student.global_position
	return center / maxf(float(students.size()), 1.0)


func _get_spawn_point(team_id: StringName) -> TeamSpawnPoint:
	for node: Node in get_tree().get_nodes_in_group(TeamSpawnPoint.SPAWN_POINT_GROUP):
		var spawn_point: TeamSpawnPoint = node as TeamSpawnPoint
		if spawn_point != null and spawn_point.team != null:
			if spawn_point.team.team_id == team_id:
				return spawn_point
	return null
