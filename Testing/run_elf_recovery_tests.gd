extends SceneTree
var failures: int = 0
func _initialize() -> void:
	call_deferred("_run")
func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _fixture(mode: int) -> ClassicSimulation:
	var sim := ClassicSimulation.new()
	sim.medieval = true
	sim.difficulty = mode
	sim.setup(0, 123, true)
	for unit: ClassicStudent in sim.students:
		unit.state = ClassicStudent.State.UNUSED
	sim.occupancy.clear()
	sim.areas.clear()
	sim.area_at.clear()
	sim._initialize_student(sim.students[0], 2, Vector2i(20, 20))
	sim.students[0].state = ClassicStudent.State.SIT
	sim.students[0].ai_spawn_wait = false
	sim.students[0].health = 7.5
	sim._add_area(Vector2i(5, 6), ClassicRules.AreaKind.HEAL, 2)
	sim._add_area(Vector2i(12, 12), ClassicRules.AreaKind.BASE, 2)
	return sim
func _run() -> void:
	for mode: int in 3:
		var sim := _fixture(mode)
		var elf: ClassicStudent = sim.students[0]
		sim.elf_recovery.update(sim, elf)
		_check(not elf.ai_elf_recovering, "Exactly thirty percent does not trigger retreat")
		elf.health = 7.4
		sim._initialize_student(sim.students[1], 3, Vector2i(20, 24))
		sim.students[1].state = ClassicStudent.State.SIT
		sim.students[1].counter = 10000
		sim.elf_recovery.update(sim, elf)
		_check(elf.ai_heal_tile == Vector2i(12, 12) and elf.ai_retreating, "All difficulties choose distant safe base over contested nearby heart")
		_check(elf.ai_heal_ready_at == 0, "Travel does not start cooldown")
		_check(is_equal_approx(sim.get_movement_multiplier(elf), 0.7), "Retreat speed reduced by thirty percent")
		# Losing every healing tile retains retreat; a recovered goal resumes it.
		sim.areas[1].owner = 3
		sim.elf_recovery.update(sim, elf)
		_check(elf.ai_elf_recovering and elf.ai_retreating and elf.ai_heal_tile.x < 0, "No safe goal does not cancel an active retreat")
		sim.areas[1].owner = 2
		sim.elf_recovery.update(sim, elf)
		_check(elf.ai_heal_tile == Vector2i(12, 12), "Safe goal becomes available again")
		# Complete travel with real simulation steps, eight per frame.
		sim.ai_enabled = false
		var arrival_tick: int = -1
		for frame: int in 180:
			for substep: int in 8:
				sim.elf_recovery.update(sim, elf)
				if elf.ai_elf_arrived and arrival_tick < 0:
					arrival_tick = sim.ticks
				sim.step()
			if elf.ai_elf_arrived:
				break
		_check(elf.ai_elf_arrived and not elf.ai_retreating, "Retreat reaches healing base at 8x")
		var arrival_ready: int = elf.ai_heal_ready_at
		_check(arrival_ready == arrival_tick + 30 * 18, "Thirty-second cooldown starts at arrival")
		_check(sim.get_movement_multiplier(elf) == 1.0, "Speed restored during stationary recovery")
		elf.health = 20
		sim.elf_recovery.update(sim, elf)
		_check(elf.ai_elf_recovering, "Recovery stays committed above eighty percent")
		var enemy: ClassicStudent = sim.students[1]
		sim.occupancy.erase(enemy.cell)
		enemy.cell = elf.cell + Vector2i.RIGHT
		sim.occupancy[enemy.cell] = enemy.id
		enemy.state = ClassicStudent.State.FIGHT
		enemy.target_id = elf.id
		elf.last_attacked_tick = sim.ticks
		var spot: Vector2i = elf.cell
		sim.elf_recovery.update(sim, elf)
		_check(elf.state == ClassicStudent.State.FIGHT and elf.target_id == enemy.id and elf.cell == spot, "Recovering elf retaliates from healing spot")
		_check(not sim.can_heal(elf), "Retaliation never activates healing")
		enemy.state = ClassicStudent.State.UNUSED
		sim.ticks += 54
		sim.elf_recovery.update(sim, elf)
		var before: float = elf.health
		sim._sitting(elf)
		_check(elf.health > before, "Safe seated recovery resumes after combat")
		elf.health = elf.maximum_health
		sim.elf_recovery.update(sim, elf)
		_check(not elf.ai_elf_recovering and elf.ai_heal_ready_at == arrival_ready, "Full HP releases recovery without restarting cooldown")
		elf.health = 1
		sim.elf_recovery.update(sim, elf)
		_check(not elf.ai_elf_recovering, "Arrival cooldown blocks new retreat")
		sim.ticks = arrival_ready
		sim.elf_recovery.update(sim, elf)
		_check(elf.ai_elf_recovering, "Retreat is available at exact cooldown boundary")
		var choices: Dictionary = {}
		for seed_value: int in 30:
			sim = _fixture(mode)
			elf = sim.students[0]
			elf.health = 25
			sim.rng.seed = seed_value
			sim.elf_recovery.threat(sim, elf, sim.students[1])
			choices[elf.ai_retreating] = true
			if not elf.ai_retreating:
				_check(elf.ai_hold_ground_until == sim.ticks + 54, "Fight choice holds three seconds")
		_check(choices.size() == 2, "Threatened defenders can choose fight or retreat on every difficulty")
	print("Elf recovery tests: %d failure(s)" % failures)
	quit(1 if failures else 0)
