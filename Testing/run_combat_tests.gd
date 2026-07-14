extends SceneTree

const STUDENT_SCENE: PackedScene = preload("res://Characters/student.tscn")
const BLACK_TEAM: TeamDefinition = preload("res://Resources/Team/black_team.tres")
const GREEN_TEAM: TeamDefinition = preload("res://Resources/Team/green_team.tres")
const PURPLE_TEAM: TeamDefinition = preload("res://Resources/Team/purple_team.tres")
const YELLOW_TEAM: TeamDefinition = preload("res://Resources/Team/yellow_team.tres")

var _failures: int = 0
var _attacks_observed: int = 0


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var purple: StudentController = _create_student(PURPLE_TEAM, Vector2(200.0, 200.0))
	var green: StudentController = _create_student(GREEN_TEAM, Vector2(230.0, 200.0))
	purple.attack_performed.connect(_on_attack_performed)
	green.attack_performed.connect(_on_attack_performed)
	var green_starting_health: float = green.current_health

	await physics_frame
	await physics_frame
	_check(_attacks_observed >= 1, "Enemy students fight when their bodies meet")
	_check(green.current_health < green_starting_health, "Contact combat deals health damage")
	_check(purple.maximum_health == 60.0, "Purple spawns with 60 HP")
	_check(purple.get_attack_damage_per_second() == 15.0, "Purple deals 15 HP per second")
	_check(green.maximum_health == 30.0, "Green spawns with 30 HP")
	_check(green.get_attack_damage_per_second() == 5.0, "Green deals 5 HP per second")

	var black: StudentController = _create_student(BLACK_TEAM, Vector2(500.0, 500.0))
	_check(black.maximum_health == 70.0, "Black spawns with 70 HP")
	_check(black.get_attack_damage_per_second() == 10.0, "Black deals 10 HP per second")

	var yellow: StudentController = _create_student(YELLOW_TEAM, Vector2(700.0, 700.0))
	var victim: StudentController = _create_student(GREEN_TEAM, Vector2(850.0, 700.0))
	var yellow_starting_maximum: float = yellow.maximum_health
	var black_starting_maximum: float = black.maximum_health
	_check(yellow.maximum_health == 100.0, "Yellow spawns with 100 HP")
	_check(yellow.get_attack_damage_per_second() == 6.0, "Yellow deals 6 HP per second")
	victim.take_damage(1.0, yellow)
	victim.take_damage(victim.current_health, black)
	_check(
		yellow.maximum_health == yellow_starting_maximum + 20.0,
		"Yellow gains 20 HP for assisting an enemy takedown"
	)
	_check(
		black.maximum_health == black_starting_maximum + 10.0,
		"Black gains 10 HP for completing an enemy takedown"
	)

	purple.queue_free()
	green.queue_free()
	black.queue_free()
	yellow.queue_free()
	if _failures == 0:
		print("Combat and team-trait tests passed.")
	quit(_failures)


func _create_student(team: TeamDefinition, position: Vector2) -> StudentController:
	var student: StudentController = STUDENT_SCENE.instantiate() as StudentController
	student.team = team
	student.position = position
	root.add_child(student)
	return student


func _on_attack_performed(
	_attacker: StudentController,
	_target: StudentController,
	_damage: float
) -> void:
	_attacks_observed += 1


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
		return
	_failures += 1
	push_error("FAIL: %s" % description)
