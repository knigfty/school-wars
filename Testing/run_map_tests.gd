extends SceneTree

const TEST_SCENE: PackedScene = preload("res://Scenes/movement_test.tscn")
const EXPECTED_MAP_BOUNDS: Rect2 = Rect2(40.0, 40.0, 1520.0, 1520.0)
const EXPECTED_CAMERA_BOUNDS: Rect2 = Rect2(-120.0, -120.0, 1840.0, 1840.0)
const EXPECTED_SPAWN_POSITIONS: Dictionary = {
	&"Black": Vector2(180.0, 180.0),
	&"Green": Vector2(1420.0, 180.0),
	&"Yellow": Vector2(180.0, 1420.0),
	&"Purple": Vector2(1420.0, 1420.0),
}

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var test_scene: Node2D = TEST_SCENE.instantiate() as Node2D
	root.add_child(test_scene)

	var arena: FourSquareArena = test_scene.get_node("Arena") as FourSquareArena
	_check(arena.get_map_bounds() == EXPECTED_MAP_BOUNDS, "Map uses square bounds")

	var quadrants: Array[Rect2] = arena.get_quadrant_bounds()
	_check(quadrants.size() == 4, "Map contains four visual quadrants")
	for quadrant: Rect2 in quadrants:
		_check(
			is_equal_approx(quadrant.size.x, quadrant.size.y),
			"Every quadrant is square"
		)

	var side_names: Array[String] = arena.get_cardinal_side_names()
	for side_name: String in ["North", "South", "East", "West"]:
		_check(side_name in side_names, "%s side is identified" % side_name)

	var spawn_points: Array[Node] = arena.get_node("SpawnPoints").get_children()
	_check(spawn_points.size() == 4, "Map contains four team spawn points")
	var unique_colors: Dictionary = {}
	for spawn_node: Node in spawn_points:
		var spawn_point: TeamSpawnPoint = spawn_node as TeamSpawnPoint
		_check(spawn_point != null, "%s is a team spawn point" % spawn_node.name)
		if spawn_point == null:
			continue
		_check(
			EXPECTED_SPAWN_POSITIONS.has(spawn_point.team_name),
			"%s is a known team" % spawn_point.team_name
		)
		if EXPECTED_SPAWN_POSITIONS.has(spawn_point.team_name):
			_check(
				spawn_point.position == EXPECTED_SPAWN_POSITIONS[spawn_point.team_name],
				"%s spawns in its assigned corner" % spawn_point.team_name
			)
		unique_colors[spawn_point.team_color.to_html()] = true
	_check(unique_colors.size() == 4, "Each corner spawn has a distinct color")

	var camera: RTSCameraController = test_scene.get_node("RTSCamera") as RTSCameraController
	_check(
		camera.world_bounds == EXPECTED_CAMERA_BOUNDS,
		"Camera includes a controlled sky margin"
	)
	_check(
		camera.world_bounds == arena.get_camera_bounds(),
		"Camera and arena use the same viewing bounds"
	)

	test_scene.queue_free()
	if _failures == 0:
		print("Four-square map tests passed.")
	quit(_failures)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
		return

	_failures += 1
	push_error("FAIL: %s" % description)
