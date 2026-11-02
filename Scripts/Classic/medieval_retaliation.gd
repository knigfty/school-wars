extends RefCounted

## Highest-priority AI response to attack attempts, independent of race strategy.
const SILENCE_TICKS: int = 3 * ClassicRules.TICKS_PER_SECOND
const ALLY_RADIUS: int = 8
var responses: Dictionary = {}

func active(unit: ClassicStudent) -> bool:
	return responses.has(unit.id) and responses[unit.id].life == unit.lifetime and unit.is_alive()

func target_id(unit: ClassicStudent) -> int:
	return int(responses[unit.id].target.id) if active(unit) else -1

func on_attack(sim, attacker: ClassicStudent, victim: ClassicStudent) -> void:
	if not sim.medieval or not sim.ai_enabled or attacker.team == victim.team:
		return
	# Firing at any opponent counts as continued attack activity.
	for existing: Dictionary in responses.values():
		if existing.target == attacker and existing.target_life == attacker.lifetime:
			existing.last = sim.ticks
	if victim.team == sim.player_team:
		return
	var ranged: bool = sim.get_attack_range(attacker) > 1
	for ally: ClassicStudent in sim.students:
		if not ally.is_alive() or ally.team != victim.team:
			continue
		# Escaping Humans, Orcs and Elves keep their safety destination under ranged fire.
		if ranged and ally.team in [0,1,2] and ally.ai_retreating:
			continue
		if ally != victim and absi(ally.cell.x-victim.cell.x)+absi(ally.cell.y-victim.cell.y)>ALLY_RADIUS:
			continue
		if not active(ally):
			responses[ally.id] = {"unit":ally,"life":ally.lifetime,"target":attacker,"target_life":attacker.lifetime,"last":sim.ticks,"started":sim.ticks,"goal":ally.designated_tile,"retreat":ally.ai_retreating,"response":ally.ranged_response_id,"pursuit":ally.ranged_pursuit_id,"proximity":sim.proximity_ai.engagements.get(ally.id,{}),"guard":ally.tile_guard_active}
		var record: Dictionary = responses[ally.id]
		record.target = attacker
		record.target_life = attacker.lifetime
		record.last = sim.ticks
		sim.proximity_ai.engagements.erase(ally.id)
		ally.tile_guard_active = false
		ally.tile_order_busy = false
		ally.ai_base_defence_tile = Vector2i(-1,-1)
		ally.returning_to_tile = false
		ally.retaliation_until = 0
		ally.ai_retreating = false
		_pursue(sim, ally, attacker)

func _pursue(sim, unit: ClassicStudent, attacker: ClassicStudent) -> void:
	if unit.state == ClassicStudent.State.FIGHT and unit.target_id != attacker.id:
		unit.state = ClassicStudent.State.STAND
	unit.priority_target_id = attacker.id
	unit.target_id = attacker.id
	if unit.state == ClassicStudent.State.WALK:
		return
	if unit.state == ClassicStudent.State.FIGHT:
		sim._face_target(unit, attacker)
	else:
		sim.start_walk(unit, Vector2i.ZERO, attacker.id)

func _release(sim, record: Dictionary) -> void:
	var unit: ClassicStudent = record.unit
	responses.erase(unit.id)
	unit.target_id = -1
	unit.priority_target_id = -1
	unit.ranged_response_id = record.response
	unit.ranged_pursuit_id = record.pursuit
	unit.ai_retreating = record.retreat
	unit.tile_guard_active = record.guard
	unit.designated_tile = record.goal if record.goal.x >= 0 else Vector2i(unit.cell.x/4,unit.cell.y/4)
	unit.tile_guard_target = -1
	unit.tile_clear_at = -1
	unit.tile_order_busy = false
	var elapsed: int = sim.ticks - int(record.started)
	if unit.ai_elf_retreat_started_at >= 0:
		unit.ai_elf_retreat_started_at += elapsed
	if unit.ai_flee_phase > 0:
		unit.ai_flee_until += elapsed
	if not record.proximity.is_empty():
		sim.proximity_ai.engagements[unit.id] = record.proximity
	if record.response >= 0 and sim.ranged_response.groups.has(record.response):
		var group: Dictionary = sim.ranged_response.groups[record.response]
		if group.mode == "chase" and group.target.is_alive() and group.target.lifetime == group.target_life:
			unit.priority_target_id = group.target.id
			sim.start_walk(unit, Vector2i.ZERO, group.target.id)
			return
	if unit.ai_retreating:
		sim.start_walk(unit, unit.designated_tile)
	elif unit.state == ClassicStudent.State.WALK:
		unit.destination = unit.cell
	else:
		sim._start_stand(unit)

func update(sim) -> void:
	for id: int in responses.keys():
		var record: Dictionary = responses[id]
		var unit: ClassicStudent = record.unit
		if not unit.is_alive() or unit.lifetime != record.life:
			responses.erase(id)
			continue
		var attacker: ClassicStudent = record.target
		if not attacker.is_alive() or attacker.lifetime != record.target_life or attacker.team == unit.team or sim.ticks-int(record.last)>=SILENCE_TICKS:
			_release(sim,record)
		else:
			_pursue(sim,unit,attacker)
