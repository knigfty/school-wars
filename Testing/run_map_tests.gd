extends SceneTree

const TEST_SCENE: PackedScene = preload("res://Scenes/movement_test.tscn")
const EXPECTED_MAP_BOUNDS: Rect2 = Rect2(80.0, 80.0, 1440.0, 1440.0)
const EXPECTED_CAMERA_BOUNDS: Rect2 = Rect2(-120.0, -120.0, 1840.0, 1840.0)
const EXPECTED_MAP_POINTS: PackedVector2Array = PackedVector2Array([
	Vector2(800.0, 80.0),
	Vector2(1520.0, 800.0),
	Vector2(800.0, 1520.0),
	Vector2(80.0, 800.0),
])
const EXPECTED_SPAWN_POSITIONS: Dictionary = {
	&"purple": Vector2(800.0, 170.0),
	&"green": Vector2(1430.0, 800.0),
	&"black": Vector2(800.0, 1430.0),
	&"yellow": Vector2(170.0, 800.0),
}
const EXPECTED_DIRECTIONS: Dictionary = {
	&"purple": "North",
	&"green": "East",
	&"black": "South",
	&"yellow": "West",
}

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var test_scene: Node2D = TEST_SCENE.instantiate() as Node2D
	root.add_child(test_scene)

	var arena: FourSquareArena = test_scene.get_node("Arena") as FourSquareArena
	_check(arena.get_map_bounds() == EXPECTED_MAP_BOUNDS, "Map bounds frame the diamond")
	_check(arena.get_map_polygon() == EXPECTED_MAP_POINTS, "Map has four pointed sides")
	for point: Vector2 in EXPECTED_MAP_POINTS:
		_check(arena.contains_world_point(point), "%s is on the map edge" % point)
	_check(not arena.contains_world_point(Vector2.ZERO), "Sky is outside the playable map")

	var side_names: Array[String] = arena.get_cardinal_side_names()
	for side_name: String in ["North", "South", "East", "West"]:
		_check(side_name in side_names, "%s point is identified" % side_name)

	var spawn_points: Array[Node] = arena.get_node("SpawnPoints").get_children()
	_check(spawn_points.size() == 4, "Map contains four team bases")
	var spawn_by_team: Dictionary = {}
	var unique_colors: Dictionary = {}
	for spawn_node: Node in spawn_points:
		var spawn_point: TeamSpawnPoint = spawn_node as TeamSpawnPoint
		_check(spawn_point != null, "%s is a team base" % spawn_node.name)
		if spawn_point == null or spawn_point.team == null:
			continue
		var team_id: StringName = spawn_point.team.team_id
		spawn_by_team[team_id] = spawn_point
		_check(EXPECTED_SPAWN_POSITIONS.has(team_id), "%s is a known team" % team_id)
		if EXPECTED_SPAWN_POSITIONS.has(team_id):
			_check(
				spawn_point.position == EXPECTED_SPAWN_POSITIONS[team_id],
				"%s base occupies its assigned point" % team_id
			)
			_check(
				spawn_point.direction_name == EXPECTED_DIRECTIONS[team_id],
				"%s base faces %s" % [team_id, EXPECTED_DIRECTIONS[team_id]]
			)
		unique_colors[spawn_point.team.color.to_html()] = true
	_check(unique_colors.size() == 4, "Every base has a distinct team color")

	for node: Node in test_scene.get_node("Units").get_children():
		var student: StudentController = node as StudentController
		_check(student != null, "%s is a student" % node.name)
		if student == null or not spawn_by_team.has(student.get_team_id()):
			continue
		var base: TeamSpawnPoint = spawn_by_team[student.get_team_id()] as TeamSpawnPoint
		_check(
			base.contains_world_point(student.global_position),
			"%s starts inside its base" % node.name
		)

	var territories: Array[Node] = get_nodes_in_group(TerritoryTile.TERRITORY_GROUP)
	_check(territories.size() == 12, "Twelve territory tiles are generated")
	for node: Node in territories:
		var tile: TerritoryTile = node as TerritoryTile
		_check(
			tile != null and tile.get_owner_team_id().is_empty(),
			"%s starts neutral" % node.name
		)

	var camera: RTSCameraController = test_scene.get_node("RTSCamera") as RTSCameraController
	_check(camera.world_bounds == EXPECTED_CAMERA_BOUNDS, "Camera includes a controlled sky margin")
	_check(camera.world_bounds == arena.get_camera_bounds(), "Camera and arena share viewing bounds")

	test_scene.queue_free()
	if _failures == 0:
		print("Diamond map and team-base tests passed.")
	quit(_failures)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
		return

	_failures += 1
	push_error("FAIL: %s" % description)
