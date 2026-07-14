class_name UnitCommandController
extends Node

@export var selection_controller_path: NodePath
@export_range(24.0, 128.0, 1.0) var formation_spacing: float = 48.0

var _selection_controller: UnitSelectionController


func _ready() -> void:
	_selection_controller = get_node_or_null(
		selection_controller_path
	) as UnitSelectionController
	if _selection_controller == null:
		push_error("%s requires a UnitSelectionController." % name)
		return

	_selection_controller.move_order_requested.connect(_on_move_order_requested)
	_selection_controller.attack_order_requested.connect(_on_attack_order_requested)
	_selection_controller.territory_order_requested.connect(_on_territory_order_requested)


func issue_move_order(
	selected_units: Array[SelectableComponent],
	world_destination: Vector2
) -> void:
	if selected_units.is_empty():
		return

	var column_count: int = ceili(sqrt(float(selected_units.size())))
	var row_count: int = ceili(float(selected_units.size()) / float(column_count))

	for index in selected_units.size():
		var column: int = index % column_count
		var row: int = floori(float(index) / float(column_count))
		var row_start: int = row * column_count
		var units_in_row: int = mini(
			column_count,
			selected_units.size() - row_start
		)
		var formation_offset := Vector2(
			(float(column) - float(units_in_row - 1) * 0.5) * formation_spacing,
			(float(row) - float(row_count - 1) * 0.5) * formation_spacing
		)
		_issue_unit_order(selected_units[index], world_destination + formation_offset)


func issue_attack_order(
	selected_units: Array[SelectableComponent],
	target: StudentController
) -> void:
	for selectable: SelectableComponent in selected_units:
		var student: StudentController = selectable.get_student()
		if student == null or not student.is_enemy(target):
			continue
		var move_order: StudentMoveOrderComponent = student.get_node_or_null(
			"MoveOrder"
		) as StudentMoveOrderComponent
		if move_order != null:
			move_order.cancel_order()
		student.set_attack_target(target)


func issue_territory_order(
	selected_units: Array[SelectableComponent],
	territory: TerritoryTile
) -> void:
	if territory == null:
		return
	issue_move_order(selected_units, territory.global_position)


func _on_move_order_requested(
	selected_units: Array[SelectableComponent],
	world_destination: Vector2
) -> void:
	issue_move_order(selected_units, world_destination)


func _on_attack_order_requested(
	selected_units: Array[SelectableComponent],
	target: StudentController
) -> void:
	issue_attack_order(selected_units, target)


func _on_territory_order_requested(
	selected_units: Array[SelectableComponent],
	territory: TerritoryTile
) -> void:
	issue_territory_order(selected_units, territory)


func _issue_unit_order(
	selectable: SelectableComponent,
	world_destination: Vector2
) -> void:
	var student: StudentController = selectable.get_parent() as StudentController
	if student == null:
		return
	student.clear_attack_target()

	var move_order: StudentMoveOrderComponent = student.get_node_or_null(
		"MoveOrder"
	) as StudentMoveOrderComponent
	if move_order == null:
		push_warning("%s has no StudentMoveOrderComponent." % student.name)
		return
	move_order.set_destination(world_destination)
