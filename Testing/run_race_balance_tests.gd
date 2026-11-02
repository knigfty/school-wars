extends SceneTree

var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _fixture(mode: int, player: int) -> ClassicSimulation:
	var sim: ClassicSimulation = ClassicSimulation.new()
	sim.medieval = true
	sim.setup(player, 123)
	sim.difficulty = mode
	sim.ai_enabled = false
	for unit: ClassicStudent in sim.students:
		unit.state = ClassicStudent.State.UNUSED
	sim.occupancy.clear()
	sim.areas.clear()
	sim.area_at.clear()
	return sim

func _unit(sim: ClassicSimulation, id: int, team: int, cell: Vector2i) -> ClassicStudent:
	var unit: ClassicStudent = sim.students[id]
	sim._initialize_student(unit, team, cell)
	unit.state = ClassicStudent.State.STAND
	return unit

func _run() -> void:
	for mode: int in 3:
		for player: int in [0, 1, 3]:
			_conversion(mode, player)
			_retreats(mode, player)
		_spawning(mode)
	print("Race balance tests: %d failure(s)" % failures)
	quit(1 if failures else 0)

func _conversion(mode: int, player: int) -> void:
	var sim: ClassicSimulation = _fixture(mode, player)
	var victim: ClassicStudent = _unit(sim, 0, 3, Vector2i(20, 20))
	victim.maximum_health = 100
	victim.punch_bonus = 40
	sim._convert_to_orc(victim)
	var converted: ClassicStudent = sim.students.back()
	_check(converted.health == 30 and converted.maximum_health == 30, "Converted maximum and full HP capped at 30")
	_check(converted.punch_bonus == 8, "Inherited permanent punch capped at 10 total")
	var target: ClassicStudent = _unit(sim, 1, 0, Vector2i(21, 20))
	var regular: ClassicStudent = _unit(sim, 2, 1, Vector2i(21, 21))
	regular.state = ClassicStudent.State.FIGHT
	regular.target_id = target.id
	regular.direction = 3
	converted.state = ClassicStudent.State.FIGHT
	converted.target_id = target.id
	converted.direction = 0
	_check(sim.get_orc_group_bonus(converted, target) == 1, "Converted orc receives shared-target bonus")
	_check(sim.get_punch_damage(converted, target) == 10, "Group damage respects converted ten-punch cap")
	converted.punch_bonus = 5
	_check(sim.get_punch_damage(converted, target) == 8, "Below cap converted damage includes group bonus")
	# A later regular orc also benefits from an earlier converted teammate.
	regular.state = ClassicStudent.State.STAND
	var follower: ClassicStudent = ClassicStudent.new()
	follower.id = sim.students.size()
	sim.students.append(follower)
	sim._initialize_student(follower, 1, Vector2i(21, 19))
	follower.state = ClassicStudent.State.FIGHT
	follower.target_id = target.id
	follower.direction = 1
	_check(sim.get_punch_damage(follower, target) == 3, "Converted teammate activates regular orc group bonus")
	victim = _unit(sim, 3, 2, Vector2i(30, 30))
	victim.maximum_health = 25
	sim._convert_to_orc(victim)
	converted = sim.students.back()
	_check(converted.health == 25 and converted.punch_bonus == 1, "Inheritance below caps preserved")

func _retreats(mode: int, player: int) -> void:
	var sim: ClassicSimulation = _fixture(mode, player)
	for race: int in 4:
		var unit: ClassicStudent = _unit(sim, race, race, Vector2i(20 + race, 20))
		unit.ai_retreating = true
		unit.ai_flee_until = 100
		sim.ticks = 99
		var expected: String = ["Retreat!", "Flee!", "Fallback!", ""][race] if race != player else ""
		_check(sim.get_retreat_text(unit) == expected, "Active retreat labels are race-specific and enemy-only")
		if race == 1:
			_check(is_equal_approx(sim.get_movement_multiplier(unit), 1.0 if player == 1 else 1.3), "Fleeing speed boost is enemy-only")
			sim.ticks = 100
			_check(sim.get_movement_multiplier(unit) == 1 and sim.get_retreat_text(unit).is_empty(), "Flee boost and label expire exactly at window end")
		unit.ai_retreating = false
		_check(sim.get_retreat_text(unit).is_empty(), "Leaving retreat clears label immediately")
		unit.ai_retreating = true
		unit.state = ClassicStudent.State.DEAD
		_check(sim.get_retreat_text(unit).is_empty(), "Dead units show no retreat label")

func _spawning(mode: int) -> void:
	for race: int in 4:
		var sim: ClassicSimulation = _fixture(mode, race)
		sim._add_area(Vector2i(1, 1), ClassicRules.AreaKind.RECRUIT, race)
		sim._add_area(Vector2i(3, 3), ClassicRules.AreaKind.HEAL, race)
		_check(sim.get_recruit_tiles(race) == 1, "Spade count remains literal")
		_check(sim.get_spawn_boost_tiles(race) == (2 if race == 3 else 1), "Only demons count hearts toward spawning")
		_check(is_equal_approx(sim.get_spawn_seconds(race), float(sim.get_recruit_threshold(race)) / (4 if race == 3 else 3) / 18), "Spawn estimate includes demon hearts")
		sim.step()
		_check(sim.recruit_progress[race] == (4 if race == 3 else 3), "Actual spawning clock includes demon hearts")
		sim.areas[1].owner = -1
		_check(sim.get_spawn_boost_tiles(race) == 1, "Losing heart removes its boost")
		sim.areas[1].owner = race
		sim.medieval = false
		_check(sim.get_spawn_boost_tiles(race) == 1, "Original mode hearts never boost spawning")
