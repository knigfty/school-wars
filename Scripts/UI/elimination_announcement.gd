class_name EliminationAnnouncement
extends PanelContainer

@export var match_manager_path: NodePath = NodePath("../../MatchManager")
@export_range(1.0, 10.0, 0.5) var display_duration: float = 4.0

var _remaining: float = 0.0
var _label: Label


func _ready() -> void:
	_label = get_node("Label") as Label
	var manager: MatchManager = get_node(match_manager_path) as MatchManager
	manager.team_eliminated.connect(show_team_eliminated)
	hide()


func _process(delta: float) -> void:
	if _remaining <= 0.0:
		return
	_remaining = maxf(_remaining - delta, 0.0)
	if is_zero_approx(_remaining):
		hide()


func show_team_eliminated(team: TeamDefinition) -> void:
	if team == null:
		return
	_label.text = "%s has been eliminated" % team.display_name
	_label.modulate = team.color.lightened(0.35)
	_remaining = display_duration
	show()
