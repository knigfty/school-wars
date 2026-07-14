extends SceneTree

const STUDENT_SCENE: PackedScene = preload("res://Characters/student.tscn")
const TERRITORY_SCENE: PackedScene = preload("res://Scenes/Territory/territory_tile.tscn")
const BLACK_TEAM: TeamDefinition = preload("res://Resources/Team/black_team.tres")
const GREEN_TEAM: TeamDefinition = preload("res://Resources/Team/green_team.tres")

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var tile: TerritoryTile = TERRITORY_SCENE.instantiate() as TerritoryTile
	root.add_child(tile)
	var black_student: StudentController = STUDENT_SCENE.instantiate() as StudentController
	black_student.team = BLACK_TEAM
	root.add_child(black_student)
	var candidates: Array[Node2D] = [black_student]

	black_student.velocity = Vector2(30.0, 0.0)
	tile.advance_capture(candidates, tile.capture_duration)
	_check(tile.get_owner_team_id().is_empty(), "Moving students cannot capture")

	black_student.velocity = Vector2.ZERO
	tile.advance_capture(candidates, tile.capture_duration)
	_check(tile.get_owner_team_id() == &"black", "A stationary student captures a neutral tile")

	var green_student: StudentController = STUDENT_SCENE.instantiate() as StudentController
	green_student.team = GREEN_TEAM
	root.add_child(green_student)
	var competing_candidates: Array[Node2D] = [black_student, green_student]
	tile.advance_capture(competing_candidates, tile.capture_duration)
	_check(tile.get_owner_team_id() == &"black", "Competing teams cannot capture together")

	var green_candidates: Array[Node2D] = [green_student]
	tile.advance_capture(green_candidates, tile.capture_duration)
	_check(tile.get_owner_team_id() == &"green", "A stationary opponent can recapture a tile")

	tile.queue_free()
	black_student.queue_free()
	green_student.queue_free()
	if _failures == 0:
		print("Territory capture tests passed.")
	quit(_failures)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
		return
	_failures += 1
	push_error("FAIL: %s" % description)
