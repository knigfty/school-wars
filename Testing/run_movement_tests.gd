extends SceneTree

const STUDENT_SCENE: PackedScene = preload("res://Characters/student.tscn")
const EXPECTED_SPEED: float = 180.0

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var student: StudentController = STUDENT_SCENE.instantiate() as StudentController
	root.add_child(student)

	_check(student.stats != null, "Student scene has a stats resource")
	_check(
		is_equal_approx(student.stats.movement_speed, EXPECTED_SPEED),
		"Movement speed comes from StudentStats"
	)

	student.set_move_intent(Vector2(4.0, 3.0))
	_check(
		student.get_move_intent().is_equal_approx(Vector2(0.8, 0.6)),
		"Movement intent is normalized"
	)

	await physics_frame
	await physics_frame
	_check(student.velocity.length() > 0.0, "Movement intent accelerates the student")
	_check(
		student.velocity.length() <= student.stats.movement_speed,
		"Velocity does not exceed configured speed"
	)

	student.stop_immediately()
	_check(student.velocity.is_zero_approx(), "Immediate stop clears velocity")

	student.queue_free()
	if _failures == 0:
		print("Student motor tests passed.")
	quit(_failures)



func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
		return

	_failures += 1
	push_error("FAIL: %s" % description)
