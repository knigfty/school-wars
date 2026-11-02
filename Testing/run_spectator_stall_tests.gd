extends SceneTree
var failures: int = 0
func _initialize() -> void:
	call_deferred("_run")
func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _fixture(mode: int) -> ClassicSimulation:
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
	return sim
func _unit(sim: ClassicSimulation, id: int, race: int, cell: Vector2i) -> ClassicStudent:
	var unit: ClassicStudent = sim.students[id]
	sim._initialize_student(unit, race, cell)
	unit.ai_spawn_wait = false
	unit.state = ClassicStudent.State.SIT
	return unit
func _run() -> void:
	_test_interrupted_returns()
	for mode: int in 3:
		var sim: ClassicSimulation = _fixture(mode)
		var elf: ClassicStudent = _unit(sim, 0, 2, Vector2i(20, 20))
		var shooter: ClassicStudent = _unit(sim, 10, 0, Vector2i(26, 20))
		shooter.level = 21
		shooter.state = ClassicStudent.State.STAND
		shooter.counter = 100000
		shooter.tile_guard_active = false
		var group: Dictionary = {"id": 0, "team": 2, "members": [{"unit":elf,"life":elf.lifetime}], "initial":1,"target":shooter,"target_life":shooter.lifetime,"mode":"retreat","rolled":false,"goal":Vector2i(8,5),"heal":false,"recover":1.0}
		sim.ranged_response.groups[0] = group
		elf.ranged_response_id = 0
		_unit(sim, 1, 2, Vector2i(21, 20))
		_unit(sim, 2, 2, Vector2i(20, 21))
		sim.ranged_response._retreat(sim, group, false, Vector2i(8, 5))
		elf.destination = Vector2i(33, 21)
		for tick: int in 500:
			sim.step()
		_check(Vector2i(elf.cell.x / 4, elf.cell.y / 4) == Vector2i(8,5) and not sim.ranged_response.active(elf), "Blocked retreat detours and completes instead of remaining locked idle")
		_check(elf.state != ClassicStudent.State.WALK and sim.occupancy.get(elf.cell, -1) == elf.id, "Retreat survivor has valid occupancy and is targetable while stationary")
		var hunter: ClassicStudent = _unit(sim, 11, 3, elf.cell + Vector2i.RIGHT)
		sim._face_target(hunter, elf)
		_check(is_equal_approx(sim.get_hit_chance(hunter, elf), 0.9), "Recovered retreat survivor remains eligible for ordinary melee hits")
		var before: float = elf.health
		sim._apply_hit(hunter, elf)
		_check(elf.health < before, "Retreat survivor can still take damage")
	# Expert endgame: all objectives owned, last enemy outside local awareness.
	var sim: ClassicSimulation = _fixture(ClassicSimulation.Difficulty.EXPERT)
	sim.ai_enabled = true
	sim.active.assign([false, false, true, true])
	var demon: ClassicStudent = _unit(sim, 0, 3, Vector2i(10, 10))
	demon.health = 10000
	demon.maximum_health = 10000
	var elf: ClassicStudent = _unit(sim, 1, 2, Vector2i(50, 50))
	elf.health = 1
	sim._add_area(Vector2i(2,2), ClassicRules.AreaKind.RECRUIT, 3)
	sim.squad_ai._plan_expert(sim, [demon], Vector2(demon.cell))
	_check(demon.designated_tile == Vector2i(12,12), "Expert army advances toward distant survivor when no objectives remain")
	for tick: int in 3000:
		sim.step()
		if sim.finished:
			break
	_check(sim.finished and sim.get_winner_team() == 3, "Spectator endgame reaches and defeats the distant final survivor")
	print("Spectator stall tests: %d failure(s)" % failures)
	quit(1 if failures else 0)

func _test_interrupted_returns() -> void:
	for mode: int in 3:
		for race: int in [0, 1, 2, 3]:
			var sim: ClassicSimulation = _fixture(mode)
			var unit: ClassicStudent = _unit(sim, 0, race, Vector2i(46, 37))
			unit.maximum_health = 31
			sim.designate_order(unit, Vector2i(10, 9))
			unit.returning_to_tile = true
			unit.state = ClassicStudent.State.STAND
			unit.counter = 0
			# This is the observed stalled state: a return outside the one-tile leash.
			for frame: int in 80:
				for substep: int in 8:
					sim.step()
			_check(not unit.returning_to_tile and Vector2i(unit.cell.x / 4, unit.cell.y / 4) == Vector2i(10, 9), "Interrupted distant return resumes at 8x on every difficulty and race")
			_check(unit.state != ClassicStudent.State.WALK and sim.occupancy.get(unit.cell, -1) == unit.id, "Returned unit finishes its walk and retains combat occupancy")
		# Returning ranged elves must route home instead of repeatedly reacquiring a target.
		var sim: ClassicSimulation = _fixture(mode)
		var elf: ClassicStudent = _unit(sim, 0, 2, Vector2i(46, 37))
		elf.maximum_health = 37
		var enemy: ClassicStudent = _unit(sim, 1, 3, Vector2i(43, 37))
		enemy.health = 10000
		enemy.maximum_health = 10000
		enemy.counter = 10000
		sim.designate_order(elf, Vector2i(10, 9))
		sim._return_to_designated(elf)
		_check(elf.state == ClassicStudent.State.WALK and elf.target_id == -1, "Ranged return reserves a movement step instead of reacquiring the old target")
		for tick: int in 100:
			sim.step()
		_check(not elf.returning_to_tile, "Ranged return completes even with an enemy on its destination tile")
