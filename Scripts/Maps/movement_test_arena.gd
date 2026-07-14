class_name FourSquareArena
extends Node2D

const MAP_BOUNDS: Rect2 = Rect2(40.0, 40.0, 1520.0, 1520.0)
const CAMERA_BOUNDS: Rect2 = Rect2(-120.0, -120.0, 1840.0, 1840.0)
const GRID_SIZE: float = 40.0
const PLATFORM_DEPTH: Vector2 = Vector2(28.0, 32.0)
const PLATFORM_SHADOW_OFFSET: Vector2 = Vector2(48.0, 58.0)
const QUADRANT_COLORS: Array[Color] = [
	Color("20242f"),
	Color("1f3a32"),
	Color("4a4022"),
	Color("372b4c"),
]
const CARDINAL_SIDE_NAMES: Array[String] = ["North", "South", "East", "West"]


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	var center: Vector2 = MAP_BOUNDS.get_center()
	var quadrants: Array[Rect2] = get_quadrant_bounds()
	draw_rect(
		Rect2(MAP_BOUNDS.position + PLATFORM_SHADOW_OFFSET, MAP_BOUNDS.size),
		Color(0.01, 0.025, 0.055, 0.42),
		true
	)
	_draw_platform_depth()
	for index: int in quadrants.size():
		draw_rect(quadrants[index], QUADRANT_COLORS[index], true)

	var grid_color: Color = Color(0.32, 0.43, 0.61, 0.22)
	var x: float = MAP_BOUNDS.position.x + GRID_SIZE
	while x < MAP_BOUNDS.end.x:
		draw_line(
			Vector2(x, MAP_BOUNDS.position.y),
			Vector2(x, MAP_BOUNDS.end.y),
			grid_color
		)
		x += GRID_SIZE

	var y: float = MAP_BOUNDS.position.y + GRID_SIZE
	while y < MAP_BOUNDS.end.y:
		draw_line(
			Vector2(MAP_BOUNDS.position.x, y),
			Vector2(MAP_BOUNDS.end.x, y),
			grid_color
		)
		y += GRID_SIZE

	var divider_color: Color = Color(0.52, 0.62, 0.78, 0.7)
	draw_line(
		Vector2(center.x, MAP_BOUNDS.position.y),
		Vector2(center.x, MAP_BOUNDS.end.y),
		divider_color,
		4.0
	)
	draw_line(
		Vector2(MAP_BOUNDS.position.x, center.y),
		Vector2(MAP_BOUNDS.end.x, center.y),
		divider_color,
		4.0
	)
	draw_rect(MAP_BOUNDS, Color("7f93b3"), false, 5.0)
	_draw_side_label("NORTH", Vector2(center.x, MAP_BOUNDS.position.y + 34.0))
	_draw_side_label("SOUTH", Vector2(center.x, MAP_BOUNDS.end.y - 34.0))
	_draw_side_label("WEST", Vector2(MAP_BOUNDS.position.x + 72.0, center.y))
	_draw_side_label("EAST", Vector2(MAP_BOUNDS.end.x - 72.0, center.y))


func get_map_bounds() -> Rect2:
	return MAP_BOUNDS


func get_camera_bounds() -> Rect2:
	return CAMERA_BOUNDS


func get_quadrant_bounds() -> Array[Rect2]:
	var half_size: Vector2 = MAP_BOUNDS.size * 0.5
	var center: Vector2 = MAP_BOUNDS.get_center()
	return [
		Rect2(MAP_BOUNDS.position, half_size),
		Rect2(Vector2(center.x, MAP_BOUNDS.position.y), half_size),
		Rect2(Vector2(MAP_BOUNDS.position.x, center.y), half_size),
		Rect2(center, half_size),
	]


func get_cardinal_side_names() -> Array[String]:
	return CARDINAL_SIDE_NAMES.duplicate()


func _draw_side_label(label_text: String, center: Vector2) -> void:
	const LABEL_WIDTH: float = 144.0
	draw_string(
		ThemeDB.fallback_font,
		center + Vector2(-LABEL_WIDTH * 0.5, 8.0),
		label_text,
		HORIZONTAL_ALIGNMENT_CENTER,
		LABEL_WIDTH,
		22,
		Color("dce7fa")
	)


func _draw_platform_depth() -> void:
	var top_right: Vector2 = Vector2(MAP_BOUNDS.end.x, MAP_BOUNDS.position.y)
	var bottom_left: Vector2 = Vector2(MAP_BOUNDS.position.x, MAP_BOUNDS.end.y)
	var bottom_right: Vector2 = MAP_BOUNDS.end
	draw_colored_polygon(
		PackedVector2Array([
			bottom_left,
			bottom_right,
			bottom_right + PLATFORM_DEPTH,
			bottom_left + PLATFORM_DEPTH,
		]),
		Color("151d2d")
	)
	draw_colored_polygon(
		PackedVector2Array([
			top_right,
			bottom_right,
			bottom_right + PLATFORM_DEPTH,
			top_right + PLATFORM_DEPTH,
		]),
		Color("101725")
	)
