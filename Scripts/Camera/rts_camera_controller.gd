class_name RTSCameraController
extends Camera2D

## Browser-safe RTS camera with bounded keyboard, edge, and mouse panning.
## The bounds account for the visible viewport at the current zoom level.

signal zoom_changed(zoom_level: float)

@export_category("Bounds")
@export var world_bounds: Rect2 = Rect2(-120.0, -120.0, 1840.0, 1840.0)

@export_category("Panning")
@export_range(1.0, 3000.0, 1.0, "or_greater") var pan_speed: float = 650.0
@export_range(0.0, 128.0, 1.0) var edge_margin: float = 24.0
@export var edge_pan_enabled: bool = true
@export_range(0.0, 40.0, 0.1) var position_smoothing: float = 14.0

@export_group("Keyboard Actions")
@export var pan_left_action: StringName = "camera_pan_left"
@export var pan_right_action: StringName = "camera_pan_right"
@export var pan_up_action: StringName = "camera_pan_up"
@export var pan_down_action: StringName = "camera_pan_down"

@export_category("Zoom")
@export_range(0.1, 8.0, 0.05) var minimum_zoom: float = 0.75
@export_range(0.1, 8.0, 0.05) var maximum_zoom: float = 2.0
@export_range(0.01, 1.0, 0.01) var zoom_step: float = 0.15
@export_range(0.0, 40.0, 0.1) var zoom_smoothing: float = 16.0

var _target_position: Vector2
var _target_zoom: float
var _dragging: bool = false
var _pointer_inside: bool = false


func _ready() -> void:
	_validate_settings()
	_target_zoom = clampf(zoom.x, minimum_zoom, maximum_zoom)
	_target_position = _clamp_position(global_position, _target_zoom)
	global_position = _target_position
	zoom = Vector2.ONE * _target_zoom


func _process(delta: float) -> void:
	var pan_direction: Vector2 = Input.get_vector(
		pan_left_action,
		pan_right_action,
		pan_up_action,
		pan_down_action
	)
	pan_direction += _get_edge_pan_direction()
	pan_direction = pan_direction.limit_length(1.0)

	if not pan_direction.is_zero_approx():
		_target_position += pan_direction * pan_speed * delta / _target_zoom

	_target_position = _clamp_position(_target_position, _target_zoom)
	var position_weight: float = _smoothing_weight(position_smoothing, delta)
	var zoom_weight: float = _smoothing_weight(zoom_smoothing, delta)
	var current_zoom: float = lerpf(zoom.x, _target_zoom, zoom_weight)

	global_position = global_position.lerp(_target_position, position_weight)
	zoom = Vector2.ONE * current_zoom
	global_position = _clamp_position(global_position, current_zoom)


func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		_pointer_inside = true

	if not _dragging:
		return

	if event is InputEventMouseMotion:
		_target_position -= event.relative / _target_zoom
		_target_position = _clamp_position(_target_position, _target_zoom)
		get_viewport().set_input_as_handled()
	elif (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_RIGHT
		and not event.pressed
	):
		_dragging = false
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_ENTER:
		_pointer_inside = true
	elif what == NOTIFICATION_WM_MOUSE_EXIT:
		_pointer_inside = false
		_dragging = false


func set_target_position(world_position: Vector2, immediate: bool = false) -> void:
	_target_position = _clamp_position(world_position, _target_zoom)
	if immediate:
		global_position = _target_position


func get_target_position() -> Vector2:
	return _target_position


func set_zoom_level(zoom_level: float, immediate: bool = false) -> void:
	var viewport_center: Vector2 = get_viewport().get_visible_rect().size * 0.5
	_set_zoom_around_screen_point(zoom_level, viewport_center)
	if immediate:
		zoom = Vector2.ONE * _target_zoom
		global_position = _target_position


func get_zoom_level() -> float:
	return _target_zoom


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			_dragging = true
			get_viewport().set_input_as_handled()
		return

	if not event.pressed:
		return

	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_set_zoom_around_screen_point(_target_zoom + zoom_step, event.position)
		get_viewport().set_input_as_handled()
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_set_zoom_around_screen_point(_target_zoom - zoom_step, event.position)
		get_viewport().set_input_as_handled()


func _set_zoom_around_screen_point(zoom_level: float, screen_point: Vector2) -> void:
	var next_zoom: float = clampf(zoom_level, minimum_zoom, maximum_zoom)
	if is_equal_approx(next_zoom, _target_zoom):
		return

	var viewport_center: Vector2 = get_viewport().get_visible_rect().size * 0.5
	var screen_offset: Vector2 = screen_point - viewport_center
	var world_focus: Vector2 = _target_position + screen_offset / _target_zoom

	_target_zoom = next_zoom
	_target_position = world_focus - screen_offset / _target_zoom
	_target_position = _clamp_position(_target_position, _target_zoom)
	zoom_changed.emit(_target_zoom)


func _get_edge_pan_direction() -> Vector2:
	if not edge_pan_enabled or not _pointer_inside or _dragging:
		return Vector2.ZERO

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var mouse_position: Vector2 = get_viewport().get_mouse_position()
	if not Rect2(Vector2.ZERO, viewport_size).has_point(mouse_position):
		return Vector2.ZERO

	var direction: Vector2 = Vector2.ZERO
	if mouse_position.x <= edge_margin:
		direction.x -= 1.0
	elif mouse_position.x >= viewport_size.x - edge_margin:
		direction.x += 1.0

	if mouse_position.y <= edge_margin:
		direction.y -= 1.0
	elif mouse_position.y >= viewport_size.y - edge_margin:
		direction.y += 1.0
	return direction


func _clamp_position(candidate: Vector2, zoom_level: float) -> Vector2:
	var bounds: Rect2 = world_bounds.abs()
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var half_view: Vector2 = viewport_size * 0.5 / maxf(zoom_level, 0.001)
	var minimum_position: Vector2 = bounds.position + half_view
	var maximum_position: Vector2 = bounds.end - half_view
	var result: Vector2 = candidate

	if minimum_position.x > maximum_position.x:
		result.x = bounds.get_center().x
	else:
		result.x = clampf(result.x, minimum_position.x, maximum_position.x)

	if minimum_position.y > maximum_position.y:
		result.y = bounds.get_center().y
	else:
		result.y = clampf(result.y, minimum_position.y, maximum_position.y)
	return result


func _smoothing_weight(speed: float, delta: float) -> float:
	if speed <= 0.0:
		return 1.0
	return 1.0 - exp(-speed * delta)


func _validate_settings() -> void:
	world_bounds = world_bounds.abs()
	minimum_zoom = maxf(minimum_zoom, 0.1)
	maximum_zoom = maxf(maximum_zoom, minimum_zoom)
	zoom_step = maxf(zoom_step, 0.01)
	edge_margin = maxf(edge_margin, 0.0)
