extends SceneTree
var failures: int = 0
func _initialize() -> void:
	call_deferred("_run")
func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _run() -> void:
	for mode: int in 3:
		for race: int in 4:
			var sim := ClassicSimulation.new()
			sim.medieval = true
			sim.difficulty = mode
			sim.setup(race,123)
			sim.ai_enabled = false
			for unit: ClassicStudent in sim.students:
				unit.state = ClassicStudent.State.UNUSED
			sim.occupancy.clear()
			var unit: ClassicStudent = sim.students[0]
			sim._initialize_student(unit,race,Vector2i(20,20))
			sim._initialize_student(sim.students[1],(race+1)%4,Vector2i(28,20))
			unit.tile_guard_active = false
			unit.priority_target_id = 1
			# A friendly wall leaves a backward detour: ordinary pursuit waits
			# instead of searching the map or reserving shared combat positions.
			for i: int in 3:
				sim._initialize_student(sim.students[i+2],race,unit.cell+[Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN][i])
			sim.start_walk(unit,Vector2i.ZERO,1)
			_check(unit.state == ClassicStudent.State.WAIT and unit.cell == Vector2i(20,20), "All Medieval races use ordinary pursuit without BFS detours")
			_check(unit.approach_cell == Vector2i(-1,-1) and unit.priority_target_id == 1, "No shared combat-position reservation; explicit target retained")
			for i: int in 3:
				sim.occupancy.erase(sim.students[i+2].cell)
				sim.students[i+2].state = ClassicStudent.State.UNUSED
			sim._start_turn(unit)
			for tick: int in 100:
				if unit.state == ClassicStudent.State.FIGHT:
					break
				sim._walking(unit)
			_check(unit.state == ClassicStudent.State.FIGHT and sim._within_attack_range(unit,sim.students[1]), "Ordinary pursuit still approaches and attacks")
			_check(unit.cell != sim.students[1].cell and sim.occupancy.get(unit.cell,-1) == unit.id, "Ordinary pursuit preserves occupied cells")
	print("Individual pursuit tests: %d failure(s)" % failures)
	quit(1 if failures else 0)
