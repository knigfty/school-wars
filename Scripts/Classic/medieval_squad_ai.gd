extends RefCounted

## Deterministic team planner. Uses ordinary movement/focus orders and public combat rules.
## Groups persist between decisions; new recruits join a nearby squad with space.
var squads: Array[Array] = []
var next_plan: int = 0
var lifetimes: Dictionary = {}
var elf_orders: Array[Vector2i] = []
var human_missions: Array[Dictionary] = []


func update(sim) -> void:
	if sim.difficulty == sim.Difficulty.NORMAL and sim.ticks < sim.AI_START_DELAY_TICKS:
		return
	for unit: ClassicStudent in sim.students:
		if not unit.is_alive() or unit.team == sim.player_team or unit.ai_base_defence_tile.x >= 0 or unit.retaliation_until > 0 or unit.returning_to_tile:
			continue
		if sim.difficulty == sim.Difficulty.EXPERT and unit.team == 0 and unit.ai_retreating:
			_human_recover(sim, unit)
			continue
		if sim.difficulty == sim.Difficulty.EXPERT and unit.team == 2:
			_try_recovery(sim, unit)
			continue
		if unit.team == 2:
			if sim.ticks < unit.ai_hold_ground_until:
				continue
			if unit.health < unit.maximum_health * 0.2:
				unit.ai_retreating = true
			elif unit.health >= unit.maximum_health * 0.8:
				unit.ai_retreating = false
			if unit.ai_retreating:
				_heal(sim, unit)
		elif unit.team == 1 and unit.ai_retreating and sim.ticks >= unit.ai_flee_until:
			unit.ai_retreating = false
			# Cancel the escape destination immediately, even between squad decisions.
			unit.state = ClassicStudent.State.STAND
			_move(sim, unit, Vector2i(unit.cell.x / 4, unit.cell.y / 4))
			next_plan = mini(next_plan, sim.ticks)
	if sim.ticks < next_plan:
		return
	next_plan = sim.ticks + (18 if sim.difficulty == sim.Difficulty.EXPERT else 36)
	_refresh(sim)
	elf_orders.clear()
	for squad: Array in squads:
		_plan(sim, squad)


func _refresh(sim) -> void:
	if sim.difficulty == sim.Difficulty.EXPERT:
		_refresh_expert(sim)
		return
	var assigned: Dictionary = {}
	for squad: Array in squads:
		for i: int in range(squad.size() - 1, -1, -1):
			var unit: ClassicStudent = squad[i]
			if not unit.is_alive() or unit.team == sim.player_team or lifetimes.get(unit.id, -1) != unit.lifetime or unit.team != squad[0].team:
				squad.remove_at(i)
			else:
				assigned[unit.id] = true
	for i: int in range(squads.size() - 1, -1, -1):
		if squads[i].is_empty():
			squads.remove_at(i)
	for unit: ClassicStudent in sim.students:
		if not unit.is_alive() or unit.team == sim.player_team or assigned.has(unit.id):
			continue
		var best: Array = []
		var distance: float = INF
		for squad: Array in squads:
			if squad[0].team != unit.team or squad.size() >= 4:
				continue
			var cost: float = unit.cell.distance_squared_to(squad[0].cell)
			if cost < distance:
				distance = cost
				best = squad
		lifetimes[unit.id] = unit.lifetime
		if best.is_empty():
			squads.append([unit])
		else:
			best.append(unit)

	# Avoid leaving a fifth recruit alone when a four-member group can split 3/2.
	for squad: Array in squads:
		if squad.size() != 1:
			continue
		for donor: Array in squads:
			if donor.size() >= 3 and donor[0].team == squad[0].team:
				squad.append(donor.pop_back())
				break


func _plan(sim, squad: Array) -> void:
	var ready: Array[ClassicStudent] = []
	var center: Vector2 = Vector2.ZERO
	for unit: ClassicStudent in squad:
		if unit.ai_base_defence_tile.x < 0 and not unit.ai_retreating and unit.retaliation_until == 0 and not unit.returning_to_tile and sim.ticks >= unit.ai_hold_ground_until:
			ready.append(unit)
			center += Vector2(unit.cell)
	if ready.is_empty():
		return
	center /= ready.size()
	var team: int = ready[0].team
	var expert: bool = sim.difficulty == sim.Difficulty.EXPERT
	var radius: float = 16.0
	var enemies: Array[ClassicStudent] = []
	var allies: int = 0
	var nearby_enemies: int = 0
	for other: ClassicStudent in sim.students:
		if not other.is_alive():
			continue
		var nearby: bool = center.distance_to(Vector2(other.cell)) <= radius
		if other.team == team:
			if nearby:
				allies += 1
		else:
			if nearby:
				nearby_enemies += 1
			if nearby:
				enemies.append(other)
	# All difficulties assess nearby enemies only.
	if team == 1 and nearby_enemies > allies:
		var escape: Vector2i = _enemy_base(sim, ready[0])
		for i: int in range(ready.size() - 1, -1, -1):
			var unit: ClassicStudent = ready[i]
			if sim.ticks >= unit.ai_flee_ready_at:
				unit.ai_retreating = true
				unit.ai_flee_until = sim.ticks + 10 * ClassicRules.TICKS_PER_SECOND
				unit.ai_flee_ready_at = sim.ticks + 30 * ClassicRules.TICKS_PER_SECOND
				_move(sim, unit, escape)
				ready.remove_at(i)
		if ready.is_empty():
			return
	# Protection and territorial defence outrank regrouping.
	if expert and team in [0, 2, 3]:
		_plan_expert(sim, ready, center)
		return
	# Rally separated members before advancing; pairs/trios remain valid squads.
	for unit: ClassicStudent in ready:
		if center.distance_to(Vector2(unit.cell)) > 12.0:
			for member: ClassicStudent in ready:
				_move(sim, member, Vector2i(center / 4.0))
			return
	if expert:
		_plan_expert(sim, ready, center)
		return
	var target: ClassicStudent = null
	var best: float = INF
	for enemy: ClassicStudent in enemies:
		var score: float = center.distance_to(Vector2(enemy.cell))
		if team == 1:
			score += enemy.health * 0.4
		elif team == 3:
			# Estimate the support around this victim, not just the victim's HP.
			var danger: float = 0.0
			for defender: ClassicStudent in sim.students:
				if defender.is_alive() and defender.team != team and defender.cell.distance_to(enemy.cell) <= 8.0:
					danger += _strength(sim, defender)
			var power: float = 0.0
			for member: ClassicStudent in ready:
				power += _strength(sim, member)
			if danger > power * 1.1:
				continue
			score = enemy.health * 2.0 + score * 0.5 + danger * 0.1
		if score < best:
			best = score
			target = enemy
	if target != null:
		for unit: ClassicStudent in ready:
			if unit.priority_target_id == target.id and unit.target_id == target.id:
				continue
			unit.priority_target_id = target.id
			unit.approach_cell = Vector2i(-1, -1)
			if unit.state == ClassicStudent.State.FIGHT:
				unit.state = ClassicStudent.State.STAND
			sim.designate_order(unit, Vector2i.ZERO, target.id)
			sim.start_walk(unit, Vector2i.ZERO, target.id)
		return
	var objective: Vector2i = Vector2i(-1, -1)
	best = INF
	for area: Dictionary in sim.areas:
		if area.owner == team or not sim.can_capture_area(area, team):
			continue
		var score: float = center.distance_to(Vector2(area.tile * 4 + Vector2i(2, 2)))
		# Orc recruitment tiles also grow capacity; hearts support elf veterans.
		if (team == 1 and area.kind == ClassicRules.AreaKind.RECRUIT) or (team == 2 and area.kind == ClassicRules.AreaKind.HEAL):
			score -= 6.0
		if score < best:
			best = score
			objective = area.tile
	if objective.x >= 0:
		for unit: ClassicStudent in ready:
			_move(sim, unit, objective)
	elif enemies.is_empty():
		# No capturable land remains: advance together toward the nearest opponent.
		for enemy: ClassicStudent in sim.students:
			if enemy.is_alive() and enemy.team != team:
				var distance: float = center.distance_to(Vector2(enemy.cell))
				if distance < best:
					best = distance
					objective = Vector2i(enemy.cell.x / 4, enemy.cell.y / 4)
		if objective.x >= 0:
			for unit: ClassicStudent in ready:
				_move(sim, unit, objective)


func _strength(sim, unit: ClassicStudent) -> float:
	return unit.health * (ClassicRules.PUNCH[unit.team] + unit.punch_bonus) * (1.0 + 0.15 * (sim.get_attack_range(unit) - 1))


func _heal(sim, unit: ClassicStudent) -> void:
	var current_tile: Vector2i = Vector2i(unit.cell.x / 4, unit.cell.y / 4)
	var threatened: bool = sim.ticks - unit.last_attacked_tick < 3 * ClassicRules.TICKS_PER_SECOND
	if not (threatened and current_tile == unit.ai_heal_tile) and sim.ticks < unit.ai_heal_decide_at and unit.ai_heal_tile.x >= 0 and sim.area_at.has(unit.ai_heal_tile) and sim.areas[sim.area_at[unit.ai_heal_tile]].owner == unit.team:
		_move(sim, unit, unit.ai_heal_tile)
		return
	var destination: Vector2i = Vector2i(-1, -1)
	var best: float = INF
	for area: Dictionary in sim.areas:
		if area.owner != unit.team or area.kind == ClassicRules.AreaKind.RECRUIT:
			continue
		if threatened and area.tile == current_tile:
			continue
		var distance: float = unit.cell.distance_squared_to(area.tile * 4 + Vector2i(2, 2))
		if sim.difficulty == sim.Difficulty.EXPERT and unit.team != 2:
			distance += _danger_at(sim, unit.team, area.tile * 4 + Vector2i(2, 2)) * 10.0
		if distance < best:
			best = distance
			destination = area.tile
	if threatened:
		var fight: bool = sim.rng.randf() < 0.5 if sim.difficulty == sim.Difficulty.NORMAL or unit.team == 2 else _danger_at(sim, unit.team, unit.cell) <= 0.0
		if fight:
			var target: ClassicStudent = null
			var nearest: float = INF
			for enemy: ClassicStudent in sim.students:
				if enemy.is_alive() and enemy.team != unit.team and unit.cell.distance_to(enemy.cell) < nearest:
					nearest = unit.cell.distance_to(enemy.cell)
					target = enemy
			if target != null:
				unit.ai_retreating = false
				unit.ai_hold_ground_until = sim.ticks + 3 * ClassicRules.TICKS_PER_SECOND
				unit.priority_target_id = target.id
				unit.state = ClassicStudent.State.STAND
				sim.designate_order(unit, Vector2i.ZERO, target.id)
				sim.start_walk(unit, Vector2i.ZERO, target.id)
				return
	if destination.x < 0:
		var threats: Array[ClassicStudent] = []
		for other: ClassicStudent in sim.students:
			if other.is_alive() and other.team != unit.team:
				threats.append(other)
		destination = _escape_tile(sim, unit, threats)
	unit.ai_heal_tile = destination
	unit.ai_heal_decide_at = sim.ticks + 3 * ClassicRules.TICKS_PER_SECOND
	_move(sim, unit, destination)


func _danger_at(sim, team: int, cell: Vector2i) -> float:
	var danger: float = 0.0
	for other: ClassicStudent in sim.students:
		if other.is_alive() and other.cell.distance_to(cell) <= 12.0:
			danger += _strength(sim, other) * (-1.0 if other.team == team else 1.0)
	return danger


func _escape_tile(sim, unit: ClassicStudent, enemies: Array[ClassicStudent]) -> Vector2i:
	var best: float = -INF
	var destination: Vector2i = Vector2i(unit.cell.x / 4, unit.cell.y / 4)
	for y: int in 16:
		for x: int in 16:
			var tile: Vector2i = Vector2i(x, y)
			var cell: Vector2i = tile * 4 + Vector2i(2, 2)
			var nearest: float = 90.0
			for enemy: ClassicStudent in enemies:
				nearest = minf(nearest, cell.distance_to(enemy.cell))
			var score: float = nearest + Vector2(tile).distance_to(Vector2(sim.bases[unit.team])) * 2.0 - unit.cell.distance_to(cell) * 0.4
			if score > best:
				best = score
				destination = tile
	return destination


func _move(sim, unit: ClassicStudent, tile: Vector2i) -> void:
	sim.designate_order(unit, tile)
	unit.priority_target_id = -1
	unit.target_id = -1
	unit.approach_cell = Vector2i(-1, -1)
	var current_tile: Vector2i = Vector2i(unit.cell.x / 4, unit.cell.y / 4)
	if current_tile == tile:
		if unit.state != ClassicStudent.State.WALK:
			unit.state = ClassicStudent.State.SIT
			unit.pattern = 13
			unit.counter = 40
		return
	if unit.state == ClassicStudent.State.WALK and Vector2i(unit.destination.x / 4, unit.destination.y / 4) == tile:
		return
	if unit.state == ClassicStudent.State.FIGHT:
		unit.state = ClassicStudent.State.STAND
	sim.start_walk(unit, tile)


func _refresh_expert(sim) -> void:
	squads.clear()
	_refresh_humans(sim)
	var supporters: Array[ClassicStudent] = []
	for unit: ClassicStudent in sim.students:
		if not unit.is_alive() or unit.team == sim.player_team or unit.team == 0:
			continue
		if unit.team == 2 and sim.get_attack_range(unit) > 1:
			supporters.append(unit)
			continue
		var group: Array = []
		var limit: int = 6 if unit.team == 1 else 4
		for squad: Array in squads:
			if squad[0].team == unit.team and squad.size() < limit:
				group = squad
				break
		if group.is_empty():
			squads.append([unit])
		else:
			group.append(unit)
	for unit: ClassicStudent in supporters:
		var group: Array = []
		var nearest: float = INF
		for squad: Array in squads:
			if squad[0].team == 2 and unit.cell.distance_squared_to(squad[0].cell) < nearest:
				group = squad
				nearest = unit.cell.distance_squared_to(squad[0].cell)
		if group.is_empty():
			squads.append([unit])
		else:
			group.append(unit)


func _focus(sim, ready: Array[ClassicStudent], target: ClassicStudent) -> void:
	for unit: ClassicStudent in ready:
		if unit.priority_target_id == target.id and unit.target_id == target.id:
			continue
		unit.priority_target_id = target.id
		unit.approach_cell = Vector2i(-1, -1)
		if unit.state == ClassicStudent.State.FIGHT:
			unit.state = ClassicStudent.State.STAND
		sim.designate_order(unit, Vector2i.ZERO, target.id)
		sim.start_walk(unit, Vector2i.ZERO, target.id)


func _plan_expert(sim, ready: Array[ClassicStudent], center: Vector2) -> void:
	var team: int = ready[0].team
	if team == 0:
		_plan_humans(sim, ready, center)
		return
	var target: ClassicStudent = null
	var best: float = INF
	for enemy: ClassicStudent in sim.students:
		if not enemy.is_alive() or enemy.team == team or center.distance_to(Vector2(enemy.cell)) > 16.0:
			continue
		var score: float = center.distance_to(Vector2(enemy.cell))
		if team == 2:
			if enemy.target_id >= 0 and enemy.target_id < sim.students.size():
				var victim: ClassicStudent = sim.students[enemy.target_id]
				if victim.is_alive() and victim.team == team and victim.health <= victim.maximum_health * 0.2 and enemy.state == ClassicStudent.State.FIGHT:
					for guard: ClassicStudent in ready:
						if guard.id != victim.id and _cell_distance(guard.cell, victim.cell) <= 10:
							score -= 10000.0
							break
		elif team == 3:
			var tile: Vector2i = Vector2i(enemy.cell.x / 4, enemy.cell.y / 4)
			if sim.area_at.has(tile) and sim.areas[sim.area_at[tile]].owner == team:
				for guard: ClassicStudent in ready:
					if _cell_distance(guard.cell, enemy.cell) <= 10:
						score -= 10000.0
						break
			score += enemy.health * 0.25
		else:
			score += enemy.health * 0.4
		if score < best:
			best = score
			target = enemy
	if target != null and (team == 1 or best < 0.0):
		var responders: Array[ClassicStudent] = []
		for unit: ClassicStudent in ready:
			var location: Vector2i = sim.students[target.target_id].cell if team == 2 else target.cell
			if team == 1 or _cell_distance(unit.cell, location) <= 10:
				responders.append(unit)
		_focus(sim, responders, target)
		return
	var objective: Vector2i = Vector2i(-1, -1)
	best = INF
	for area: Dictionary in sim.areas:
		if not sim.can_capture_area(area, team):
			continue
		var score: float = center.distance_to(Vector2(area.tile * 4 + Vector2i(2, 2)))
		if team == 0:
			var occupied: bool = false
			for enemy: ClassicStudent in sim.students:
				if enemy.is_alive() and enemy.team != team and center.distance_to(Vector2(enemy.cell)) <= 16.0 and Vector2i(enemy.cell.x / 4, enemy.cell.y / 4) == area.tile:
					occupied = true
					break
			if occupied:
				continue
		if team == 2:
			score += _elf_spacing_cost(area.tile, ready)
		if score < best:
			best = score
			objective = area.tile
	if objective.x < 0 and target == null and team == 2:
		for y: int in 16:
			for x: int in 16:
				var tile: Vector2i = Vector2i(x, y)
				var score: float = center.distance_to(Vector2(tile * 4 + Vector2i(2, 2))) + _elf_spacing_cost(tile, ready)
				if score < best:
					best = score
					objective = tile
	if objective.x >= 0:
		if team == 2:
			elf_orders.append(objective)
		for unit: ClassicStudent in ready:
			_move(sim, unit, objective)
	elif target != null:
		_focus(sim, ready, target)


func _enemy_base(sim, unit: ClassicStudent) -> Vector2i:
	var destination: Vector2i = Vector2i(unit.cell.x / 4, unit.cell.y / 4)
	var best: float = INF
	for area: Dictionary in sim.areas:
		if area.kind == ClassicRules.AreaKind.BASE and area.owner >= 0 and area.owner != unit.team and sim.active[area.owner]:
			var distance: float = unit.cell.distance_squared_to(area.tile * 4 + Vector2i(2, 2))
			if distance < best:
				best = distance
				destination = area.tile
	return destination


func _cell_distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _nearby_healing_tile(sim, unit: ClassicStudent) -> Vector2i:
	var destination: Vector2i = Vector2i(-1, -1)
	var best: int = 11
	for area: Dictionary in sim.areas:
		if area.owner != unit.team or area.kind == ClassicRules.AreaKind.RECRUIT:
			continue
		var corner: Vector2i = area.tile * 4
		var closest: Vector2i = Vector2i(clampi(unit.cell.x, corner.x, corner.x + 3), clampi(unit.cell.y, corner.y, corner.y + 3))
		var distance: int = _cell_distance(unit.cell, closest)
		if distance < best:
			best = distance
			destination = area.tile
	return destination


func _try_recovery(sim, unit: ClassicStudent) -> void:
	if unit.team != 2:
		return
	var threshold: float = 0.2
	var recovered: float = 1.0
	if unit.ai_retreating:
		if unit.health >= unit.maximum_health * recovered:
			unit.ai_retreating = false
			unit.ai_heal_tile = Vector2i(-1, -1)
			return
		if not sim.area_at.has(unit.ai_heal_tile) or sim.areas[sim.area_at[unit.ai_heal_tile]].owner != unit.team:
			unit.ai_heal_tile = _nearby_healing_tile(sim, unit)
		if unit.ai_heal_tile.x < 0:
			unit.ai_retreating = false
			unit.target_id = -1
			unit.priority_target_id = -1
			unit.state = ClassicStudent.State.STAND
			return
		_move(sim, unit, unit.ai_heal_tile)
	elif unit.health <= unit.maximum_health * threshold and sim.ticks >= unit.ai_heal_ready_at:
		var destination: Vector2i = _nearby_healing_tile(sim, unit)
		if destination.x >= 0:
			unit.ai_retreating = true
			unit.ai_heal_tile = destination
			unit.ai_heal_ready_at = sim.ticks + 45 * ClassicRules.TICKS_PER_SECOND
			_move(sim, unit, destination)


func _elf_spacing_cost(tile: Vector2i, ready: Array[ClassicStudent]) -> float:
	var cost: float = 0.0
	var cell: Vector2 = Vector2(tile * 4 + Vector2i(2, 2))
	for squad: Array in squads:
		if squad[0].team == 2 and not squad.has(ready[0]):
			cost += maxf(0.0, 12.0 - cell.distance_to(Vector2(squad[0].cell))) * 20.0
	for destination: Vector2i in elf_orders:
		cost += maxf(0.0, 12.0 - cell.distance_to(Vector2(destination * 4 + Vector2i(2, 2)))) * 100.0
	return cost


func _mission_alive(mission: Dictionary) -> Array[ClassicStudent]:
	var alive: Array[ClassicStudent] = []
	for record: Dictionary in mission.members:
		var unit: ClassicStudent = record.unit
		if unit.is_alive() and unit.team == 0 and unit.lifetime == record.lifetime:
			alive.append(unit)
	return alive


func _refresh_humans(sim) -> void:
	var assigned: Dictionary = {}
	for i: int in range(human_missions.size() - 1, -1, -1):
		var mission: Dictionary = human_missions[i]
		var alive: Array[ClassicStudent] = _mission_alive(mission)
		var recovered: bool = mission.recovering
		for unit: ClassicStudent in alive:
			if unit.ai_retreating:
				recovered = false
		var captured: bool = mission.goal.x >= 0 and sim.area_at.has(mission.goal) and sim.areas[sim.area_at[mission.goal]].owner == 0
		if alive.is_empty() or recovered or (captured and not mission.recovering):
			human_missions.remove_at(i)
			continue
		for unit: ClassicStudent in alive:
			assigned[unit.id] = true
	if sim.player_team == 0:
		return
	for unit: ClassicStudent in sim.students:
		if not unit.is_alive() or unit.team != 0 or assigned.has(unit.id):
			continue
		var available: Dictionary = {}
		for mission: Dictionary in human_missions:
			if not mission.recovering and _mission_alive(mission).size() < 4:
				available = mission
				break
		if available.is_empty():
			available = {"members": [], "initial": [], "goal": Vector2i(-1, -1), "rolled": false, "recovering": false}
			human_missions.append(available)
		available.members.append({"unit": unit, "lifetime": unit.lifetime})
	for mission: Dictionary in human_missions:
		var group: Array = []
		group.assign(_mission_alive(mission))
		if not group.is_empty():
			squads.append(group)


func _nearest_human_heal(sim, unit: ClassicStudent) -> Vector2i:
	var destination: Vector2i = Vector2i(-1, -1)
	var best: int = 100000
	for area: Dictionary in sim.areas:
		if area.owner == 0 and area.kind != ClassicRules.AreaKind.RECRUIT:
			var distance: int = _cell_distance(unit.cell, area.tile * 4 + Vector2i(2, 2))
			if distance < best:
				best = distance
				destination = area.tile
	return destination


func _human_recover(sim, unit: ClassicStudent) -> void:
	var destination: Vector2i = _nearest_human_heal(sim, unit)
	if destination.x < 0:
		unit.ai_retreating = false
		return
	if unit.health >= unit.maximum_health and Vector2i(unit.cell.x / 4, unit.cell.y / 4) == destination:
		unit.ai_retreating = false
		return
	_move(sim, unit, destination)


func _plan_humans(sim, ready: Array[ClassicStudent], center: Vector2) -> void:
	var mission: Dictionary = {}
	for candidate: Dictionary in human_missions:
		for record: Dictionary in candidate.members:
			if record.unit == ready[0] and record.lifetime == ready[0].lifetime:
				mission = candidate
				break
		if not mission.is_empty():
			break
	if mission.is_empty() or mission.recovering:
		return
	var alive: Array[ClassicStudent] = _mission_alive(mission)
	if mission.goal.x >= 0 and not mission.rolled and _mission_alive({"members": mission.initial}).size() * 2 <= mission.initial.size():
		var eligible: bool = true
		for unit: ClassicStudent in alive:
			if sim.ticks < unit.ai_heal_ready_at:
				eligible = false
		if eligible:
			mission.rolled = true
			if sim.rng.randf() < 0.5:
				for unit: ClassicStudent in alive:
					if _nearest_human_heal(sim, unit).x >= 0:
						unit.ai_retreating = true
						unit.ai_heal_ready_at = sim.ticks + 45 * ClassicRules.TICKS_PER_SECOND
						mission.recovering = true
						_human_recover(sim, unit)
				if mission.recovering:
					return
	if mission.goal.x < 0:
		var best: float = INF
		var origin: Vector2i = Vector2i(center / 4.0)
		for area: Dictionary in sim.areas:
			if not sim.can_capture_area(area, 0) or _cell_distance(origin, area.tile) > 5:
				continue
			var score: float = center.distance_to(Vector2(area.tile * 4 + Vector2i(2, 2)))
			for enemy: ClassicStudent in sim.students:
				if enemy.is_alive() and enemy.team != 0 and Vector2i(enemy.cell.x / 4, enemy.cell.y / 4) == area.tile:
					score += 1000.0
			if score < best:
				best = score
				mission.goal = area.tile
	if mission.goal.x < 0:
		return
	if mission.initial.is_empty():
		mission.initial.assign(mission.members)
	var target: ClassicStudent = null
	for enemy: ClassicStudent in sim.students:
		if enemy.is_alive() and enemy.team != 0 and Vector2i(enemy.cell.x / 4, enemy.cell.y / 4) == mission.goal and center.distance_to(Vector2(enemy.cell)) <= 20.0:
			if target == null or enemy.health < target.health:
				target = enemy
	if target != null:
		_focus(sim, ready, target)
	else:
		for unit: ClassicStudent in ready:
			_move(sim, unit, mission.goal)
