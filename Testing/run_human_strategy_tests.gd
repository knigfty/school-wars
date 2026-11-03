extends SceneTree
var failures: int = 0
func _initialize() -> void:
	call_deferred("_run")
func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _sim(mode: int) -> ClassicSimulation:
	var sim := ClassicSimulation.new()
	sim.medieval = true
	sim.difficulty = mode
	sim.setup(3, 123)
	sim.ticks = ClassicSimulation.AI_START_DELAY_TICKS
	for unit: ClassicStudent in sim.students:
		unit.state = ClassicStudent.State.UNUSED
	sim.occupancy.clear()
	sim.areas.clear()
	sim.area_at.clear()
	sim.bases.assign([Vector2i(0,0),Vector2i(15,0),Vector2i(0,15),Vector2i(15,15)])
	for race: int in 4:
		sim._add_area(sim.bases[race], ClassicRules.AreaKind.BASE, race)
	return sim
func _unit(sim: ClassicSimulation, id: int, race: int, cell: Vector2i, hp: float = 20) -> ClassicStudent:
	var unit: ClassicStudent = sim.students[id]
	sim._initialize_student(unit, race, cell)
	unit.health = hp
	unit.maximum_health = hp
	unit.ai_spawn_wait = false
	unit.state = ClassicStudent.State.SIT
	return unit
func _run() -> void:
	_heart_group_step_tests()
	_retaliation_tests()
	_squad_structure_tests()
	for mode: int in 3:
		var sim := _sim(mode)
		var human := _unit(sim, 0, 0, Vector2i(24,24))
		_unit(sim, 1, 0, Vector2i(25,24))
		human.health = 6
		sim.human_ai.update(sim)
		_check(not sim.human_ai.controls(human), "Exactly 30% HP does not begin retreat")
		human.health = 5
		_check(sim.human_ai._destination(sim, human) == sim.bases[0], "Nearby ally no longer substitutes for healing base")
		sim._add_area(Vector2i(11,6), ClassicRules.AreaKind.HEAL, 0)
		_check(sim.human_ai._destination(sim, human) == Vector2i(11,6), "Owned healing tile at 20 cells is eligible")
		human.cell.x = 23
		_check(sim.human_ai._destination(sim, human) == sim.bases[0], "Healing tile beyond 20 cells falls back to base")
		human.cell.x = 24
		sim.human_ai.update(sim)
		_check(sim.human_ai.controls(human) and human.ai_heal_tile == Vector2i(11,6), "Low HP begins committed healing retreat")
		sim.ticks += 1000
		sim.human_ai.update(sim)
		_check(sim.human_ai.controls(human), "Travel duration cannot abandon full-healing commitment")
		# Ownership loss retargets the base rather than an ally.
		sim.areas[-1].owner = 2
		sim.human_ai.update(sim)
		_check(human.ai_heal_tile == sim.bases[0], "Lost healing tile retargets base")
		sim.occupancy.erase(human.cell)
		human.cell = Vector2i(1,1)
		human.previous_cell = human.cell
		human.state = ClassicStudent.State.SIT
		sim.occupancy[human.cell] = human.id
		sim.human_ai.update(sim)
		_check(sim.human_ai.controls(human) and not human.ai_retreating, "Arrival begins healing without releasing commitment")
		sim._com_order(human)
		sim.squad_ai.update(sim)
		sim.proximity_ai.update(sim)
		_check(human.state == ClassicStudent.State.SIT and human.designated_tile == sim.bases[0], "Individual, squad and interception planners cannot pull healing Human away")
		for tick: int in 151:
			sim._sitting(human)
			sim.human_ai.update(sim)
		_check(human.health == human.maximum_health and not sim.human_ai.controls(human), "Base recovery releases only after actual full healing")
		_check(human.ai_heal_ready_at == sim.ticks+360, "Full recovery starts existing twenty-second cooldown")
		# Capture must hold all wounded occupants, even above retreat threshold,
		# while allowing healthy members to continue and respecting active cooldowns.
		sim = _sim(mode)
		var tile := Vector2i(5,5)
		sim._add_area(tile, ClassicRules.AreaKind.HEAL, -1)
		for id: int in 3:
			var unit := _unit(sim, id, 0, Vector2i(20+id,20))
			unit.health = 15 if id < 2 else 20
			unit.ai_heal_ready_at = sim.ticks+1000
		sim.areas[-1].progress[0] = 299
		sim._capture_areas()
		_check(sim.areas[-1].owner == 0 and sim.human_ai.controls(sim.students[0]) and sim.human_ai.controls(sim.students[1]), "Captured heart commits every wounded Human despite cooldown or HP above 30%")
		_check(sim.human_ai.controls(sim.students[2]), "Healthy Human waits for wounded companions")
		sim.human_ai.update(sim)
		for tick: int in 51:
			for id: int in 2:
				sim._sitting(sim.students[id])
			sim.human_ai.update(sim)
		_check(not sim.human_ai.controls(sim.students[0]) and sim.students[0].health == 20, "Captured-heart occupants resume orders after real healing reaches full HP")
		# Player-controlled Humans retain manual orders.
		sim.player_team = 0
		human = sim.students[0]
		human.health = 1
		sim.human_ai.update(sim)
		_check(not sim.human_ai.controls(human), "Player Humans retain manual control")
		sim._initialize_student(human, 0, Vector2i(20,20))
		_check(human.ai_regroup_started_at == -1 and human.ai_heal_tile == Vector2i(-1,-1), "Fresh Human resets committed healing")
	print("Human organisation and full-healing tests: %d failure(s)" % failures)
	quit(1 if failures else 0)

func _retaliation_tests() -> void:
	for mode: int in 3:
		var sim := _sim(mode)
		var human := _unit(sim, 0, 0, Vector2i(20,20))
		var ally := _unit(sim, 1, 0, Vector2i(21,20))
		var shooter := _unit(sim, 10, 2, Vector2i(40,20), 95)
		sim._add_area(Vector2i(8,5), ClassicRules.AreaKind.HEAL, 0)
		human.health = 5
		sim.human_ai.update(sim)
		var goal: Vector2i = human.designated_tile
		sim.retaliation_ai.on_attack(sim, shooter, human)
		_check(human.ai_retreating and not sim.retaliation_ai.active(human) and human.designated_tile == goal, "Actual Human retreat ignores ranged attack attempts and retains safety destination")
		_check(sim.retaliation_ai.active(ally), "Nearby available ally covers retreating Human")
		shooter.maximum_health = 25
		shooter.cell = Vector2i(20,21)
		sim.retaliation_ai.on_attack(sim, shooter, human)
		_check(sim.retaliation_ai.active(human) and sim._may_engage(human, shooter), "Melee retaliation interrupts actual Human retreat")
		# After the reserved step, melee response must route toward the attacker,
		# rather than being diverted back into retreat routing.
		human.state = ClassicStudent.State.STAND
		human.previous_cell = human.cell
		shooter.cell = Vector2i(16,20)
		sim._start_turn(human)
		_check(human.state == ClassicStudent.State.WALK and human.cell.x < 20, "Interrupted Human actually moves toward melee attacker instead of safety tile")
		shooter.state = ClassicStudent.State.DEAD
		sim.retaliation_ai.update(sim)
		sim.human_ai.update(sim)
		_check(sim.human_ai.controls(human) and human.ai_retreating and human.designated_tile == goal, "Human resumes retreat after melee attacker dies")

func _squad_structure_tests() -> void:
	for mode: int in [ClassicSimulation.Difficulty.NORMAL, ClassicSimulation.Difficulty.EXPERT]:
		var sim := _sim(mode)
		for id: int in 4:
			_unit(sim, id, 0, Vector2i(20+id,20))
		if mode == ClassicSimulation.Difficulty.EXPERT:
			for id: int in [4,5]:
				var ranged := _unit(sim, id, 0, Vector2i(20+id,20))
				ranged.level = 3
			_unit(sim, 6, 2, Vector2i(20,22))
		sim.squad_ai._refresh(sim)
		var humans: int = 0
		var largest: int = 0
		for group: Array in sim.squad_ai.squads:
			if group[0].team == 0:
				humans += group.size()
				largest = maxi(largest, group.size())
				for member: ClassicStudent in group:
					_check(member.team == 0, "Human squads never recruit Elf supporters")
		_check(humans == (6 if mode == ClassicSimulation.Difficulty.EXPERT else 4), "Human squad membership includes all available core units and ranged supporters")
		_check(largest == (6 if mode == ClassicSimulation.Difficulty.EXPERT else 4), "Expert Human ranged supporters join a full four-member core like Elves")

func _heart_group_step_tests() -> void:
	for mode: int in 3:
		var sim := _sim(mode)
		var tile := Vector2i(5,5)
		sim._add_area(tile,ClassicRules.AreaKind.HEAL,0)
		sim._add_area(Vector2i(8,5),ClassicRules.AreaKind.RECRUIT,-1)
		var wounded := _unit(sim,0,0,Vector2i(23,20))
		wounded.health = 10
		var healthy := _unit(sim,1,0,Vector2i(22,20))
		var moderate := _unit(sim,2,0,Vector2i(21,20))
		moderate.health = 18
		# Reproduce missed capture hook / old ownership and an outgoing reserved step.
		sim.designate_order(wounded,Vector2i(8,5))
		sim._reserve_step(wounded,0)
		_check(wounded.cell.x == 24, "Fixture reserves exit across heart boundary")
		var released: bool = false
		for tick: int in 300:
			sim.step()
			if not sim.human_ai.controls(healthy):
				released = true
				_check(wounded.health == wounded.maximum_health and moderate.health == moderate.maximum_health, "Group releases only after every wounded companion reaches full HP")
				_check(wounded.designated_tile == healthy.designated_tile and moderate.designated_tile == healthy.designated_tile and healthy.designated_tile == Vector2i(8,5), "Healed group receives one common departure destination on every difficulty")
				break
			_check(Vector2i(healthy.cell.x/4,healthy.cell.y/4) == tile, "Healthy companion stays on heart through real simulation steps")
			if moderate.health == moderate.maximum_health:
				_check(sim.human_ai.controls(moderate) and Vector2i(moderate.cell.x/4,moderate.cell.y/4) == tile, "Earlier-healed member waits for slowest companion")
		_check(released, "Outgoing unit returns, heals and releases group without deadlock")
		# A fallen member cannot permanently block the waiting cohort.
		sim = _sim(mode)
		sim._add_area(tile,ClassicRules.AreaKind.HEAL,0)
		wounded = _unit(sim,0,0,Vector2i(20,20))
		wounded.health = 10
		healthy = _unit(sim,1,0,Vector2i(21,20))
		sim.human_ai.update(sim)
		wounded.state = ClassicStudent.State.DEAD
		sim.human_ai.update(sim)
		_check(not sim.human_ai.controls(healthy), "Dead wounded companion does not trap healthy group")
