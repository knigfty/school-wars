extends SceneTree

const STUDENT_SCENE: PackedScene = preload("res://Characters/student.tscn")
const SELECTION_CONTROLLER_SCRIPT: Script = preload(
	"res://Scripts/UI/unit_selection_controller.gd"
)
const TERRITORY_SCENE: PackedScene = preload("res://Scenes/Territory/territory_tile.tscn")
const GREEN_TEAM: TeamDefinition = preload("res://Resources/Team/green_team.tres")

var _failures: int = 0
var _move_order_destinations: Array[Vector2] = []
var _attack_targets: Array[StudentController] = []
var _territory_targets: Array[TerritoryTile] = []


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var first_student: StudentController = STUDENT_SCENE.instantiate() as StudentController
	var second_student: StudentController = STUDENT_SCENE.instantiate() as StudentController
	first_student.position = Vector2(100.0, 100.0)
	second_student.position = Vector2(300.0, 300.0)
	second_student.team = GREEN_TEAM
	root.add_child(first_student)
	root.add_child(second_student)

	var controller: UnitSelectionController = SELECTION_CONTROLLER_SCRIPT.new()
	root.add_child(controller)
	var first_selectable: SelectableComponent = (
		first_student.get_node("Selectable") as SelectableComponent
	)
	var second_selectable: SelectableComponent = (
		second_student.get_node("Selectable") as SelectableComponent
	)
	var first_indicator: CanvasItem = first_student.get_node("SelectionIndicator") as CanvasItem
	controller.move_order_requested.connect(_on_move_order_requested)
	controller.attack_order_requested.connect(_on_attack_order_requested)
	controller.territory_order_requested.connect(_on_territory_order_requested)

	controller.select_in_screen_rect(Rect2(80.0, 80.0, 40.0, 40.0))
	_check(first_selectable.is_selected(), "Student inside marquee is selected")
	_check(first_indicator.visible, "Selected student displays its selection indicator")
	_check(not second_selectable.is_selected(), "Student outside marquee stays unselected")
	_check(controller.get_selected_units().size() == 1, "Selection list contains one student")

	controller._handle_click(Vector2(200.0, 200.0))
	_check(_move_order_destinations.size() == 1, "Second left click requests a move order")
	_check(
		_move_order_destinations[0].is_equal_approx(Vector2(200.0, 200.0)),
		"Move request converts the click to the expected world destination"
	)
	_check(first_selectable.is_selected(), "Move request preserves the active selection")

	controller._handle_click(Vector2(300.0, 300.0))
	_check(_attack_targets.size() == 1, "Clicking an enemy requests an attack order")
	_check(_attack_targets[0] == second_student, "Attack order identifies the clicked enemy")
	_check(first_selectable.is_selected(), "Enemy order preserves the active squad")

	var territory: TerritoryTile = TERRITORY_SCENE.instantiate() as TerritoryTile
	territory.position = Vector2(400.0, 400.0)
	root.add_child(territory)
	controller._handle_click(Vector2(400.0, 400.0))
	_check(_territory_targets.size() == 1, "Clicking a square requests a territory order")
	_check(_territory_targets[0] == territory, "Territory order targets the square center")

	controller.select_in_screen_rect(Rect2(500.0, 500.0, 20.0, 20.0))
	_check(not first_selectable.is_selected(), "New selection clears previous selection")
	_check(not first_indicator.visible, "Cleared student hides its selection indicator")
	_check(controller.get_selected_units().is_empty(), "Empty marquee clears selection")

	first_student.queue_free()
	second_student.queue_free()
	controller.queue_free()
	territory.queue_free()
	if _failures == 0:
		print("Selection tests passed.")
	quit(_failures)


func _on_move_order_requested(
	_selected_units: Array[SelectableComponent],
	world_destination: Vector2
) -> void:
	_move_order_destinations.append(world_destination)


func _on_attack_order_requested(
	_selected_units: Array[SelectableComponent],
	target: StudentController
) -> void:
	_attack_targets.append(target)


func _on_territory_order_requested(
	_selected_units: Array[SelectableComponent],
	territory: TerritoryTile
) -> void:
	_territory_targets.append(territory)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
		return

	_failures += 1
	push_error("FAIL: %s" % description)
