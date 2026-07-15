class_name TerritoryTile
extends Area2D

signal ownership_changed(tile: TerritoryTile, previous_team: StringName, team: TeamDefinition)

const TERRITORY_GROUP: StringName = &"territory_tiles"

@export var capture_duration: float = 5.0
@export var capture_reduction_per_additional_student: float = 1.0
@export var minimum_capture_duration: float = 1.0
@export var stationary_speed_threshold: float = 5.0
@export var tile_size: Vector2 = Vector2(110.0, 56.0)
@export_enum("heart", "club", "spade", "diamond") var emblem: String = "diamond"

var owner_team: TeamDefinition
var _capturing_team: TeamDefinition
var _capture_elapsed: float = 0.0
var _current_capture_duration: float = 5.0


func _ready() -> void:
	add_to_group(TERRITORY_GROUP)
	monitoring = true
	queue_redraw()


func _physics_process(delta: float) -> void:
	advance_capture(get_overlapping_bodies(), delta)


func advance_capture(candidates: Array[Node2D], delta: float) -> void:
	var stationary_teams: Dictionary = {}
	var stationary_counts: Dictionary = {}
	for candidate: Node2D in candidates:
		var student: StudentController = candidate as StudentController
		if student == null or student.team == null:
			continue
		if student.velocity.length() > stationary_speed_threshold:
			continue
		var team_id: StringName = student.get_team_id()
		stationary_teams[team_id] = student.team
		stationary_counts[team_id] = int(stationary_counts.get(team_id, 0)) + 1

	if stationary_teams.size() != 1:
		_reset_capture()
		return

	var candidate_team: TeamDefinition = stationary_teams.values()[0] as TeamDefinition
	var stationary_count: int = int(stationary_counts[candidate_team.team_id])
	if owner_team != null and owner_team.team_id == candidate_team.team_id:
		_reset_capture()
		return

	if _capturing_team == null or _capturing_team.team_id != candidate_team.team_id:
		_capturing_team = candidate_team
		_capture_elapsed = 0.0

	_current_capture_duration = get_required_capture_duration(stationary_count)
	_capture_elapsed += maxf(delta, 0.0)
	queue_redraw()
	if _capture_elapsed >= _current_capture_duration:
		_set_owner(candidate_team)


func get_required_capture_duration(stationary_student_count: int) -> float:
	var additional_students: int = maxi(stationary_student_count - 1, 0)
	return maxf(
		minimum_capture_duration,
		capture_duration
		- float(additional_students) * capture_reduction_per_additional_student
	)


func get_owner_team_id() -> StringName:
	return owner_team.team_id if owner_team != null else &""


func get_capture_ratio() -> float:
	if _capturing_team == null:
		return 0.0
	return clampf(_capture_elapsed / maxf(_current_capture_duration, 0.01), 0.0, 1.0)


func contains_world_point(world_point: Vector2) -> bool:
	var local_point: Vector2 = to_local(world_point)
	var half_size: Vector2 = tile_size * 0.5
	return (
		absf(local_point.x) / half_size.x
		+ absf(local_point.y) / half_size.y
	) <= 1.0


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
	_current_capture_duration = capture_duration
	queue_redraw()


func _draw() -> void:
	var half_size: Vector2 = tile_size * 0.5
	var points: PackedVector2Array = PackedVector2Array([
		Vector2(0.0, -half_size.y),
		Vector2(half_size.x, 0.0),
		Vector2(0.0, half_size.y),
		Vector2(-half_size.x, 0.0),
	])
	var lower_points: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in points:
		lower_points.append(point + Vector2(0.0, 7.0))
	draw_colored_polygon(lower_points, Color("c1c4c2"))
	var fill_color: Color = Color("fafaf8")
	if owner_team != null:
		fill_color = owner_team.color.lightened(0.12)
	draw_colored_polygon(points, fill_color)
	var outline: PackedVector2Array = points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, Color(1.0, 1.0, 1.0, 0.72), 2.0)

	var emblem_color: Color = Color("b7bab8")
	if owner_team != null:
		emblem_color = owner_team.color.darkened(0.18)
	_draw_emblem(emblem_color)

	var capture_ratio: float = get_capture_ratio()
	if capture_ratio > 0.0 and _capturing_team != null:
		var bar_rect: Rect2 = Rect2(Vector2(-40.0, 35.0), Vector2(80.0, 6.0))
		draw_rect(bar_rect, Color(0.05, 0.06, 0.08, 0.7), true)
		draw_rect(
			Rect2(bar_rect.position, Vector2(bar_rect.size.x * capture_ratio, bar_rect.size.y)),
			_capturing_team.color,
			true
		)


func _draw_emblem(color: Color) -> void:
	match emblem:
		"heart":
			draw_circle(Vector2(-7.0, -2.0), 8.0, color)
			draw_circle(Vector2(7.0, -2.0), 8.0, color)
			draw_colored_polygon(PackedVector2Array([
				Vector2(-14.0, 1.0), Vector2(14.0, 1.0), Vector2(0.0, 16.0)
			]), color)
		"club":
			draw_circle(Vector2(0.0, -9.0), 8.0, color)
			draw_circle(Vector2(-9.0, 1.0), 8.0, color)
			draw_circle(Vector2(9.0, 1.0), 8.0, color)
			draw_colored_polygon(PackedVector2Array([
				Vector2(-4.0, 4.0), Vector2(4.0, 4.0), Vector2(7.0, 15.0), Vector2(-7.0, 15.0)
			]), color)
		"spade":
			draw_circle(Vector2(-7.0, 3.0), 8.0, color)
			draw_circle(Vector2(7.0, 3.0), 8.0, color)
			draw_colored_polygon(PackedVector2Array([
				Vector2(0.0, -16.0), Vector2(14.0, 2.0), Vector2(-14.0, 2.0)
			]), color)
			draw_colored_polygon(PackedVector2Array([
				Vector2(-4.0, 7.0), Vector2(4.0, 7.0), Vector2(7.0, 16.0), Vector2(-7.0, 16.0)
			]), color)
		_:
			draw_colored_polygon(PackedVector2Array([
				Vector2(0.0, -15.0), Vector2(13.0, 0.0), Vector2(0.0, 15.0), Vector2(-13.0, 0.0)
			]), color)
