class_name StudentMoveOrderComponent
extends Node

signal move_started(destination: Vector2)
signal destination_reached(destination: Vector2)
signal move_blocked(destination: Vector2)

@export_range(1.0, 64.0, 1.0) var arrival_distance: float = 10.0
@export_range(24.0, 160.0, 4.0) var arrival_slowdown_distance: float = 72.0
@export_range(0.25, 5.0, 0.25) var stall_timeout: float = 1.5
@export_range(0.1, 8.0, 0.1) var minimum_progress_distance: float = 2.0

var _student: StudentController
var _destination: Vector2 = Vector2.ZERO
var _has_active_order: bool = false
var _waypoints: Array[Vector2] = []
var _waypoint_index: int = 0
var _best_waypoint_distance: float = INF
var _stall_elapsed: float = 0.0


func _ready() -> void:
	_student = get_parent() as StudentController
	if _student == null:
		push_error("%s requires a StudentController parent." % name)
		set_physics_process(false)
		return

	process_physics_priority = -10


func _physics_process(delta: float) -> void:
	if not _has_active_order:
		return

	if _waypoint_index >= _waypoints.size():
		_complete_order()
		return

	var offset: Vector2 = _waypoints[_waypoint_index] - _student.global_position
	var waypoint_distance: float = offset.length()
	if waypoint_distance <= arrival_distance:
		_waypoint_index += 1
		if _waypoint_index >= _waypoints.size():
			_complete_order()
		else:
			_reset_stall_watchdog()
		return

	if waypoint_distance <= _best_waypoint_distance - minimum_progress_distance:
		_best_waypoint_distance = waypoint_distance
		_stall_elapsed = 0.0
	else:
		_stall_elapsed += maxf(delta, 0.0)

	if _stall_elapsed >= stall_timeout:
		if _waypoint_index < _waypoints.size() - 1:
			_waypoint_index = _waypoints.size() - 1
			_reset_stall_watchdog()
			offset = _waypoints[_waypoint_index] - _student.global_position
		else:
			var blocked_destination: Vector2 = _destination
			cancel_order()
			move_blocked.emit(blocked_destination)
			return

	var arrival_speed_scale: float = clampf(
		waypoint_distance / maxf(arrival_slowdown_distance, arrival_distance),
		0.2,
		1.0
	)
	_student.set_move_intent(offset.normalized() * arrival_speed_scale)


func set_destination(world_destination: Vector2) -> void:
	_destination = world_destination
	_waypoints = [_destination]
	_waypoint_index = 0
	_has_active_order = true
	_reset_stall_watchdog()
	move_started.emit(_destination)


func cancel_order() -> void:
	_has_active_order = false
	_waypoints.clear()
	_waypoint_index = 0
	_best_waypoint_distance = INF
	_stall_elapsed = 0.0
	if _student != null:
		_student.stop_immediately()


func has_active_order() -> bool:
	return _has_active_order


func get_destination() -> Vector2:
	return _destination


func get_waypoints() -> Array[Vector2]:
	return _waypoints.duplicate()


func _complete_order() -> void:
	var reached_destination: Vector2 = _destination
	cancel_order()
	destination_reached.emit(reached_destination)


func _reset_stall_watchdog() -> void:
	_stall_elapsed = 0.0
	if _student == null or _waypoint_index >= _waypoints.size():
		_best_waypoint_distance = INF
		return
	_best_waypoint_distance = _student.global_position.distance_to(
		_waypoints[_waypoint_index]
	)
