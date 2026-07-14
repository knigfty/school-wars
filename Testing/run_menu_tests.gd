extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://Scenes/main.tscn")
const BLACK_TEAM: TeamDefinition = preload("res://Resources/Team/black_team.tres")
const GREEN_TEAM: TeamDefinition = preload("res://Resources/Team/green_team.tres")
const PURPLE_TEAM: TeamDefinition = preload("res://Resources/Team/purple_team.tres")

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var app: GameFlowController = MAIN_SCENE.instantiate() as GameFlowController
	root.add_child(app)
	var menu: GameMenu = app.get_node("Menu") as GameMenu
	var end_screen: Control = app.get_node("EndScreen") as Control
	_check(menu.visible, "Game menu is shown when the project launches")
	_check(menu.get_team_buttons().size() == 4, "Menu offers four team colors")
	_check(app.current_match == null, "Match does not run behind the launch menu")

	menu.select_team(&"green")
	_check(app.current_match != null, "Choosing a color starts a match")
	_check(not menu.visible, "Team menu hides after selection")
	var selection: UnitSelectionController = app.current_match.get_node(
		"HUD/SelectionOverlay"
	) as UnitSelectionController
	_check(selection.player_team_id == &"green", "Selection is restricted to Green")
	var ai: TeamAIController = app.current_match.get_node(
		"TeamAIController"
	) as TeamAIController
	_check(ai.player_team_id == &"green", "Opponent AI excludes the chosen team")
	var camera: RTSCameraController = app.current_match.get_node(
		"RTSCamera"
	) as RTSCameraController
	_check(camera.get_pan_target_position().x > 800.0, "Camera opens near Green's east base")

	app.show_match_result(true, GREEN_TEAM)
	var result_title: Label = app.get_node(
		"EndScreen/ResultPanel/Margin/VBox/Title"
	) as Label
	_check(end_screen.visible, "Victory screen appears when the match ends")
	_check(result_title.text == "VICTORY", "Winning shows the Victory result")
	_check(
		app.current_match.process_mode == Node.PROCESS_MODE_DISABLED,
		"Finished match stops processing behind the result screen"
	)

	app.return_to_menu()
	_check(menu.visible, "Result screen can return to the game menu")
	_check(not end_screen.visible, "Result screen closes on return")
	_check(app.current_match == null, "Returning to menu disposes the old match")

	app.start_match(BLACK_TEAM)
	app.show_match_result(false, PURPLE_TEAM)
	_check(result_title.text == "DEFEAT", "Losing shows the Defeat result")
	app.return_to_menu()

	app.queue_free()
	if _failures == 0:
		print("Game menu and result-screen tests passed.")
	quit(_failures)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
		return
	_failures += 1
	push_error("FAIL: %s" % description)
