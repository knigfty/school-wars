extends SceneTree
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _fixture(mode: int, player: int) -> ClassicSimulation:
	var sim: ClassicSimulation = ClassicSimulation.new()
	sim.medieval = true
	sim.setup(player, 123)
	sim.ai_enabled = false
	sim.difficulty = mode
	for unit: ClassicStudent in sim.students:
		unit.state = ClassicStudent.State.UNUSED
	sim.occupancy.clear()
	sim.areas.clear()
	sim.area_at.clear()
	return sim

func _unit(sim: ClassicSimulation, id: int, race: int, cell: Vector2i, reach: int = 1) -> ClassicStudent:
	var unit: ClassicStudent = sim.students[id]
	sim._initialize_student(unit, race, cell)
	unit.ai_spawn_wait = false
	unit.state = ClassicStudent.State.SIT
	if race == 2:
		unit.maximum_health = 25 + (2 * (reach - 1) if reach <= 3 else (4 + 3 * (reach - 3) if reach <= 5 else 10 + 4 * (reach - 5)))
	elif race == 0:
		unit.level = 3 * ((reach - 1) / 2)
	return unit

func _run() -> void:
	for mode: int in 3:
		for race: int in [0, 2]:
			for player: int in [race, 3]:
				_defence(mode, race, player)
				_approach(mode, race, player)
		_retaliation(mode)
	print("Ranged tile tests: %d failure(s)" % failures)
	quit(1 if failures else 0)

func _defence(mode: int, race: int, player: int) -> void:
	var sim: ClassicSimulation = _fixture(mode, player)
	var unit: ClassicStudent = _unit(sim, 0, race, Vector2i(22, 20), 7)
	sim._add_area(Vector2i(5, 5), ClassicRules.AreaKind.RECRUIT, race)
	var enemy: ClassicStudent = _unit(sim, 1, 1, Vector2i(28, 20))
	enemy.health = 1000
	sim.designate_order(unit, Vector2i(5, 5))
	sim._update_tile_order(unit)
	_check(unit.target_id == enemy.id and unit.state == ClassicStudent.State.FIGHT, "Ranged guard fires at distant enemy beyond adjacent tile")
	_check(unit.cell == Vector2i(22, 20) and sim._may_engage(unit, enemy), "Ranged defence stays on home tile")
	# Move victim past reach: guard must not take a chase step.
	sim.occupancy.erase(enemy.cell)
	enemy.cell = Vector2i(35, 20)
	sim.occupancy[enemy.cell] = enemy.id
	sim._update_tile_order(unit)
	_check(unit.target_id == -1 and unit.cell == Vector2i(22, 20), "Ranged guard drops out-of-reach victim without chasing")
	# Ordinary ground is also a valid idle defensive position.
	sim.areas.clear()
	sim.area_at.clear()
	enemy.cell = Vector2i(28, 20)
	sim._update_tile_order(unit)
	_check(unit.target_id == enemy.id and unit.cell == Vector2i(22, 20), "Idle ranged defence works without an owned objective")

func _approach(mode: int, race: int, player: int) -> void:
	var sim: ClassicSimulation = _fixture(mode, player)
	var unit: ClassicStudent = _unit(sim, 0, race, Vector2i(16, 20), 7)
	var enemy: ClassicStudent = _unit(sim, 1, 1, Vector2i(22, 20))
	enemy.health = 1000
	var weak: ClassicStudent = _unit(sim, 2, 1, Vector2i(23, 23))
	weak.health = 1
	sim._add_area(Vector2i(5, 5), ClassicRules.AreaKind.RECRUIT, -1)
	sim.designate_order(unit, Vector2i(5, 5))
	sim.start_walk(unit, Vector2i(5, 5))
	_check(unit.state == ClassicStudent.State.FIGHT and unit.target_id == enemy.id and unit.cell == Vector2i(16, 20), "Tile order opens fire from range before entering destination")
	sim._update_tile_order(unit)
	_check(unit.target_id == enemy.id, "Reachable victim takes priority over unreachable weaker victim")
	var start: Vector2i = unit.cell
	for step: int in 10:
		sim.step()
	_check(unit.cell == start and unit.state == ClassicStudent.State.FIGHT, "Full battle clock preserves standoff position")
	_check(sim.areas[0].progress[race] == 0, "Outside ranged combat does not capture destination")
	enemy.state = ClassicStudent.State.UNUSED
	weak.state = ClassicStudent.State.UNUSED
	sim.occupancy.erase(enemy.cell)
	sim.occupancy.erase(weak.cell)
	sim._update_tile_order(unit)
	_check(unit.returning_to_tile and unit.designated_tile == Vector2i(5, 5), "Clearing enemies resumes travel to capture tile")

func _retaliation(mode: int) -> void:
	var sim: ClassicSimulation = _fixture(mode, 2)
	var elf: ClassicStudent = _unit(sim, 0, 2, Vector2i(22, 20), 7)
	var enemy: ClassicStudent = _unit(sim, 1, 0, Vector2i(28, 20))
	enemy.health = 100
	sim._add_area(Vector2i(7, 5), ClassicRules.AreaKind.BASE, 0)
	sim._apply_hit(elf, enemy)
	_check(enemy.ranged_pursuit_id == -1 and not sim.proximity_ai.active(enemy), "Distant ranged hit does not create unlimited human pursuit")
	_check(not sim._may_engage(enemy, elf), "Human cannot pursue distant shooter outside its tile")
	_check(not sim._update_base_defence(enemy), "Counter-pursuit is not relocked by base defence")
	elf.cell = Vector2i(10, 20)
	_check(not sim._may_engage(enemy, elf), "Human does not follow shooter beyond local encounter")
	# Melee guards on ordinary ground also retaliate across a cell-adjacent edge.
	var guard: ClassicStudent = _unit(sim, 2, 2, Vector2i(23, 30))
	var hitter: ClassicStudent = _unit(sim, 3, 1, Vector2i(24, 30))
	sim._apply_hit(hitter, guard)
	sim._update_tile_order(guard)
	_check(guard.target_id == hitter.id and guard.state == ClassicStudent.State.FIGHT and guard.cell == Vector2i(23, 30), "Idle melee defender retaliates without needing owned ground")
	# A current retreat is not cancelled by an incoming ranged hit.
	enemy.ai_retreating = true
	sim._apply_hit(elf, enemy)
	_check(enemy.ai_retreating, "Enemy can keep its existing retreat decision under ranged fire")
	# Player ranged defenders remember their shooter and return fire while holding.
	enemy.ai_retreating = false
	enemy.level = 9
	enemy.cell = Vector2i(28, 20)
	elf.cell = Vector2i(22, 20)
	elf.state = ClassicStudent.State.SIT
	sim._apply_hit(enemy, elf)
	_check(elf.tile_guard_target == enemy.id and elf.target_id == enemy.id and elf.state == ClassicStudent.State.FIGHT, "Idle player ranged defender returns fire immediately")
	sim._update_tile_order(elf)
	_check(elf.target_id == enemy.id and elf.cell == Vector2i(22, 20), "Return fire persists on next guard update")
