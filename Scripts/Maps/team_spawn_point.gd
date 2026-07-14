class_name TeamSpawnPoint
extends Marker2D

const SPAWN_POINT_GROUP: StringName = &"team_spawn_points"

@export var team: TeamDefinition
@export var direction_name: String = "North"
@export var marker_size: Vector2 = Vector2(150.0, 76.0)


func _ready() -> void:
	add_to_group(SPAWN_POINT_GROUP)
	queue_redraw()


func _draw() -> void:
	if team == null:
		return
	var points: PackedVector2Array = _get_diamond_points()
	draw_colored_polygon(points, team.color.darkened(0.42))
	var outline: PackedVector2Array = points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, team.color.lightened(0.38), 4.0)
	draw_circle(Vector2.ZERO, 13.0, team.color.lightened(0.18))
	draw_string(
		ThemeDB.fallback_font,
		Vector2(-marker_size.x * 0.5, marker_size.y * 0.5 + 24.0),
		"%s · %s" % [team.display_name.to_upper(), direction_name.to_upper()],
		HORIZONTAL_ALIGNMENT_CENTER,
		marker_size.x,
		18,
		team.color.lightened(0.45)
	)


func contains_world_point(world_point: Vector2) -> bool:
	var local_point: Vector2 = to_local(world_point)
	return (
		absf(local_point.x) / (marker_size.x * 0.5)
		+ absf(local_point.y) / (marker_size.y * 0.5)
	) <= 1.0


func get_spawn_position(spawn_index: int) -> Vector2:
	const OFFSETS: Array[Vector2] = [
		Vector2.ZERO,
		Vector2(-28.0, 0.0),
		Vector2(28.0, 0.0),
		Vector2(0.0, -17.0),
		Vector2(0.0, 17.0),
	]
	return global_position + OFFSETS[spawn_index % OFFSETS.size()]


func _get_diamond_points() -> PackedVector2Array:
	var half_size: Vector2 = marker_size * 0.5
	return PackedVector2Array([
		Vector2(0.0, -half_size.y),
		Vector2(half_size.x, 0.0),
		Vector2(0.0, half_size.y),
		Vector2(-half_size.x, 0.0),
	])
