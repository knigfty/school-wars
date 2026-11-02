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
	sim.setup(0, 567)
	sim.ai_enabled = false
	for unit: ClassicStudent in sim.students:
		unit.state = ClassicStudent.State.UNUSED
	sim.occupancy.clear()
	return sim

func _pair(sim: ClassicSimulation, ranged: bool, moving: bool, punch_bonus: int = 0, elf: bool = false) -> Array[ClassicStudent]:
	sim.occupancy.clear()
	var attacker: ClassicStudent = sim.students[0]
	var target: ClassicStudent = sim.students[1]
	sim._initialize_student(attacker, 2 if elf else 0, Vector2i(20, 20))
	if ranged:
		attacker.level = 3
		if elf:
			attacker.maximum_health = 31
	sim._initialize_student(target, 3, Vector2i(22 if ranged else 21, 20))
	target.punch_bonus = punch_bonus
	target.state = ClassicStudent.State.WALK if moving else ClassicStudent.State.STAND
	target.previous_cell = target.cell - Vector2i.DOWN
	target.walk_tick = 2.5
	target.direction = 1
	attacker.direction = 0
	attacker.state = ClassicStudent.State.FIGHT
	attacker.target_id = target.id
	attacker.priority_target_id = target.id
	attacker.tile_guard_active = false
	return [attacker, target]

func _run() -> void:
	for difficulty: int in 3:
		for player_team: int in 4:
			for elf: bool in [false, true]:
				var sim: ClassicSimulation = _sim()
				sim.difficulty = difficulty
				sim.player_team = player_team
				for bonus: int in [0, 3, 8, 13]:
					var pair: Array[ClassicStudent] = _pair(sim, true, true, bonus, elf)
					var speed: float = sim.get_movement_multiplier(pair[1])
					var expected: float = 0.5 if is_equal_approx(speed, 1.2) else (0.7 if speed < 1.2 else 0.3)
					_check(is_equal_approx(sim.get_hit_chance(pair[0], pair[1]), expected), "Moving ranged accuracy follows live speed for all races, sides and difficulties")
	_test_rolls_and_motion()
	_test_contact_and_phases()
	_test_live_moving_attack()
	_test_classic()
	print("Accuracy tests: %d failure(s)" % failures)
	quit(1 if failures else 0)

func _test_rolls_and_motion() -> void:
	var sim: ClassicSimulation = _sim()
	for scenario: int in 5:
		var hits: int = 0
		for seed_value: int in 100:
			var ranged: bool = scenario != 4
			var moving: bool = scenario < 3
			var bonus: int = [0, 3, 13, 0, 0][scenario]
			var expected: float = [0.7, 0.5, 0.3, 0.8, 0.9][scenario]
			var pair: Array[ClassicStudent] = _pair(sim, ranged, moving, bonus)
			var attacker: ClassicStudent = pair[0]
			var target: ClassicStudent = pair[1]
			_check(is_equal_approx(sim.get_hit_chance(attacker, target), expected), "Exact requested accuracy bucket")
			attacker.fight_phase = 2
			attacker.counter = 0
			var before: float = target.health
			var cell_before: Vector2i = target.cell
			var previous_before: Vector2i = target.previous_cell
			var probe: RandomNumberGenerator = RandomNumberGenerator.new()
			probe.seed = seed_value
			var should_hit: bool = probe.randf() >= 1.0 - expected
			sim.rng.seed = seed_value
			sim._fighting(attacker)
			_check((target.health < before) == should_hit, "Actual attack resolves the seeded hit chance")
			if should_hit:
				hits += 1
				_check(target.damage_contributors.has(attacker.id), "Moving hits award damage participation")
			else:
				_check(target.damage_contributors.is_empty(), "Misses grant no damage credit")
			if moving:
				_check(target.state == ClassicStudent.State.WALK and target.walk_tick == 2.5 and target.direction == 1, "Nonlethal ranged hits preserve walking progress and facing")
				_check(target.cell == cell_before and target.previous_cell == previous_before and sim.occupancy[cell_before] == target.id, "Ranged hits preserve reserved movement cells")
				if should_hit:
					for step: int in 4:
						sim._walking(target)
					_check(target.state != ClassicStudent.State.WALK or target.walk_tick != 2.5, "Hit target can finish its current step")
		_check(hits > 0 and hits < 100, "Both hits and misses exercised in each bucket")

func _test_contact_and_phases() -> void:
	var sim: ClassicSimulation = _sim()
	var pair: Array[ClassicStudent] = _pair(sim, true, true)
	var attacker: ClassicStudent = pair[0]
	var target: ClassicStudent = pair[1]
	attacker.fight_phase = 0
	sim._fighting(attacker)
	_check(attacker.fight_phase == 1, "Ranged attack starts against a moving target")
	attacker.fight_phase = 3
	attacker.counter = 0
	sim._fighting(attacker)
	_check(attacker.fight_phase == 1 and attacker.state == ClassicStudent.State.FIGHT, "Ranged attack continues cycling against a moving target")
	_check(sim._can_attack_priority(attacker), "Moving ranged focus keeps priority")
	target.cell = Vector2i(21, 20)
	_check(is_equal_approx(sim.get_hit_chance(attacker, target), 0.7), "Extended reach remains ranged even against an adjacent target")
	target.cell = Vector2i(30, 20)
	_check(not sim._contact_target(attacker, target) and sim.get_hit_chance(attacker, target) == 0, "No hit beyond reach")
	pair = _pair(sim, false, true)
	attacker = pair[0]
	target = pair[1]
	attacker.fight_phase = 0
	sim._fighting(attacker)
	_check(attacker.fight_phase == 0 and sim.get_hit_chance(attacker, target) == 0, "Melee still waits for a moving target")
	for state: int in [ClassicStudent.State.STAND, ClassicStudent.State.SIT, ClassicStudent.State.WAIT, ClassicStudent.State.FIGHT]:
		target.state = state
		_check(is_equal_approx(sim.get_hit_chance(attacker, target), 0.9), "All stationary melee target states have 90 percent accuracy")
	target.state = ClassicStudent.State.DEAD
	_check(sim.get_hit_chance(attacker, target) == 0, "Dead targets cannot be hit")
	pair = _pair(sim, true, true)
	attacker = pair[0]
	target = pair[1]
	target.health = 1
	sim._apply_hit(attacker, target)
	_check(target.state == ClassicStudent.State.DEAD and target.health == 0, "Moving targets can be killed")
	_check(attacker.level == 4 and attacker.maximum_health == 22, "Moving target death awards normal human progression")

func _test_classic() -> void:
	var sim: ClassicSimulation = _sim()
	sim.medieval = false
	var pair: Array[ClassicStudent] = _pair(sim, false, false)
	_check(sim.get_hit_chance(pair[0], pair[1]) == 0.5, "Original stationary accuracy stays 50 percent")
	pair[1].state = ClassicStudent.State.WALK
	_check(sim.get_hit_chance(pair[0], pair[1]) == 0, "Original mode still blocks moving-target contact")


func _test_live_moving_attack() -> void:
	# Exercise the real battle clock from wind-up through impact while the victim walks.
	for elf: bool in [false, true]:
		var sim: ClassicSimulation = _sim()
		var pair: Array[ClassicStudent] = _pair(sim, true, true, 0, elf)
		var attacker: ClassicStudent = pair[0]
		var target: ClassicStudent = pair[1]
		target.tile_guard_active = false
		target.ai_retreating = true
		target.destination = Vector2i(50, 20)
		attacker.fight_phase = 0
		var before: float = target.health
		for candidate: int in 100:
			var probe: RandomNumberGenerator = RandomNumberGenerator.new()
			probe.seed = candidate
			if probe.randf() >= 0.3:
				sim.rng.seed = candidate
				break
		for tick: int in 5:
			sim.step()
		_check(target.health < before and target.state == ClassicStudent.State.WALK, "Live ranged wind-up connects while victim keeps walking")
