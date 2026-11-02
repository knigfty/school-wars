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
	_test_partial_groups()
	_test_group_healing()
	_test_conquest_capture()
	for mode: int in 3:
		var sim := _sim(mode)
		for id: int in 8:
			_unit(sim,id,0,Vector2i(4+id%4,4+id/4))
		sim._add_area(Vector2i(4,4), ClassicRules.AreaKind.RECRUIT,-1)
		sim._add_area(Vector2i(12,12), ClassicRules.AreaKind.HEAL,-1)
		_unit(sim,20,1,Vector2i(10,10))
		_unit(sim,21,2,Vector2i(40,10))
		_unit(sim,22,3,Vector2i(10,40))
		sim.human_ai.update(sim)
		_check(sim.human_ai.squads.size()==2, "Eight humans form two four-person squads on every difficulty")
		for squad: Array in sim.human_ai.squads:
			_check(squad.size()==4,"Normal capture squad cap is four")
		_check(sim.students[0].designated_tile==Vector2i(12,12),"Full-map awareness selects distant empty quadrant over nearby occupied quadrant")
		var strength_sim := _sim(mode)
		_unit(strength_sim,20,1,Vector2i(60,0),10)
		_unit(strength_sim,21,1,Vector2i(60,1),10)
		_unit(strength_sim,22,2,Vector2i(0,60),30)
		_check(strength_sim.human_ai.weakest_race(strength_sim)==2, "Weakest-race score uses both count and combined HP")
		# A larger enemy group cannot be acquired by the proximity controller.
		for id: int in range(1,8):
			sim.students[id].state=ClassicStudent.State.UNUSED
		var human: ClassicStudent=sim.students[0]
		for id: int in range(20,23):
			sim.occupancy.erase(sim.students[id].cell)
			sim.students[id].cell=human.cell+Vector2i(id-19,0)
		_check(not sim.human_ai.can_engage(sim,human,sim.students[20]),"Lone human refuses a larger enemy group")
		sim.proximity_ai.update(sim)
		_check(not sim.proximity_ai.active(human),"Proximity interception respects human numerical safety")
		# Trigger conquest and wait for the entire army, including a distant member.
		sim=_sim(mode)
		for id: int in 10:
			_unit(sim,id,0,Vector2i(id%4,id/4))
		sim.occupancy.erase(sim.students[9].cell)
		sim.students[9].cell=Vector2i(40,40)
		sim.occupancy[sim.students[9].cell]=9
		_unit(sim,20,1,Vector2i(60,0),40)
		_unit(sim,21,2,Vector2i(0,60),10)
		_unit(sim,22,3,Vector2i(60,60),80)
		sim.human_ai.update(sim)
		_check(sim.human_ai.phase=="rally", "Ten living humans trigger conquest rally and wait for distant member")
		for id: int in 10:
			_check(sim.students[id].designated_tile==sim.bases[0],"Entire conquest army receives base rally order")
		sim.occupancy.erase(sim.students[9].cell)
		sim.students[9].cell=Vector2i(18,3) # Exactly fifteen movement cells from base edge.
		sim.occupancy[sim.students[9].cell]=9
		sim.human_ai.update(sim)
		_check(sim.human_ai.phase=="attack" and sim.human_ai.target_race==2,"All humans within fifteen cells release wave against weakest count-times-HP race")
		for id: int in 10:
			_check(sim.students[id].priority_target_id==21,"Conquest wave shares one enemy focus")
		# Casualties trigger committed return, not continued capture orders.
		for id: int in range(3,10):
			sim.students[id].state=ClassicStudent.State.UNUSED
		for id: int in 3:
			sim.occupancy.erase(sim.students[id].cell)
			sim.students[id].cell=Vector2i(30+id,30)
			sim.occupancy[sim.students[id].cell]=id
		sim.human_ai.update(sim)
		_check(sim.human_ai.phase=="retreat", "Three conquest survivors retreat")
		for id: int in 3:
			_check(sim.students[id].ai_retreating and sim.students[id].designated_tile==sim.bases[0],"Survivors return to their base")
		for id: int in 3:
			sim.students[id].cell=Vector2i(id,0)
			sim.students[id].state=ClassicStudent.State.SIT
		sim.human_ai.update(sim)
		_check(sim.human_ai.phase=="normal" and not sim.students[0].ai_retreating,"Arrival resets conquest and restores normal capture strategy")
		# Successful elimination transitions to base capture, then normal state.
		sim.human_ai.phase="attack"
		sim.human_ai.target_race=2
		sim.students[21].state=ClassicStudent.State.DEAD
		sim.active[2]=true
		sim.human_ai.update(sim)
		_check(sim.human_ai.phase=="capture" and sim.students[0].designated_tile==sim.bases[2],"Last enemy defeated takes capture priority over three-survivor retreat, including death animation")
		sim.areas[sim.area_at[sim.bases[2]]].owner=0
		sim.human_ai.update(sim)
		_check(sim.human_ai.phase=="normal", "Captured base completes conquest")
	print("Human strategy tests: %d failure(s)" % failures)
	quit(1 if failures else 0)

func _test_conquest_capture() -> void:
	for mode: int in 3:
		var sim := _sim(mode)
		sim.bases[2] = Vector2i(0,2)
		sim._add_area(sim.bases[2], ClassicRules.AreaKind.BASE,2)
		for id: int in 10:
			var human: ClassicStudent = _unit(sim,id,0,Vector2i(id%4,id/4),200)
			human.punch_bonus = 36
		_unit(sim,20,2,Vector2i(0,8),1)
		_unit(sim,21,1,Vector2i(60,0),10000)
		_unit(sim,22,3,Vector2i(60,60),10000)
		for tick: int in 500:
			sim.step()
			if sim.areas[sim.area_at[sim.bases[2]]].owner == 0:
				break
		_check(not sim.active[2] and sim.get_count(2) == 0, "Conquest eliminates chosen race through real combat")
		_check(sim.areas[sim.area_at[sim.bases[2]]].owner == 0, "Conquest seats survivors and captures eliminated race's base")

func _test_partial_groups() -> void:
	for mode: int in 3:
		var sim := _sim(mode)
		sim._add_area(Vector2i(5,5),ClassicRules.AreaKind.RECRUIT,-1)
		for id: int in 5:
			_unit(sim,id,0,Vector2i(id,0))
		sim.human_ai.update(sim)
		var leader: ClassicStudent = sim.students[4]
		_check(sim.human_ai.squads.size()==2 and sim.human_ai.squads[1].size()==1,"Fifth recruit starts its own squad immediately")
		_check(leader.designated_tile==Vector2i(5,5) and leader.state==ClassicStudent.State.WALK,"One-person squad moves out to capture instead of waiting at base")
		for id: int in range(5,8):
			_unit(sim,id,0,Vector2i(id,0))
			sim.ticks+=18
			sim.human_ai.update(sim)
			_check(sim.human_ai.squads[1].size()==id-3,"Subsequent recruits fill the travelling second squad")
			_check(sim.human_ai.squads[1][0].unit==leader,"Joining recruits preserve the existing squad leader")
			_check(sim.students[id].designated_tile==leader.designated_tile,"Recruits follow the squad's current objective")

func _test_group_healing() -> void:
	for mode: int in 3:
		var sim := _sim(mode)
		for id: int in 4:
			_unit(sim,id,0,Vector2i(4+id,4))
		sim._add_area(Vector2i(2,2),ClassicRules.AreaKind.HEAL,-1)
		sim._add_area(Vector2i(10,10),ClassicRules.AreaKind.HEAL,0)
		for id: int in 4:
			sim.students[id].health=10
		sim.human_ai.update(sim)
		_check(sim.human_ai.recoveries.is_empty(),"Exactly fifty percent combined HP does not trigger retreat")
		sim.students[0].health=9
		sim.human_ai.update(sim)
		_check(sim.human_ai.recoveries.size()==1,"Below fifty percent combined HP triggers one group recovery")
		for id: int in 4:
			_check(sim.students[id].ai_retreating and sim.students[id].designated_tile==Vector2i(10,10),"Entire group prefers a captured heart over a nearer new heart")
		# Previously owned hearts remain preferred when empty, even after losing them.
		sim.areas[sim.area_at[Vector2i(10,10)]].owner=3
		var members: Array[ClassicStudent]=sim.human_ai.army(sim)
		_check(sim.human_ai._healing_goal(sim,members)==Vector2i(10,10),"Previously captured empty heart remains a preferred recapture destination")
		var enemy: ClassicStudent=_unit(sim,20,1,Vector2i(40,40))
		sim.human_ai.update(sim)
		_check(sim.students[0].designated_tile==Vector2i(2,2),"Contested preferred heart reroutes all members to an empty heart")
		_unit(sim,21,1,Vector2i(8,8))
		sim.human_ai.update(sim)
		_check(sim.students[0].designated_tile==sim.bases[0],"No empty heart sends group to base")
		# Actual travel, capture, sitting and healing on an empty neutral heart.
		sim=_sim(mode)
		for id: int in 4:
			_unit(sim,id,0,Vector2i(4+id,4))
			sim.students[id].health=9
		sim._add_area(Vector2i(2,2),ClassicRules.AreaKind.HEAL,-1)
		for tick: int in 600:
			sim.step()
			if sim.areas[sim.area_at[Vector2i(2,2)]].owner==0 and sim.human_ai.recoveries.is_empty():
				break
		_check(sim.areas[sim.area_at[Vector2i(2,2)]].owner==0,"Retreating squad captures an empty neutral heart")
		_check(sim.human_ai.recoveries.is_empty(),"Group resumes normal orders after full recovery")
		for id: int in 4:
			_check(sim.students[id].health==sim.students[id].maximum_health and not sim.students[id].ai_retreating,"All members heal fully before group retreat ends")
