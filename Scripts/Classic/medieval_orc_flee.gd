extends RefCounted

## One shared flee itinerary for ordinary and ranged-response orc AI.
const DURATION: int = 10 * ClassicRules.TICKS_PER_SECOND
const COOLDOWN: int = 10 * ClassicRules.TICKS_PER_SECOND

func begin(sim, unit: ClassicStudent) -> void:
	if unit.ai_flee_cooldown_pending or unit.ai_flee_phase > 0 or sim.ticks < unit.ai_flee_ready_at:
		return
	unit.ai_retreating = true
	unit.ai_spawn_wait = false
	unit.ai_flee_until = sim.ticks + DURATION
	unit.ai_flee_cooldown_pending = true
	unit.ai_flee_quadrant = _quiet_quadrant(sim, unit)
	unit.ai_flee_phase = 1
	var quadrant: int = unit.ai_flee_quadrant
	_move(sim, unit, Vector2i(4 + (quadrant % 2) * 8, 4 + (quadrant / 2) * 8), false)

func _quadrant(tile: Vector2i) -> int:
	return tile.x / 8 + 2 * (tile.y / 8)

func _quiet_quadrant(sim, unit: ClassicStudent) -> int:
	var counts: Array[int] = [0, 0, 0, 0]
	for enemy: ClassicStudent in sim.students:
		if enemy.is_alive() and enemy.team != unit.team:
			counts[_quadrant(Vector2i(enemy.cell.x / 4, enemy.cell.y / 4))] += 1
	var best: int = 0
	var best_distance: int = 100000
	for quadrant: int in 4:
		var center: Vector2i = Vector2i(16 + (quadrant % 2) * 32, 16 + (quadrant / 2) * 32)
		var distance: int = absi(center.x - unit.cell.x) + absi(center.y - unit.cell.y)
		if counts[quadrant] < counts[best] or (counts[quadrant] == counts[best] and distance < best_distance):
			best = quadrant
			best_distance = distance
	return best

func _capture_goal(sim, unit: ClassicStudent) -> Vector2i:
	var goal: Vector2i = Vector2i(-1, -1)
	var best_enemies: int = 100000
	var best_distance: int = 100000
	for area: Dictionary in sim.areas:
		if _quadrant(area.tile) != unit.ai_flee_quadrant or not sim.can_capture_area(area, unit.team):
			continue
		var enemies: int = 0
		for enemy: ClassicStudent in sim.students:
			if enemy.is_alive() and enemy.team != unit.team and Vector2i(enemy.cell.x / 4, enemy.cell.y / 4) == area.tile:
				enemies += 1
		var center: Vector2i = area.tile * 4 + Vector2i(2, 2)
		var distance: int = absi(center.x - unit.cell.x) + absi(center.y - unit.cell.y)
		if enemies < best_enemies or (enemies == best_enemies and distance < best_distance):
			goal = area.tile
			best_enemies = enemies
			best_distance = distance
	return goal

func _move(sim, unit: ClassicStudent, goal: Vector2i, capture: bool) -> void:
	var response: int = unit.ranged_response_id
	sim.designate_order(unit, goal)
	unit.ranged_response_id = response
	unit.tile_guard_active = capture
	unit.target_id = -1
	unit.priority_target_id = -1
	unit.ranged_pursuit_id = -1
	unit.ai_base_defence_tile = Vector2i(-1, -1)
	unit.ai_flee_goal = goal
	if unit.state == ClassicStudent.State.FIGHT:
		unit.state = ClassicStudent.State.STAND
	if Vector2i(unit.cell.x / 4, unit.cell.y / 4) != goal:
		sim.start_walk(unit, goal)
	elif unit.state != ClassicStudent.State.WALK:
		unit.state = ClassicStudent.State.SIT

func update(sim, unit: ClassicStudent) -> void:
	if not unit.is_alive() or unit.team != 1:
		return
	if unit.ai_flee_cooldown_pending and unit.state == ClassicStudent.State.SIT and (unit.ai_flee_phase == 0 or (unit.ai_flee_phase == 2 and Vector2i(unit.cell.x / 4, unit.cell.y / 4) == unit.ai_flee_goal)):
		unit.ai_flee_cooldown_pending = false
		unit.ai_flee_ready_at = sim.ticks + COOLDOWN
	if unit.ai_flee_phase == 0:
		return
	if sim.ticks >= unit.ai_flee_until:
		unit.ai_retreating = false
		unit.ai_flee_phase = 0
		# Keep the capture assignment instead of resuming the old chase.
		unit.tile_guard_active = true
		return
	if sim.ticks >= unit.ai_flee_until - DURATION / 2 and unit.ai_flee_phase == 1:
		unit.ai_flee_phase = 2
		var goal: Vector2i = _capture_goal(sim, unit)
		_move(sim, unit, goal if goal.x >= 0 else unit.ai_flee_goal, true)
	elif unit.ai_flee_phase == 2 and sim.area_at.has(unit.ai_flee_goal):
		var area: Dictionary = sim.areas[sim.area_at[unit.ai_flee_goal]]
		if area.owner == unit.team or not sim.can_capture_area(area, unit.team):
			var goal: Vector2i = _capture_goal(sim, unit)
			if goal.x >= 0:
				_move(sim, unit, goal, true)
