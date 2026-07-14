class_name TeamSpawnPoint
extends Marker2D

const SPAWN_POINT_GROUP: StringName = &"team_spawn_points"

@export var team_name: StringName = &"Team"
@export var team_color: Color = Color.WHITE
@export_range(64.0, 240.0, 1.0) var marker_size: float = 128.0


func _ready() -> void:
	add_to_group(SPAWN_POINT_GROUP)
	queue_redraw()


func _draw() -> void:
	var half_size: float = marker_size * 0.5
	var marker_rect: Rect2 = Rect2(
		Vector2(-half_size, -half_size),
		Vector2.ONE * marker_size
	)
	draw_rect(marker_rect, team_color.darkened(0.55), true)
	draw_rect(marker_rect, team_color.lightened(0.35), false, 5.0)
	draw_circle(Vector2.ZERO, 14.0, team_color.lightened(0.2))
	draw_string(
		ThemeDB.fallback_font,
		Vector2(-half_size, half_size + 26.0),
		String(team_name).to_upper(),
		HORIZONTAL_ALIGNMENT_CENTER,
		marker_size,
		18,
		team_color.lightened(0.45)
	)
