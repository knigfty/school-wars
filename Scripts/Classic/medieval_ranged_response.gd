extends RefCounted

## Persistent responses to ranged damage, independent of strategic difficulty.
var groups: Dictionary = {}
var next_id: int = 0

func active(unit: ClassicStudent) -> bool:
	return unit.ranged_response_id >= 0 and groups.has(unit.ranged_response_id)

func on_hit(sim, defender: ClassicStudent, attacker: ClassicStudent) -> void:
	if active(defender) or defender.ai_retreating:
		return
	var members: Array = []
	var origin: Vector2i = Vector2i(defender.cell.x / 4, defender.cell.y / 4)
	for unit: ClassicStudent in sim.students:
		if unit.is_alive() and unit.team == defender.team and not active(unit) and not unit.ai_retreating and Vector2i(unit.cell.x / 4, unit.cell.y / 4) == origin and ((unit.tile_guard_active and unit.designated_tile == origin) or unit.state in [ClassicStudent.State.SIT, ClassicStudent.State.STAND, ClassicStudent.State.WAIT]):
			if defender.team != 1 or unit == defender:
				members.append({"unit": unit, "life": unit.lifetime})
	if members.is_empty():
		return
	var id: int = next_id
	next_id += 1
	var group: Dictionary = {"id": id, "team": defender.team, "members": members, "initial": members.size(), "target": attacker, "target_life": attacker.lifetime, "mode": "chase", "rolled": false, "goal": origin, "heal": false, "recover": 1.0}
	groups[id] = group
	for record: Dictionary in members:
		record.unit.ranged_response_id = id
	if defender.team in [0, 2] and sim.rng.randf() >= 0.5:
		_retreat(sim, group, defender.team == 0)
	else:
		_chase(sim, group)
	if defender.team == 1:
		_orc_decide(sim, group, defender)

func _members(group: Dictionary) -> Array[ClassicStudent]:
	var result: Array[ClassicStudent] = []
	for record: Dictionary in group.members:
		var unit: ClassicStudent = record.unit
		if unit.is_alive() and unit.lifetime == record.life and unit.team == group.team and unit.ranged_response_id == group.id:
			result.append(unit)
	return result

func _release(unit: ClassicStudent) -> void:
	unit.ranged_response_id = -1
	unit.ranged_pursuit_id = -1
	unit.ai_retreating = false
	unit.ai_flee_until = 0
	unit.tile_guard_active = true
	unit.tile_guard_target = -1
	unit.tile_clear_at = -1
	unit.tile_order_busy = false
	unit.designated_tile = Vector2i(unit.cell.x / 4, unit.cell.y / 4)
	unit.priority_target_id = -1
	unit.target_id = -1

func _prepare(unit: ClassicStudent) -> void:
	unit.ai_spawn_wait = false
	unit.tile_guard_active = false
	unit.tile_guard_target = -1
	unit.tile_order_busy = false
	unit.ai_base_defence_tile = Vector2i(-1, -1)
	unit.returning_to_tile = false
	unit.retaliation_until = 0
	unit.retaliation_target_id = -1

func _chase(sim, group: Dictionary) -> void:
	group.mode = "chase"
	for unit: ClassicStudent in _members(group):
		_prepare(unit)
		unit.ai_retreating = false
		unit.priority_target_id = group.target.id
		unit.ranged_pursuit_id = group.target.id
		# Retain a reserved step; ordinary walking completes it before fighting.
		if unit.state == ClassicStudent.State.WALK:
			unit.target_id = group.target.id
		else:
			unit.state = ClassicStudent.State.STAND
			sim.start_walk(unit, Vector2i.ZERO, group.target.id)

func _healing_goal(sim, unit: ClassicStudent, limit: int = 100000) -> Vector2i:
	var goal: Vector2i = Vector2i(-1, -1)
	var best: int = limit + 1
	for area: Dictionary in sim.areas:
		if area.owner != unit.team or area.kind == ClassicRules.AreaKind.RECRUIT:
			continue
		var corner: Vector2i = area.tile * 4
		var distance: int = absi(unit.cell.x - clampi(unit.cell.x, corner.x, corner.x + 3)) + absi(unit.cell.y - clampi(unit.cell.y, corner.y, corner.y + 3))
		if distance < best:
			best = distance
			goal = area.tile
	return goal

func _retreat(sim, group: Dictionary, heal: bool, goal: Vector2i = Vector2i(-1, -1)) -> void:
	var members: Array[ClassicStudent] = _members(group)
	if members.is_empty():
		return
	if goal.x < 0 and heal:
		goal = _healing_goal(sim, members[0])
		if goal.x < 0:
			heal = false
	if goal.x < 0:
		var threats: Array[ClassicStudent] = []
		for enemy: ClassicStudent in sim.students:
			if enemy.is_alive() and enemy.team != group.team:
				threats.append(enemy)
		goal = sim.squad_ai._escape_tile(sim, members[0], threats)
	var current_tile: Vector2i = Vector2i(members[0].cell.x / 4, members[0].cell.y / 4)
	if goal == current_tile and not group.get("recovery", false):
		# Leaving a threatened tile must actually choose another tile.
		heal = false
		var best: int = -1
		for direction: Vector2i in ClassicRules.DIRECTIONS:
			var alternative: Vector2i = current_tile + direction
			if alternative.x < 0 or alternative.y < 0 or alternative.x >= 16 or alternative.y >= 16:
				continue
			var distance: int = absi(alternative.x * 4 - group.target.cell.x) + absi(alternative.y * 4 - group.target.cell.y)
			if distance > best:
				best = distance
				goal = alternative
	group.mode = "retreat"
	group.goal = goal
	group.heal = heal
	for unit: ClassicStudent in members:
		_prepare(unit)
		unit.ai_retreating = true
		unit.priority_target_id = -1
		unit.ranged_pursuit_id = -1
		unit.target_id = -1
		unit.designated_tile = goal
		unit.ai_heal_tile = goal
		if unit.state == ClassicStudent.State.FIGHT:
			unit.state = ClassicStudent.State.STAND
		if Vector2i(unit.cell.x / 4, unit.cell.y / 4) != goal:
			sim.start_walk(unit, goal)
		elif unit.state != ClassicStudent.State.WALK:
			unit.state = ClassicStudent.State.SIT

func _orc_decide(sim, group: Dictionary, unit: ClassicStudent) -> void:
	if sim.ticks < unit.ai_flee_ready_at:
		return
	var allies: int = 0
	var attackers: int = 0
	var origin: Vector2i = Vector2i(unit.cell.x / 4, unit.cell.y / 4)
	for other: ClassicStudent in sim.students:
		var tile: Vector2i = Vector2i(other.cell.x / 4, other.cell.y / 4)
		if not other.is_alive() or absi(tile.x - origin.x) + absi(tile.y - origin.y) > 2:
			continue
		if other.team == unit.team:
			allies += 1
		elif sim._valid_enemy(other, other.target_id) and sim.students[other.target_id].team == unit.team and other.state in [ClassicStudent.State.FIGHT, ClassicStudent.State.WALK]:
			attackers += 1
	if attackers > allies or unit.health <= unit.maximum_health * 0.2:
		unit.ai_flee_until = sim.ticks + 10 * ClassicRules.TICKS_PER_SECOND
		unit.ai_flee_ready_at = sim.ticks + 30 * ClassicRules.TICKS_PER_SECOND
		# Preserve the established orc escape direction toward an enemy base.
		_retreat(sim, group, false, sim.squad_ai._enemy_base(sim, unit))

func update(sim) -> void:
	# Snapshot IDs: elf recovery may create a new response while iterating.
	for id: int in groups.keys():
		var group: Dictionary = groups[id]
		var members: Array[ClassicStudent] = _members(group)
		if members.is_empty():
			groups.erase(id)
			continue
		var valid_target: bool = group.target.is_alive() and group.target.lifetime == group.target_life and group.target.team != group.team
		if group.mode == "chase":
			if not valid_target:
				for unit: ClassicStudent in members:
					_release(unit)
				groups.erase(id)
				continue
			if group.team == 3 and not group.rolled and members.size() * 2 <= group.initial:
				group.rolled = true
				if sim.rng.randf() < 0.5:
					_retreat(sim, group, false)
					continue
			if group.team == 1:
				_orc_decide(sim, group, members[0])
			elif group.team == 2:
				for unit: ClassicStudent in members:
					_elf_recover(sim, unit)
		else:
			if group.team == 1:
				if sim.ticks >= members[0].ai_flee_until:
					if valid_target:
						_chase(sim, group)
					else:
						_release(members[0])
						groups.erase(id)
				continue
			if group.heal and (not sim.area_at.has(group.goal) or sim.areas[sim.area_at[group.goal]].owner != group.team):
				_retreat(sim, group, true)
				continue
			var done: bool = true
			for unit: ClassicStudent in members:
				if Vector2i(unit.cell.x / 4, unit.cell.y / 4) != group.goal or unit.state == ClassicStudent.State.WALK or (group.heal and unit.health < unit.maximum_health * group.recover):
					done = false
			if done:
				for unit: ClassicStudent in members:
					_release(unit)
				groups.erase(id)

func _elf_recover(sim, unit: ClassicStudent) -> void:
	var expert: bool = sim.difficulty == sim.Difficulty.EXPERT
	if unit.health > unit.maximum_health * 0.2 or (not expert and unit.health == unit.maximum_health * 0.2) or (expert and sim.ticks < unit.ai_heal_ready_at):
		return
	var goal: Vector2i = _healing_goal(sim, unit, 10 if expert else 100000)
	if goal.x < 0:
		return
	var id: int = next_id
	next_id += 1
	var group: Dictionary = {"id": id, "team": 2, "members": [{"unit": unit, "life": unit.lifetime}], "initial": 1, "target": unit, "target_life": unit.lifetime, "mode": "retreat", "rolled": true, "goal": goal, "heal": true, "recover": 1.0 if expert else 0.8, "recovery": true}
	groups[id] = group
	unit.ranged_response_id = id
	if expert:
		unit.ai_heal_ready_at = sim.ticks + 45 * ClassicRules.TICKS_PER_SECOND
	_retreat(sim, group, true, goal)
