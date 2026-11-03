extends SceneTree
var failures: int = 0
func _initialize() -> void:
	call_deferred("_run")
func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _fixture(mode: int, race: int) -> ClassicSimulation:
	var sim := ClassicSimulation.new()
	sim.medieval = true
	sim.difficulty = mode
	sim.setup(1, 123)
	for unit: ClassicStudent in sim.students:
		unit.state = ClassicStudent.State.UNUSED
	sim.occupancy.clear()
	sim.areas.clear()
	sim.area_at.clear()
	sim._initialize_student(sim.students[0], race, Vector2i(20, 20))
	sim.students[0].state = ClassicStudent.State.SIT
	sim.students[0].ai_spawn_wait = false
	sim._initialize_student(sim.students[1], 1, Vector2i(23, 20))
	sim.students[1].state = ClassicStudent.State.WALK
	sim.students[1].previous_cell = Vector2i(24, 20)
	return sim
func _run() -> void:
	_test_demon_territorial_awareness()
	_test_blocking_retreat()
	for mode: int in 3:
		for race: int in [0, 2, 3]:
			var sim := _fixture(mode, race)
			var unit: ClassicStudent = sim.students[0]
			var victim: ClassicStudent = sim.students[1]
			if race == 2:
				unit.maximum_health = 29
			elif race == 0:
				unit.level = 3
			sim.proximity_ai.update(sim)
			_check(unit.target_id == victim.id and sim.proximity_ai.active(unit), "Passing enemy is intercepted on every difficulty")
			_check(unit.priority_target_id == victim.id, "Proximity commitment overrides strategic goals")
			# Reposition the committed target far beyond detection.
			sim.occupancy.erase(victim.cell)
			victim.cell = Vector2i(40, 40)
			sim.occupancy[victim.cell] = victim.id
			sim.proximity_ai.update(sim)
			_check(sim.proximity_ai.active(unit) == (race == 3), "Only demons retain unlimited pursuit after enemy leaves")
			if race == 0:
				_check(not unit.returning_to_tile, "Human interception releases without a special encounter-tile leash")
			if race == 3:
				victim.state = ClassicStudent.State.DEAD
				sim.proximity_ai.update(sim)
				_check(not sim.proximity_ai.active(unit), "Demon pursuit ends when target dies")
		var sim := _fixture(mode, 0)
		sim.proximity_ai.update(sim)
		_check(not sim.proximity_ai.active(sim.students[0]), "Human ignores enemies outside current reach")
		sim.students[1].cell = Vector2i(21,20)
		sim.proximity_ai.update(sim)
		_check(sim.proximity_ai.active(sim.students[0]), "Human intercepts enemies inside current reach on every difficulty")
		sim = _fixture(mode, 2)
		var elf: ClassicStudent = sim.students[0]
		var enemy: ClassicStudent = sim.students[1]
		enemy.cell = Vector2i(21, 20)
		elf.state = ClassicStudent.State.WALK
		elf.previous_cell = Vector2i(19, 20)
		elf.walk_tick = 2
		sim.proximity_ai.update(sim)
		_check(elf.state == ClassicStudent.State.WALK and elf.walk_tick == 2, "Moving elf preserves reserved step before attacking")
		sim._walking(elf)
		sim._walking(elf)
		sim._walking(elf)
		sim._walking(elf)
		_check(elf.state == ClassicStudent.State.FIGHT and sim.get_hit_chance(elf, enemy) > 0, "Elf can attack a moving enemy even at base reach")
		sim.proximity_ai.engagements.clear()
		elf.ai_elf_recovering = true
		elf.ai_retreating = false
		elf.target_id = -1
		sim.proximity_ai.update(sim)
		_check(not sim.proximity_ai.active(elf) and elf.target_id == -1, "Healing elves do not initiate proximity attacks")
	print("Proximity AI tests: %d failure(s)" % failures)
	quit(1 if failures else 0)

func _test_blocking_retreat() -> void:
	for mode: int in 3:
		var sim := _fixture(mode, 3)
		var demon: ClassicStudent = sim.students[0]
		var primary: ClassicStudent = sim.students[1]
		sim.proximity_ai.update(sim)
		primary.cell = Vector2i(40, 40)
		demon.state = ClassicStudent.State.STAND
		demon.previous_cell = demon.cell
		var blocker: ClassicStudent = sim.students[2]
		sim._initialize_student(blocker, 2, demon.cell + Vector2i.RIGHT)
		blocker.state = ClassicStudent.State.WAIT
		blocker.ai_retreating = true
		blocker.ai_elf_recovering = true
		blocker.health = 100
		blocker.maximum_health = 100
		for tick: int in 60:
			sim.ticks += 1
			sim.proximity_ai.update(sim)
			if demon.state == ClassicStudent.State.FIGHT:
				sim._fighting(demon)
		_check(blocker.health < 100, "Demon damages adjacent retreating blocker while primary pursuit is distant")
		_check(sim.proximity_ai.engagements[demon.id].target == primary.id, "Clearing blocker retains original pursuit commitment")
		blocker.state = ClassicStudent.State.DEAD
		sim.proximity_ai.update(sim)
		_check(demon.priority_target_id == primary.id, "Demon resumes original pursuit after blocker dies")


func _test_demon_territorial_awareness() -> void:
	for mode: int in 3:
		for eliminated: int in 3:
			for owned: bool in [false, true]:
				for inside: bool in [false, true]:
					var sim := _fixture(mode, 3)
					sim.active.assign([true, true, true, true])
					for race: int in eliminated:
						sim.active[race] = false
					var radius: int = 16 * (1 << eliminated)
					_check(sim.get_demon_awareness_radius() == radius, "Demon awareness doubles only for eliminated rivals")
					var demon: ClassicStudent = sim.students[0]
					var enemy: ClassicStudent = sim.students[1]
					demon.cell = Vector2i(0, 0)
					enemy.cell = Vector2i(radius if inside else radius + 1, 0) if radius < 64 else Vector2i(63, 11 if inside else 12)
					var tile := Vector2i(enemy.cell.x / 4, enemy.cell.y / 4)
					sim.areas.append({"tile": tile, "owner": 3 if owned else 2, "kind": ClassicRules.AreaKind.HEAL})
					sim.area_at[tile] = 0
					sim.proximity_ai.update(sim)
					_check(sim.proximity_ai.active(demon) == (owned and inside), "All difficulties acquire owned-objective intruders only within scaled straight-line radius")
