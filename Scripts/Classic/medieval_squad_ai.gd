extends RefCounted

## Deterministic team planner. Uses ordinary movement/focus orders and public combat rules.
## Groups persist between decisions; new recruits join a nearby squad with space.
var squads: Array[Array] = []
var next_plan: int = 0
var lifetimes: Dictionary = {}
var elf_orders: Array[Vector2i] = []


func update(sim) -> void:
	if sim.difficulty == sim.Difficulty.NORMAL and sim.ticks < sim.AI_START_DELAY_TICKS:
		return
	for unit: ClassicStudent in sim.students:
		sim.orc_flee.update(sim, unit)
		if sim.retaliation_ai.active(unit) or sim.proximity_ai.active(unit) or sim.ranged_response.active(unit) or not unit.is_alive() or unit.team == sim.player_team or unit.tile_order_busy or unit.ai_base_defence_tile.x >= 0 or unit.retaliation_until > 0 or unit.returning_to_tile:
			continue
		if unit.team == 2:
			sim.elf_recovery.update(sim, unit)

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
		if not sim.human_ai.controls(unit) and not sim.retaliation_ai.active(unit) and not sim.proximity_ai.active(unit) and not unit.ai_elf_recovering and not sim.ranged_response.active(unit) and not unit.tile_order_busy and unit.ai_base_defence_tile.x < 0 and not unit.ai_retreating and unit.retaliation_until == 0 and not unit.returning_to_tile and sim.ticks >= unit.ai_hold_ground_until:
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
			if nearby or (team == 3 and sim.is_demon_owned_intruder(other) and center.distance_to(Vector2(other.cell)) <= sim.get_demon_awareness_radius()):
				enemies.append(other)
	# Threat counts stay local; Demon territorial candidates can extend farther.
	if team == 1 and nearby_enemies > allies:
		for i: int in range(ready.size() - 1, -1, -1):
			var unit: ClassicStudent = ready[i]
			if not unit.ai_flee_cooldown_pending and sim.ticks >= unit.ai_flee_ready_at:
				sim.orc_flee.begin(sim, unit)
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
		# Orc recruitment tiles also grow capacity; Humans and Elves favour hearts.
		if (team == 1 and area.kind == ClassicRules.AreaKind.RECRUIT) or (team in [0, 2] and area.kind == ClassicRules.AreaKind.HEAL):
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
	if unit.team == 2:
		sim.elf_recovery.update(sim, unit)

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
	var supporters: Array[ClassicStudent] = []
	for unit: ClassicStudent in sim.students:
		if not unit.is_alive() or unit.team == sim.player_team:
			continue
		if unit.team in [0, 2] and sim.get_attack_range(unit) > 1:
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
			if squad[0].team == unit.team and unit.cell.distance_squared_to(squad[0].cell) < nearest:
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
	var target: ClassicStudent = null
	var best: float = INF
	for enemy: ClassicStudent in sim.students:
		if not enemy.is_alive() or enemy.team == team or (center.distance_to(Vector2(enemy.cell)) > 16.0 and not (team == 3 and sim.is_demon_owned_intruder(enemy) and center.distance_to(Vector2(enemy.cell)) <= sim.get_demon_awareness_radius())):
			continue
		var score: float = center.distance_to(Vector2(enemy.cell))
		if team in [0, 2]:
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
					if guard.cell.distance_to(enemy.cell) <= sim.get_demon_awareness_radius():
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
			var location: Vector2i = sim.students[target.target_id].cell if team in [0, 2] else target.cell
			if team == 1 or (team == 3 and unit.cell.distance_to(location) <= sim.get_demon_awareness_radius()) or (team != 3 and _cell_distance(unit.cell, location) <= 10):
				responders.append(unit)
		_focus(sim, responders, target)
		return
	var objective: Vector2i = Vector2i(-1, -1)
	best = INF
	for area: Dictionary in sim.areas:
		if not sim.can_capture_area(area, team):
			continue
		var score: float = center.distance_to(Vector2(area.tile * 4 + Vector2i(2, 2)))
		if score < best:
			best = score
			objective = area.tile
	if objective.x < 0 and target == null:
		# No objectives and nothing locally visible: advance toward a surviving
		# army instead of idling forever. Combat acquisition remains local.
		for enemy: ClassicStudent in sim.students:
			if enemy.is_alive() and enemy.team != team:
				var distance: float = center.distance_to(Vector2(enemy.cell))
				if distance < best:
					best = distance
					objective = Vector2i(enemy.cell.x / 4, enemy.cell.y / 4)

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
	sim.elf_recovery.update(sim, unit)

func _elf_spacing_cost(_tile: Vector2i, _ready: Array[ClassicStudent]) -> float:
	# Kept for compatibility; other squads never add a separation penalty.
	return 0.0
