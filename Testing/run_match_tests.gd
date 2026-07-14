extends SceneTree

const MATCH_SCENE: PackedScene = preload("res://Scenes/movement_test.tscn")
const BLACK_TEAM: TeamDefinition = preload("res://Resources/Team/black_team.tres")

var _failures: int = 0
var _match_results: Array[bool] = []


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var match_scene: Node2D = MATCH_SCENE.instantiate() as Node2D
	root.add_child(match_scene)
	var manager: MatchManager = match_scene.get_node("MatchManager") as MatchManager
	manager.configure_player_team(BLACK_TEAM)
	manager.match_ended.connect(_on_match_ended)

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

	var territories: Array[Node] = get_nodes_in_group(TerritoryTile.TERRITORY_GROUP)
	for index: int in manager.victory_territory_count:
		var territory: TerritoryTile = territories[index] as TerritoryTile
		territory._set_owner(BLACK_TEAM)
	manager.evaluate_match()
	_check(manager.has_ended(), "Controlling the conquest threshold ends the match")
	_check(_match_results == [true], "Player conquest emits a Victory result")

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
	defeat_manager.set_elapsed_for_testing(defeat_manager.defeat_grace_period)
	defeat_manager.evaluate_match()
	_check(defeat_manager.has_ended(), "Player elimination ends the match")
	_check(_match_results == [false], "Player elimination emits a Defeat result")

	defeat_scene.queue_free()
	if _failures == 0:
		print("Match rules and opponent AI tests passed.")
	quit(_failures)


func _on_match_ended(player_won: bool, _winner: TeamDefinition) -> void:
	_match_results.append(player_won)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
		return
	_failures += 1
	push_error("FAIL: %s" % description)
