class_name GameFlowController
extends Node

@export var match_scene: PackedScene
@export var menu_path: NodePath = NodePath("Menu")
@export var end_screen_path: NodePath = NodePath("EndScreen")
@export var result_title_path: NodePath = NodePath("EndScreen/ResultPanel/Margin/VBox/Title")
@export var result_detail_path: NodePath = NodePath("EndScreen/ResultPanel/Margin/VBox/Detail")
@export var menu_button_path: NodePath = NodePath(
	"EndScreen/ResultPanel/Margin/VBox/MenuButton"
)

var current_match: Node2D
var selected_team: TeamDefinition

var _menu: GameMenu
var _end_screen: Control
var _result_title: Label
var _result_detail: Label


func _ready() -> void:
	_menu = get_node(menu_path) as GameMenu
	_end_screen = get_node(end_screen_path) as Control
	_result_title = get_node(result_title_path) as Label
	_result_detail = get_node(result_detail_path) as Label
	var menu_button: Button = get_node(menu_button_path) as Button
	_menu.team_selected.connect(start_match)
	menu_button.pressed.connect(return_to_menu)
	show_menu()


func show_menu() -> void:
	_end_screen.hide()
	_menu.show()
	_menu.process_mode = Node.PROCESS_MODE_ALWAYS


func start_match(team: TeamDefinition) -> void:
	if team == null or match_scene == null:
		return
	_free_current_match()
	selected_team = team
	_menu.hide()
	_end_screen.hide()
	current_match = match_scene.instantiate() as Node2D
	add_child(current_match)
	move_child(current_match, 0)
	_configure_match(team)


func show_match_result(player_won: bool, winner: TeamDefinition) -> void:
	if current_match != null:
		current_match.process_mode = Node.PROCESS_MODE_DISABLED
	_result_title.text = "VICTORY" if player_won else "DEFEAT"
	_result_title.modulate = Color("71ec7b") if player_won else Color("ee6262")
	if player_won:
		_result_detail.text = "%s controls the school." % selected_team.display_name
	elif winner != null:
		_result_detail.text = "%s won the territory war." % winner.display_name
	else:
		_result_detail.text = "Your students were eliminated."
	_end_screen.show()
	_end_screen.process_mode = Node.PROCESS_MODE_ALWAYS


func return_to_menu() -> void:
	_free_current_match()
	selected_team = null
	show_menu()


func _configure_match(team: TeamDefinition) -> void:
	var selection: UnitSelectionController = current_match.get_node(
		"HUD/SelectionOverlay"
	) as UnitSelectionController
	selection.configure_player_team(team.team_id)

	var ai: TeamAIController = current_match.get_node("TeamAIController") as TeamAIController
	ai.configure_player_team(team.team_id)

	var manager: MatchManager = current_match.get_node("MatchManager") as MatchManager
	manager.match_ended.connect(show_match_result)
	manager.configure_player_team(team)

	var camera: RTSCameraController = current_match.get_node("RTSCamera") as RTSCameraController
	for node: Node in get_tree().get_nodes_in_group(TeamSpawnPoint.SPAWN_POINT_GROUP):
		var spawn_point: TeamSpawnPoint = node as TeamSpawnPoint
		if spawn_point != null and spawn_point.team == team:
			camera.set_zoom_level(1.0, true)
			camera.set_target_position(spawn_point.global_position, true)
			break


func _free_current_match() -> void:
	if current_match == null:
		return
	current_match.free()
	current_match = null
