class_name TerritoryField
extends Node2D

@export var territory_scene: PackedScene
@export_range(1, 40, 1) var territory_count: int = 12
@export var generation_seed: int = 0
@export var field_center: Vector2 = Vector2(800.0, 800.0)
@export var field_half_span: float = 570.0
@export var minimum_tile_spacing: float = 155.0
@export var base_clearance: float = 170.0


func _ready() -> void:
	generate_territories()


func generate_territories() -> void:
	for child: Node in get_children():
		child.queue_free()
	if territory_scene == null:
		push_error("%s requires a territory scene." % name)
		return

	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	if generation_seed == 0:
		random.randomize()
	else:
		random.seed = generation_seed

	var positions: Array[Vector2] = []
	var base_positions: Array[Vector2] = []
	for node: Node in get_tree().get_nodes_in_group(TeamSpawnPoint.SPAWN_POINT_GROUP):
		var spawn_point: TeamSpawnPoint = node as TeamSpawnPoint
		if spawn_point != null:
			base_positions.append(spawn_point.global_position)

	var attempts: int = 0
	while positions.size() < territory_count and attempts < territory_count * 100:
		attempts += 1
		var offset: Vector2 = Vector2(
			random.randf_range(-field_half_span, field_half_span),
			random.randf_range(-field_half_span, field_half_span)
		)
		if absf(offset.x) + absf(offset.y) > field_half_span:
			continue
		var candidate: Vector2 = field_center + offset
		if not _is_clear(candidate, positions, minimum_tile_spacing):
			continue
		if not _is_clear(candidate, base_positions, base_clearance):
			continue
		positions.append(candidate)

	for territory_position: Vector2 in positions:
		var territory: TerritoryTile = territory_scene.instantiate() as TerritoryTile
		territory.position = to_local(territory_position)
		add_child(territory)


func _is_clear(candidate: Vector2, positions: Array[Vector2], clearance: float) -> bool:
	for position: Vector2 in positions:
		if candidate.distance_to(position) < clearance:
			return false
	return true
