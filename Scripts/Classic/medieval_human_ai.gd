extends RefCounted

## Individual low-health retreat, shared by all AI difficulties.
const TRAVEL_LIMIT: int = 20 * ClassicRules.TICKS_PER_SECOND
const COOLDOWN: int = 20 * ClassicRules.TICKS_PER_SECOND

func controls(unit: ClassicStudent) -> bool:
	return unit.team == 0 and unit.ai_regroup_started_at >= 0

func is_recovering(unit: ClassicStudent) -> bool:
	return controls(unit)

func _nearest(sim, unit: ClassicStudent) -> ClassicStudent:
	var result: ClassicStudent = null
	var best: int = 21
	for ally: ClassicStudent in sim.students:
		if ally == unit or not ally.is_alive() or ally.team != 0:
			continue
		var distance: int = absi(ally.cell.x - unit.cell.x) + absi(ally.cell.y - unit.cell.y)
		if distance < best:
			best = distance
			result = ally
	return result

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
	var ally: ClassicStudent = _nearest(sim, unit)
	if ally != null:
		unit.ai_regroup_target_id = ally.id
		unit.ai_regroup_target_life = ally.lifetime
		return Vector2i(ally.cell.x / 4, ally.cell.y / 4)
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

func update(sim) -> void:
	if not sim.medieval or not sim.ai_enabled or sim.player_team == 0:
		return
	for unit: ClassicStudent in sim.students:
		if not unit.is_alive() or unit.team != 0:
			continue
		if not controls(unit):
			if unit.health >= unit.maximum_health * 0.3 or sim.ticks < unit.ai_heal_ready_at:
				continue
			# Retreat replaces strategic orders; subsequent melee retaliation can interrupt.
			sim.retaliation_ai.responses.erase(unit.id)
			sim.proximity_ai.engagements.erase(unit.id)
			sim.ranged_response._prepare(unit)
			unit.ranged_response_id = -1
			unit.ranged_pursuit_id = -1
			unit.priority_target_id = -1
			unit.target_id = -1
			unit.ai_regroup_started_at = sim.ticks
			unit.ai_regroup_replan_at = sim.ticks
			unit.ai_retreating = true
		if sim.ticks - unit.ai_regroup_started_at >= TRAVEL_LIMIT:
			if sim.retaliation_ai.active(unit):
				sim.retaliation_ai.responses[unit.id].retreat = false
			_finish(sim, unit)
			continue
		if sim.retaliation_ai.active(unit):
			continue # Melee retaliation retains its existing priority.
		if sim.ticks >= unit.ai_regroup_replan_at:
			unit.designated_tile = _destination(sim, unit)
			unit.ai_regroup_replan_at = sim.ticks + ClassicRules.TICKS_PER_SECOND
		var goal: Vector2i = unit.designated_tile
		if Vector2i(unit.cell.x / 4, unit.cell.y / 4) == goal and unit.state != ClassicStudent.State.WALK:
			_finish(sim, unit)
			continue
		unit.designated_tile = goal
		unit.tile_guard_active = false
		unit.ai_retreating = true
		unit.destination = goal * 4 + Vector2i(1, 1)
		if unit.state not in [ClassicStudent.State.WALK, ClassicStudent.State.WAIT]:
			unit.state = ClassicStudent.State.STAND
			sim.start_walk(unit, goal)
