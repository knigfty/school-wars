extends SceneTree

var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _fixture(player: int = 3) -> ClassicSimulation:
	var sim: ClassicSimulation = ClassicSimulation.new()
	sim.medieval = true
	sim.difficulty = ClassicSimulation.Difficulty.NORMAL
	sim.setup(player, 1234)
	sim.ticks = ClassicSimulation.AI_START_DELAY_TICKS
	for unit: ClassicStudent in sim.students:
		unit.state = ClassicStudent.State.UNUSED
	sim.occupancy.clear()
	sim.areas.clear()
	sim.area_at.clear()
	return sim

func _unit(sim: ClassicSimulation, id: int, team: int, cell: Vector2i) -> ClassicStudent:
	var unit: ClassicStudent = sim.students[id]
	sim._initialize_student(unit, team, cell)
	unit.state = ClassicStudent.State.SIT
	return unit

func _run() -> void:
	_player_tile_tests()
	_expert_strategy_tests()
	_start_delay_tests()
	_retreat_timing_tests()
	var sim: ClassicSimulation = _fixture()
	sim.difficulty = ClassicSimulation.Difficulty.EASY
	_check(not sim.uses_squad_ai(), "Easy retains original AI")
	sim.difficulty = ClassicSimulation.Difficulty.EXPERT
	sim.medieval = false
	_check(not sim.uses_squad_ai(), "Classic never uses medieval squads")
	sim.medieval = true
	sim.ai_enabled = false
	_check(not sim.uses_squad_ai(), "AI disable switch still works")
	sim.ai_enabled = true
	sim.difficulty = ClassicSimulation.Difficulty.NORMAL
	for i: int in 5:
		_unit(sim, i, 0, Vector2i(4 + i, 4))
	sim._add_area(Vector2i(4, 4), ClassicRules.AreaKind.RECRUIT, -1)
	sim.squad_ai.update(sim)
	_check(sim.squad_ai.squads.size() == 2, "Five humans form two squads")
	for squad: Array in sim.squad_ai.squads:
		_check(squad.size() >= 2 and squad.size() <= 4, "Human squad size is 2–4")
		for unit: ClassicStudent in squad:
			_check(Vector2i(unit.destination.x / 4, unit.destination.y / 4) == Vector2i(4, 4), "Humans share capture objective")
	# Capture orders seat the whole squad and advance as soon as ownership changes.
	for unit: ClassicStudent in sim.students.slice(0, 5):
		unit.cell = Vector2i(16 + unit.id % 4, 16 + unit.id / 4)
		unit.state = ClassicStudent.State.SIT
	sim._add_area(Vector2i(8, 8), ClassicRules.AreaKind.RECRUIT, -1)
	sim.areas[0].owner = 0
	sim.ticks = 436
	sim.squad_ai.update(sim)
	_check(Vector2i(sim.students[0].destination.x / 4, sim.students[0].destination.y / 4) == Vector2i(8, 8), "Humans advance after capture")

	sim = _fixture()
	var elf: ClassicStudent = _unit(sim, 0, 2, Vector2i(20, 20))
	var enemy: ClassicStudent = _unit(sim, 1, 1, Vector2i(21, 20))
	sim._add_area(Vector2i(2, 2), ClassicRules.AreaKind.HEAL, 2)
	sim._add_area(Vector2i(0, 0), ClassicRules.AreaKind.BASE, 2)
	elf.health = elf.maximum_health * 0.19
	sim.squad_ai.update(sim)
	_check(elf.ai_retreating and elf.target_id == -1 and elf.priority_target_id == -1, "Wounded elf disengages")
	_check(Vector2i(elf.destination.x / 4, elf.destination.y / 4) == Vector2i(2, 2), "Elf chooses nearest owned healing tile")
	sim._engage_defender(elf, enemy)
	_check(elf.target_id == -1, "Retreating elf ignores engagement")
	elf.health = elf.maximum_health * 0.5
	sim.squad_ai.update(sim)
	_check(elf.ai_retreating, "Elf continues healing until recovery threshold")
	elf.health = elf.maximum_health * 0.8
	sim.squad_ai.update(sim)
	_check(not elf.ai_retreating, "Healthy elf rejoins")

	sim = _fixture()
	var orc: ClassicStudent = _unit(sim, 0, 1, Vector2i(8, 8))
	sim.bases[1] = Vector2i.ZERO
	sim._add_area(Vector2i(15, 15), ClassicRules.AreaKind.BASE, 0)
	_unit(sim, 1, 0, Vector2i(9, 8))
	_unit(sim, 2, 0, Vector2i(9, 9))
	sim.squad_ai.update(sim)
	_check(orc.ai_retreating and orc.target_id == -1, "Outnumbered orc flees")
	_check(orc.destination.distance_to(Vector2i.ZERO) > orc.cell.distance_to(Vector2i.ZERO), "Orc flees toward enemy base")

	sim = _fixture()
	var a: ClassicStudent = _unit(sim, 0, 1, Vector2i(20, 20))
	var b: ClassicStudent = _unit(sim, 1, 1, Vector2i(20, 21))
	enemy = _unit(sim, 2, 0, Vector2i(24, 20))
	sim.squad_ai.update(sim)
	_check(a.priority_target_id == enemy.id and b.priority_target_id == enemy.id, "Orcs focus one victim together")

	sim = _fixture(0)
	a = _unit(sim, 0, 3, Vector2i(20, 20))
	b = _unit(sim, 1, 3, Vector2i(20, 21))
	var strong: ClassicStudent = _unit(sim, 2, 0, Vector2i(24, 20))
	var weak: ClassicStudent = _unit(sim, 3, 2, Vector2i(27, 20))
	weak.health = 1
	sim.squad_ai.update(sim)
	_check(a.priority_target_id == weak.id and b.priority_target_id == weak.id, "Demons jointly prefer weaker prey over a closer healthy enemy")
	strong.state = ClassicStudent.State.UNUSED
	weak.state = ClassicStudent.State.UNUSED
	# Reused slots must not leave recruits in a squad of another race.
	sim._initialize_student(a, 1, Vector2i(10, 10))
	sim.ticks = 436
	sim.squad_ai.update(sim)
	for squad: Array in sim.squad_ai.squads:
		for member: ClassicStudent in squad:
			_check(member.team == squad[0].team, "Respawns cannot mix races in squads")

	for mode: int in [ClassicSimulation.Difficulty.NORMAL, ClassicSimulation.Difficulty.EXPERT]:
		for seed_value: int in [12, 1234, 9876]:
			sim = ClassicSimulation.new()
			sim.medieval = true
			sim.difficulty = mode
			sim.setup(0, seed_value)
			for tick: int in 2400:
				sim.step()
				for unit: ClassicStudent in sim.students:
					if unit.state != ClassicStudent.State.UNUSED:
						_check(sim.occupancy.get(unit.cell, -1) == unit.id, "Squad orders preserve occupancy")
	# Every Expert race detects targets across the map, beyond the old demon radius.
	for team: int in 4:
		for mode: int in [ClassicSimulation.Difficulty.NORMAL, ClassicSimulation.Difficulty.EXPERT]:
			sim = _fixture((team + 1) % 4)
			sim.difficulty = mode
			a = _unit(sim, 0, team, Vector2i(2, 2))
			b = _unit(sim, 1, team, Vector2i(2, 3))
			weak = _unit(sim, 2, (team + 1) % 4, Vector2i(61, 61))
			weak.health = 1
			sim.squad_ai.update(sim)
			_check((a.priority_target_id == weak.id and b.priority_target_id == weak.id) == false, "Whole-map Expert awareness for race %d" % team)
	# Remote enemies must not make locally safe Expert orcs flee.
	sim = _fixture(0)
	sim.difficulty = ClassicSimulation.Difficulty.EXPERT
	a = _unit(sim, 0, 1, Vector2i(2, 2))
	for i: int in 3:
		_unit(sim, i + 1, 0, Vector2i(58 + i, 60))
	sim.squad_ai.update(sim)
	_check(not a.ai_retreating and a.priority_target_id == -1, "Expert orcs ignore distant enemies")
	print("Squad AI tests: %d failure(s)" % failures)
	quit(1 if failures else 0)


func _retreat_timing_tests() -> void:
	var sim: ClassicSimulation = _fixture(0)
	var elf: ClassicStudent = _unit(sim, 0, 2, Vector2i(20, 20))
	var enemy: ClassicStudent = _unit(sim, 1, 0, Vector2i(21, 20))
	sim._add_area(Vector2i(5, 5), ClassicRules.AreaKind.HEAL, 2)
	elf.health = 2
	enemy.state = ClassicStudent.State.FIGHT
	enemy.target_id = elf.id
	sim.ticks = 100
	sim._sitting(elf)
	_check(elf.health == 2, "Attacked sitting elf cannot heal, even before a hit lands")
	enemy.state = ClassicStudent.State.SIT
	sim.ticks = 153
	sim._sitting(elf)
	_check(elf.health == 2, "Elf cannot heal before three safe seconds")
	sim.ticks = 154
	sim._sitting(elf)
	_check(elf.health > 2, "Elf resumes healing at exactly three safe seconds")
	elf.state = ClassicStudent.State.WALK
	_check(not sim.can_heal(elf), "Walking elf cannot heal")
	sim._initialize_student(elf, 2, Vector2i(20, 20))
	_check(elf.last_attacked_tick < 0 and elf.ai_hold_ground_until == 0, "Respawn resets healing and decision state")
	# Expert fights with strong nearby support, escapes to another heart without it.
	for supported: bool in [false, true]:
		sim = _fixture(0)
		sim.difficulty = ClassicSimulation.Difficulty.EXPERT
		elf = _unit(sim, 0, 2, Vector2i(20, 20))
		elf.health = 2
		elf.last_attacked_tick = sim.ticks
		enemy = _unit(sim, 1, 0, Vector2i(21, 20))
		sim._add_area(Vector2i(5, 5), ClassicRules.AreaKind.HEAL, 2)
		sim._add_area(Vector2i(12, 12), ClassicRules.AreaKind.BASE, 2)
		if supported:
			var ally: ClassicStudent = _unit(sim, 2, 2, Vector2i(20, 21))
			ally.punch_bonus = 100
		sim.squad_ai.update(sim)
		if supported:
			_check(not elf.ai_retreating and elf.priority_target_id == enemy.id, "Supported Expert elf fights back")
		else:
			_check(elf.ai_retreating or elf.priority_target_id == enemy.id, "Expert elves use Normal healing choices")
	var choices: Dictionary = {}
	for seed_value: int in 24:
		sim = _fixture(0)
		sim.rng.seed = seed_value
		elf = _unit(sim, 0, 2, Vector2i(20, 20))
		elf.health = 2
		elf.last_attacked_tick = sim.ticks
		_unit(sim, 1, 0, Vector2i(21, 20))
		sim._add_area(Vector2i(5, 5), ClassicRules.AreaKind.HEAL, 2)
		sim._add_area(Vector2i(12, 12), ClassicRules.AreaKind.BASE, 2)
		sim.squad_ai.update(sim)
		choices[elf.ai_retreating] = true
	_check(choices.size() == 2, "Normal elves randomly choose both fight and escape")
	sim = _fixture(0)
	var orc: ClassicStudent = _unit(sim, 0, 1, Vector2i(20, 20))
	_unit(sim, 1, 0, Vector2i(21, 20))
	_unit(sim, 2, 0, Vector2i(21, 21))
	sim.squad_ai.update(sim)
	_check(orc.ai_flee_until == 580 and orc.ai_flee_ready_at == 940, "Orc flee lasts ten seconds with thirty-second reuse")
	sim.ticks = 579
	sim.squad_ai.update(sim)
	_check(orc.ai_retreating, "Orc can flee before ten seconds elapse")
	sim.ticks = 580
	sim.squad_ai.update(sim)
	_check(not orc.ai_retreating and orc.priority_target_id >= 0, "Orc returns to combat at ten seconds despite outnumbering")
	sim.ticks = 939
	sim.squad_ai.next_plan = 0
	sim.squad_ai.update(sim)
	_check(not orc.ai_retreating, "Orc cannot flee during cooldown")
	sim.ticks = 940
	sim.squad_ai.next_plan = 0
	sim.squad_ai.update(sim)
	_check(orc.ai_retreating and orc.ai_flee_until == 1120, "Orc may flee again after thirty seconds")
	sim._initialize_student(orc, 1, Vector2i(20, 20))
	_check(orc.ai_flee_ready_at == 0 and not orc.ai_retreating, "New orc lifetime resets flee cooldown")


func _start_delay_tests() -> void:
	for mode: int in [ClassicSimulation.Difficulty.NORMAL, ClassicSimulation.Difficulty.EXPERT]:
		var sim: ClassicSimulation = _fixture(3)
		sim.difficulty = mode
		sim.ticks = 0
		var human: ClassicStudent = _unit(sim, 0, 0, Vector2i(4, 4))
		sim._add_area(Vector2i(8, 8), ClassicRules.AreaKind.RECRUIT, -1)
		sim.squad_ai.update(sim)
		_check((human.state == ClassicStudent.State.WALK) == (mode == ClassicSimulation.Difficulty.EXPERT), "Only Expert issues opening orders immediately")
		if mode == ClassicSimulation.Difficulty.NORMAL:
			sim.ticks = ClassicSimulation.AI_START_DELAY_TICKS - 1
			sim.squad_ai.update(sim)
			_check(human.state == ClassicStudent.State.SIT, "Normal waits through opening delay")
			sim.ticks += 1
			sim.squad_ai.update(sim)
			_check(human.state == ClassicStudent.State.WALK, "Normal starts at opening delay boundary")
			# Fresh reinforcements after the opening are immediately eligible.
			var recruit: ClassicStudent = _unit(sim, 1, 0, Vector2i(5, 4))
			sim.ticks += 36
			sim.squad_ai.update(sim)
			_check(recruit.state == ClassicStudent.State.WALK, "Opening delay is not reapplied to recruits")


func _expert_strategy_tests() -> void:
	for team: int in 4:
		var sim: ClassicSimulation = _fixture((team + 1) % 4)
		sim.difficulty = ClassicSimulation.Difficulty.EXPERT
		for color: int in 4:
			var baseline: int = 750 if color == 1 else 1500
			_check(sim.get_recruit_threshold(color) == baseline, "Expert retains normal spawn rates")
		var limit: int = 6 if team == 1 else 4
		for id: int in limit + 1:
			_unit(sim, id, team, Vector2i(8 + id, 8))
		sim.squad_ai._refresh(sim)
		_check(sim.squad_ai.squads.size() == 2 and sim.squad_ai.squads[0].size() == limit and sim.squad_ai.squads[1].size() == 1, "Expert fills race squads before making another")
	var sim: ClassicSimulation = _fixture(0)
	sim.difficulty = ClassicSimulation.Difficulty.EXPERT
	for id: int in 6:
		var elf: ClassicStudent = _unit(sim, id, 2, Vector2i(8 + id, 8))
		if id >= 4:
			elf.maximum_health = 28
	sim.squad_ai._refresh(sim)
	_check(sim.squad_ai.squads.size() == 1 and sim.squad_ai.squads[0].size() == 6, "Ranged elves may join a full four-member group")
	sim = _fixture(3)
	sim.difficulty = ClassicSimulation.Difficulty.EXPERT
	var human: ClassicStudent = _unit(sim, 0, 0, Vector2i(20, 20))
	_unit(sim, 1, 1, Vector2i(24, 20))
	sim._add_area(Vector2i(6, 5), ClassicRules.AreaKind.RECRUIT, -1)
	sim._add_area(Vector2i(8, 5), ClassicRules.AreaKind.RECRUIT, -1)
	sim.squad_ai.update(sim)
	_check(human.priority_target_id == -1 and Vector2i(human.destination.x / 4, human.destination.y / 4) == Vector2i(8, 5), "Expert humans capture peaceful tile over closer occupied tile")
	sim = _fixture(0)
	sim.difficulty = ClassicSimulation.Difficulty.EXPERT
	var guard: ClassicStudent = _unit(sim, 0, 2, Vector2i(20, 20))
	var wounded: ClassicStudent = _unit(sim, 1, 2, Vector2i(21, 20))
	wounded.health = 1
	var attacker: ClassicStudent = _unit(sim, 2, 1, Vector2i(22, 20))
	attacker.state = ClassicStudent.State.FIGHT
	attacker.target_id = wounded.id
	sim._add_area(Vector2i(5, 5), ClassicRules.AreaKind.HEAL, 2)
	sim._add_area(Vector2i(8, 8), ClassicRules.AreaKind.RECRUIT, -1)
	sim.squad_ai.update(sim)
	_check(guard.priority_target_id == attacker.id, "Expert elves protect wounded ally before capturing")
	attacker.target_id = -1
	attacker.state = ClassicStudent.State.SIT
	sim.ticks += 18
	sim.squad_ai.update(sim)
	_check(guard.priority_target_id == -1 and Vector2i(guard.destination.x / 4, guard.destination.y / 4) == Vector2i(8, 8), "Expert elves capture when no wounded allies are attacked")
	sim = _fixture(0)
	sim.difficulty = ClassicSimulation.Difficulty.EXPERT
	var demon: ClassicStudent = _unit(sim, 0, 3, Vector2i(20, 20))
	demon.health = 1
	var invader: ClassicStudent = _unit(sim, 1, 0, Vector2i(21, 20))
	invader.punch_bonus = 100
	sim._add_area(Vector2i(5, 5), ClassicRules.AreaKind.RECRUIT, 3)
	sim._add_area(Vector2i(3, 3), ClassicRules.AreaKind.HEAL, 3)
	sim._add_area(Vector2i(8, 8), ClassicRules.AreaKind.RECRUIT, -1)
	sim.squad_ai.update(sim)
	_check(demon.priority_target_id == invader.id and not demon.ai_retreating, "Wounded Expert demon defends owned tile even against stronger enemy")
	invader.state = ClassicStudent.State.UNUSED
	sim.ticks += 18
	sim.squad_ai.update(sim)
	_check(demon.ai_retreating and Vector2i(demon.destination.x / 4, demon.destination.y / 4) == Vector2i(3, 3), "After defence demon below thirty percent seeks healing")
	demon.health = demon.maximum_health
	sim.ticks += 18
	sim.squad_ai.update(sim)
	_check(not demon.ai_retreating and Vector2i(demon.destination.x / 4, demon.destination.y / 4) == Vector2i(8, 8), "Healthy demon captures after defence")
	sim = _fixture(0)
	sim.difficulty = ClassicSimulation.Difficulty.EXPERT
	demon = _unit(sim, 0, 3, Vector2i(2, 2))
	invader = _unit(sim, 1, 1, Vector2i(61, 61))
	sim._add_area(Vector2i(15, 15), ClassicRules.AreaKind.RECRUIT, 3)
	sim.squad_ai.update(sim)
	_check(demon.priority_target_id == -1, "Distant invasion does not grant Expert demon global awareness")

	# Separate objectives prevent nearby elf groups from piling onto one tile.
	sim = _fixture(0)
	sim.difficulty = ClassicSimulation.Difficulty.EXPERT
	for id: int in 8:
		_unit(sim, id, 2, Vector2i(20 + id, 20))
	sim._add_area(Vector2i(8, 8), ClassicRules.AreaKind.RECRUIT, -1)
	sim._add_area(Vector2i(12, 12), ClassicRules.AreaKind.RECRUIT, -1)
	sim.squad_ai.update(sim)
	_check(sim.students[0].destination.distance_to(sim.students[4].destination) >= 12, "Expert elf groups choose separated destinations")


func _player_tile_tests() -> void:
	for race: int in 4:
		for mode: int in [ClassicSimulation.Difficulty.NORMAL, ClassicSimulation.Difficulty.EXPERT]:
			var sim: ClassicSimulation = _fixture(race)
			sim.difficulty = mode
			var player: ClassicStudent = _unit(sim, 0, race, Vector2i(23, 20))
			var enemy: ClassicStudent = _unit(sim, 1, (race + 1) % 4, Vector2i(24, 20))
			sim._start_sit(player)
			_check((player.target_id == enemy.id) == (mode == ClassicSimulation.Difficulty.NORMAL), "Cross-tile automatic aggro restricted only on Expert for every player race")
			player.target_id = -1
			player.state = ClassicStudent.State.SIT
			sim._engage_defender(player, enemy)
			_check((player.target_id == enemy.id) == (mode == ClassicSimulation.Difficulty.NORMAL), "Cross-tile retaliation respects Expert player hold")
			if mode != ClassicSimulation.Difficulty.EXPERT:
				continue
			enemy.cell = Vector2i(22, 20)
			player.target_id = -1
			player.state = ClassicStudent.State.SIT
			sim._start_sit(player)
			_check(player.target_id == enemy.id, "Expert player can automatically engage same-tile enemy")
			enemy.cell = Vector2i(24, 20)
			sim._fighting(player)
			_check(player.target_id == -1, "Automatic pursuit stops when enemy leaves tile")
			sim.command([player.id], Vector2i.ZERO, enemy.id)
			_check(player.priority_target_id == enemy.id and player.target_id == enemy.id, "Explicit attack permits crossing tiles")
			sim.command([player.id], Vector2i(8, 8))
			_check(player.priority_target_id == -1 and Vector2i(player.destination.x / 4, player.destination.y / 4) == Vector2i(8, 8), "Explicit move still crosses tiles")
