class_name StudentMoveOrderComponent
extends Node

signal move_started(destination: Vector2)
signal destination_reached(destination: Vector2)

@export_range(1.0, 64.0, 1.0) var arrival_distance: float = 10.0

var _student: StudentController
var _destination: Vector2 = Vector2.ZERO
var _has_active_order: bool = false


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

	var offset: Vector2 = _destination - _student.global_position
	if offset.length() <= arrival_distance:
		var reached_destination: Vector2 = _destination
		cancel_order()
		destination_reached.emit(reached_destination)
		return

	_student.set_move_intent(offset.normalized())


func set_destination(world_destination: Vector2) -> void:
	_destination = world_destination
	_has_active_order = true
	move_started.emit(_destination)


func cancel_order() -> void:
	_has_active_order = false
	if _student != null:
		_student.stop_immediately()


func has_active_order() -> bool:
	return _has_active_order


func get_destination() -> Vector2:
	return _destination

