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
	_destination_tests()
	_retaliation_tests()
	_squad_structure_tests()
	for mode: int in 3:
		var sim := _sim(mode)
		var human := _unit(sim, 0, 0, Vector2i(20,20))
		var ally := _unit(sim, 1, 0, Vector2i(28,20))
		_unit(sim, 2, 0, Vector2i(50,50))
		_unit(sim, 20, 1, Vector2i(21,20))
		human.health = 6
		sim.human_ai.update(sim)
		_check(not sim.human_ai.controls(human), "Exactly 30% individual HP does not regroup")
		human.health = 5
		sim.human_ai.update(sim)
		_check(sim.human_ai.controls(human) and human.ai_retreating, "Below 30% individual HP regroups on every difficulty")
		_check(human.ai_regroup_target_id == ally.id and human.designated_tile == Vector2i(7,5), "Nearest living Human is the regroup destination")
		_check(human.ai_heal_ready_at == 0, "Travel does not start regroup cooldown")
		sim.proximity_ai.update(sim)
		_check(not sim.proximity_ai.active(human), "Retreating Humans do not initiate proximity interception")
		var start: int = sim.ticks
		# Exercise actual movement and arrival, rather than only teleporting.
		for tick: int in 200:
			sim.ticks += 1
			sim.human_ai.update(sim)
			if human.state == ClassicStudent.State.WALK:
				sim._walking(human)
			elif human.state == ClassicStudent.State.WAIT:
				human.counter -= 1
				if human.counter < 0:
					sim._start_turn(human)
			if not sim.human_ai.controls(human):
				break
		_check(not sim.human_ai.controls(human) and Vector2i(human.cell / 4) == Vector2i(ally.cell / 4), "Regroup reaches an ally tile through real movement")
		_check(human.ai_heal_ready_at == sim.ticks + 20*18 and sim.ticks < start+20*18, "Arrival starts twenty-second cooldown")
		sim.human_ai.update(sim)
		_check(not sim.human_ai.controls(human), "Low HP cannot restart regroup during cooldown")
		# Retarget dead/reused allies without extending the original deadline.
		sim = _sim(mode)
		human = _unit(sim,0,0,Vector2i(20,20))
		ally = _unit(sim,1,0,Vector2i(40,40))
		human.health = 1
		sim.human_ai.update(sim)
		start = sim.ticks
		ally.state = ClassicStudent.State.DEAD
		sim.human_ai.update(sim)
		_check(human.ai_regroup_target_id == -1, "Dead ally cannot remain regroup target")
		sim.ticks = start+20*18-1
		sim.human_ai.update(sim)
		_check(sim.human_ai.controls(human), "Lone or blocked Human waits until travel deadline")
		sim.ticks += 1
		sim.human_ai.update(sim)
		_check(not human.ai_retreating and human.ai_heal_ready_at == sim.ticks+20*18, "Timeout ends regroup and starts cooldown at exactly twenty seconds")
		sim._initialize_student(human,0,Vector2i(20,20))
		_check(human.ai_regroup_started_at == -1 and human.ai_heal_ready_at == 0, "Respawn resets regroup lifecycle")
		# Healthy Humans use individual Easy orders and Normal/Expert squads.
		sim._add_area(Vector2i(7,5),ClassicRules.AreaKind.RECRUIT,-1)
		human.state = ClassicStudent.State.SIT
		human.idle_ticks = sim.AI_START_DELAY_TICKS
		human.tile_order_busy = false
		sim._com_order(human)
		_check((human.state == ClassicStudent.State.WALK) == (mode == 0), "Only Easy Humans receive individual strategic orders")
		sim.squad_ai.update(sim)
		var grouped: bool = false
		if mode != 0:
			for group: Array in sim.squad_ai.squads:
				grouped = grouped or human in group
			_check(grouped, "Normal/Expert Humans participate in squads")
		# Player units are never automatically retreated.
		sim.player_team = 0
		human.health = 1
		sim.human_ai.update(sim)
		_check(not human.ai_retreating, "Player Humans keep player control")
	print("Human organisation, retreat and retaliation tests: %d failure(s)" % failures)
	quit(1 if failures else 0)

func _destination_tests() -> void:
	for mode: int in 3:
		var sim := _sim(mode)
		var human := _unit(sim, 0, 0, Vector2i(24,24))
		var ally := _unit(sim, 1, 0, Vector2i(25,24))
		# Healing outranks even an adjacent ally. Nearest tile cell is 20 away.
		sim._add_area(Vector2i(11,6), ClassicRules.AreaKind.HEAL, 0)
		_check(sim.human_ai._destination(sim, human) == Vector2i(11,6), "Healing tile at inclusive 20-cell boundary outranks nearer ally")
		sim.areas[-1].owner = 2
		_check(sim.human_ai._destination(sim, human) == Vector2i(6,6), "Hostile healing tile is ignored in favour of nearby ally")
		ally.cell = Vector2i(44,24)
		_check(sim.human_ai._destination(sim, human) == Vector2i(11,6), "Ally at inclusive 20-cell boundary is eligible")
		ally.cell.x += 1
		_check(sim.human_ai._destination(sim, human) == sim.bases[0], "Ally beyond 20 cells falls back to base")
		sim.areas[-1].owner = 0
		human.cell.x = 23
		_check(sim.human_ai._destination(sim, human) == sim.bases[0], "Healing tile beyond 20 cells is ineligible")
		human.cell = Vector2i(24,24)
		human.health = 5
		sim.human_ai.update(sim)
		_check(human.ai_retreating and human.designated_tile == Vector2i(11,6), "Low-health Human selects healing priority on every difficulty")
		# Arrival must be at the selected destination, not just any friendly tile.
		human.state = ClassicStudent.State.SIT
		sim.human_ai.update(sim)
		_check(sim.human_ai.controls(human), "Retreat does not end on an unrelated friendly tile")
		human.cell = Vector2i(44,24)
		human.state = ClassicStudent.State.SIT
		sim.human_ai.update(sim)
		_check(not sim.human_ai.controls(human) and human.ai_heal_ready_at == sim.ticks + 360, "Healing destination arrival starts existing cooldown")

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
