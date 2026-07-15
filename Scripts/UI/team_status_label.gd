class_name TeamStatusLabel
extends Label

@export var spawner_path: NodePath
@export_range(0.1, 5.0, 0.1) var refresh_interval: float = 0.5

var _elapsed: float = 0.0


func _ready() -> void:
	_refresh()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < refresh_interval:
		return
	_elapsed = 0.0
	_refresh()


func _refresh() -> void:
	var spawner: TeamReinforcementSpawner = get_node_or_null(
		spawner_path
	) as TeamReinforcementSpawner
	if spawner == null:
		text = "Unit counts unavailable"
		return
	var entries: PackedStringArray = PackedStringArray()
	for node: Node in get_tree().get_nodes_in_group(TeamSpawnPoint.SPAWN_POINT_GROUP):
		var spawn_point: TeamSpawnPoint = node as TeamSpawnPoint
		if spawn_point == null or spawn_point.team == null:
			continue
		var team_id: StringName = spawn_point.team.team_id
		entries.append(
			"%s: %d" % [
				spawn_point.team.display_name,
				spawner.get_student_count(team_id),
			]
		)
	text = " · ".join(entries)
