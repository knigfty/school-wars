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
		sim.elf_recovery.update(sim,elf)
		_check(not elf.ai_elf_recovering, "Exactly 30% HP does not trigger retreat")
		elf.health = 2
		# Nearby enemies no longer invalidate the nearest owned healing tile.
		sim._initialize_student(sim.students[1],3,Vector2i(20,24))
		sim.elf_recovery.update(sim,elf)
		_check(elf.ai_heal_tile == Vector2i(5,6) and elf.ai_retreating, "Nearest owned heart chosen even when contested")
		_check(elf.ai_heal_ready_at == 0, "Cooldown does not start at departure")
		_check(sim.get_movement_multiplier(elf) == 0.7, "Retreat speed retained")
		var start: int = sim.ticks
		sim.areas[0].owner = 3
		sim.elf_recovery.update(sim,elf)
		_check(elf.ai_heal_tile == Vector2i(12,12) and elf.ai_elf_retreat_started_at == start, "Ownership loss retargets without resetting deadline")
		sim.areas[1].owner = 3
		sim.elf_recovery.update(sim,elf)
		_check(elf.ai_heal_tile.x < 0 and elf.ai_retreating, "No healing tile retains retreat only until deadline")
		sim.ticks = start+20*18-1
		sim.elf_recovery.update(sim,elf)
		_check(elf.ai_retreating, "Travel continues just before twenty seconds")
		sim.ticks += 1
		sim.elf_recovery.update(sim,elf)
		_check(not elf.ai_retreating and not elf.ai_elf_recovering and elf.ai_heal_ready_at == sim.ticks+30*18, "Timeout starts thirty-second cooldown")
		sim.elf_recovery.update(sim,elf)
		_check(not elf.ai_elf_recovering, "Low HP does not immediately restart timed-out retreat")
		# Arrival starts cooldown; healing remains committed until full HP.
		sim = _fixture(mode)
		elf = sim.students[0]
		elf.health = 2
		sim.elf_recovery.begin(sim,elf)
		sim.occupancy.erase(elf.cell)
		elf.cell = Vector2i(20,24)
		elf.previous_cell = elf.cell
		elf.state = ClassicStudent.State.SIT
		sim.occupancy[elf.cell] = elf.id
		sim.ticks = 20*18
		sim.elf_recovery.update(sim,elf)
		_check(elf.ai_elf_arrived and not elf.ai_retreating and elf.ai_heal_ready_at == sim.ticks+30*18, "Arrival at deadline wins over timeout")
		var ready: int = elf.ai_heal_ready_at
		sim.ticks += 1000
		sim.elf_recovery.update(sim,elf)
		_check(elf.ai_elf_recovering, "Arrival recovery remains committed beyond travel deadline")
		elf.health = elf.maximum_health
		sim.elf_recovery.update(sim,elf)
		_check(not elf.ai_elf_recovering and elf.ai_heal_ready_at == ready, "Full healing releases without restarting cooldown")
	print("Elf recovery tests: %d failure(s)" % failures)
	quit(1 if failures else 0)
