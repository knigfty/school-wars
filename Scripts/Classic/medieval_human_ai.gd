extends RefCounted

## Shared Human strategy for Easy, Normal, and Expert.
var started: bool = false
var phase: String = "normal"
var target_race: int = -1
var next_plan: int = 0
var squads: Array[Array] = []

func army(sim) -> Array[ClassicStudent]:
	var result: Array[ClassicStudent] = []
	for unit: ClassicStudent in sim.students:
		if unit.is_alive() and unit.team == 0:
			result.append(unit)
	return result

func controls(unit: ClassicStudent) -> bool:
	return started and unit.team == 0 and phase != "normal"

func distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

func base_distance(sim, unit: ClassicStudent) -> int:
	var corner: Vector2i = sim.bases[0] * 4
	return distance(unit.cell, Vector2i(clampi(unit.cell.x, corner.x, corner.x + 3), clampi(unit.cell.y, corner.y, corner.y + 3)))

func can_engage(sim, unit: ClassicStudent, target: ClassicStudent) -> bool:
	if not started or unit.team != 0 or unit.team == sim.player_team:
		return true
	if phase in ["rally", "retreat"]:
		return false
	var enemies: int = 0
	var allies: int = 0
	for other: ClassicStudent in sim.students:
		if not other.is_alive():
			continue
		if other.team != 0 and distance(other.cell, target.cell) <= 3:
			enemies += 1
		elif other.team == 0 and distance(other.cell, unit.cell) <= 8:
			allies += 1
	if phase == "attack":
		allies = army(sim).size()
	return enemies <= allies

func weakest_race(sim) -> int:
	var result: int = -1
	var best: float = INF
	for race: int in range(1, 4):
		var count: int = 0
		var health: float = 0.0
		for enemy: ClassicStudent in sim.students:
			if enemy.is_alive() and enemy.team == race:
				count += 1
				health += enemy.health
		if count > 0 and count * health < best:
			best = count * health
			result = race
	return result

func _clear(sim, unit: ClassicStudent) -> void:
	sim.proximity_ai.engagements.erase(unit.id)
	sim.ranged_response._prepare(unit)
	unit.ranged_response_id = -1
	unit.ranged_pursuit_id = -1
	unit.priority_target_id = -1
	unit.target_id = -1
	unit.ai_retreating = false
	if unit.state == ClassicStudent.State.FIGHT:
		unit.state = ClassicStudent.State.STAND

func _move(sim, unit: ClassicStudent, goal: Vector2i, retreat: bool = false) -> void:
	if unit.target_id >= 0 or unit.designated_tile != goal or not unit.tile_guard_active:
		_clear(sim, unit)
		sim.designate_order(unit, goal)
	unit.ai_retreating = retreat
	if Vector2i(unit.cell.x / 4, unit.cell.y / 4) != goal:
		if unit.state != ClassicStudent.State.WALK or Vector2i(unit.destination.x / 4, unit.destination.y / 4) != goal:
			sim.start_walk(unit, goal)

func _enter(sim, new_phase: String, humans: Array[ClassicStudent]) -> void:
	phase = new_phase
	next_plan = 0
	for unit: ClassicStudent in humans:
		_clear(sim, unit)

func _refresh(humans: Array[ClassicStudent]) -> void:
	var assigned: Dictionary = {}
	for group: Array in squads:
		for i: int in range(group.size() - 1, -1, -1):
			var record: Dictionary = group[i]
			if not record.unit.is_alive() or record.unit.team != 0 or record.unit.lifetime != record.life:
				group.remove_at(i)
			else:
				assigned[record.unit.id] = true
	for i: int in range(squads.size() - 1, -1, -1):
		if squads[i].is_empty():
			squads.remove_at(i)
	for unit: ClassicStudent in humans:
		if assigned.has(unit.id):
			continue
		var destination: Array = []
		for group: Array in squads:
			if group.size() < 4:
				destination = group
				break
		if destination.is_empty():
			destination = []
			squads.append(destination)
		destination.append({"unit": unit, "life": unit.lifetime})

	# Compact casualty-thinned squads back into complete groups of four.
	var records: Array = []
	for group: Array in squads:
		records.append_array(group)
	squads.clear()
	for i: int in records.size():
		if i % 4 == 0:
			squads.append([])
		squads.back().append(records[i])

func _normal(sim, humans: Array[ClassicStudent]) -> void:
	_refresh(humans)
	if sim.difficulty != sim.Difficulty.EXPERT and sim.ticks < sim.AI_START_DELAY_TICKS:
		return
	if sim.ticks < next_plan:
		return
	next_plan = sim.ticks + 18
	var populations: Array[int] = [0, 0, 0, 0]
	for enemy: ClassicStudent in sim.students:
		if enemy.is_alive() and enemy.team != 0:
			populations[enemy.cell.x / 32 + 2 * (enemy.cell.y / 32)] += 1
	for group: Array in squads:
		var members: Array[ClassicStudent] = []
		var center := Vector2.ZERO
		for record: Dictionary in group:
			members.append(record.unit)
			center += Vector2(record.unit.cell)
		center /= members.size()
		var origin := Vector2i(center)
		var goal := Vector2i(-1, -1)
		var best_count: int = 100000
		var best_quadrant_distance: int = 100000
		var best_tile_distance: int = 100000
		for area: Dictionary in sim.areas:
			if not sim.can_capture_area(area, 0):
				continue
			var safe: bool = true
			for enemy: ClassicStudent in sim.students:
				if enemy.is_alive() and enemy.team != 0 and Vector2i(enemy.cell.x / 4, enemy.cell.y / 4) == area.tile and not can_engage(sim, members[0], enemy):
					safe = false
			if not safe:
				continue
			var quadrant: int = area.tile.x / 8 + 2 * (area.tile.y / 8)
			var quadrant_center := Vector2i(16 + (quadrant % 2) * 32, 16 + (quadrant / 2) * 32)
			var q_distance: int = distance(origin, quadrant_center)
			var tile_distance: int = distance(origin, area.tile * 4 + Vector2i(2, 2))
			if populations[quadrant] < best_count or (populations[quadrant] == best_count and (q_distance < best_quadrant_distance or (q_distance == best_quadrant_distance and tile_distance < best_tile_distance))):
				goal = area.tile
				best_count = populations[quadrant]
				best_quadrant_distance = q_distance
				best_tile_distance = tile_distance
		# Keep a four-person squad together before beginning another capture march.
		var rally: bool = false
		for unit: ClassicStudent in members:
			if distance(unit.cell, origin) > 8:
				rally = true
		if rally:
			goal = Vector2i(origin.x / 4, origin.y / 4)
		# Do not abandon a squadmate during local interception.
		for unit: ClassicStudent in members:
			if sim.proximity_ai.active(unit):
				goal = sim.proximity_ai.engagements[unit.id].origin
				break
		if members.size() < 4 and humans.size() >= 4:
			goal = sim.bases[0]
		var fallback: ClassicStudent = null
		if goal.x < 0:
			var nearest: int = 100000
			for enemy: ClassicStudent in sim.students:
				if enemy.is_alive() and enemy.team != 0 and can_engage(sim, members[0], enemy):
					var cost: int = distance(origin, enemy.cell)
					if cost < nearest:
						nearest = cost
						fallback = enemy
		for unit: ClassicStudent in members:
			if sim.proximity_ai.active(unit) or unit.ai_spawn_wait:
				continue
			if goal.x >= 0:
				_move(sim, unit, goal)
			elif fallback != null:
				_clear(sim, unit)
				sim.designate_order(unit, Vector2i.ZERO, fallback.id)
				unit.priority_target_id = fallback.id
				sim.start_walk(unit, Vector2i.ZERO, fallback.id)

func update(sim) -> void:
	if not sim.medieval or not sim.ai_enabled or sim.player_team == 0:
		return
	started = true
	var humans: Array[ClassicStudent] = army(sim)
	if humans.is_empty():
		phase = "normal"
		target_race = -1
		squads.clear()
		return
	if phase == "normal" and humans.size() >= 10:
		_enter(sim, "rally", humans)
	if phase == "normal":
		_normal(sim, humans)
		return
	if phase == "rally" and humans.size() <= 3:
		_enter(sim, "retreat", humans)
	if phase == "attack":
		var enemy_survivors: int = 0
		for enemy: ClassicStudent in sim.students:
			if enemy.is_alive() and enemy.team == target_race:
				enemy_survivors += 1
		if enemy_survivors == 0:
			_enter(sim, "capture", humans)
		elif humans.size() <= 3:
			_enter(sim, "retreat", humans)
	if phase == "capture" and sim.areas[sim.area_at[sim.bases[target_race]]].owner == 0:
		_enter(sim, "normal", humans)
		target_race = -1
		return
	if phase in ["rally", "retreat"]:
		var arrived: bool = true
		for unit: ClassicStudent in humans:
			_move(sim, unit, sim.bases[0], phase == "retreat")
			if (base_distance(sim, unit) > 15 if phase == "rally" else Vector2i(unit.cell.x / 4, unit.cell.y / 4) != sim.bases[0]):
				arrived = false
		if arrived:
			if phase == "retreat":
				_enter(sim, "normal", humans)
				target_race = -1
				return
			target_race = weakest_race(sim)
			if target_race < 0:
				_enter(sim, "normal", humans)
				return
			_enter(sim, "attack", humans)
	if phase == "capture":
		for unit: ClassicStudent in humans:
			_move(sim, unit, sim.bases[target_race])
	elif phase == "attack":
		var victim: ClassicStudent = null
		var best: int = 100000
		var center := Vector2.ZERO
		for unit: ClassicStudent in humans:
			center += Vector2(unit.cell)
		center /= humans.size()
		for enemy: ClassicStudent in sim.students:
			if enemy.is_alive() and enemy.team == target_race and can_engage(sim, humans[0], enemy):
				var cost: int = distance(Vector2i(center), enemy.cell)
				if cost < best:
					best = cost
					victim = enemy
		for unit: ClassicStudent in humans:
			if victim == null:
				_move(sim, unit, sim.bases[0])
			elif unit.priority_target_id != victim.id or unit.target_id != victim.id:
				_clear(sim, unit)
				sim.designate_order(unit, Vector2i.ZERO, victim.id)
				unit.priority_target_id = victim.id
				sim.start_walk(unit, Vector2i.ZERO, victim.id)
