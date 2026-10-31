extends RefCounted

## Deterministic team planner. Uses ordinary movement/focus orders and public combat rules.
## Groups persist between decisions; new recruits join a nearby squad with space.
var squads: Array[Array] = []
var next_plan: int = 0
var lifetimes: Dictionary = {}


func update(sim) -> void:
	for unit: ClassicStudent in sim.students:
		if not unit.is_alive() or unit.team == sim.player_team:
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
		elif unit.ai_retreating and sim.ticks >= unit.ai_flee_until:
			unit.ai_retreating = false
			# Cancel the escape destination immediately, even between squad decisions.
			unit.state = ClassicStudent.State.STAND
			_move(sim, unit, Vector2i(unit.cell.x / 4, unit.cell.y / 4))
			next_plan = mini(next_plan, sim.ticks)
	if sim.ticks < next_plan:
		return
	next_plan = sim.ticks + (18 if sim.difficulty == sim.Difficulty.EXPERT else 36)
	_refresh(sim)
	for squad: Array in squads:
		_plan(sim, squad)


func _refresh(sim) -> void:
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
		if not unit.ai_retreating and sim.ticks >= unit.ai_hold_ground_until:
			ready.append(unit)
			center += Vector2(unit.cell)
	if ready.is_empty():
		return
	center /= ready.size()
	var team: int = ready[0].team
	var global_awareness: bool = sim.difficulty == sim.Difficulty.EXPERT
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
			if nearby or global_awareness:
				enemies.append(other)
	# Awareness is global in Expert; being outnumbered is still a local threat.
	if team == 1 and nearby_enemies > allies:
		var escape: Vector2i = _escape_tile(sim, ready[0], enemies)
		for i: int in range(ready.size() - 1, -1, -1):
			var unit: ClassicStudent = ready[i]
			if sim.ticks >= unit.ai_flee_ready_at:
				unit.ai_retreating = true
				unit.ai_flee_until = sim.ticks + 3 * ClassicRules.TICKS_PER_SECOND
				unit.ai_flee_ready_at = sim.ticks + 30 * ClassicRules.TICKS_PER_SECOND
				_move(sim, unit, escape)
				ready.remove_at(i)
		if ready.is_empty():
			return
	# Rally separated members before advancing; pairs/trios remain valid squads.
	for unit: ClassicStudent in ready:
		if center.distance_to(Vector2(unit.cell)) > 12.0:
			for member: ClassicStudent in ready:
				_move(sim, member, Vector2i(center / 4.0))
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
		if sim.difficulty == sim.Difficulty.EXPERT:
			distance += _danger_at(sim, unit.team, area.tile * 4 + Vector2i(2, 2)) * 10.0
		if distance < best:
			best = distance
			destination = area.tile
	if threatened:
		var fight: bool = sim.rng.randf() < 0.5 if sim.difficulty == sim.Difficulty.NORMAL else _danger_at(sim, unit.team, unit.cell) <= 0.0
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
