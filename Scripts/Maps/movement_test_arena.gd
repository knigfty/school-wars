class_name FourSquareArena
extends Node2D

const MAP_CENTER: Vector2 = Vector2(800.0, 800.0)
const MAP_HALF_SPAN: float = 720.0
const MAP_BOUNDS: Rect2 = Rect2(80.0, 80.0, 1440.0, 1440.0)
const CAMERA_BOUNDS: Rect2 = Rect2(-120.0, -120.0, 1840.0, 1840.0)
const PLATFORM_DEPTH: Vector2 = Vector2(0.0, 42.0)
const PLATFORM_SHADOW_OFFSET: Vector2 = Vector2(34.0, 70.0)
const CARDINAL_SIDE_NAMES: Array[String] = ["North", "South", "East", "West"]


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	var points: PackedVector2Array = get_map_polygon()
	var shadow_points: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in points:
		shadow_points.append(point + PLATFORM_SHADOW_OFFSET)
	draw_colored_polygon(shadow_points, Color(0.01, 0.025, 0.055, 0.48))
	_draw_platform_depth(points)
	draw_colored_polygon(points, Color("c8c9c8"))
	_draw_platform_grid()

	var outline: PackedVector2Array = points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, Color("2f3338"), 4.0, true)
	_draw_side_label("NORTH", Vector2(MAP_CENTER.x, 44.0))
	_draw_side_label("SOUTH", Vector2(MAP_CENTER.x, 1570.0))
	_draw_side_label("WEST", Vector2(44.0, MAP_CENTER.y))
	_draw_side_label("EAST", Vector2(1556.0, MAP_CENTER.y))


func get_map_polygon() -> PackedVector2Array:
	return PackedVector2Array([
		MAP_CENTER + Vector2(0.0, -MAP_HALF_SPAN),
		MAP_CENTER + Vector2(MAP_HALF_SPAN, 0.0),
		MAP_CENTER + Vector2(0.0, MAP_HALF_SPAN),
		MAP_CENTER + Vector2(-MAP_HALF_SPAN, 0.0),
	])


func contains_world_point(world_point: Vector2) -> bool:
	var offset: Vector2 = world_point - MAP_CENTER
	return absf(offset.x) + absf(offset.y) <= MAP_HALF_SPAN


func get_map_bounds() -> Rect2:
	return MAP_BOUNDS


func get_camera_bounds() -> Rect2:
	return CAMERA_BOUNDS


func get_cardinal_side_names() -> Array[String]:
	return CARDINAL_SIDE_NAMES.duplicate()


func _draw_platform_grid() -> void:
	var grid_color: Color = Color(0.35, 0.37, 0.39, 0.09)
	var offset: float = -MAP_HALF_SPAN + 90.0
	while offset < MAP_HALF_SPAN:
		var half_width: float = MAP_HALF_SPAN - absf(offset)
		draw_line(
			MAP_CENTER + Vector2(-half_width, offset),
			MAP_CENTER + Vector2(half_width, offset),
			grid_color,
			1.0
		)
		draw_line(
			MAP_CENTER + Vector2(offset, -half_width),
			MAP_CENTER + Vector2(offset, half_width),
			grid_color,
			1.0
		)
		offset += 90.0


func _draw_side_label(label_text: String, center: Vector2) -> void:
	const LABEL_WIDTH: float = 144.0
	draw_string(
		ThemeDB.fallback_font,
		center + Vector2(-LABEL_WIDTH * 0.5, 8.0),
		label_text,
		HORIZONTAL_ALIGNMENT_CENTER,
		LABEL_WIDTH,
		22,
		Color("e8edf5")
	)


func _draw_platform_depth(points: PackedVector2Array) -> void:
	var east: Vector2 = points[1]
	var south: Vector2 = points[2]
	var west: Vector2 = points[3]
	draw_colored_polygon(
		PackedVector2Array([
			west,
			south,
			south + PLATFORM_DEPTH,
			west + PLATFORM_DEPTH,
		]),
		Color("585d63")
	)
	draw_colored_polygon(
		PackedVector2Array([
			south,
			east,
			east + PLATFORM_DEPTH,
			south + PLATFORM_DEPTH,
		]),
		Color("454a50")
	)
