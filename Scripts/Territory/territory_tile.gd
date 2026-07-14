class_name TerritoryTile
extends Area2D

signal ownership_changed(tile: TerritoryTile, previous_team: StringName, team: TeamDefinition)

const TERRITORY_GROUP: StringName = &"territory_tiles"

@export var capture_duration: float = 2.5
@export var stationary_speed_threshold: float = 5.0
@export var tile_size: Vector2 = Vector2(110.0, 56.0)

var owner_team: TeamDefinition
var _capturing_team: TeamDefinition
var _capture_elapsed: float = 0.0


func _ready() -> void:
	add_to_group(TERRITORY_GROUP)
	monitoring = true
	queue_redraw()


func _physics_process(delta: float) -> void:
	advance_capture(get_overlapping_bodies(), delta)


func advance_capture(candidates: Array[Node2D], delta: float) -> void:
	var stationary_teams: Dictionary = {}
	for candidate: Node2D in candidates:
		var student: StudentController = candidate as StudentController
		if student == null or student.team == null:
			continue
		if student.velocity.length() > stationary_speed_threshold:
			continue
		stationary_teams[student.get_team_id()] = student.team

	if stationary_teams.size() != 1:
		_reset_capture()
		return

	var candidate_team: TeamDefinition = stationary_teams.values()[0] as TeamDefinition
	if owner_team != null and owner_team.team_id == candidate_team.team_id:
		_reset_capture()
		return

	if _capturing_team == null or _capturing_team.team_id != candidate_team.team_id:
		_capturing_team = candidate_team
		_capture_elapsed = 0.0

	_capture_elapsed += maxf(delta, 0.0)
	queue_redraw()
	if _capture_elapsed >= capture_duration:
		_set_owner(candidate_team)


func get_owner_team_id() -> StringName:
	return owner_team.team_id if owner_team != null else &""


func get_capture_ratio() -> float:
	if _capturing_team == null:
		return 0.0
	return clampf(_capture_elapsed / maxf(capture_duration, 0.01), 0.0, 1.0)


func _set_owner(next_team: TeamDefinition) -> void:
	var previous_team: StringName = get_owner_team_id()
	owner_team = next_team
	_reset_capture()
	queue_redraw()
	ownership_changed.emit(self, previous_team, next_team)


func _reset_capture() -> void:
	if _capturing_team == null and is_zero_approx(_capture_elapsed):
		return
	_capturing_team = null
	_capture_elapsed = 0.0
	queue_redraw()


func _draw() -> void:
	var half_size: Vector2 = tile_size * 0.5
	var points: PackedVector2Array = PackedVector2Array([
		Vector2(0.0, -half_size.y),
		Vector2(half_size.x, 0.0),
		Vector2(0.0, half_size.y),
		Vector2(-half_size.x, 0.0),
	])
	var fill_color: Color = Color("f4f5f2")
	if owner_team != null:
		fill_color = owner_team.color.lightened(0.2)
	draw_colored_polygon(points, fill_color)
	var outline: PackedVector2Array = points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, Color(0.2, 0.23, 0.28, 0.45), 2.0)

	var emblem_color: Color = Color("b8bdbb")
	if owner_team != null:
		emblem_color = owner_team.color.darkened(0.2)
	draw_circle(Vector2(0.0, 2.0), 12.0, emblem_color)
	draw_circle(Vector2(-13.0, -2.0), 8.0, emblem_color)

	var capture_ratio: float = get_capture_ratio()
	if capture_ratio > 0.0 and _capturing_team != null:
		var bar_rect: Rect2 = Rect2(Vector2(-40.0, 35.0), Vector2(80.0, 6.0))
		draw_rect(bar_rect, Color(0.05, 0.06, 0.08, 0.7), true)
		draw_rect(
			Rect2(bar_rect.position, Vector2(bar_rect.size.x * capture_ratio, bar_rect.size.y)),
			_capturing_team.color,
			true
		)
