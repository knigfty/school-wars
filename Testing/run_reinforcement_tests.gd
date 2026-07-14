extends SceneTree

const TEST_SCENE: PackedScene = preload("res://Scenes/movement_test.tscn")

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var test_scene: Node2D = TEST_SCENE.instantiate() as Node2D
	root.add_child(test_scene)
	var spawner: TeamReinforcementSpawner = test_scene.get_node(
		"ReinforcementSpawner"
	) as TeamReinforcementSpawner
	var no_territory_interval: float = spawner.calculate_spawn_interval(0)
	var three_territory_interval: float = spawner.calculate_spawn_interval(3)
	var many_territory_interval: float = spawner.calculate_spawn_interval(100)
	_check(
		three_territory_interval < no_territory_interval,
		"Captured tiles increase reinforcement rate"
	)
	_check(
		many_territory_interval == spawner.minimum_spawn_interval,
		"Reinforcement rate respects its safety cap"
	)

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
