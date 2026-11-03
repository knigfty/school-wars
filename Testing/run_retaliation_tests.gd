extends SceneTree
var failures: int = 0
func _initialize() -> void:
	call_deferred("_run")
func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _unit(sim: ClassicSimulation,id:int,race:int,cell:Vector2i) -> ClassicStudent:
	var unit: ClassicStudent=sim.students[id]
	sim._initialize_student(unit,race,cell)
	unit.ai_spawn_wait=false
	unit.state=ClassicStudent.State.SIT
	unit.health=1000
	unit.maximum_health=1000
	return unit
func _sim(mode:int,race:int) -> ClassicSimulation:
	var sim:=ClassicSimulation.new()
	sim.medieval=true
	sim.difficulty=mode
	sim.setup(0 if race==2 else 2,123)
	sim.ticks=100
	for unit:ClassicStudent in sim.students:
		unit.state=ClassicStudent.State.UNUSED
	sim.occupancy.clear()
	sim.areas.clear()
	sim.area_at.clear()
	_unit(sim,0,race,Vector2i(20,20))
	if race==2:
		sim.students[0].maximum_health=25
		sim.students[0].health=25
	_unit(sim,1,race,Vector2i(21,20))
	_unit(sim,2,race,Vector2i(20,22))
	_unit(sim,3,race,Vector2i(20,32))
	var shooter:ClassicStudent=_unit(sim,10,sim.player_team,Vector2i(40,20))
	shooter.maximum_health=95 if shooter.team==2 else 1000
	shooter.level=30
	shooter.state=ClassicStudent.State.FIGHT
	shooter.target_id=0
	shooter.priority_target_id=0
	shooter.tile_guard_active=false
	shooter.fight_phase=1
	shooter.counter=10000
	sim._add_area(Vector2i(5,5),ClassicRules.AreaKind.BASE,race)
	return sim
func _run() -> void:
	for mode:int in 3:
		for race:int in 4:
			for context:String in ["guard","retreat","healing","conquest"]:
				var sim:=_sim(mode,race)
				var victim:ClassicStudent=sim.students[0]
				var shooter:ClassicStudent=sim.students[10]
				if context=="retreat":
					victim.ai_retreating=true
				if context=="healing" and race==2:
					victim.ai_elf_recovering=true
					victim.ai_elf_arrived=true
				_check(sim._contact_target(shooter,victim),"Long-range test shot has valid contact")
				sim._apply_hit(shooter,victim)
				if context=="retreat" and race in [0,1,2]:
					_check(not sim.retaliation_ai.active(victim) and victim.ai_retreating and victim.priority_target_id==-1,"Escaping Humans, Orcs and Elves ignore ranged retaliation and keep retreating")
					_check(sim.retaliation_ai.active(sim.students[1]),"Non-retreating nearby allies can still cover the escaping unit")
					continue
				for id:int in 3:
					_check(sim.retaliation_ai.active(sim.students[id]) and sim.students[id].priority_target_id==10,"Victim and nearby allies always respond regardless of race, difficulty or state")
				_check(not sim.retaliation_ai.active(sim.students[3]),"Distant allies are not pulled into the response")
				_check(sim._may_engage(victim,shooter),"Retaliation bypasses tile leash, retreat and Human numerical restrictions")
				for tick:int in 30:
					sim.step()
				_check(sim.retaliation_ai.active(victim) and victim.priority_target_id==10,"Strategic planners cannot override retaliation")
				_check(victim.cell!=Vector2i(20,20),"Out-of-range defender advances towards shooter")
				# Continued attack attempts, even misses, sustain the response.
				sim.retaliation_ai.on_attack(sim,shooter,victim)
				var last:int=sim.ticks
				sim.ticks=last+53
				sim.retaliation_ai.update(sim)
				_check(sim.retaliation_ai.active(victim),"Pursuit persists just before three seconds of silence")
				sim.ticks=last+54
				sim.retaliation_ai.update(sim)
				_check(not sim.retaliation_ai.active(victim),"Pursuit releases at exactly three seconds without attacking")
			# Death and lifetime reuse cannot retain or transfer retaliation.
			var sim:=_sim(mode,race)
			sim.retaliation_ai.on_attack(sim,sim.students[10],sim.students[0])
			sim.students[10].state=ClassicStudent.State.DEAD
			sim.retaliation_ai.update(sim)
			_check(not sim.retaliation_ai.active(sim.students[0]),"Attacker death ends retaliation")
			sim=_sim(mode,race)
			sim.retaliation_ai.on_attack(sim,sim.students[10],sim.students[0])
			sim._initialize_student(sim.students[0],race,Vector2i(20,20))
			sim.retaliation_ai.update(sim)
			_check(not sim.retaliation_ai.active(sim.students[0]),"A replacement unit never inherits retaliation")
	for mode:int in 3:
		for race:int in [0,1,2]:
			var escape:=_sim(mode,race)
			var ally:ClassicStudent=escape.students[1]
			ally.ai_retreating=true
			ally.designated_tile=Vector2i(2,2)
			escape.retaliation_ai.on_attack(escape,escape.students[10],escape.students[0])
			_check(not escape.retaliation_ai.active(ally) and ally.designated_tile==Vector2i(2,2) and ally.ai_retreating,"A retreating ally is never recruited into a nearby ranged response")
			# Melee attackers retain ordinary retaliation, even during retreat.
			escape=_sim(mode,race)
			escape.students[0].ai_retreating=true
			var melee:ClassicStudent=escape.students[11]
			escape._initialize_student(melee,3,Vector2i(21,20))
			escape.retaliation_ai.on_attack(escape,melee,escape.students[0])
			_check(escape.retaliation_ai.active(escape.students[0]),"Retreat exception applies to ranged fire; melee still triggers retaliation")
	# A real missed attack still wakes defenders, independently of damage credit.
	var missed: bool=false
	for seed_value:int in 32:
		var probe:=_sim(0,0)
		probe.rng.seed=seed_value
		var shooter:ClassicStudent=probe.students[10]
		shooter.fight_phase=2
		shooter.counter=-1
		var health:float=probe.students[0].health
		probe._fighting(shooter)
		if probe.students[0].health==health:
			_check(probe.retaliation_ai.active(probe.students[0]) and probe.students[0].damage_contributors.is_empty(),"Missed attack activates retaliation without awarding damage participation")
			missed=true
			break
	_check(missed,"Missed-attack regression exercises a real miss")
	var paused:=_sim(1,2)
	paused.students[0].ai_elf_recovering=true
	paused.students[0].ai_retreating=true
	paused.students[0].ai_elf_retreat_started_at=100
	paused.retaliation_ai.on_attack(paused,paused.students[10],paused.students[0])
	paused.ticks=154
	paused.retaliation_ai.update(paused)
	_check(not paused.retaliation_ai.active(paused.students[0]) and paused.students[0].ai_elf_retreat_started_at==100,"Ranged fire leaves escaping Elf retreat timer running normally")
	var ongoing:=_sim(0,0)
	ongoing.retaliation_ai.on_attack(ongoing,ongoing.students[10],ongoing.students[0])
	ongoing.ticks=150
	var third_party:ClassicStudent=_unit(ongoing,20,1,Vector2i(40,21))
	ongoing.retaliation_ai.on_attack(ongoing,ongoing.students[10],third_party)
	ongoing.ticks=154
	ongoing.retaliation_ai.update(ongoing)
	_check(ongoing.retaliation_ai.active(ongoing.students[0]),"Attacker firing at another opponent still sustains pursuit")
	var orc_pause:=_sim(0,1)
	orc_pause.students[0].ai_retreating=true
	orc_pause.students[0].ai_flee_phase=1
	orc_pause.students[0].ai_flee_until=280
	orc_pause.retaliation_ai.on_attack(orc_pause,orc_pause.students[10],orc_pause.students[0])
	orc_pause.ticks=154
	orc_pause.retaliation_ai.update(orc_pause)
	_check(not orc_pause.retaliation_ai.active(orc_pause.students[0]) and orc_pause.students[0].ai_flee_until==280 and orc_pause.students[0].ai_retreating,"Ranged fire does not pause or redirect the Orc flee itinerary")
	# A lethal opening hit still calls nearby allies to retaliate.
	var sim:=_sim(2,0)
	sim.students[0].health=1
	sim._apply_hit(sim.students[10],sim.students[0])
	_check(sim.students[0].state==ClassicStudent.State.DEAD and sim.retaliation_ai.active(sim.students[1]),"Nearby survivors respond to a lethal opening attack")
	print("Universal retaliation tests: %d failure(s)"%failures)
	quit(1 if failures else 0)
