extends RefCounted

## Individual low-health regrouping, shared by all AI difficulties.
const TRAVEL_LIMIT: int = 20 * ClassicRules.TICKS_PER_SECOND
const COOLDOWN: int = 20 * ClassicRules.TICKS_PER_SECOND

func controls(unit: ClassicStudent) -> bool:
	return unit.team == 0 and unit.ai_regroup_started_at >= 0

func is_recovering(unit: ClassicStudent) -> bool:
	return controls(unit)

func _nearest(sim, unit: ClassicStudent) -> ClassicStudent:
	var result: ClassicStudent = null
	var best: int = 100000
	for ally: ClassicStudent in sim.students:
		if ally == unit or not ally.is_alive() or ally.team != 0:
			continue
		var distance: int = absi(ally.cell.x - unit.cell.x) + absi(ally.cell.y - unit.cell.y)
		if distance < best:
			best = distance
			result = ally
	return result

func _has_company(sim, unit: ClassicStudent) -> bool:
	var corner := Vector2i(unit.cell.x / 4, unit.cell.y / 4) * 4
	for y: int in 4:
		for x: int in 4:
			var id: int = int(sim.occupancy.get(corner + Vector2i(x,y), -1))
			if id >= 0 and id < sim.students.size():
				var ally: ClassicStudent = sim.students[id]
				if ally != unit and ally.team == 0 and ally.is_alive():
					return true
	return false

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
			if unit.health >= unit.maximum_health * 0.5 or sim.ticks < unit.ai_heal_ready_at:
				continue
			# Regrouping replaces the old group healing/conquest decision.
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
		if unit.state != ClassicStudent.State.WALK and _has_company(sim, unit):
			_finish(sim, unit)
			continue
		var ally: ClassicStudent = null
		if unit.ai_regroup_target_id >= 0 and unit.ai_regroup_target_id < sim.students.size():
			ally = sim.students[unit.ai_regroup_target_id]
			if not ally.is_alive() or ally.team != 0 or ally.lifetime != unit.ai_regroup_target_life:
				ally = null
		if ally == null or sim.ticks >= unit.ai_regroup_replan_at:
			ally = _nearest(sim, unit)
			unit.ai_regroup_replan_at = sim.ticks + ClassicRules.TICKS_PER_SECOND
			unit.ai_regroup_target_id = ally.id if ally != null else -1
			unit.ai_regroup_target_life = ally.lifetime if ally != null else -1
		if ally == null:
			# A lone survivor waits out the deadline without inventing a destination.
			unit.destination = unit.cell
			if unit.state != ClassicStudent.State.WALK:
				unit.state = ClassicStudent.State.WAIT
				unit.counter = 2
			continue
		var goal := Vector2i(ally.cell.x / 4, ally.cell.y / 4)
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
