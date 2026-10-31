class_name ClassicMinimap
extends Control

var board: ClassicBoard
var _dragging: bool = false


func _ready() -> void:
	custom_minimum_size = Vector2(176, 104)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _process(_delta: float) -> void:
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if board == null or board.paused:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if _dragging:
			_move_camera(event.position)
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_move_camera(event.position)
		accept_event()


func _move_camera(point: Vector2) -> void:
	board.set_camera((point - Vector2(size.x * 0.5, 12)) / _scale())


func _scale() -> float:
	return minf((size.x - 16) / 1536.0, (size.y - 24) / 768.0)


func _point(world: Vector2) -> Vector2:
	return world * _scale() + Vector2(size.x * 0.5, 12)


func _draw() -> void:
	draw_style_box(_panel(), Rect2(Vector2.ZERO, size))
	if board == null or board.simulation == null:
		return
	var diamond: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in [Vector2.ZERO, Vector2(768, 384), Vector2(0, 768), Vector2(-768, 384)]:
		diamond.append(_point(point))
	draw_colored_polygon(diamond, Color("393939"))
	if board.simulation.medieval:
		for area: Dictionary in board.simulation.areas:
			if area.kind == ClassicRules.AreaKind.BASE:
				var base_center: Vector2 = ClassicRules.cell_to_world(Vector2(area.tile * 4) + Vector2(1.5, 1.5))
				draw_rect(Rect2(_point(base_center) - Vector2(3, 3), Vector2(6, 6)), ClassicRules.COLORS[area.owner])
	for student: ClassicStudent in board.simulation.students:
		if student.is_alive():
			draw_rect(Rect2(_point(student.world_position()) - Vector2.ONE, Vector2(3, 3)), ClassicRules.COLORS[student.team].lightened(0.2))
	var half_view: Vector2 = board.size * 0.5 / board.view_zoom
	var view: Rect2 = Rect2(_point(board.camera_center - half_view), half_view * 2 * _scale())
	draw_rect(view.intersection(Rect2(Vector2(4, 4), size - Vector2(8, 8))), Color("8bd666"), false, 1)


func _panel() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.04, 0.92)
	style.set_corner_radius_all(5)
	return style
