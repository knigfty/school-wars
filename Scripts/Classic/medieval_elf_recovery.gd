extends RefCounted

## One recovery lifecycle for every AI difficulty. Cooldown begins on arrival.
func eligible(sim, unit: ClassicStudent) -> bool:
	return sim.medieval and unit.is_alive() and unit.team == 2 and unit.team != sim.player_team

func safe_tile(sim, tile: Vector2i) -> bool:
	if not sim.area_at.has(tile):
		return false
	var area: Dictionary = sim.areas[sim.area_at[tile]]
	if area.owner != 2 or area.kind == ClassicRules.AreaKind.RECRUIT:
		return false
	for enemy: ClassicStudent in sim.students:
		if enemy.is_alive() and enemy.team != 2 and Vector2i(enemy.cell.x / 4, enemy.cell.y / 4) == tile:
			return false
	return true

func nearest(sim, unit: ClassicStudent) -> Vector2i:
	var result := Vector2i(-1, -1)
	var best: int = 100000
	for area: Dictionary in sim.areas:
		if not safe_tile(sim, area.tile):
			continue
		var corner: Vector2i = area.tile * 4
		var distance: int = absi(unit.cell.x - clampi(unit.cell.x, corner.x, corner.x + 3)) + absi(unit.cell.y - clampi(unit.cell.y, corner.y, corner.y + 3))
		if distance < best:
			best = distance
			result = area.tile
	return result

func begin(sim, unit: ClassicStudent) -> bool:
	if sim.retaliation_ai.active(unit) or not eligible(sim, unit) or unit.ai_elf_recovering or sim.ticks < unit.ai_heal_ready_at:
		return false
	var goal: Vector2i = nearest(sim, unit)
	if goal.x < 0:
		return false
	sim.ranged_response._prepare(unit)
	unit.ranged_response_id = -1
	unit.ranged_pursuit_id = -1
	unit.priority_target_id = -1
	unit.target_id = -1
	unit.ai_elf_recovering = true
	unit.ai_retreating = true
	unit.ai_heal_tile = goal
	unit.ai_elf_arrived = false
	unit.ai_elf_retreat_started_at = sim.ticks
	update(sim, unit)
	return true

func threat(sim, unit: ClassicStudent, attacker: ClassicStudent) -> void:
	if sim.retaliation_ai.active(unit) or not eligible(sim, unit) or unit.ai_retreating or unit.ai_elf_recovering or not unit.tile_guard_active or sim.ticks < unit.ai_hold_ground_until:
		return
	if sim.rng.randf() < 0.5 and begin(sim, unit):
		return
	unit.ai_hold_ground_until = sim.ticks + 3 * ClassicRules.TICKS_PER_SECOND
	unit.tile_guard_target = attacker.id

func update(sim, unit: ClassicStudent) -> void:
	if sim.retaliation_ai.active(unit) or not eligible(sim, unit):
		return
	if not unit.ai_elf_recovering:
		if unit.health < unit.maximum_health * 0.3 and sim.ticks >= unit.ai_hold_ground_until:
			begin(sim, unit)
		return
	var tile := Vector2i(unit.cell.x / 4, unit.cell.y / 4)
	# Once at a healing spot, defend it locally even if an enemy enters it.
	var owned_healing: bool = sim.area_at.has(tile) and sim.areas[sim.area_at[tile]].owner == 2 and sim.areas[sim.area_at[tile]].kind != ClassicRules.AreaKind.RECRUIT
	if owned_healing and unit.state != ClassicStudent.State.WALK and (unit.ai_elf_arrived or safe_tile(sim, tile)):
		if not unit.ai_elf_arrived:
			unit.ai_heal_ready_at = sim.ticks + 30 * ClassicRules.TICKS_PER_SECOND
		unit.ai_elf_arrived = true
		unit.ai_elf_retreat_started_at = -1
		unit.ai_heal_tile = tile
		unit.ai_retreating = false
		if unit.health >= unit.maximum_health:
			unit.ai_elf_recovering = false
			unit.ai_elf_arrived = false
			sim.ranged_response._release(unit)
			return
		var attacker: ClassicStudent = null
		for enemy: ClassicStudent in sim.students:
			if enemy.is_alive() and enemy.team != 2 and enemy.target_id == unit.id and sim._within_attack_range(unit, enemy) and sim.ticks - unit.last_attacked_tick < 3 * ClassicRules.TICKS_PER_SECOND:
				if attacker == null or enemy.health < attacker.health:
					attacker = enemy
		if attacker != null:
			unit.target_id = attacker.id
			sim._face_target(unit, attacker)
			sim._start_fight(unit, attacker)
		elif unit.state != ClassicStudent.State.SIT:
			unit.target_id = -1
			unit.state = ClassicStudent.State.SIT
			unit.pattern = 13
			unit.counter = 40
		return
	if unit.ai_elf_arrived and not owned_healing:
		unit.ai_elf_arrived = false
		unit.ai_elf_retreat_started_at = sim.ticks
	if unit.ai_elf_retreat_started_at >= 0 and sim.ticks - unit.ai_elf_retreat_started_at >= 15 * ClassicRules.TICKS_PER_SECOND:
		unit.ai_elf_recovering = false
		unit.ai_elf_arrived = false
		unit.ai_elf_retreat_started_at = -1
		unit.ai_heal_tile = Vector2i(-1, -1)
		if unit.state == ClassicStudent.State.WALK:
			unit.destination = unit.cell # Finish only the already reserved step.
		# Reuse the existing fight decision hold, avoiding immediate low-HP restart.
		unit.ai_hold_ground_until = sim.ticks + 3 * ClassicRules.TICKS_PER_SECOND
		sim.ranged_response._release(unit)
		return
	unit.ai_retreating = true
	# A lost/contested goal is replaced, without releasing the retreat commitment.
	if not safe_tile(sim, unit.ai_heal_tile):
		unit.ai_heal_tile = nearest(sim, unit)
	if unit.ai_heal_tile.x < 0:
		if unit.state != ClassicStudent.State.WALK:
			unit.state = ClassicStudent.State.WAIT
			unit.counter = 2
		return
	unit.designated_tile = unit.ai_heal_tile
	unit.target_id = -1
	unit.priority_target_id = -1
	if unit.state not in [ClassicStudent.State.WALK, ClassicStudent.State.WAIT]:
		sim.start_walk(unit, unit.ai_heal_tile)
	elif unit.state == ClassicStudent.State.WALK:
		unit.destination = unit.ai_heal_tile * 4 + Vector2i(1, 1)
