extends SceneTree

const STUDENT_SCENE: PackedScene = preload("res://Characters/student.tscn")
const TEST_SCENE: PackedScene = preload("res://Scenes/movement_test.tscn")
const WORLD_LAYER: int = 1
const STUDENT_LAYER: int = 2
const STUDENT_COLLISION_MASK: int = WORLD_LAYER | STUDENT_LAYER

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var student: StudentController = STUDENT_SCENE.instantiate() as StudentController
	_check(student.collision_layer == STUDENT_LAYER, "Student is on the Students layer")
	_check(
		student.collision_mask == STUDENT_COLLISION_MASK,
		"Student scans only the World and Students layers"
	)

	var test_scene: Node2D = TEST_SCENE.instantiate() as Node2D
	var walls: StaticBody2D = test_scene.get_node("Arena/Walls") as StaticBody2D
	_check(not walls.visible, "Perimeter collision body is invisible")
	_check(walls.collision_layer == WORLD_LAYER, "Perimeter walls use the World layer")
	_check(walls.collision_mask == 0, "Arena walls scan no collision layers")
	_check(walls.get_child_count() == 4, "Map circumference has exactly four walls")
	for wall_shape: Node in walls.get_children():
		_check(wall_shape is CollisionShape2D, "%s is a collision shape" % wall_shape.name)
		if wall_shape is CollisionShape2D:
			var collision_shape: CollisionShape2D = wall_shape as CollisionShape2D
			_check(not collision_shape.disabled, "%s is enabled" % wall_shape.name)

	var static_bodies: Array[Node] = test_scene.find_children(
		"*",
		"StaticBody2D",
		true,
		false
	)
	_check(static_bodies.size() == 1, "No internal wall bodies exist")

	student.free()
	test_scene.free()
	if _failures == 0:
		print("Collision configuration tests passed.")
	quit(_failures)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
		return

	_failures += 1
	push_error("FAIL: %s" % description)
