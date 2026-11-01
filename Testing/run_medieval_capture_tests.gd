extends SceneTree

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func _empty_sim() -> ClassicSimulation:
	var sim: ClassicSimulation = ClassicSimulation.new()
	sim.medieval = true
	sim.setup(0, 12345)
	sim.ai_enabled = false
	for unit: ClassicStudent in sim.students:
		unit.state = ClassicStudent.State.UNUSED
	sim.occupancy.clear()
	sim.areas.clear()
	sim.area_at.clear()
	return sim


func _seat(sim: ClassicSimulation, count: int, team: int, tile: Vector2i) -> void:
	for i: int in count:
		var unit: ClassicStudent = sim.students[i]
		unit.team = team
		unit.state = ClassicStudent.State.SIT
		unit.cell = tile * 4 + Vector2i(i % 4, i / 4)
		unit.previous_cell = unit.cell
		unit.counter = 10000
		unit.health = ClassicRules.HEALTH[team]
		unit.maximum_health = unit.health
		sim.occupancy[unit.cell] = unit.id


func _run() -> void:
	_contested_capture_tests()
	var durations: Array[int] = [12, 9, 6, 4, 2, 1, 1, 1, 1, 1, 1, 1]
	for count: int in range(1, 13):
		for kind: int in [ClassicRules.AreaKind.RECRUIT, ClassicRules.AreaKind.HEAL, ClassicRules.AreaKind.BASE]:
			var sim: ClassicSimulation = _empty_sim()
			var tile: Vector2i = Vector2i(5, 5)
			sim._add_area(tile, kind, 1 if kind == ClassicRules.AreaKind.BASE else -1)
			sim.active[1] = false
			_seat(sim, count, 0, tile)
			var ticks_needed: int = durations[count - 1] * 18
			for tick: int in ticks_needed - 1:
				sim._capture_areas()
			_check(sim.areas[0].owner != 0, "Human capture not early: count=%d kind=%d" % [count, kind])
			sim._capture_areas()
			_check(sim.areas[0].owner == 0, "Exact human capture time: count=%d kind=%d" % [count, kind])

	for team: int in range(1, 4):
		var sim: ClassicSimulation = _empty_sim()
		sim._add_area(Vector2i(5, 5), ClassicRules.AreaKind.RECRUIT, -1)
		_seat(sim, 3, team, Vector2i(5, 5))
		for tick: int in 99:
			sim._capture_areas()
		_check(sim.areas[0].owner == -1, "Other races retain 300 total seated ticks")
		sim._capture_areas()
		_check(sim.areas[0].owner == team, "Other races capture normally")

	var sim: ClassicSimulation = _empty_sim()
	sim._add_area(Vector2i(5, 5), ClassicRules.AreaKind.RECRUIT, -1)
	_seat(sim, 1, 0, Vector2i(5, 5))
	for tick: int in 108:
		sim._capture_areas()
	_check(is_equal_approx(sim.areas[0].progress[0], 150), "One human halfway after six seconds")
	_seat(sim, 6, 0, Vector2i(5, 5))
	for tick: int in 8:
		sim._capture_areas()
	_check(sim.areas[0].owner == -1, "Adding humans preserves normalized progress")
	sim._capture_areas()
	_check(sim.areas[0].owner == 0, "Six humans finish remaining half in half second")

	sim = _empty_sim()
	var tile: Vector2i = sim.bases[1]
	sim._add_area(tile, ClassicRules.AreaKind.BASE, 1)
	_seat(sim, 6, 0, tile)
	var enemy: ClassicStudent = sim.students[20]
	enemy.team = 1
	enemy.state = ClassicStudent.State.STAND
	for tick: int in 30:
		sim._capture_areas()
	_check(sim.areas[0].owner == 1 and sim.areas[0].progress[0] == 0, "Living owner locks base capture")
	enemy.state = ClassicStudent.State.DEAD
	sim.active[1] = false
	for tick: int in 30:
		sim._capture_areas()
	_check(sim.areas[0].owner == 1, "Unfinished death cleanup locks base")
	enemy.state = ClassicStudent.State.UNUSED
	for tick: int in 18:
		sim._capture_areas()
	_check(sim.areas[0].owner == 0, "Eliminated owner's base becomes capturable")
	_check(sim.areas[0].spawn_progress == 0, "Captured base starts fresh spawn cycle")
	_check(tile in sim.get_spawn_bases(0) and tile not in sim.get_spawn_bases(1), "Base belongs to new spawn team")
	_check(sim.can_capture_area(sim.areas[0], 2), "Conquered base can be contested while new owner lives")

	for unit: ClassicStudent in sim.students:
		unit.state = ClassicStudent.State.UNUSED
	sim.active[0] = true
	_seat(sim, 3, 2, tile)
	for tick: int in 100:
		sim._capture_areas()
	_check(sim.areas[0].owner == 2, "Base can be recaptured while new owner remains active")

	sim = _empty_sim()
	sim._add_area(Vector2i(5, 5), ClassicRules.AreaKind.RECRUIT, -1)
	_seat(sim, 6, 0, Vector2i(5, 5))
	for tick: int in 17:
		sim.step()
	_check(sim.areas[0].owner == -1, "Real simulation loop does not capture early")
	sim.step()
	_check(sim.areas[0].owner == 0, "Real simulation loop captures once per tick")

	sim = _empty_sim()
	sim._add_area(sim.bases[3], ClassicRules.AreaKind.BASE, 3)
	sim.active[3] = false
	_seat(sim, 1, 1, Vector2i(5, 5))
	var ai: ClassicStudent = sim.students[0]
	ai.idle_ticks = 500
	sim.leader = 2
	sim._com_order(ai)
	_check(ai.state != ClassicStudent.State.SIT, "AI pursues an eliminated base even during leader targeting")

	# Capacity stacks; the team interval stays unchanged and spawns rotate.
	for team: int in 4:
		for base_count: int in [2, 3, 4]:
			sim = _empty_sim()
			sim._add_area(sim.bases[team], ClassicRules.AreaKind.BASE, team)
			var original_seconds: float = sim.get_spawn_seconds(team)
			for n: int in range(1, base_count):
				sim._add_area(sim.bases[(team + n) % 4], ClassicRules.AreaKind.BASE, team)
			_check(sim.get_team_capacity(team) == 12 + (base_count - 1) * 6, "Captured bases retain capacity bonus")
			_check(is_equal_approx(sim.get_spawn_seconds(team), original_seconds), "Extra bases never accelerate spawning")
			for turn: int in base_count * 2:
				var expected: Vector2i = sim.areas[turn % base_count].tile
				_check(sim.get_priority_spawn_base(team) == expected, "Bases alternate in stable order")
				sim.recruit_progress[team] = sim.get_recruit_threshold(team) - 2
				var before: int = sim.get_count(team)
				sim.step()
				_check(sim.get_count(team) == before + 1 and sim.last_spawn_base[team] == expected, "One successful spawn advances rotation")
			var blocked: Vector2i = sim.get_priority_spawn_base(team)
			for y: int in 4:
				for x: int in 4:
					sim.occupancy[blocked * 4 + Vector2i(x, y)] = -1
			sim.recruit_progress[team] = sim.get_recruit_threshold(team)
			var before: int = sim.get_count(team)
			sim.step()
			_check(sim.get_count(team) == before + 1 and sim.last_spawn_base[team] != blocked, "Full base is skipped so another base can spawn")
			sim.areas[0].owner = (team + 1) % 4
			_check(sim.get_priority_spawn_base(team) != blocked, "Lost base stays outside rotation")
			_check(is_equal_approx(sim.get_spawn_seconds(team), original_seconds), "Losing base leaves interval unchanged")
			# Lose a conquered base as well, checking capacity reverses immediately.
			sim.areas[1].owner = (team + 1) % 4
			_check(sim.get_team_capacity(team) == 12 + (base_count - 2) * 6, "Losing conquered base removes six capacity")

	# Reproduce real capture with a crowded home: new capacity must be usable.
	sim = _empty_sim()
	sim._add_area(sim.bases[0], ClassicRules.AreaKind.BASE, 0)
	sim._add_area(sim.bases[1], ClassicRules.AreaKind.BASE, 1)
	sim.active[1] = false
	_seat(sim, 16, 0, sim.bases[0])
	var captor: ClassicStudent = sim.students[16]
	sim._initialize_student(captor, 0, sim.bases[1] * 4 + Vector2i(1, 1))
	captor.state = ClassicStudent.State.SIT
	captor.counter = 10000
	for tick: int in 216:
		sim._capture_areas()
	_check(sim.areas[1].owner == 0, "Crowded-home fixture captures eliminated base")
	_check(sim.get_priority_spawn_base(0) == sim.bases[1] and sim.has_spawn_space(0), "Captured base offers spawn space when home is full")
	sim.recruit_progress[0] = sim.get_recruit_threshold(0)
	sim.step()
	_check(sim.get_count(0) == 18 and sim.last_spawn_base[0] == sim.bases[1], "Captured base recruits after real ownership transfer despite full home")
	# All full: no population change or timer loss.
	for spawn_tile: Vector2i in sim.get_spawn_bases(0):
		for y: int in 4:
			for x: int in 4:
				sim.occupancy[spawn_tile * 4 + Vector2i(x, y)] = -1
	sim.recruit_progress[0] = sim.get_recruit_threshold(0)
	sim.step()
	_check(not sim.has_spawn_space(0) and sim.get_count(0) == 18 and sim.recruit_progress[0] == sim.get_recruit_threshold(0), "All full bases hold ready timer without spawning")

	sim = _empty_sim()
	sim.medieval = false
	sim._add_area(Vector2i(5, 5), ClassicRules.AreaKind.BASE, 1)
	sim.active[1] = false
	_seat(sim, 6, 0, Vector2i(5, 5))
	for unit: ClassicStudent in sim.students.slice(0, 6):
		for tick: int in 300:
			sim._sitting(unit)
	_check(sim.areas[0].owner == 1, "Classic bases remain uncapturable")

	print("Medieval capture/base tests: %d failure(s)" % failures)
	quit(1 if failures else 0)


func _contested_capture_tests() -> void:
	for mode: int in 3:
		for kind: int in [ClassicRules.AreaKind.RECRUIT, ClassicRules.AreaKind.HEAL, ClassicRules.AreaKind.BASE]:
			var sim: ClassicSimulation = _empty_sim()
			sim.difficulty = mode
			sim._add_area(Vector2i(5, 5), kind, 1 if kind == ClassicRules.AreaKind.BASE else -1)
			sim.active[1] = false
			_seat(sim, 1, 0, Vector2i(5, 5))
			var enemy: ClassicStudent = sim.students[20]
			sim._initialize_student(enemy, 2, Vector2i(21, 20))
			sim.areas[0].progress[0] = 123.0
			for state: int in [ClassicStudent.State.SIT, ClassicStudent.State.STAND, ClassicStudent.State.WALK, ClassicStudent.State.FIGHT, ClassicStudent.State.WAIT]:
				enemy.state = state
				sim._capture_areas()
				_check(sim.areas[0].progress[0] == 123, "Living opponent in any active state pauses capture without losing progress")
			enemy.state = ClassicStudent.State.DEAD
			for state: int in [ClassicStudent.State.WALK, ClassicStudent.State.FIGHT]:
				sim.students[0].state = state
				sim._capture_areas()
				_check(sim.areas[0].progress[0] == 123, "Moving or fighting units cannot generate capture progress")
			sim.students[0].state = ClassicStudent.State.SIT
			sim._capture_areas()
			_check(sim.areas[0].progress[0] > 123, "Seated units resume capture once no living opponents remain")
