extends SceneTree

const MATCH_SCENE: PackedScene = preload("res://Scenes/movement_test.tscn")
const BLACK_TEAM: TeamDefinition = preload("res://Resources/Team/black_team.tres")
const GREEN_TEAM: TeamDefinition = preload("res://Resources/Team/green_team.tres")
const PURPLE_TEAM: TeamDefinition = preload("res://Resources/Team/purple_team.tres")

var _failures: int = 0
var _match_results: Array[bool] = []
var _eliminated_team_ids: Array[StringName] = []


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var match_scene: Node2D = MATCH_SCENE.instantiate() as Node2D
	root.add_child(match_scene)
	var manager: MatchManager = match_scene.get_node("MatchManager") as MatchManager
	manager.configure_player_team(BLACK_TEAM)
	manager.match_ended.connect(_on_match_ended)
	manager.team_eliminated.connect(_on_team_eliminated)

	var ai: TeamAIController = match_scene.get_node("TeamAIController") as TeamAIController
	ai.configure_player_team(&"black")
	ai.issue_orders()
	var black_has_order: bool = false
	var opponent_has_order: bool = false
	for node: Node in get_nodes_in_group(StudentController.STUDENT_GROUP):
		var student: StudentController = node as StudentController
		if student == null:
			continue
		var order: StudentMoveOrderComponent = student.get_node("MoveOrder")
		if student.get_team_id() == &"black":
			black_has_order = black_has_order or order.has_active_order()
		else:
			opponent_has_order = opponent_has_order or order.has_active_order()
	_check(not black_has_order, "AI never overrides the player's team")
	_check(opponent_has_order, "Opponent teams receive territory orders")
	_check(ai.get_strategy_name(&"green") == &"expansion", "Green AI spreads to territory")
	_check(ai.get_strategy_name(&"purple") == &"aggression", "Purple AI seeks fights")
	_check(
		ai.get_strategy_name(&"yellow") == &"takedown_focus",
		"Yellow AI focuses vulnerable enemies"
	)
	_check(ai.get_strategy_name(&"black") == &"balanced", "Black AI balances its goals")
	_check(
		ai.get_chase_fraction(&"purple") > ai.get_chase_fraction(&"green"),
		"Aggressive AI is more likely to chase while Green holds territory"
	)
	var tactical_territories: Array[Node] = get_nodes_in_group(
		TerritoryTile.TERRITORY_GROUP
	)
	var defended_tile: TerritoryTile = tactical_territories[0] as TerritoryTile
	defended_tile._set_owner(PURPLE_TEAM)
	var purple_students: Array[StudentController] = []
	var black_target: StudentController
	for node: Node in get_nodes_in_group(StudentController.STUDENT_GROUP):
		var tactical_student: StudentController = node as StudentController
		if tactical_student == null:
			continue
		if tactical_student.get_team_id() == &"purple":
			purple_students.append(tactical_student)
		elif tactical_student.get_team_id() == &"black":
			black_target = tactical_student
	purple_students[0].global_position = defended_tile.global_position
	ai._order_students_to_enemy(
		purple_students,
		black_target,
		ai.get_chase_fraction(&"purple")
	)
	_check(
		purple_students[0].get_attack_target() == null,
		"AI can keep a student defending owned territory"
	)
	_check(
		purple_students[1].get_attack_target() == black_target,
		"AI can send another student chasing a fleeing enemy"
	)
	for node: Node in get_nodes_in_group(StudentController.STUDENT_GROUP):
		var student: StudentController = node as StudentController
		if student != null and student.get_team_id() == &"purple":
			student.free()
	manager.evaluate_match()
	_check(&"purple" in _eliminated_team_ids, "Zero-unit teams are permanently eliminated")
	var spawner: TeamReinforcementSpawner = match_scene.get_node(
		"ReinforcementSpawner"
	) as TeamReinforcementSpawner
	_check(spawner.is_team_eliminated(&"purple"), "Eliminated teams stop spawning")
	_check(
		not manager.has_ended(),
		"Zero units eliminates a color regardless of its captured squares"
	)
	_check(_match_results.is_empty(), "Elimination emits no Victory or Defeat result")
	var announcement: EliminationAnnouncement = match_scene.get_node(
		"HUD/EliminationAnnouncement"
	) as EliminationAnnouncement
	_check(announcement.visible, "Elimination announcement appears at the top")
	var announcement_label: Label = announcement.get_node("Label") as Label
	_check(
		announcement_label.text == "Purple has been eliminated",
		"Announcement names the eliminated color"
	)
	announcement._process(4.0)
	_check(not announcement.visible, "Elimination announcement hides after four seconds")

	var territories: Array[Node] = get_nodes_in_group(TerritoryTile.TERRITORY_GROUP)
	for index: int in mini(8, territories.size()):
		var territory: TerritoryTile = territories[index] as TerritoryTile
		territory._set_owner(BLACK_TEAM)
	manager.evaluate_match()
	_check(not manager.has_ended(), "Territory control alone does not end the match")
	_check(_match_results.is_empty(), "Territory control emits no Victory result")

	for node: Node in get_nodes_in_group(StudentController.STUDENT_GROUP):
		var opponent: StudentController = node as StudentController
		if opponent == null or opponent.get_team_id() == &"black":
			continue
		opponent.free()
	manager.evaluate_match()
	_check(manager.has_ended(), "Eliminating all three opponents ends the match")
	_check(_match_results == [true], "Last surviving player team receives Victory")

	match_scene.free()
	_match_results.clear()
	var defeat_scene: Node2D = MATCH_SCENE.instantiate() as Node2D
	root.add_child(defeat_scene)
	var defeat_manager: MatchManager = defeat_scene.get_node("MatchManager") as MatchManager
	defeat_manager.configure_player_team(BLACK_TEAM)
	defeat_manager.match_ended.connect(_on_match_ended)
	for node: Node in get_nodes_in_group(StudentController.STUDENT_GROUP):
		var student: StudentController = node as StudentController
		if student != null and student.get_team_id() == &"black":
			student.free()
	defeat_manager.evaluate_match()
	_check(defeat_manager.is_team_eliminated(&"black"), "Player reaches eliminated state")
	_check(defeat_manager.has_ended(), "Player elimination ends the match immediately")
	_check(_match_results == [false], "Player elimination emits a Defeat result")

	defeat_scene.queue_free()
	if _failures == 0:
		print("Match rules and opponent AI tests passed.")
	quit(_failures)


func _on_match_ended(player_won: bool, _winner: TeamDefinition) -> void:
	_match_results.append(player_won)


func _on_team_eliminated(team: TeamDefinition) -> void:
	_eliminated_team_ids.append(team.team_id)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
		return
	_failures += 1
	push_error("FAIL: %s" % description)
