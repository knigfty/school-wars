extends SceneTree
var failures: int = 0
func _initialize() -> void:
	call_deferred("_run")
func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _unit(sim: ClassicSimulation, id: int, race: int, cell: Vector2i) -> ClassicStudent:
	var unit: ClassicStudent = sim.students[id]
	sim._initialize_student(unit, race, cell)
	unit.ai_spawn_wait = false
	unit.state = ClassicStudent.State.SIT
	return unit
func _run() -> void:
	for mode: int in 3:
		var sim: ClassicSimulation = ClassicSimulation.new()
		sim.medieval = true
		sim.difficulty = mode
		sim.setup(0, 123, true)
		sim.ai_enabled = false
		for unit: ClassicStudent in sim.students:
			unit.state = ClassicStudent.State.UNUSED
		sim.occupancy.clear()
		sim.areas.clear()
		sim.area_at.clear()
		sim.ticks = 100
		var orc: ClassicStudent = _unit(sim, 0, 1, Vector2i(20,20))
		# Quadrant 3 is the only empty quadrant.
		_unit(sim, 1, 0, Vector2i(21,21))
		_unit(sim, 2, 2, Vector2i(40,20))
		_unit(sim, 3, 3, Vector2i(20,40))
		sim._add_area(Vector2i(9,9), ClassicRules.AreaKind.RECRUIT, -1)
		sim._add_area(Vector2i(14,14), ClassicRules.AreaKind.HEAL, -1)
		sim._add_area(Vector2i(3,3), ClassicRules.AreaKind.RECRUIT, -1)
		sim.orc_flee.begin(sim, orc)
		_check(orc.ai_flee_quadrant == 3 and orc.ai_flee_phase == 1 and orc.ai_flee_goal == Vector2i(12,12), "First half heads toward least-enemy quadrant")
		_check(orc.ai_flee_until == 280 and orc.ai_flee_ready_at == 640 and not orc.tile_guard_active, "Flee keeps ten-second duration, thirty-second cooldown, and travel-first behaviour")
		sim.ticks = 189
		sim.orc_flee.update(sim, orc)
		_check(orc.ai_flee_phase == 1, "Travel phase lasts until exact halfway point")
		# Occupied nearer target must lose to the empty farther target.
		_unit(sim, 4, 3, Vector2i(36,36))
		sim.ticks = 190
		sim.orc_flee.update(sim, orc)
		_check(orc.ai_flee_phase == 2 and orc.ai_flee_goal == Vector2i(14,14) and orc.tile_guard_active, "Second half selects uncontested capture tile inside chosen quadrant")
		_check(is_equal_approx(sim.get_movement_multiplier(orc), 1.3) and sim.get_retreat_text(orc) == "Flee!", "Speed boost and flee label cover both halves")
		# Move to objective and prove sitting still produces ordinary capture progress.
		sim.occupancy.erase(orc.cell)
		orc.cell = Vector2i(56,56)
		orc.previous_cell = orc.cell
		sim.occupancy[orc.cell] = orc.id
		orc.state = ClassicStudent.State.SIT
		sim._capture_areas()
		_check(sim.areas[sim.area_at[Vector2i(14,14)]].progress[1] > 0, "Phase-two fleeing orc can capture")
		sim.ticks = 280
		sim.orc_flee.update(sim, orc)
		_check(not orc.ai_retreating and orc.ai_flee_phase == 0 and orc.designated_tile == Vector2i(14,14), "Flee ends without restoring old enemy-base chase")
		_check(sim.get_movement_multiplier(orc) == 1 and sim.get_retreat_text(orc).is_empty(), "Flee effects expire exactly at window end")
		sim._initialize_student(orc,1,Vector2i(20,20))
		_check(orc.ai_flee_phase == 0 and orc.ai_flee_quadrant == -1, "Fresh lifetime resets itinerary")
	print("Orc flee tests: %d failure(s)" % failures)
	quit(1 if failures else 0)
