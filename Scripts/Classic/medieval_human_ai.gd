extends RefCounted

## Individual low-health retreat, shared by all AI difficulties.
const COOLDOWN: int = 20 * ClassicRules.TICKS_PER_SECOND

func controls(unit: ClassicStudent) -> bool:
	return unit.team == 0 and unit.ai_regroup_started_at >= 0

func is_recovering(unit: ClassicStudent) -> bool:
	return controls(unit)

func _destination(sim, unit: ClassicStudent) -> Vector2i:
	unit.ai_regroup_target_id = -1
	unit.ai_regroup_target_life = -1
	var goal := Vector2i(-1, -1)
	var best: int = 21
	for area: Dictionary in sim.areas:
		if area.owner != 0 or area.kind == ClassicRules.AreaKind.RECRUIT:
			continue
		var corner: Vector2i = area.tile * 4
		var nearest := Vector2i(clampi(unit.cell.x, corner.x, corner.x + 3), clampi(unit.cell.y, corner.y, corner.y + 3))
		var distance: int = absi(nearest.x - unit.cell.x) + absi(nearest.y - unit.cell.y)
		if distance < best:
			best = distance
			goal = area.tile
	if goal.x >= 0:
		return goal
	# Prefer the nearest owned base; the original home remains a last resort.
	best = 100000
	goal = sim.bases[0]
	for tile: Vector2i in sim.get_spawn_bases(0):
		var distance: int = absi(tile.x * 4 + 1 - unit.cell.x) + absi(tile.y * 4 + 1 - unit.cell.y)
		if distance < best:
			best = distance
			goal = tile
	return goal

func _finish(sim, unit: ClassicStudent) -> void:
	unit.ai_regroup_started_at = -1
	unit.ai_regroup_target_id = -1
	unit.ai_regroup_target_life = -1
	unit.ai_retreating = false
	unit.ai_heal_ready_at = sim.ticks + COOLDOWN
	# Complete the reserved movement step before accepting ordinary orders.
	unit.designated_tile = Vector2i(unit.cell.x / 4, unit.cell.y / 4)
	unit.destination = unit.cell
	unit.tile_guard_active = true
	unit.idle_ticks = sim.AI_START_DELAY_TICKS
	if unit.state != ClassicStudent.State.WALK:
		sim._start_stand(unit)

func _valid_healing_tile(sim, tile: Vector2i) -> bool:
	return sim.area_at.has(tile) and sim.areas[sim.area_at[tile]].owner == 0 and sim.areas[sim.area_at[tile]].kind != ClassicRules.AreaKind.RECRUIT

func _begin(sim, unit: ClassicStudent, goal: Vector2i) -> void:
	sim.proximity_ai.engagements.erase(unit.id)
	# Shared retaliation retains priority, including if capture and an attack
	# happen in the same tick. Its release must resume this healing destination.
	if sim.retaliation_ai.active(unit):
		var response: Dictionary = sim.retaliation_ai.responses[unit.id]
		response.goal = goal
		response.retreat = true
		response.proximity = {}
	else:
		sim.ranged_response._prepare(unit)
		unit.priority_target_id = -1
		unit.target_id = -1
	unit.ai_regroup_started_at = sim.ticks
	unit.ai_heal_tile = goal
	unit.designated_tile = goal
	unit.tile_guard_active = false
	unit.tile_order_busy = false
	unit.returning_to_tile = false
	unit.ai_retreating = not sim.retaliation_ai.active(unit)

func hold_captured_heart(sim, tile: Vector2i) -> void:
	if not sim.ai_enabled or sim.player_team == 0:
		return
	for unit: ClassicStudent in sim.students:
		if unit.is_alive() and unit.team == 0 and unit.health < unit.maximum_health and Vector2i(unit.cell.x / 4, unit.cell.y / 4) == tile:
			_begin(sim, unit, tile)

func update(sim) -> void:
	if not sim.medieval or not sim.ai_enabled or sim.player_team == 0:
		return
	for unit: ClassicStudent in sim.students:
		if not unit.is_alive() or unit.team != 0:
			continue
		if not controls(unit):
			if unit.health >= unit.maximum_health * 0.3 or sim.ticks < unit.ai_heal_ready_at:
				continue
			_begin(sim, unit, _destination(sim, unit))
		if sim.retaliation_ai.active(unit):
			continue
		if unit.health >= unit.maximum_health:
			_finish(sim, unit)
			unit.ai_heal_tile = Vector2i(-1, -1)
			continue
		if not _valid_healing_tile(sim, unit.ai_heal_tile):
			unit.ai_heal_tile = _destination(sim, unit)
		var goal: Vector2i = unit.ai_heal_tile
		unit.designated_tile = goal
		unit.tile_guard_active = false
		if Vector2i(unit.cell.x / 4, unit.cell.y / 4) == goal and unit.state != ClassicStudent.State.WALK and _valid_healing_tile(sim, goal):
			unit.ai_retreating = false
			unit.target_id = -1
			unit.priority_target_id = -1
			unit.state = ClassicStudent.State.SIT
			unit.pattern = 13
			unit.counter = 40
			continue
		unit.ai_retreating = true
		unit.destination = goal * 4 + Vector2i(1, 1)
		if unit.state not in [ClassicStudent.State.WALK, ClassicStudent.State.WAIT]:
			unit.state = ClassicStudent.State.STAND
			sim.start_walk(unit, goal)
