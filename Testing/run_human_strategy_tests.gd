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
	for mode: int in 3:
		var sim := _sim(mode)
		var human := _unit(sim, 0, 0, Vector2i(20,20))
		var ally := _unit(sim, 1, 0, Vector2i(28,20))
		_unit(sim, 2, 0, Vector2i(50,50))
		_unit(sim, 20, 1, Vector2i(21,20))
		human.health = 10
		sim.human_ai.update(sim)
		_check(not sim.human_ai.controls(human), "Exactly 50% individual HP does not regroup")
		human.health = 9
		sim.human_ai.update(sim)
		_check(sim.human_ai.controls(human) and human.ai_retreating, "Below 50% individual HP regroups on every difficulty")
		_check(human.ai_regroup_target_id == ally.id and human.designated_tile == Vector2i(7,5), "Nearest living Human is the regroup destination")
		_check(human.ai_heal_ready_at == 0, "Travel does not start regroup cooldown")
		sim.proximity_ai.update(sim)
		_check(not sim.proximity_ai.active(human), "Human proximity interception removed")
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
		# Healthy Humans use basic individual orders, with no squad/conquest planner.
		sim._add_area(Vector2i(7,5),ClassicRules.AreaKind.RECRUIT,-1)
		human.state = ClassicStudent.State.SIT
		human.idle_ticks = sim.AI_START_DELAY_TICKS
		human.tile_order_busy = false
		sim._com_order(human)
		_check(human.state == ClassicStudent.State.WALK, "Basic Human orders remain available on all difficulties")
		sim.squad_ai.update(sim)
		for group: Array in sim.squad_ai.squads:
			_check(group[0].team != 0, "Human squad planning removed")
		# Player units are never automatically retreated.
		sim.player_team = 0
		human.health = 1
		sim.human_ai.update(sim)
		_check(not human.ai_retreating, "Player Humans keep player control")
	print("Human regroup tests: %d failure(s)" % failures)
	quit(1 if failures else 0)
