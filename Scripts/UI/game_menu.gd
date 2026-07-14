class_name GameMenu
extends Control

signal team_selected(team: TeamDefinition)

@export var black_team: TeamDefinition
@export var green_team: TeamDefinition
@export var yellow_team: TeamDefinition
@export var purple_team: TeamDefinition

var _teams: Array[TeamDefinition] = []
var _team_buttons: Array[Button] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_teams = [black_team, green_team, yellow_team, purple_team]
	_create_team_buttons()
	resized.connect(_layout_team_buttons)
	_layout_team_buttons()
	queue_redraw()


func select_team(team_id: StringName) -> void:
	for team: TeamDefinition in _teams:
		if team != null and team.team_id == team_id:
			team_selected.emit(team)
			return


func get_team_buttons() -> Array[Button]:
	return _team_buttons


func _create_team_buttons() -> void:
	for index: int in _teams.size():
		var team: TeamDefinition = _teams[index]
		if team == null:
			continue
		var button: Button = Button.new()
		button.name = "%sTeamButton" % team.display_name
		button.text = ""
		button.focus_mode = Control.FOCUS_ALL
		button.tooltip_text = team.trait_description
		button.add_theme_stylebox_override("normal", _make_button_style(Color.TRANSPARENT))
		button.add_theme_stylebox_override(
			"hover",
			_make_button_style(Color(team.color, 0.14), team.color.lightened(0.3))
		)
		button.add_theme_stylebox_override(
			"focus",
			_make_button_style(Color(team.color, 0.1), Color.WHITE)
		)
		button.add_theme_stylebox_override(
			"pressed",
			_make_button_style(Color(team.color, 0.24), team.color.lightened(0.45))
		)
		button.pressed.connect(_on_team_button_pressed.bind(team))
		button.mouse_entered.connect(queue_redraw)
		button.mouse_exited.connect(queue_redraw)
		add_child(button)
		_team_buttons.append(button)


func _layout_team_buttons() -> void:
	var rects: Array[Rect2] = _get_team_card_rects()
	for index: int in mini(rects.size(), _team_buttons.size()):
		_team_buttons[index].position = rects[index].position
		_team_buttons[index].size = rects[index].size
	queue_redraw()


func _draw() -> void:
	_draw_background()
	var viewport_size: Vector2 = size
	var title_center: Vector2 = Vector2(viewport_size.x * 0.64, viewport_size.y * 0.34)
	_draw_centered_text("SCHOOL WARS", title_center, 58, Color.WHITE, Color.BLACK, 4.0)
	_draw_centered_text(
		"CHOOSE YOUR SCHOOL COLOUR",
		title_center + Vector2(0.0, 48.0),
		18,
		Color("69e8e4"),
		Color("102226"),
		2.0
	)

	var hero_center: Vector2 = Vector2(viewport_size.x * 0.22, viewport_size.y * 0.31)
	_draw_student(hero_center + Vector2(-72.0, 18.0), black_team, 2.0, true)
	_draw_student(hero_center + Vector2(-18.0, 54.0), green_team, 2.05, false)
	_draw_student(hero_center + Vector2(40.0, 12.0), yellow_team, 2.15, true)
	_draw_student(hero_center + Vector2(88.0, -38.0), purple_team, 2.0, false)

	var card_rects: Array[Rect2] = _get_team_card_rects()
	for index: int in mini(card_rects.size(), _teams.size()):
		_draw_team_card(card_rects[index], _teams[index], index)


func _draw_background() -> void:
	var band_count: int = 20
	for index: int in band_count:
		var ratio: float = float(index) / float(band_count - 1)
		var color: Color = Color("050505").lerp(Color("4b4c4d"), ratio)
		var band_height: float = size.y * 0.64 / float(band_count)
		draw_rect(
			Rect2(0.0, band_height * index, size.x, band_height + 1.0),
			color,
			true
		)
	draw_rect(Rect2(0.0, size.y * 0.64, size.x, size.y * 0.36), Color("8a8b8b"), true)
	draw_rect(Rect2(0.0, size.y * 0.64, size.x, 2.0), Color("b8b9b9"), true)
	draw_rect(Rect2(0.0, size.y - 3.0, size.x, 3.0), Color("57595b"), true)


func _draw_team_card(card_rect: Rect2, team: TeamDefinition, pose: int) -> void:
	if team == null:
		return
	var button: Button = _team_buttons[pose] if pose < _team_buttons.size() else null
	var hovered: bool = button != null and button.is_hovered()
	var card_color: Color = Color(0.08, 0.085, 0.09, 0.16 if not hovered else 0.3)
	draw_rect(card_rect, card_color, true)
	draw_rect(card_rect, Color(team.color, 0.45 if not hovered else 0.9), false, 2.0)
	_draw_student(
		Vector2(card_rect.get_center().x, card_rect.position.y + card_rect.size.y * 0.42),
		team,
		1.0,
		pose % 2 == 0
	)
	_draw_centered_text(
		team.display_name.to_upper(),
		Vector2(card_rect.get_center().x, card_rect.end.y - 38.0),
		20,
		Color.WHITE,
		Color("343434"),
		2.0
	)
	_draw_centered_text(
		team.trait_name,
		Vector2(card_rect.get_center().x, card_rect.end.y - 15.0),
		11,
		team.color.lightened(0.38),
		Color("343434"),
		1.0
	)


func _draw_student(
	center: Vector2,
	team: TeamDefinition,
	scale_factor: float,
	lean_left: bool
) -> void:
	if team == null:
		return
	var lean: float = -3.0 if lean_left else 3.0
	_draw_scaled_polygon(
		center + Vector2(6.0, 27.0) * scale_factor,
		PackedVector2Array([-18, 0, -12, -5, 0, -7, 13, -4, 18, 1, 10, 6, -9, 6]),
		scale_factor,
		Color(0.0, 0.0, 0.0, 0.45)
	)
	_draw_scaled_polygon(
		center,
		PackedVector2Array([-11, 8, -2, 8, -3, 28, -12, 28, 2, 8, 11, 8, 12, 28, 3, 28]),
		scale_factor,
		Color("101216")
	)
	_draw_scaled_polygon(
		center + Vector2(lean, 0.0),
		PackedVector2Array([0, -17, 15, -7, 14, 14, 0, 19, -14, 14, -15, -7]),
		scale_factor,
		team.color.darkened(0.42)
	)
	_draw_scaled_polygon(
		center + Vector2(lean, 0.0),
		PackedVector2Array([0, -14, 11, -5, 10, 11, 0, 15, -10, 11, -11, -5]),
		scale_factor,
		team.color.darkened(0.18)
	)
	_draw_scaled_polygon(
		center + Vector2(lean, -22.0),
		PackedVector2Array([0, -9, 7, -6, 9, 1, 6, 8, 0, 10, -7, 7, -9, 0, -6, -7]),
		scale_factor,
		Color("b78350")
	)
	_draw_scaled_polygon(
		center + Vector2(lean, -22.0),
		PackedVector2Array([-8, -2, -6, -9, 1, -12, 8, -7, 7, -2, 2, -6, -4, -5]),
		scale_factor,
		Color("15100c")
	)
	_draw_scaled_polygon(
		center + Vector2(lean, -22.0),
		PackedVector2Array([-10, -10, 0, -15, 10, -10, 8, -6, -8, -6]),
		scale_factor,
		team.color.darkened(0.25)
	)
	for button_y: float in [-7.0, 0.0, 7.0]:
		draw_circle(
			center + Vector2(lean, button_y) * scale_factor,
			1.7 * scale_factor,
			Color("f5cd42")
		)


func _draw_scaled_polygon(
	center: Vector2,
	points: PackedVector2Array,
	scale_factor: float,
	color: Color
) -> void:
	var transformed: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in points:
		transformed.append(center + point * scale_factor)
	draw_colored_polygon(transformed, color)


func _draw_centered_text(
	text_value: String,
	center: Vector2,
	font_size: int,
	color: Color,
	outline_color: Color,
	outline_size: float
) -> void:
	var width: float = minf(size.x * 0.58, 540.0)
	var baseline: Vector2 = center + Vector2(-width * 0.5, float(font_size) * 0.35)
	for offset: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		draw_string(
			ThemeDB.fallback_font,
			baseline + offset * outline_size,
			text_value,
			HORIZONTAL_ALIGNMENT_CENTER,
			width,
			font_size,
			outline_color
		)
	draw_string(
		ThemeDB.fallback_font,
		baseline,
		text_value,
		HORIZONTAL_ALIGNMENT_CENTER,
		width,
		font_size,
		color
	)


func _get_team_card_rects() -> Array[Rect2]:
	var gap: float = 12.0
	var total_width: float = minf(size.x * 0.82, 820.0)
	var card_width: float = (total_width - gap * 3.0) / 4.0
	var card_height: float = minf(size.y * 0.27, 158.0)
	var start_x: float = (size.x - total_width) * 0.5
	var top: float = size.y * 0.68
	var result: Array[Rect2] = []
	for index: int in 4:
		result.append(
			Rect2(start_x + float(index) * (card_width + gap), top, card_width, card_height)
		)
	return result


func _make_button_style(
	background: Color,
	border: Color = Color.TRANSPARENT
) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	return style


func _on_team_button_pressed(team: TeamDefinition) -> void:
	team_selected.emit(team)
