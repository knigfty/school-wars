extends SceneTree

const TEST_SCENE: PackedScene = preload("res://Scenes/movement_test.tscn")
const BLACK_TEAM: TeamDefinition = preload("res://Resources/Team/black_team.tres")
const GREEN_TEAM: TeamDefinition = preload("res://Resources/Team/green_team.tres")
const PURPLE_TEAM: TeamDefinition = preload("res://Resources/Team/purple_team.tres")
const YELLOW_TEAM: TeamDefinition = preload("res://Resources/Team/yellow_team.tres")

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var test_scene: Node2D = TEST_SCENE.instantiate() as Node2D
	root.add_child(test_scene)
	var spawner: TeamReinforcementSpawner = test_scene.get_node(
		"ReinforcementSpawner"
	) as TeamReinforcementSpawner
	var yellow_base: float = spawner.calculate_spawn_interval(15.0, 0)
	var yellow_three_tiles: float = spawner.calculate_spawn_interval(15.0, 3)
	var green_base: float = spawner.calculate_spawn_interval(10.0, 0)
	var green_three_tiles: float = spawner.calculate_spawn_interval(10.0, 3)
	var black_base: float = spawner.calculate_spawn_interval(12.0, 0)
	var many_territory_interval: float = spawner.calculate_spawn_interval(10.0, 100)
	_check(yellow_base == 15.0, "Yellow and Purple start at one unit per 15 seconds")
	_check(green_base == 10.0, "Green starts at one unit per 10 seconds")
	_check(black_base == 12.0, "Black starts at one unit per 12 seconds")
	_check(
		yellow_three_tiles == 12.0 and green_three_tiles == 7.0,
		"Every captured square reduces the spawn interval by one second"
	)
	_check(
		many_territory_interval == spawner.minimum_spawn_interval,
		"Reinforcement rate respects its safety cap"
	)
	_check(spawner.get_maximum_students(YELLOW_TEAM.team_id) == 10, "Yellow caps at 10 units")
	_check(spawner.get_maximum_students(PURPLE_TEAM.team_id) == 10, "Purple caps at 10 units")
	_check(spawner.get_maximum_students(GREEN_TEAM.team_id) == 15, "Green caps at 15 units")
	_check(spawner.get_maximum_students(BLACK_TEAM.team_id) == 12, "Black caps at 12 units")

	for node: Node in get_nodes_in_group(TeamSpawnPoint.SPAWN_POINT_GROUP):
		var spawn_point: TeamSpawnPoint = node as TeamSpawnPoint
		if spawn_point == null:
			continue
		for spawn_index: int in 10:
			_check(
				spawn_point.contains_world_point(spawn_point.get_spawn_position(spawn_index)),
				"%s reinforcement slot %d stays in base" % [spawn_point.name, spawn_index]
			)

	test_scene.queue_free()
	if _failures == 0:
		print("Reinforcement economy tests passed.")
	quit(_failures)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
		return
	_failures += 1
	push_error("FAIL: %s" % description)
