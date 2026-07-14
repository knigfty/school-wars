class_name TeamAIController
extends Node

@export_range(1.0, 15.0, 0.5) var order_interval: float = 4.0
@export_range(10.0, 80.0, 1.0) var formation_spacing: float = 32.0

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
		var territory: TerritoryTile = _choose_territory(team_id, students, spawn_point)
		if territory != null:
			_order_students_to_territory(students, territory)


func _get_team_students(team_id: StringName) -> Array[StudentController]:
	var result: Array[StudentController] = []
	for node: Node in get_tree().get_nodes_in_group(StudentController.STUDENT_GROUP):
		var student: StudentController = node as StudentController
		if student != null and student.get_team_id() == team_id:
			result.append(student)
	return result


func _choose_territory(
	team_id: StringName,
	students: Array[StudentController],
	spawn_point: TeamSpawnPoint
) -> TerritoryTile:
	var origin: Vector2 = spawn_point.global_position
	if not students.is_empty():
		origin = Vector2.ZERO
		for student: StudentController in students:
			origin += student.global_position
		origin /= float(students.size())

	var best_tile: TerritoryTile
	var best_score: float = INF
	for node: Node in get_tree().get_nodes_in_group(TerritoryTile.TERRITORY_GROUP):
		var tile: TerritoryTile = node as TerritoryTile
		if tile == null or tile.get_owner_team_id() == team_id:
			continue
		var ownership_penalty: float = 180.0 if not tile.get_owner_team_id().is_empty() else 0.0
		var score: float = origin.distance_to(tile.global_position) + ownership_penalty
		if score < best_score:
			best_score = score
			best_tile = tile
	return best_tile


func _order_students_to_territory(
	students: Array[StudentController],
	territory: TerritoryTile
) -> void:
	if students.is_empty():
		return
	var center_offset: float = float(students.size() - 1) * 0.5
	for index: int in students.size():
		var student: StudentController = students[index]
		var move_order: StudentMoveOrderComponent = student.get_node_or_null(
			"MoveOrder"
		) as StudentMoveOrderComponent
		if move_order == null:
			continue
		student.clear_attack_target()
		var offset: Vector2 = Vector2(
			(float(index) - center_offset) * formation_spacing,
			0.0
		)
		move_order.set_destination(territory.global_position + offset)
