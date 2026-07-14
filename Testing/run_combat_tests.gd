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
	_check(
		is_equal_approx(purple.get_attack_damage(), purple.stats.attack_damage * 1.4),
		"Purple's trait increases attack damage"
	)

	var black: StudentController = _create_student(BLACK_TEAM, Vector2(500.0, 500.0))
	_check(
		black.maximum_health > black.stats.maximum_health,
		"Black's all-rounder trait increases maximum health"
	)
	_check(
		black.get_attack_damage() > black.stats.attack_damage,
		"Black's all-rounder trait increases attack damage"
	)

	var yellow: StudentController = _create_student(YELLOW_TEAM, Vector2(700.0, 700.0))
	var victim: StudentController = _create_student(GREEN_TEAM, Vector2(850.0, 700.0))
	var yellow_starting_maximum: float = yellow.maximum_health
	victim.take_damage(victim.current_health, yellow)
	_check(
		yellow.maximum_health == yellow_starting_maximum + 12.0,
		"Yellow gains maximum health for an enemy takedown"
	)

	var black_starting_maximum: float = black.maximum_health
	black.on_enemy_takedown(green)
	_check(
		black.maximum_health == black_starting_maximum + 3.0,
		"Black receives a smaller takedown growth bonus"
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
