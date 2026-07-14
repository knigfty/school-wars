class_name UnitSelectionController
extends Control

signal selection_changed(selected_units: Array[SelectableComponent])
signal move_order_requested(
	selected_units: Array[SelectableComponent],
	world_destination: Vector2
)
signal attack_order_requested(
	selected_units: Array[SelectableComponent],
	target: StudentController
)
signal territory_order_requested(
	selected_units: Array[SelectableComponent],
	territory: TerritoryTile
)

@export_range(0.0, 32.0, 1.0) var drag_threshold: float = 6.0
@export_range(1.0, 64.0, 1.0) var click_radius: float = 18.0
@export var marquee_fill_color: Color = Color(0.22, 0.72, 1.0, 0.18)
@export var marquee_border_color: Color = Color(0.42, 0.85, 1.0, 0.95)
@export var player_team_id: StringName = &""

var _dragging: bool = false
var _drag_start: Vector2 = Vector2.ZERO
var _drag_current: Vector2 = Vector2.ZERO
var _selected_units: Array[SelectableComponent] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _input(event: InputEvent) -> void:
	if not _dragging:
		return

	if event is InputEventMouseMotion:
		_drag_current = event.position
		queue_redraw()
		get_viewport().set_input_as_handled()
	elif (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and not event.pressed
	):
		_finish_selection(event.position)
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
	):
		_begin_selection(event.position)
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_EXIT and _dragging:
		_cancel_drag()


func select_in_screen_rect(screen_rect: Rect2) -> void:
	var normalized_rect: Rect2 = screen_rect.abs()
	var next_selection: Array[SelectableComponent] = []
	var selection_team_id: StringName = &""
	for selectable in _get_selectable_units():
		if not normalized_rect.has_point(selectable.get_screen_position()):
			continue
		var student: StudentController = selectable.get_student()
		if student == null:
			continue
		if selection_team_id.is_empty():
			selection_team_id = student.get_team_id()
		if student.get_team_id() == selection_team_id:
			next_selection.append(selectable)
	_set_selection(next_selection)


func configure_player_team(team_id: StringName) -> void:
	player_team_id = team_id
	_set_selection([])


func get_selected_units() -> Array[SelectableComponent]:
	return _selected_units


func _draw() -> void:
	if not _dragging or _drag_start.distance_to(_drag_current) < drag_threshold:
		return

	var marquee: Rect2 = Rect2(_drag_start, _drag_current - _drag_start).abs()
	draw_rect(marquee, marquee_fill_color, true)
	draw_rect(marquee, marquee_border_color, false, 2.0)


func _begin_selection(screen_position: Vector2) -> void:
	_dragging = true
	_drag_start = screen_position
	_drag_current = screen_position
	queue_redraw()


func _finish_selection(screen_position: Vector2) -> void:
	_drag_current = screen_position
	if _drag_start.distance_to(_drag_current) < drag_threshold:
		_handle_click(_drag_current)
	else:
		var selection_rect: Rect2 = Rect2(
			_drag_start,
			_drag_current - _drag_start
		).abs()
		select_in_screen_rect(selection_rect)

	_dragging = false
	queue_redraw()


func _cancel_drag() -> void:
	_dragging = false
	queue_redraw()


func _handle_click(screen_position: Vector2) -> void:
	var clicked_unit: SelectableComponent = _find_closest_selectable(screen_position)
	if clicked_unit != null:
		var clicked_student: StudentController = clicked_unit.get_student()
		if _is_enemy_of_selection(clicked_student):
			attack_order_requested.emit(_selected_units, clicked_student)
			return
		if not _can_select_student(clicked_student):
			return
		var clicked_selection: Array[SelectableComponent] = [clicked_unit]
		_set_selection(clicked_selection)
		return

	if _selected_units.is_empty():
		_set_selection([])
		return

	var world_destination: Vector2 = (
		get_viewport().get_canvas_transform().affine_inverse() * screen_position
	)
	var territory: TerritoryTile = _find_territory(world_destination)
	if territory != null:
		territory_order_requested.emit(_selected_units, territory)
		return
	move_order_requested.emit(_selected_units, world_destination)


func _is_enemy_of_selection(target: StudentController) -> bool:
	if target == null or _selected_units.is_empty():
		return false
	var leader: StudentController = _selected_units[0].get_student()
	return leader != null and leader.is_enemy(target)


func _find_territory(world_position: Vector2) -> TerritoryTile:
	for node: Node in get_tree().get_nodes_in_group(TerritoryTile.TERRITORY_GROUP):
		var territory: TerritoryTile = node as TerritoryTile
		if territory != null and territory.contains_world_point(world_position):
			return territory
	return null


func _find_closest_selectable(screen_position: Vector2) -> SelectableComponent:
	var closest: SelectableComponent
	var closest_distance: float = click_radius
	for selectable in _get_all_selectable_units():
		var distance: float = screen_position.distance_to(selectable.get_screen_position())
		if distance <= closest_distance:
			closest = selectable
			closest_distance = distance
	return closest


func _get_selectable_units() -> Array[SelectableComponent]:
	var selectables: Array[SelectableComponent] = []
	for selectable: SelectableComponent in _get_all_selectable_units():
		if _can_select_student(selectable.get_student()):
			selectables.append(selectable)
	return selectables


func _get_all_selectable_units() -> Array[SelectableComponent]:
	var selectables: Array[SelectableComponent] = []
	var selectable_nodes: Array[Node] = get_tree().get_nodes_in_group(
		SelectableComponent.SELECTABLE_GROUP
	)
	for node in selectable_nodes:
		var selectable: SelectableComponent = node as SelectableComponent
		if selectable != null:
			selectables.append(selectable)
	return selectables


func _can_select_student(student: StudentController) -> bool:
	return (
		student != null
		and (player_team_id.is_empty() or student.get_team_id() == player_team_id)
	)


func _set_selection(next_selection: Array[SelectableComponent]) -> void:
	for selectable in _get_all_selectable_units():
		selectable.set_selected(selectable in next_selection)
	_selected_units = next_selection
	selection_changed.emit(_selected_units)
