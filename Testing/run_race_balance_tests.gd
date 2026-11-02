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
		_conversion_hit_stacks(mode)
		_stacked_orc_damage(mode)
		_spawning(mode)
		_elf_and_demon_balance(mode)
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

func _elf_and_demon_balance(mode: int) -> void:
	for player: int in [-1, 2, 3]:
		var sim: ClassicSimulation = _fixture(mode, player)
		var elf: ClassicStudent = _unit(sim, 0, 2, Vector2i(20, 20))
		var demon: ClassicStudent = _unit(sim, 1, 3, Vector2i(21, 20))
		sim.areas.append({"tile": Vector2i(5, 5), "owner": 2})
		sim.area_at[Vector2i(5, 5)] = 0
		_check(sim.get_punch_damage(elf, demon) == 3, "Owned tiles no longer grant elf punch")
		elf.cell = Vector2i(24, 20)
		_check(sim.get_punch_damage(elf, demon) == 3, "Elf bonus ends immediately outside owned tile")
		elf.cell = Vector2i(20, 20)
		sim.areas[0].owner = 3
		_check(sim.get_punch_damage(elf, demon) == 3, "Enemy tile grants no elf bonus")
		sim.medieval = false
		sim.areas[0].owner = 2
		_check(sim.get_punch_damage(elf, demon) == 3, "Classic ignores elf tile bonus")
		sim.medieval = true
		var awards: int = 0
		for trial: int in 1000:
			var victim: ClassicStudent = _unit(sim, 2, 1, Vector2i(22, 20))
			demon.punch_bonus = 0
			demon.health = 2
			demon.event_text = ""
			victim.damage_contributors[demon.id] = {"tick": sim.ticks, "lifetime": demon.lifetime, "team": 3}
			sim._reward_defeat(elf, victim)
			awards += demon.punch_bonus
			_check(demon.health == 2, "Demon assist never heals")
			_check((demon.event_text != "") == (demon.punch_bonus == 1), "Only successful assist rolls show punch reward")
		_check(awards > 430 and awards < 570, "Demon assist reward succeeds about half the time across difficulties and teams")

func _stacked_orc_damage(mode: int) -> void:
	for converted_slot: int in [-1, 0, 1, 2, 3]:
		var sim: ClassicSimulation = _fixture(mode, 0)
		var target: ClassicStudent = _unit(sim, 10, 0, Vector2i(20, 20))
		for count: int in 4:
			var orc: ClassicStudent = _unit(sim, count, 1, target.cell - ClassicRules.DIRECTIONS[count])
			orc.state = ClassicStudent.State.FIGHT
			orc.target_id = target.id
			orc.direction = count
			orc.is_converted = count == converted_slot
			var total: float = 0.0
			for id: int in range(count + 1):
				_check(sim.get_punch_damage(sim.students[id], target) == 2 + id, "Engaged Orc punch is 2/3/4/5, including converted Orcs")
				total += sim.get_punch_damage(sim.students[id], target)
			_check(total == [2, 5, 9, 14][count], "One connected swing per Orc sums to 2/5/9/14")
		# A moving/non-contact ally cannot contribute to the stack.
		sim.students[0].state = ClassicStudent.State.WALK
		_check(sim.get_orc_group_bonus(sim.students[3], target) == 2, "Moving orcs do not inflate group damage")
		sim.students[1].cell = Vector2i(1, 1)
		_check(sim.get_orc_group_bonus(sim.students[3], target) == 1, "Out-of-contact orcs do not inflate group damage")
		sim.students[2].target_id = -1
		_check(sim.get_orc_group_bonus(sim.students[3], target) == 0, "Different targets do not inflate group damage")

func _conversion_hit_stacks(mode: int) -> void:
	var sim: ClassicSimulation = _fixture(mode, 0)
	var orc: ClassicStudent = _unit(sim, 0, 1, Vector2i(20, 20))
	orc.is_converted = true
	var victim: ClassicStudent = _unit(sim, 1, 2, Vector2i(21, 20))
	victim.health = 1000
	victim.maximum_health = 1000
	for hit: int in 4:
		sim.ticks = 100 + hit * 10
		sim._apply_hit(orc, victim)
		_check(sim.get_orc_conversion_chance(victim) == (hit + 1) * 0.25, "Repeated hits by one converted orc each add a conversion stack")
	sim.ticks = 190
	_check(sim.get_orc_conversion_chance(victim) == 1.0, "Five-second boundary includes oldest stack")
	sim.ticks = 191
	_check(sim.get_orc_conversion_chance(victim) == 0.75, "Oldest stack expires independently without refreshing")
	sim.ticks = 201
	_check(sim.get_orc_conversion_chance(victim) == 0.5, "Each stack has its own five-second lifetime")
	sim.ticks = 221
	_check(sim.get_orc_conversion_chance(victim) == 0.0, "All stacks eventually expire")
	var human: ClassicStudent = _unit(sim, 2, 0, Vector2i(22, 20))
	sim._apply_hit(human, victim)
	_check(sim.get_orc_conversion_chance(victim) == 0.0, "Non-orc damage adds no conversion stack")
	sim._initialize_student(victim, 2, Vector2i(21, 20))
	_check(victim.orc_conversion_hits.is_empty(), "New unit lifetime clears conversion stacks")
