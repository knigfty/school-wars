extends SceneTree

const STUDENT_SCENE: PackedScene = preload("res://Characters/student.tscn")
const COMMAND_CONTROLLER_SCRIPT: Script = preload(
	"res://Scripts/Commands/unit_command_controller.gd"
)
const GREEN_TEAM: TeamDefinition = preload("res://Resources/Team/green_team.tres")

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var first_student: StudentController = STUDENT_SCENE.instantiate() as StudentController
	var second_student: StudentController = STUDENT_SCENE.instantiate() as StudentController
	var enemy_student: StudentController = STUDENT_SCENE.instantiate() as StudentController
	first_student.position = Vector2(100.0, 100.0)
	second_student.position = Vector2(140.0, 100.0)
	enemy_student.position = Vector2(600.0, 500.0)
	enemy_student.team = GREEN_TEAM
	root.add_child(first_student)
	root.add_child(second_student)
	root.add_child(enemy_student)

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
	_check(first_order.get_waypoints().size() == 1, "Move order uses a direct route")
	first_order._physics_process(0.01)
	var expected_direction: Vector2 = (
		first_order.get_destination() - first_student.global_position
	).normalized()
	_check(
		first_student.get_move_intent().is_equal_approx(expected_direction),
		"Move order steers naturally toward its destination"
	)

	await physics_frame
	await physics_frame
	_check(first_student.velocity.length() > 0.0, "Move order drives the movement motor")

	first_order.cancel_order()
	second_order.cancel_order()
	_check(first_student.velocity.is_zero_approx(), "Cancelling an order stops the student")

	command_controller.issue_attack_order(selected_units, enemy_student)
	_check(
		first_student.get_attack_target() == enemy_student,
		"Attack order assigns the enemy to the first student"
	)
	_check(
		second_student.get_attack_target() == enemy_student,
		"Attack order assigns the enemy to the second student"
	)

	enemy_student.position = first_student.position + Vector2(20.0, 0.0)
	var enemy_health_before_retreat: float = enemy_student.current_health
	command_controller.issue_move_order(selected_units, Vector2(800.0, 800.0))
	_check(
		first_student.get_attack_target() == null and first_order.has_active_order(),
		"A move command overwrites explicit combat status"
	)
	first_order._physics_process(1.0)
	first_student._physics_process(1.0)
	_check(
		enemy_student.current_health == enemy_health_before_retreat
		and first_student.velocity.length() > 0.0,
		"Active movement takes priority over automatic contact combat"
	)

	first_order.cancel_order()
	first_order.set_destination(first_student.global_position + Vector2(20.0, 0.0))
	first_order._physics_process(0.01)
	_check(
		first_student.get_move_intent().length() < 1.0,
		"Students slow smoothly as they approach their destination"
	)
	first_order.cancel_order()
	first_order.stall_timeout = 0.1
	first_order.set_destination(
		first_student.global_position + Vector2(400.0, 300.0)
	)
	_check(
		first_order.get_waypoints().size() == 1,
		"Natural movement retains a single direct destination"
	)
	first_order._physics_process(0.11)
	_check(
		not first_order.has_active_order() and first_student.velocity.is_zero_approx(),
		"A fully blocked move order cancels instead of hanging forever"
	)

	first_student.queue_free()
	second_student.queue_free()
	enemy_student.queue_free()
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
