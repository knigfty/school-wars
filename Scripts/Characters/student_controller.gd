class_name StudentController
extends CharacterBody2D

## Command-driven movement motor for one student. This script never reads
## player input; future AI or order systems provide intent through
## [method set_move_intent].

signal movement_started
signal movement_stopped

const STUDENT_GROUP: StringName = &"students"

@export var stats: StudentStats
@export var team: TeamDefinition

var _move_intent: Vector2 = Vector2.ZERO
var _was_moving: bool = false


func _ready() -> void:
	add_to_group(STUDENT_GROUP)
	if stats == null:
		push_error("%s requires a StudentStats resource." % name)
		set_physics_process(false)
		return
	if team == null or not team.is_configured():
		push_error("%s requires a configured TeamDefinition." % name)
		return
	_apply_team_visuals()


func _physics_process(delta: float) -> void:
	var target_velocity: Vector2 = _move_intent * stats.movement_speed
	var change_rate: float = (
		stats.acceleration
		if not _move_intent.is_zero_approx()
		else stats.deceleration
	)
	velocity = velocity.move_toward(target_velocity, change_rate * delta)
	move_and_slide()
	_update_movement_signals()


func set_move_intent(direction: Vector2) -> void:
	_move_intent = direction.limit_length(1.0)


func get_move_intent() -> Vector2:
	return _move_intent


func stop_immediately() -> void:
	_move_intent = Vector2.ZERO
	velocity = Vector2.ZERO
	_update_movement_signals()


func get_team_id() -> StringName:
	return team.team_id if team != null else &""


func get_team_color() -> Color:
	return team.color if team != null else Color.WHITE


func _update_movement_signals() -> void:
	var is_moving: bool = not velocity.is_zero_approx()
	if is_moving == _was_moving:
		return

	_was_moving = is_moving
	if is_moving:
		movement_started.emit()
	else:
		movement_stopped.emit()


func _apply_team_visuals() -> void:
	var outline: Polygon2D = get_node_or_null("Visuals/Outline") as Polygon2D
	var body: Polygon2D = get_node_or_null("Visuals/Body") as Polygon2D
	var team_mark: Polygon2D = get_node_or_null("Visuals/TeamMark") as Polygon2D
	if outline != null:
		outline.color = team.color.lightened(0.42)
	if body != null:
		body.color = team.color.darkened(0.3)
	if team_mark != null:
		team_mark.color = team.color
