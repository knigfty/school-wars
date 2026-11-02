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
	for mode: int in 3:
		for race: int in [0, 2, 3]:
			var sim := _fixture(mode, race)
			var unit: ClassicStudent = sim.students[0]
			var victim: ClassicStudent = sim.students[1]
			if race == 2:
				unit.maximum_health = 29
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
				_check(unit.returning_to_tile and unit.designated_tile == Vector2i(5, 5), "Humans regroup at encounter tile")
			if race == 3:
				victim.state = ClassicStudent.State.DEAD
				sim.proximity_ai.update(sim)
				_check(not sim.proximity_ai.active(unit), "Demon pursuit ends when target dies")
		# Human routes cannot use a cell outside their encounter tile.
		var sim := _fixture(mode, 0)
		var human: ClassicStudent = sim.students[0]
		sim.proximity_ai.update(sim)
		_check(sim.proximity_ai.allows_cell(human, Vector2i(23, 23)) and not sim.proximity_ai.allows_cell(human, Vector2i(24, 23)), "Human encounter path is confined to its current tile")
		sim = _fixture(mode, 0)
		human = sim.students[0]
		human.level = 6 # Reach five; detection must extend beyond three cells.
		sim.students[1].cell = Vector2i(25, 20)
		sim.proximity_ai.update(sim)
		_check(sim.proximity_ai.active(human), "Upgraded human intercepts at its larger attack range")
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
