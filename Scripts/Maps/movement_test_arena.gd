class_name FourSquareArena
extends Node2D

const MAP_CENTER: Vector2 = Vector2(800.0, 800.0)
const MAP_HALF_SPAN: float = 720.0
const MAP_BOUNDS: Rect2 = Rect2(80.0, 80.0, 1440.0, 1440.0)
const CAMERA_BOUNDS: Rect2 = Rect2(-120.0, -120.0, 1840.0, 1840.0)
const PLATFORM_DEPTH: Vector2 = Vector2(0.0, 52.0)
const PLATFORM_SHADOW_OFFSET: Vector2 = Vector2(28.0, 70.0)
const CARDINAL_SIDE_NAMES: Array[String] = ["North", "South", "East", "West"]


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	var points: PackedVector2Array = get_map_polygon()
	var shadow_points: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in points:
		shadow_points.append(point + PLATFORM_SHADOW_OFFSET)
	draw_colored_polygon(shadow_points, Color(0.01, 0.02, 0.055, 0.32))
	_draw_platform_depth(points)
	draw_colored_polygon(points, Color("e8e9e7"))
	_draw_surface_highlights(points)

	var outline: PackedVector2Array = points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, Color("c9ccca"), 3.0, true)


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


func _draw_surface_highlights(points: PackedVector2Array) -> void:
	var north: Vector2 = points[0]
	var east: Vector2 = points[1]
	var west: Vector2 = points[3]
	var inset: float = 12.0
	draw_colored_polygon(
		PackedVector2Array([
			north,
			east,
			east + Vector2(-inset, 0.0),
			north + Vector2(0.0, inset),
		]),
		Color("d9dbd9")
	)
	draw_colored_polygon(
		PackedVector2Array([
			west,
			north,
			north + Vector2(0.0, inset),
			west + Vector2(inset, 0.0),
		]),
		Color("f7f7f5")
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
		Color("a9acab")
	)
	draw_colored_polygon(
		PackedVector2Array([
			south,
			east,
			east + PLATFORM_DEPTH,
			south + PLATFORM_DEPTH,
		]),
		Color("8f9393")
	)
	draw_line(
		west + PLATFORM_DEPTH,
		south + PLATFORM_DEPTH,
		Color("707575"),
		4.0,
		true
	)
	draw_line(
		south + PLATFORM_DEPTH,
		east + PLATFORM_DEPTH,
		Color("656a6b"),
		4.0,
		true
	)
