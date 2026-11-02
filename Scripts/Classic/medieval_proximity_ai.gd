extends RefCounted

## Tick-level interception, independent of the slower strategic planner.
var engagements: Dictionary = {}

func active(unit: ClassicStudent) -> bool:
	return engagements.has(unit.id) and engagements[unit.id].life == unit.lifetime

func allows_cell(unit: ClassicStudent, cell: Vector2i) -> bool:
	return not active(unit) or unit.team != 0 or Vector2i(cell.x / 4, cell.y / 4) == engagements[unit.id].origin

func may_engage(sim, unit: ClassicStudent, target: ClassicStudent) -> bool:
	if not active(unit) or engagements[unit.id].target != target.id:
		return false
	if unit.team == 2:
		return sim._within_attack_range(unit, target)
	if unit.team == 3:
		return true
	var corner: Vector2i = engagements[unit.id].origin * 4
	var closest := Vector2i(clampi(target.cell.x, corner.x, corner.x + 3), clampi(target.cell.y, corner.y, corner.y + 3))
	return absi(closest.x - target.cell.x) + absi(closest.y - target.cell.y) <= sim.get_attack_range(unit)

func _release(sim, unit: ClassicStudent, record: Dictionary) -> void:
	engagements.erase(unit.id)
	unit.target_id = -1
	unit.priority_target_id = -1
	unit.ranged_pursuit_id = -1
	unit.ai_base_defence_tile = Vector2i(-1, -1)
	var goal: Vector2i = record.origin if unit.team == 0 else record.goal
	sim.designate_order(unit, goal)
	if unit.team == 0:
		# Return to the encounter tile before rejoining strategic squad orders.
		unit.returning_to_tile = true
	if unit.state != ClassicStudent.State.WALK:
		unit.state = ClassicStudent.State.STAND
	sim.start_walk(unit, goal)

func update(sim) -> void:
	for unit: ClassicStudent in sim.students:
		if not unit.is_alive() or unit.team == sim.player_team or unit.team == 1:
			engagements.erase(unit.id)
			continue
		if unit.ai_elf_recovering or (unit.team == 2 and unit.ai_retreating):
			engagements.erase(unit.id)
			continue
		if active(unit):
			var record: Dictionary = engagements[unit.id]
			var target: ClassicStudent = sim.students[record.target]
			if not target.is_alive() or target.lifetime != record.target_life or target.team == unit.team or not may_engage(sim, unit, target):
				_release(sim, unit, record)
				continue
		else:
			if unit.returning_to_tile or (unit.ai_spawn_wait and unit.state == ClassicStudent.State.STAND and unit.counter >= 0):
				continue
			var target: ClassicStudent = null
			var radius: int = sim.get_attack_range(unit) if unit.team == 2 else (maxi(3, sim.get_attack_range(unit)) if unit.team == 0 else 3)
			var best: int = radius + 1
			for enemy: ClassicStudent in sim.students:
				if not enemy.is_alive() or enemy.team == unit.team:
					continue
				var distance: int = absi(unit.cell.x - enemy.cell.x) + absi(unit.cell.y - enemy.cell.y)
				if distance < best:
					best = distance
					target = enemy
			if target == null:
				continue
			var origin := Vector2i(unit.cell.x / 4, unit.cell.y / 4)
			engagements[unit.id] = {"life": unit.lifetime, "target": target.id, "target_life": target.lifetime, "origin": origin, "goal": unit.designated_tile if unit.designated_tile.x >= 0 else origin}
			sim.ranged_response._prepare(unit)
			unit.ranged_response_id = -1
			unit.ai_retreating = false
		var target: ClassicStudent = sim.students[engagements[unit.id].target]
		unit.priority_target_id = target.id
		unit.target_id = target.id
		if unit.state == ClassicStudent.State.WALK:
			continue # Finish the reserved step, then fire or pursue normally.
		if unit.state == ClassicStudent.State.FIGHT:
			sim._face_target(unit, target)
		else:
			sim.start_walk(unit, Vector2i.ZERO, target.id)
