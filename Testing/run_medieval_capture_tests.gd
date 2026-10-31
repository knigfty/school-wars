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
	_check(not sim.can_capture_area(sim.areas[0], 2), "Conquered base protected while new owner lives")

	for unit: ClassicStudent in sim.students:
		unit.state = ClassicStudent.State.UNUSED
	sim.active[0] = false
	_seat(sim, 3, 2, tile)
	for tick: int in 100:
		sim._capture_areas()
	_check(sim.areas[0].owner == 2, "Base can be conquered again after new owner is eliminated")

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

	# Each base independently recruits, even with another base blocked.
	for team: int in 4:
		sim = _empty_sim()
		sim._add_area(sim.bases[team], ClassicRules.AreaKind.BASE, team)
		var captured: Vector2i = sim.bases[(team + 1) % 4]
		sim._add_area(captured, ClassicRules.AreaKind.BASE, team)
		sim._add_area(Vector2i(5, 5), ClassicRules.AreaKind.RECRUIT, team)
		sim.recruit_progress[team] = sim.get_recruit_threshold(team) - 2
		sim.areas[1].spawn_progress = sim.get_recruit_threshold(team) - 2
		sim.step()
		_check(sim.get_count(team) == 2, "Both owned bases spawn at owner threshold")
		var from_home: int = 0
		var from_captured: int = 0
		for unit: ClassicStudent in sim.students:
			if not unit.is_alive() or unit.team != team:
				continue
			var spawned_tile: Vector2i = Vector2i(unit.cell.x / 4, unit.cell.y / 4)
			from_home += int(spawned_tile == sim.bases[team])
			from_captured += int(spawned_tile == captured)
		_check(from_home == 1 and from_captured == 1, "Spawned units use both base locations")
		_check(sim.areas[1].spawn_progress == 1, "Spades affect captured base rate")
		sim.areas[2].owner = -1
		sim.step()
		_check(sim.areas[1].spawn_progress == 3, "Losing spade immediately slows captured base")
		for y: int in 4:
			for x: int in 4:
				sim.occupancy[sim.bases[team] * 4 + Vector2i(x, y)] = -1
		_check(sim.has_spawn_space(team), "HUD finds space in captured base")
		sim.areas[1].spawn_progress = sim.get_recruit_threshold(team)
		var before: int = sim.get_count(team)
		sim.step()
		_check(sim.get_count(team) == before + 1, "Blocked home does not block captured base")
		sim.recruit_progress[team] = sim.get_recruit_threshold(team)
		sim.areas[1].spawn_progress = sim.get_recruit_threshold(team)
		for unit: ClassicStudent in sim.students:
			if unit.state == ClassicStudent.State.UNUSED and sim.get_count(team) < sim.get_team_capacity(team):
				unit.team = team
				unit.state = ClassicStudent.State.STAND
				unit.counter = 10000
		before = sim.get_count(team)
		sim.step()
		_check(sim.get_count(team) == before, "Multiple bases obey shared team capacity")
		sim.active[team] = false
		var progress: int = sim.areas[1].spawn_progress
		sim.step()
		_check(sim.areas[1].spawn_progress == progress, "Eliminated owners do not recruit from captured bases")

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
