extends SceneTree

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func _sim() -> ClassicSimulation:
	var sim: ClassicSimulation = ClassicSimulation.new()
	sim.medieval = true
	sim.setup(0, 12345)
	sim.ai_enabled = false
	for unit: ClassicStudent in sim.students:
		unit.state = ClassicStudent.State.UNUSED
	sim.occupancy.clear()
	return sim


func _unit(sim: ClassicSimulation, id: int, team: int, cell: Vector2i) -> ClassicStudent:
	var unit: ClassicStudent = sim.students[id]
	sim._initialize_student(unit, team, cell)
	return unit


func _hit(sim: ClassicSimulation, attacker: ClassicStudent, victim: ClassicStudent) -> void:
	sim._face_target(attacker, victim)
	var old_hp: float = victim.health
	for attempt: int in 100:
		attacker.state = ClassicStudent.State.FIGHT
		attacker.target_id = victim.id
		attacker.fight_phase = 2
		attacker.counter = 0
		sim._fighting(attacker)
		if victim.health != old_hp:
			return
	_check(false, "Successful hit was resolved")


func _run() -> void:
	_test_humans()
	_test_assists()
	_test_range()
	_test_speed()
	_test_conversion()
	_test_reset()
	_test_battles()
	print("Medieval race progression tests: %d failure(s)" % failures)
	quit(1 if failures else 0)


func _test_humans() -> void:
	var sim: ClassicSimulation = _sim()
	var human: ClassicStudent = _unit(sim, 0, 0, Vector2i(20, 20))
	human.health = 5
	for kill: int in range(1, 6):
		var victim: ClassicStudent = _unit(sim, kill, 2, Vector2i(21, 20))
		victim.health = 1
		_hit(sim, human, victim)
		if kill <= 3:
			_check(human.event_text == ["+2 HP", "+2 PUNCH", "+3 RANGE"][kill - 1] and human.level_ticks == 30, "Human milestone shows actual reward")
		_check(human.level == kill, "Human kill count increments")
		_check(human.maximum_health == 22, "Human first-kill HP milestone applies once")
		_check(human.health == 5, "Human max HP reward does not instantly heal")
		_check(sim.get_punch_damage(human, victim) == (6 if kill >= 2 else 4), "Human second-kill punch milestone applies once")
		_check(sim.get_attack_range(human) == (3 if kill >= 3 else 1), "Human third-kill reach is exactly three cells")


func _test_assists() -> void:
	for elapsed: int in [0, 53, 54, 55]:
		var sim: ClassicSimulation = _sim()
		var elf: ClassicStudent = _unit(sim, 0, 2, Vector2i(20, 20))
		var demon: ClassicStudent = _unit(sim, 1, 3, Vector2i(21, 19))
		var killer: ClassicStudent = _unit(sim, 2, 0, Vector2i(22, 20))
		var victim: ClassicStudent = _unit(sim, 3, 1, Vector2i(21, 20))
		elf.health = 5
		victim.health = 100
		sim.ticks = 10
		_hit(sim, elf, victim)
		_hit(sim, elf, victim)
		# Defender may have begun walking after another hit; keep it stationary.
		victim.state = ClassicStudent.State.STAND
		_hit(sim, demon, victim)
		sim.ticks = 10 + elapsed
		victim.state = ClassicStudent.State.STAND
		victim.health = 1
		_hit(sim, killer, victim)
		_check(elf.maximum_health == (26 if elapsed <= 54 else 25), "Elf assist window includes exactly three seconds")
		_check(demon.punch_bonus == (1 if elapsed <= 54 else 0), "Demon assist window includes exactly three seconds")
		_check(elf.event_text == ("25 + 1 HP" if elapsed <= 54 else ""), "Elf event only appears for awarded HP")
		_check(demon.event_text == ("5 + 1 PUNCH" if elapsed <= 54 else ""), "Demon event only appears for awarded punch")
		_check(elf.health == 5 and elf.level == 0 and demon.level == 0, "Assists grant stats without healing or counting as kills")
		_check(victim.damage_contributors.is_empty(), "Victim damage ledger cleared after death")

	for team: int in [2, 3]:
		var sim: ClassicSimulation = _sim()
		var killer: ClassicStudent = _unit(sim, 0, team, Vector2i(20, 20))
		var victim: ClassicStudent = _unit(sim, 1, 1, Vector2i(21, 20))
		victim.health = 100
		_hit(sim, killer, victim)
		victim.health = 1
		_hit(sim, killer, victim)
		_check(killer.maximum_health == (26 if team == 2 else 15), "Killing elf earns one HP, not two")
		_check(killer.punch_bonus == (1 if team == 3 else 0), "Killing demon earns one punch, not two")

	var sim: ClassicSimulation = _sim()
	var elf: ClassicStudent = _unit(sim, 0, 2, Vector2i(20, 20))
	var victim: ClassicStudent = _unit(sim, 1, 1, Vector2i(21, 20))
	var killer: ClassicStudent = _unit(sim, 2, 0, Vector2i(22, 20))
	victim.health = 100
	_hit(sim, elf, victim)
	elf.state = ClassicStudent.State.DEAD
	victim.health = 1
	_hit(sim, killer, victim)
	_check(elf.maximum_health == 25, "Dead assistants do not gain bonuses")

	sim = _sim()
	elf = _unit(sim, 0, 2, Vector2i(20, 20))
	victim = _unit(sim, 1, 1, Vector2i(21, 20))
	killer = _unit(sim, 2, 0, Vector2i(22, 20))
	victim.health = 100
	_hit(sim, elf, victim)
	var old_lifetime: int = elf.lifetime
	elf = _unit(sim, 0, 2, Vector2i(20, 20))
	_check(elf.lifetime != old_lifetime, "Reused unit slot gets a new lifetime")
	victim.health = 1
	_hit(sim, killer, victim)
	_check(elf.maximum_health == 25, "Respawn cannot inherit previous unit's assist credit")


func _test_range() -> void:
	var sim: ClassicSimulation = _sim()
	var elf: ClassicStudent = _unit(sim, 0, 2, Vector2i(20, 20))
	var victim: ClassicStudent = _unit(sim, 1, 1, Vector2i(22, 20))
	for hp: int in [25, 29, 30, 34, 35, 39, 40, 45]:
		elf.maximum_health = hp
		var expected: int = 4 if hp >= 40 else (3 if hp >= 35 else (2 if hp >= 30 else 1))
		_check(sim.get_attack_range(elf) == expected, "Elf range tier at %d HP" % hp)
	elf.maximum_health = 30
	victim.health = 100
	_hit(sim, elf, victim)
	_check(victim.health == 97, "Ranged elf actually deals damage at two cells")
	_check(victim.state == ClassicStudent.State.WALK, "Melee defender pursues ranged attacker")
	victim.state = ClassicStudent.State.STAND
	victim.cell = Vector2i(23, 20)
	_check(not sim._contact_target(elf, victim), "Ranged attacker cannot hit outside reach")
	elf.maximum_health = 35
	_check(sim._contact_target(elf, victim), "Next range tier hits at three cells")
	victim.cell = Vector2i(22, 21)
	_check(sim._contact_target(elf, victim), "Range uses grid Manhattan distance")
	elf.maximum_health = 29
	victim.cell = Vector2i(21, 20)
	victim.health = 1
	_hit(sim, elf, victim)
	_check(elf.maximum_health == 30 and sim.get_attack_range(elf) == 2, "HP reward immediately unlocks range")

	var human: ClassicStudent = _unit(sim, 3, 0, Vector2i(30, 30))
	human.level = 3
	victim = _unit(sim, 4, 1, Vector2i(33, 30))
	human.priority_target_id = victim.id
	sim.start_walk(human, Vector2i.ZERO, victim.id)
	_check(human.state == ClassicStudent.State.FIGHT and human.cell == Vector2i(30, 30), "Focus command fights from unlocked range")
	victim.state = ClassicStudent.State.STAND
	_check(sim._can_attack_priority(human), "Priority attack respects unlocked range")
	victim.health = 100
	_hit(sim, human, victim)
	_check(victim.health == 96, "Human range hit resolves")
	victim.cell = Vector2i(35, 30)
	human.state = ClassicStudent.State.STAND
	sim._start_turn(human)
	_check(human.state == ClassicStudent.State.WALK, "Ranged focus pursues out-of-range target")
	for tick: int in 40:
		if human.state == ClassicStudent.State.FIGHT:
			break
		sim._walking(human)
	_check(human.state == ClassicStudent.State.FIGHT and sim._within_attack_range(human, victim), "Ranged pathfinding stops in valid attack range")
	_check(human.cell != victim.cell, "Ranged approach never overlaps target")

	sim.medieval = false
	_check(sim.get_attack_range(human) == 1 and sim.get_attack_range(elf) == 1, "Classic ignores race range upgrades")


func _test_speed() -> void:
	var sim: ClassicSimulation = _sim()
	var demon: ClassicStudent = _unit(sim, 0, 3, Vector2i(2, 2))
	for punch: int in [5, 7, 8, 11, 12, 17, 18, 25]:
		demon.punch_bonus = punch - 5
		var expected: float = 1.4 if punch >= 18 else (1.3 if punch >= 12 else (1.2 if punch >= 8 else 1.0))
		_check(is_equal_approx(sim.get_movement_multiplier(demon), expected), "Demon speed tier at %d punch" % punch)
	for multiplier: float in [1.0, 1.2, 1.3, 1.4]:
		sim = _sim()
		demon = _unit(sim, 0, 3, Vector2i(2, 2))
		demon.punch_bonus = 13 if multiplier == 1.4 else (7 if multiplier == 1.3 else (3 if multiplier == 1.2 else 0))
		demon.destination = Vector2i(62, 2)
		sim._start_turn(demon)
		for tick: int in 60:
			sim._walking(demon)
		var expected_cell: float = 2.0 + 60.0 * multiplier / 6.0
		var actual_cell: float = demon.world_position().x / 24.0 + demon.world_position().y / 12.0
		_check(absf(actual_cell - expected_cell) < 0.001, "Fractional walk progress preserves full speed tier over time")
		_check(sim.occupancy[demon.cell] == demon.id and sim.occupancy.size() == 1, "Fast walking preserves one reserved cell")
	sim.medieval = false
	_check(sim.get_movement_multiplier(demon) == 1.0, "Classic movement remains unchanged")


func _test_conversion() -> void:
	var chances: ClassicSimulation = _sim()
	chances.ticks = 100
	var prey: ClassicStudent = _unit(chances, 10, 2, Vector2i(20, 20))
	for count: int in range(1, 6):
		var attacker: ClassicStudent = _unit(chances, count, 1, Vector2i(count, 0))
		prey.damage_contributors[attacker.id] = {"tick": 46, "lifetime": attacker.lifetime, "team": 1}
		_check(is_equal_approx(chances.get_orc_conversion_chance(prey), minf(1.0, count * 0.25)), "Distinct recent orcs add 25 percent, capped at 100")
	chances.ticks = 101
	_check(chances.get_orc_conversion_chance(prey) == 0.0, "Orc hits expire after three seconds")
	prey.damage_contributors.clear()
	prey.damage_contributors[1] = {"tick": 101, "lifetime": 1, "team": 1}
	prey.damage_contributors[1] = {"tick": 101, "lifetime": 1, "team": 1}
	prey.damage_contributors[2] = {"tick": 101, "lifetime": 1, "team": 0}
	_check(chances.get_orc_conversion_chance(prey) == 0.25, "Repeated hits and non-orc hits do not increase conversion chance")
	var kills: int = 0
	var conversions: int = 0
	for seed_value: int in 300:
		var sim: ClassicSimulation = _sim()
		var orc: ClassicStudent = _unit(sim, 0, 1, Vector2i(20, 20))
		var victim: ClassicStudent = _unit(sim, 1, 2, Vector2i(21, 20))
		var watcher: ClassicStudent = _unit(sim, 2, 0, Vector2i(22, 20))
		watcher.target_id = victim.id
		watcher.priority_target_id = victim.id
		victim.health = 1
		orc.direction = 0
		orc.state = ClassicStudent.State.FIGHT
		orc.target_id = victim.id
		orc.fight_phase = 2
		orc.counter = 0
		var probe: RandomNumberGenerator = RandomNumberGenerator.new()
		probe.seed = seed_value
		var hit: bool = probe.randf() >= 0.5
		var convert: bool = hit and probe.randf() < 0.25
		sim.rng.seed = seed_value
		sim._fighting(orc)
		if not hit:
			_check(victim.health == 1 and victim.damage_contributors.is_empty(), "Misses never grant credit or conversion")
			continue
		kills += 1
		_check(orc.event_text == ("ORCS RISE!" if convert else "") and orc.level_ticks == (30 if convert else 0), "Orc celebrates only successful conversion")
		_check(victim.state == (ClassicStudent.State.UNUSED if convert else ClassicStudent.State.DEAD), "Conversion uses seeded 25 percent roll")
		_check(watcher.target_id == -1 and watcher.priority_target_id == -1, "Dead target orders cleared before conversion")
		if convert:
			conversions += 1
			var converted: ClassicStudent = sim.students.back()
			_check(converted.team == 1 and converted.cell == Vector2i(21, 20), "Fresh orc appears at death location")
			_check(converted.health == 10 and converted.maximum_health == 10 and converted.level == 0 and converted.punch_bonus == 0, "Conversion resets all stats to fresh orc")
			_check(sim.occupancy[converted.cell] == converted.id, "Converted unit occupies death cell without corpse overlap")
			_check(not sim.active[2], "Conversion of last elf triggers elimination")
	_check(conversions > 0 and conversions < kills, "Both conversion outcomes exercised")
	for seed_value: int in 32:
		var guaranteed: ClassicSimulation = _sim()
		var killer: ClassicStudent = _unit(guaranteed, 0, 1, Vector2i(20, 20))
		var victim: ClassicStudent = _unit(guaranteed, 10, 2, Vector2i(21, 20))
		for id: int in range(1, 4):
			var helper: ClassicStudent = _unit(guaranteed, id, 1, Vector2i(id, 0))
			victim.damage_contributors[id] = {"tick": guaranteed.ticks, "lifetime": helper.lifetime, "team": 1}
		victim.health = 1
		killer.state = ClassicStudent.State.FIGHT
		killer.direction = 0
		killer.target_id = victim.id
		killer.fight_phase = 2
		killer.counter = 0
		guaranteed.rng.seed = seed_value
		guaranteed._fighting(killer)
		if victim.health == 0:
			_check(victim.state == ClassicStudent.State.UNUSED and guaranteed.students.back().team == 1, "Four recent orc hitters guarantee conversion on a lethal hit")

	var sim: ClassicSimulation = _sim()
	for id: int in 12:
		_unit(sim, id, 1, Vector2i(id, 2))
	var victim: ClassicStudent = _unit(sim, 20, 2, Vector2i(21, 20))
	victim.state = ClassicStudent.State.DEAD
	sim._target_died(victim)
	sim._convert_to_orc(victim)
	_check(sim.get_count(1) == 13, "Combat conversion can exceed normal population cap")
	_check(sim.spawn_student(1) == null, "Normal spawning stays blocked above capacity")


func _test_reset() -> void:
	var sim: ClassicSimulation = _sim()
	for team: int in 4:
		var unit: ClassicStudent = _unit(sim, team, team, Vector2i(team, 5))
		unit.level = 10
		unit.punch_bonus = 20
		unit.maximum_health = 50
		unit.show_event("old reward")
		unit.walk_tick = 1.5
		unit.damage_contributors[20] = {"tick": 0, "lifetime": 1}
		sim._initialize_student(unit, team, Vector2i(team, 5))
		_check(unit.level == 0 and unit.punch_bonus == 0 and unit.damage_contributors.is_empty(), "Fresh units reset progression and assist history")
		_check(unit.event_text.is_empty() and unit.level_ticks == 0, "Fresh units clear event text")
		_check(unit.walk_tick == 0 and sim.get_attack_range(unit) == 1 and sim.get_movement_multiplier(unit) == 1.0, "Fresh units reset range and movement")


func _test_battles() -> void:
	for seed_value: int in 4:
		var sim: ClassicSimulation = ClassicSimulation.new()
		sim.medieval = true
		sim.setup(0, seed_value)
		# Bring all races together and unlock ranged/speed tiers to stress combat.
		sim.occupancy.clear()
		for unit: ClassicStudent in sim.students:
			if not unit.is_alive():
				continue
			unit.cell = Vector2i(20 + unit.id % 3, 20 + unit.team * 2)
			unit.previous_cell = unit.cell
			unit.destination = unit.cell
			if unit.team == 0:
				unit.level = 3
				unit.punch_bonus = 2
			elif unit.team == 2:
				unit.maximum_health = 40
			elif unit.team == 3:
				unit.punch_bonus = 13
			sim.occupancy[unit.cell] = unit.id
		for tick: int in 1800:
			sim.step()
			var occupied: Dictionary = {}
			for unit: ClassicStudent in sim.students:
				if unit.state == ClassicStudent.State.UNUSED:
					continue
				_check(not occupied.has(unit.cell), "Battle retains unique occupied cells")
				occupied[unit.cell] = unit.id
				_check(sim.occupancy.get(unit.cell, -1) == unit.id, "Battle occupancy matches units")
				_check(unit.health >= 0 and unit.health <= unit.maximum_health, "Battle HP remains valid")
				_check(unit.walk_tick >= 0, "Movement progress remains valid")
			_check(occupied.size() == sim.occupancy.size(), "No stale occupancy entries after conversions")
			if sim.finished:
				break
