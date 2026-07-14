class_name StudentMoveOrderComponent
extends Node

signal move_started(destination: Vector2)
signal destination_reached(destination: Vector2)

@export_range(1.0, 64.0, 1.0) var arrival_distance: float = 10.0

var _student: StudentController
var _destination: Vector2 = Vector2.ZERO
var _has_active_order: bool = false
var _waypoints: Array[Vector2] = []
var _waypoint_index: int = 0


func _ready() -> void:
	_student = get_parent() as StudentController
	if _student == null:
		push_error("%s requires a StudentController parent." % name)
		set_physics_process(false)
		return

	process_physics_priority = -10


func _physics_process(_delta: float) -> void:
	if not _has_active_order:
		return

	if _waypoint_index >= _waypoints.size():
		_complete_order()
		return

	var offset: Vector2 = _waypoints[_waypoint_index] - _student.global_position
	if offset.length() <= arrival_distance:
		_waypoint_index += 1
		if _waypoint_index >= _waypoints.size():
			_complete_order()
		return

	_student.set_move_intent(offset.normalized())


func set_destination(world_destination: Vector2) -> void:
	_destination = world_destination
	_waypoints = _build_crisscross_waypoints(_student.global_position, _destination)
	_waypoint_index = 0
	_has_active_order = true
	move_started.emit(_destination)


func cancel_order() -> void:
	_has_active_order = false
	_waypoints.clear()
	_waypoint_index = 0
	if _student != null:
		_student.stop_immediately()


func has_active_order() -> bool:
	return _has_active_order


func get_destination() -> Vector2:
	return _destination


func get_waypoints() -> Array[Vector2]:
	return _waypoints.duplicate()


func _build_crisscross_waypoints(start: Vector2, finish: Vector2) -> Array[Vector2]:
	var offset: Vector2 = finish - start
	var diagonal_down_amount: float = (offset.x + offset.y) * 0.5
	var diagonal_up_amount: float = (offset.x - offset.y) * 0.5
	var diagonal_down: Vector2 = Vector2(diagonal_down_amount, diagonal_down_amount)
	var diagonal_up: Vector2 = Vector2(diagonal_up_amount, -diagonal_up_amount)
	var first_leg: Vector2 = diagonal_down
	if _student.get_instance_id() % 2 == 0:
		first_leg = diagonal_up
	var corner: Vector2 = start + first_leg
	var result: Array[Vector2] = []
	if (
		corner.distance_to(start) > arrival_distance
		and corner.distance_to(finish) > arrival_distance
	):
		result.append(corner)
	result.append(finish)
	return result


func _complete_order() -> void:
	var reached_destination: Vector2 = _destination
	cancel_order()
	destination_reached.emit(reached_destination)
