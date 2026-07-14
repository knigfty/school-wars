extends SceneTree

const STUDENT_SCENE: PackedScene = preload("res://Characters/student.tscn")
const COMMAND_CONTROLLER_SCRIPT: Script = preload(
	"res://Scripts/Commands/unit_command_controller.gd"
)

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var first_student: StudentController = STUDENT_SCENE.instantiate() as StudentController
	var second_student: StudentController = STUDENT_SCENE.instantiate() as StudentController
	first_student.position = Vector2(100.0, 100.0)
	second_student.position = Vector2(140.0, 100.0)
	root.add_child(first_student)
	root.add_child(second_student)

	var first_selectable: SelectableComponent = (
		first_student.get_node("Selectable") as SelectableComponent
	)
	var second_selectable: SelectableComponent = (
		second_student.get_node("Selectable") as SelectableComponent
	)
	var first_order: StudentMoveOrderComponent = (
		first_student.get_node("MoveOrder") as StudentMoveOrderComponent
	)
	var second_order: StudentMoveOrderComponent = (
		second_student.get_node("MoveOrder") as StudentMoveOrderComponent
	)

	var command_controller: UnitCommandController = COMMAND_CONTROLLER_SCRIPT.new()
	command_controller.formation_spacing = 40.0
	var selected_units: Array[SelectableComponent] = [
		first_selectable,
		second_selectable,
	]
	command_controller.issue_move_order(selected_units, Vector2(500.0, 500.0))

	_check(first_order.has_active_order(), "First selected student receives a move order")
	_check(second_order.has_active_order(), "Second selected student receives a move order")
	_check(
		first_order.get_destination().is_equal_approx(Vector2(480.0, 500.0)),
		"First student receives the left formation slot"
	)
	_check(
		second_order.get_destination().is_equal_approx(Vector2(520.0, 500.0)),
		"Second student receives the right formation slot"
	)

	await physics_frame
	_check(first_student.velocity.length() > 0.0, "Move order drives the movement motor")

	first_order.cancel_order()
	second_order.cancel_order()
	_check(first_student.velocity.is_zero_approx(), "Cancelling an order stops the student")

	first_student.queue_free()
	second_student.queue_free()
	command_controller.free()
	if _failures == 0:
		print("Move order tests passed.")
	quit(_failures)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
		return

	_failures += 1
	push_error("FAIL: %s" % description)
