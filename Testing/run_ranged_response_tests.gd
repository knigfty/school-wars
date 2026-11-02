extends SceneTree
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _fixture(race: int, mode: int) -> ClassicSimulation:
	var sim: ClassicSimulation = ClassicSimulation.new()
	sim.medieval = true
	sim.setup(0 if race in [2, 3] else 2, 123)
	sim.ai_enabled = false
	sim.difficulty = mode
	sim.ticks = 1000
	for unit: ClassicStudent in sim.students:
		unit.state = ClassicStudent.State.UNUSED
	sim.occupancy.clear()
	sim.areas.clear()
	sim.area_at.clear()
	for id: int in 4:
		sim._initialize_student(sim.students[id], race, Vector2i(20 + id, 20))
		sim.students[id].ai_spawn_wait = false
		sim.students[id].state = ClassicStudent.State.SIT
	sim._initialize_student(sim.students[10], sim.player_team, Vector2i(26, 20))
	var shooter: ClassicStudent = sim.students[10]
	shooter.level = 21
	shooter.maximum_health = 67
	shooter.health = 67
	shooter.state = ClassicStudent.State.FIGHT
	shooter.target_id = 0
	sim._add_area(Vector2i(5, 5), ClassicRules.AreaKind.RECRUIT, race)
	sim._add_area(Vector2i(8, 8), ClassicRules.AreaKind.HEAL, race)
	return sim

func _seed(roll_low: bool) -> int:
	for value: int in 100:
		var probe: RandomNumberGenerator = RandomNumberGenerator.new()
		probe.seed = value
		if (probe.randf() < 0.5) == roll_low:
			return value
	return 0

func _run() -> void:
	for mode: int in 3:
		var human_sim: ClassicSimulation = _fixture(0, mode)
		human_sim.ranged_response.on_hit(human_sim, human_sim.students[0], human_sim.students[10])
		_check(human_sim.ranged_response.groups.is_empty(), "Ranged hits do not create unlimited human pursuit")
		_demons(mode)
		_orcs(mode)
		_lifecycle(mode)
	print("Ranged response tests: %d failure(s)" % failures)
	quit(1 if failures else 0)

func _demons(mode: int) -> void:
	for flee: bool in [false, true]:
		var sim: ClassicSimulation = _fixture(3, mode)
		sim._apply_hit(sim.students[10], sim.students[0])
		var group: Dictionary = sim.ranged_response.groups[sim.students[0].ranged_response_id]
		_check(group.mode == "chase", "Demon group always starts by pursuing")
		sim.students[0].state = ClassicStudent.State.DEAD
		sim.ranged_response.update(sim)
		_check(not group.rolled, "One loss out of four does not trigger demon flee roll")
		sim.students[1].state = ClassicStudent.State.DEAD
		sim.rng.seed = _seed(flee)
		sim.ranged_response.update(sim)
		_check(group.rolled and group.mode == ("retreat" if flee else "chase"), "Half-loss demon decision has both seeded 50 percent outcomes")
		for id: int in [2, 3]:
			_check(sim.students[id].ai_retreating == flee, "Demon survivors flee or fight together")
		sim.rng.seed = _seed(not flee)
		sim.ranged_response.update(sim)
		_check(group.mode == ("retreat" if flee else "chase"), "Demon casualty decision is not rerolled")

func _orcs(mode: int) -> void:
	var sim: ClassicSimulation = _fixture(1, mode)
	sim._apply_hit(sim.students[10], sim.students[0])
	var orc: ClassicStudent = sim.students[0]
	var group: Dictionary = sim.ranged_response.groups[orc.ranged_response_id]
	_check(group.mode == "chase" and sim.students[1].ranged_response_id == -1, "Orc chooses pursuit individually")
	# Fewer attackers than nearby orcs; low HP independently permits escape.
	orc.health = 1
	sim.ranged_response.update(sim)
	_check(group.mode == "retreat" and orc.ai_flee_until == sim.ticks + 180 and orc.ai_flee_ready_at == 0 and orc.ai_flee_cooldown_pending, "Low-HP orc flees with cooldown pending until sitting")
	_check(is_equal_approx(sim.get_movement_multiplier(orc), 1.3), "Response flee keeps orc speed boost")
	sim.ticks = orc.ai_flee_until
	sim.ranged_response.update(sim)
	_check(not sim.ranged_response.active(orc) and not orc.ai_retreating and orc.tile_guard_active, "Orc finishes fleeing with its new tile assignment")
	orc.state = ClassicStudent.State.SIT
	sim.orc_flee.update(sim, orc)
	orc.designated_tile = Vector2i(orc.cell.x / 4, orc.cell.y / 4)
	sim.ranged_response.on_hit(sim, orc, sim.students[10])
	_check(not orc.ai_retreating, "Cooldown forbids another low-HP flee")
	# New isolated defender faces two attackers exactly two tile steps away.
	sim = _fixture(1, mode)
	for id: int in [1, 2, 3]:
		sim.students[id].state = ClassicStudent.State.UNUSED
	sim.students[10].cell = Vector2i(28, 20)
	sim._initialize_student(sim.students[11], sim.player_team, Vector2i(20, 28))
	sim.students[11].state = ClassicStudent.State.FIGHT
	sim.students[11].target_id = 0
	sim._apply_hit(sim.students[10], sim.students[0])
	_check(sim.students[0].ai_retreating, "Orc detects outnumbering at exact two-tile boundary")
	# Distant attackers outside the scan must not cause escape.
	sim = _fixture(1, mode)
	for id: int in [1, 2, 3]:
		sim.students[id].state = ClassicStudent.State.UNUSED
	sim.students[10].cell = Vector2i(32, 20)
	sim._initialize_student(sim.students[11], sim.player_team, Vector2i(20, 32))
	sim.students[11].state = ClassicStudent.State.FIGHT
	sim.students[11].target_id = 0
	sim._apply_hit(sim.students[10], sim.students[0])
	_check(not sim.students[0].ai_retreating, "Orc ignores attackers outside two-tile scan")


func _lifecycle(mode: int) -> void:
	var sim: ClassicSimulation = _fixture(3, mode)
	sim.students[0].health = 1
	sim._apply_hit(sim.students[10], sim.students[0])
	var group: Dictionary = sim.ranged_response.groups[sim.students[1].ranged_response_id]
	_check(sim.students[0].state == ClassicStudent.State.DEAD and group.initial == 4, "Lethal opening hit preserves original demon group count")
	_check(sim.students[1].priority_target_id == 10, "Survivors respond even when first ranged victim dies")
	# A replacement lifetime cannot inherit the old group commitment.
	sim._initialize_student(sim.students[0], 3, Vector2i(21, 21))
	_check(not sim.ranged_response.active(sim.students[0]) and sim.ranged_response._members(group).size() == 3, "Recruits cannot change original response membership")
	sim = _fixture(0, mode)
	sim._initialize_student(sim.students[5], 0, Vector2i(21, 21))
	sim.students[5].state = ClassicStudent.State.WALK
	sim.students[5].designated_tile = Vector2i(10, 10)
	sim._apply_hit(sim.students[10], sim.students[0])
	_check(sim.ranged_response.groups.is_empty(), "Human ranged defence cannot create a cross-tile pursuit or retreat group")
	_check(sim.students[5].ranged_response_id == -1, "Unrelated human travellers retain their own orders")
