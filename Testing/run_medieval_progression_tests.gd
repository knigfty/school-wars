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
	sim.designate_order(attacker, Vector2i.ZERO, victim.id)
	attacker.priority_target_id = victim.id
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
	_test_scaling_and_inheritance()
	_test_expert_demon_speed()
	_test_demon_healing()
	_test_expert_enemy_rewards()
	_test_new_mechanics()
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
	for kill: int in range(1, 31):
		var victim: ClassicStudent = _unit(sim, 1, 2, Vector2i(21, 20))
		victim.health = 1
		_hit(sim, human, victim)
		_check(human.event_text == ["+2 HP", "+2 PUNCH", "+2 RANGE"][(kill - 1) % 3], "Human kill rewards cycle indefinitely")
		_check(human.level == kill, "Human kill count increments")
		_check(human.maximum_health == 20 + 2 * ((kill + 2) / 3), "Human HP grows on every cycle")
		_check(human.health == 5, "Maximum HP upgrades do not instantly heal")
		_check(human.punch_bonus == 2 * ((kill + 1) / 3), "Human punch grows on every cycle")
		_check(sim.get_attack_range(human) == 1 + 2 * (kill / 3), "Human reach gains two cells per completed cycle")


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
	for hp: int in [25, 27, 28, 31, 32, 35, 36, 45]:
		elf.maximum_health = hp
		var expected: int = 1 + maxi(0, hp - 25) / 3
		_check(sim.get_attack_range(elf) == expected, "Elf range tier at %d HP" % hp)
	elf.maximum_health = 28
	victim.health = 100
	_hit(sim, elf, victim)
	_check(victim.health == 97, "Ranged elf actually deals damage at two cells")
	_check(victim.state == ClassicStudent.State.WALK, "Melee defender pursues ranged attacker")
	victim.state = ClassicStudent.State.STAND
	victim.cell = Vector2i(23, 20)
	_check(not sim._contact_target(elf, victim), "Ranged attacker cannot hit outside reach")
	elf.maximum_health = 32
	_check(sim._contact_target(elf, victim), "Next range tier hits at three cells")
	victim.cell = Vector2i(22, 21)
	_check(sim._contact_target(elf, victim), "Range uses grid Manhattan distance")
	elf.maximum_health = 27
	victim.cell = Vector2i(21, 20)
	victim.health = 1
	_hit(sim, elf, victim)
	_check(elf.maximum_health == 28 and sim.get_attack_range(elf) == 2, "HP reward immediately unlocks range")

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
			_check(converted.health == 25 and converted.maximum_health == 25 and converted.level == 0 and converted.punch_bonus == 1, "Conversion inherits elf HP and punch but resets orc progression")
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


func _test_new_mechanics() -> void:
	var sim: ClassicSimulation = _sim()
	var regular: ClassicStudent = _unit(sim, 0, 1, Vector2i(4, 4))
	var victim: ClassicStudent = _unit(sim, 1, 2, Vector2i(20, 20))
	sim._convert_to_orc(victim)
	_check(sim.get_count(1) == 2 and sim.get_regular_count(1) == 1 and sim.get_converted_count(1) == 1, "Converted orcs have separate population")
	var converted: ClassicStudent = sim.students.back()
	converted.state = ClassicStudent.State.UNUSED
	_check(sim.get_converted_count(1) == 0, "Removed conversion leaves separate count")
	sim._initialize_student(converted, 1, converted.cell)
	_check(not converted.is_converted and sim.get_regular_count(1) == 2, "Normal respawn clears conversion flag")
	regular.state = ClassicStudent.State.UNUSED
	converted.is_converted = true
	_check(sim.get_count(1) == 1 and sim.get_regular_count(1) == 0, "Converted survivors still keep team alive")
	sim._check_elimination(1)
	_check(sim.active[1], "Converted survivor prevents elimination")
	# A converted unit does not block the last regular spawn slot.
	for id: int in range(2, 13):
		_unit(sim, id, 1, Vector2i(id, 10))
	_check(sim.get_regular_count(1) == 11 and sim.spawn_student(1) != null, "Conversions do not block regular spawning")
	_check(sim.get_regular_count(1) == 12 and sim.spawn_student(1) == null, "Regular capacity still enforced")
	for level: int in [3, 4]:
		for seed_value: int in 20:
			sim = _sim()
			var human: ClassicStudent = _unit(sim, 0, 0, Vector2i(20, 20))
			human.level = level
			var primary: ClassicStudent = _unit(sim, 1, 2, Vector2i(22, 20))
			var secondary: ClassicStudent = _unit(sim, 2, 3, Vector2i(22, 21))
			var third: ClassicStudent = _unit(sim, 3, 1, Vector2i(23, 20))
			human.state = ClassicStudent.State.FIGHT
			human.target_id = primary.id
			human.fight_phase = 2
			human.counter = 0
			var before: float = secondary.health
			var third_before: float = third.health
			sim.rng.seed = seed_value
			sim._fighting(human)
			if primary.health < primary.maximum_health:
				_check(secondary.health == before, "Humans never hit a second victim after cleave removal")
				_check(third.health == third_before, "Cleave hits at most two victims")
			else:
				_check(secondary.health == before, "Missed swing cannot cleave")

	# Both victims can die in one successful upgraded swing and award two kills.
	sim = _sim()
	var veteran: ClassicStudent = _unit(sim, 0, 0, Vector2i(20, 20))
	veteran.level = 4
	var first: ClassicStudent = _unit(sim, 1, 2, Vector2i(22, 20))
	var second: ClassicStudent = _unit(sim, 2, 3, Vector2i(22, 21))
	first.health = 1
	second.health = 1
	_hit(sim, veteran, first)
	_check(first.state == ClassicStudent.State.DEAD and second.state != ClassicStudent.State.DEAD and veteran.level == 5, "Human attack rewards only its single defeated target")


func _test_expert_enemy_rewards() -> void:
	for mode: int in [ClassicSimulation.Difficulty.EASY, ClassicSimulation.Difficulty.NORMAL, ClassicSimulation.Difficulty.EXPERT]:
		for race: int in [2, 3]:
			for player_controlled: bool in [false, true]:
				var sim: ClassicSimulation = _sim()
				sim.difficulty = mode
				sim.player_team = race if player_controlled else 0
				var killer: ClassicStudent = _unit(sim, 0, race, Vector2i(20, 20))
				var assist: ClassicStudent = _unit(sim, 1, race, Vector2i(20, 21))
				var victim: ClassicStudent = _unit(sim, 2, 1, Vector2i(21, 20))
				for unit: ClassicStudent in [killer, assist]:
					victim.damage_contributors[unit.id] = {"tick": sim.ticks, "lifetime": unit.lifetime, "team": race}
				sim._reward_defeat(killer, victim)
				var reward: int = 2 if mode == ClassicSimulation.Difficulty.EXPERT and not player_controlled else 1
				for unit: ClassicStudent in [killer, assist]:
					var expected: int = reward if race == 2 else (2 if mode == ClassicSimulation.Difficulty.EXPERT and unit == killer else 1)
					_check((unit.maximum_health - ClassicRules.HEALTH[race] if race == 2 else unit.punch_bonus) == expected, "Elf enemy rewards and Expert demon kill/assist rewards are scoped correctly")
					_check((" + %d " % expected) in unit.event_text, "Reward popup displays actual increment")


func _test_demon_healing() -> void:
	for mode: int in 3:
		var sim: ClassicSimulation = _sim()
		sim.difficulty = mode
		var demon: ClassicStudent = _unit(sim, 0, 3, Vector2i(20, 20))
		demon.state = ClassicStudent.State.SIT
		demon.health = 2
		demon.counter = 10000
		sim._add_area(Vector2i(5, 5), ClassicRules.AreaKind.HEAL, 3)
		sim._sitting(demon)
		_check(demon.health == 2, "Demon cannot heal on an owned heart")
		sim.areas[sim.area_at[Vector2i(5, 5)]].kind = ClassicRules.AreaKind.BASE
		sim._sitting(demon)
		_check(is_equal_approx(demon.health, 2.1), "Demon can heal while seated on an owned base")
		var assist: ClassicStudent = _unit(sim, 1, 3, Vector2i(20, 21))
		var expired: ClassicStudent = _unit(sim, 2, 3, Vector2i(20, 22))
		var victim: ClassicStudent = _unit(sim, 3, 1, Vector2i(21, 20))
		demon.health = 2
		assist.health = 2
		expired.health = 2
		sim.ticks = 100
		victim.damage_contributors[demon.id] = {"tick": 100, "lifetime": demon.lifetime, "team": 3}
		victim.damage_contributors[assist.id] = {"tick": 46, "lifetime": assist.lifetime, "team": 3}
		victim.damage_contributors[expired.id] = {"tick": 45, "lifetime": expired.lifetime, "team": 3}
		sim._reward_defeat(demon, victim)
		_check(demon.health == 5, "Demon killer heals three HP without extra assist healing")
		_check(assist.health == 3 and expired.health == 2, "Demon assist healing includes exactly three seconds and excludes older hits")
		demon.health = demon.maximum_health - 1
		assist.health = assist.maximum_health
		victim.damage_contributors[assist.id] = {"tick": 100, "lifetime": assist.lifetime, "team": 3}
		sim._reward_defeat(demon, victim)
		_check(demon.health == demon.maximum_health and assist.health == assist.maximum_health, "Combat healing cannot exceed maximum HP")


func _test_expert_demon_speed() -> void:
	for player_controlled: bool in [false, true]:
		var sim: ClassicSimulation = _sim()
		sim.difficulty = ClassicSimulation.Difficulty.EXPERT
		sim.player_team = 3 if player_controlled else 0
		var demon: ClassicStudent = _unit(sim, 0, 3, Vector2i(2, 2))
		for bonus: int in [0, 1, 2, 3, 4, 5, 6, 13, 20, 40]:
			demon.punch_bonus = bonus
			_check(is_equal_approx(sim.get_movement_multiplier(demon), 1.0 + 0.05 * floori(bonus / 2.0)), "Expert demon speed adds five percent per complete two bonus punch")
		# Verify fractional movement uses the scaling, beyond the old maximum tier.
		demon.punch_bonus = 20
		demon.destination = Vector2i(63, 2)
		sim._start_turn(demon)
		for tick: int in 60:
			sim._walking(demon)
		var actual: float = demon.world_position().x / 24.0 + demon.world_position().y / 12.0
		_check(absf(actual - 17.0) < 0.001, "Expert fifty-percent movement bonus is preserved in actual walking")


func _test_scaling_and_inheritance() -> void:
	for mode: int in 3:
		var sim: ClassicSimulation = _sim()
		sim.difficulty = mode
		var human: ClassicStudent = _unit(sim, 0, 0, Vector2i(20, 20))
		var enemy: ClassicStudent = _unit(sim, 1, 1, Vector2i(21, 20))
		sim._add_area(Vector2i(5, 5), ClassicRules.AreaKind.RECRUIT, 0)
		human.state = ClassicStudent.State.FIGHT
		sim.ticks = 100
		_check(sim.get_punch_damage(human, enemy) == 5, "Human territorial punch activates on every difficulty")
		human.cell = Vector2i(24, 20)
		sim.ticks = 153
		_check(sim.get_punch_damage(human, enemy) == 5, "Human punch lasts for the three-second grace window")
		sim.ticks = 154
		_check(sim.get_punch_damage(human, enemy) == 4, "Human punch expires at exactly three seconds")
		human.maximum_health = 20
		human.punch_bonus = 6
		human.level = 30
		human.health = 0
		sim._convert_to_orc(human)
		var converted: ClassicStudent = sim.students.back()
		_check(converted.health == 20 and converted.maximum_health == 20 and sim.get_punch_damage(converted, enemy) == 10, "Converted human preserves twenty HP and ten permanent punch")
		_check(sim.get_attack_range(converted) == 1 and converted.level == 0 and converted.home_punch_until == -1, "Conversion strips reach and temporary territorial bonus")
		var elf: ClassicStudent = _unit(sim, 2, 2, Vector2i(30, 30))
		for bonus: int in [0, 1, 2, 3, 5, 6, 8, 9, 30, 300]:
			elf.maximum_health = 25 + bonus
			_check(sim.get_attack_range(elf) == 1 + bonus / 3, "Elf reach scales per three bonus HP without a tier cap")
		_check(sim._attack_positions(elf, Vector2i(30, 30)).size() <= 4096, "Large reach remains bounded by actual map cells")
