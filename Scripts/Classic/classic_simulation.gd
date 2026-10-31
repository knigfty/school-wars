class_name ClassicSimulation
extends RefCounted

## Scene-independent, seeded simulation. Rendering and input never change its clock.
signal sound_requested(cue: String, position: Vector2)
signal team_eliminated(team: int)
signal match_finished(won: bool)

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var students: Array[ClassicStudent] = []
var areas: Array[Dictionary] = []
var occupancy: Dictionary = {}
var area_at: Dictionary = {}
var bases: Array[Vector2i] = []
var active: Array[bool] = [true, true, true, true]
var recruit_progress: Array[int] = [0, 0, 0, 0]
var player_team: int = 0
var ticks: int = 0
var leader: int = -1
var finished: bool = false
var ai_enabled: bool = true


func setup(team: int, map_seed: int) -> void:
	player_team = clampi(team, 0, 3)
	rng.seed = map_seed
	students.clear()
	areas.clear()
	occupancy.clear()
	area_at.clear()
	bases.assign([Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO])
	active.assign([true, true, true, true])
	recruit_progress.assign([0, 0, 0, 0])
	ticks = 0
	leader = -1
	finished = false
	var order: Array[int] = [0, 1, 2, 3]
	# The Flash source swaps with any of four entries on every iteration.
	for i: int in 4:
		var other: int = rng.randi_range(0, 3)
		var saved: int = order[i]
		order[i] = order[other]
		order[other] = saved
	var corners: Array[Vector2i] = [Vector2i(0, 0), Vector2i(15, 0), Vector2i(0, 15), Vector2i(15, 15)]
	for i: int in 4:
		bases[order[i]] = corners[i]
		_add_area(corners[i], ClassicRules.AreaKind.BASE, order[i])
	# Exactly 26 placement attempts, not a fixed number of neutral tiles.
	for attempt: int in 26:
		var tile: Vector2i = Vector2i(rng.randi_range(0, 15), rng.randi_range(0, 15))
		var clear: bool = not area_at.has(tile)
		for direction: Vector2i in ClassicRules.DIRECTIONS:
			if area_at.has(tile + direction):
				clear = false
		if clear:
			var kind: int = ClassicRules.AreaKind.HEAL if rng.randf() * 3.0 >= 2.0 else ClassicRules.AreaKind.RECRUIT
			_add_area(tile, kind, -1)
	for i: int in 48:
		var student: ClassicStudent = ClassicStudent.new()
		student.id = i
		students.append(student)
	for color: int in 4:
		for i: int in 3:
			spawn_student(color)


func _add_area(tile: Vector2i, kind: int, owner: int) -> void:
	area_at[tile] = areas.size()
	areas.append({"tile": tile, "kind": kind, "owner": owner, "progress": [0, 0, 0, 0]})


func get_count(team: int) -> int:
	var count: int = 0
	for student: ClassicStudent in students:
		if student.state != ClassicStudent.State.UNUSED and student.team == team:
			count += 1
	return count


func get_recruit_tiles(team: int) -> int:
	var count: int = 0
	for area: Dictionary in areas:
		if area.kind == ClassicRules.AreaKind.RECRUIT and area.owner == team:
			count += 1
	return count


func get_spawn_seconds(team: int) -> float:
	return float(ClassicRules.RECRUIT_THRESHOLD[team]) / float(2 + get_recruit_tiles(team)) / 18.0


func get_team_capacity(team: int) -> int:
	var captured: int = 0
	if team == 1:
		for area: Dictionary in areas:
			if area.owner == team and area.kind != ClassicRules.AreaKind.BASE:
				captured += 1
	return ClassicRules.TEAM_CAP + captured / 2


func _target_died(target: ClassicStudent) -> void:
	for unit: ClassicStudent in students:
		if unit.target_id == target.id:
			unit.destination = target.cell
			unit.target_id = -1
		if unit.priority_target_id == target.id:
			unit.priority_target_id = -1


func spawn_student(team: int) -> ClassicStudent:
	if not active[team] or get_count(team) >= get_team_capacity(team):
		return null
	var slots: Array[Vector2i] = []
	for y: int in 4:
		for x: int in 4:
			var cell: Vector2i = bases[team] * 4 + Vector2i(x, y)
			if not occupancy.has(cell):
				slots.append(cell)
	if slots.is_empty():
		return null
	# Grow the shared pool when Green's territory bonus exceeds the original 48 slots.
	var has_unused: bool = false
	for unit: ClassicStudent in students:
		if unit.state == ClassicStudent.State.UNUSED:
			has_unused = true
			break
	if not has_unused:
		var extra: ClassicStudent = ClassicStudent.new()
		extra.id = students.size()
		students.append(extra)
	for student: ClassicStudent in students:
		if student.state != ClassicStudent.State.UNUSED:
			continue
		student.team = team
		student.cell = slots[rng.randi_range(0, slots.size() - 1)]
		student.previous_cell = student.cell
		student.destination = student.cell
		student.health = ClassicRules.HEALTH[team]
		student.maximum_health = student.health
		student.level = 0
		student.level_ticks = 0
		student.direction = rng.randi_range(0, 3)
		student.target_id = -1
		student.priority_target_id = -1
		student.pattern = 10
		student.counter = rng.randi_range(10, 29)
		student.idle_ticks = 0
		student.history.clear()
		student.state = ClassicStudent.State.STAND
		occupancy[student.cell] = student.id
		return student
	return null


func step() -> void:
	if finished:
		return
	ticks += 1
	for student: ClassicStudent in students:
		student.level_ticks = maxi(0, student.level_ticks - 1)
		match student.state:
			ClassicStudent.State.STAND:
				student.counter -= 1
				if student.counter < 0:
					_start_sit(student)
			ClassicStudent.State.SIT:
				_sitting(student)
			ClassicStudent.State.WALK:
				_walking(student)
			ClassicStudent.State.WAIT:
				student.counter -= 1
				if student.counter < 0:
					_start_turn(student)
			ClassicStudent.State.FIGHT:
				_fighting(student)
			ClassicStudent.State.DEAD:
				_dying(student)
	if ai_enabled:
		_com_order(students[ticks % students.size()])
	for color: int in 4:
		if active[color]:
			recruit_progress[color] += 2 + get_recruit_tiles(color)
			if recruit_progress[color] > ClassicRules.RECRUIT_THRESHOLD[color]:
				recruit_progress[color] -= ClassicRules.RECRUIT_THRESHOLD[color]
				spawn_student(color)


func command(ids: Array[int], tile: Vector2i, target_id: int = -1) -> void:
	if finished or not ClassicRules.in_grid(tile * 4):
		return
	for id: int in ids:
		if id < 0 or id >= students.size():
			continue
		var student: ClassicStudent = students[id]
		if student.is_alive() and student.team == player_team:
			student.priority_target_id = target_id if _valid_enemy(student, target_id) else -1
			if student.state == ClassicStudent.State.FIGHT:
				student.state = ClassicStudent.State.STAND
			start_walk(student, tile, target_id)


func start_walk(student: ClassicStudent, tile: Vector2i, target_id: int = -1) -> void:
	student.target_id = target_id if _valid_enemy(student, target_id) else -1
	if student.target_id >= 0:
		var target: ClassicStudent = students[student.target_id]
		student.destination = target.cell
		if _adjacent(student.cell, target.cell):
			_start_fight(student, target)
			_engage_defender(target, student)
			return
	else:
		student.destination = tile * 4 + Vector2i(rng.randi_range(0, 3), rng.randi_range(0, 3))
	student.history.clear()
	if student.state != ClassicStudent.State.WALK:
		student.pattern = rng.randi_range(0, 9)
		_start_turn(student)


func _can_attack_priority(student: ClassicStudent) -> bool:
	if not _valid_enemy(student, student.priority_target_id):
		return false
	var priority: ClassicStudent = students[student.priority_target_id]
	return _adjacent(student.cell, priority.cell) and priority.state != ClassicStudent.State.WALK


func _engage_defender(target: ClassicStudent, attacker: ClassicStudent) -> void:
	if _can_attack_priority(target):
		return
	if target.state == ClassicStudent.State.FIGHT and _valid_enemy(target, target.target_id):
		if _contact_target(target, students[target.target_id]):
			return
	# Keep the focus order, but defend locally when its target is out of reach.
	if target.state == ClassicStudent.State.FIGHT:
		target.state = ClassicStudent.State.STAND
	# Flash remembers the attacker while the defender completes its reserved step.
	target.target_id = attacker.id
	if target.state != ClassicStudent.State.WALK:
		_start_fight(target, attacker)


func _start_stand(student: ClassicStudent) -> void:
	student.state = ClassicStudent.State.STAND
	student.counter = rng.randi_range(20, 49)
	student.pattern = 10
	student.idle_ticks = 0
	student.history.clear()


func _start_sit(student: ClassicStudent) -> void:
	if _valid_enemy(student, student.priority_target_id):
		start_walk(student, Vector2i.ZERO, student.priority_target_id)
		return
	var targets: Array[ClassicStudent] = []
	for other: ClassicStudent in students:
		if not other.is_alive() or other.team == student.team:
			continue
		if leader >= 0 and student.team != player_team and student.team != leader and other.team != leader:
			continue
		var offset: Vector2i = other.cell - student.cell
		if absi(offset.x) + absi(offset.y) <= 10:
			targets.append(other)
	if not targets.is_empty():
		start_walk(student, Vector2i.ZERO, targets[rng.randi_range(0, targets.size() - 1)].id)
		return
	student.state = ClassicStudent.State.SIT
	student.counter = rng.randi_range(30, 49)
	student.pattern = rng.randi_range(13, 15)


func _sitting(student: ClassicStudent) -> void:
	var tile: Vector2i = Vector2i(student.cell.x / 4, student.cell.y / 4)
	if area_at.has(tile):
		var area: Dictionary = areas[area_at[tile]]
		if area.kind >= ClassicRules.AreaKind.RECRUIT and area.owner != student.team:
			area.progress[student.team] += 1
			if area.progress[student.team] >= ClassicRules.CAPTURE_TICKS:
				area.owner = student.team
				for color: int in 4:
					if color != student.team:
						area.progress[color] = 0
				_update_leader()
		if area.owner == student.team and area.kind != ClassicRules.AreaKind.RECRUIT:
			student.health = minf(student.maximum_health, student.health + ClassicRules.HEAL_PER_TICK)
	student.counter -= 1
	student.idle_ticks += 1
	if student.counter < 0:
		_start_sit(student)


func _start_turn(student: ClassicStudent) -> void:
	if student.history.size() > 6:
		var repeats: int = 0
		for cell: Vector2i in student.history.slice(-6):
			if cell == student.cell:
				repeats += 1
		if repeats >= 3:
			_start_stand(student)
			return
	if student.target_id >= 0:
		if not _valid_enemy(student, student.target_id):
			_target_died(students[student.target_id])
		else:
			student.destination = students[student.target_id].cell
	var offset: Vector2i = student.destination - student.cell
	var choices: Array[int] = []
	var preferred: int = -1
	for index: int in 4:
		var direction: Vector2i = ClassicRules.DIRECTIONS[index]
		if offset.x * direction.x < 0 or offset.y * direction.y < 0:
			continue
		var next: Vector2i = student.cell + direction
		if not ClassicRules.in_grid(next) or occupancy.has(next):
			continue
		if (offset.x == 0 and direction.y != 0) or (offset.y == 0 and direction.x != 0):
			preferred = index
		choices.append(index)
	if offset == Vector2i.ZERO or choices.is_empty():
		if student.state == ClassicStudent.State.WAIT:
			_start_stand(student)
		else:
			student.state = ClassicStudent.State.WAIT
			student.counter = rng.randi_range(20, 99)
			student.pattern = 10
			student.history.clear()
		return
	student.direction = preferred if preferred >= 0 else choices[rng.randi_range(0, choices.size() - 1)]
	occupancy.erase(student.cell)
	student.history.append(student.cell)
	if student.history.size() > 12:
		student.history.pop_front()
	student.previous_cell = student.cell
	student.cell += ClassicRules.DIRECTIONS[student.direction]
	occupancy[student.cell] = student.id
	student.walk_tick = 0
	student.state = ClassicStudent.State.WALK


func _walking(student: ClassicStudent) -> void:
	student.walk_tick += 1
	student.pattern = (student.pattern + 1) % 10
	if student.walk_tick < 6:
		return
	if student.target_id >= 0:
		if not _valid_enemy(student, student.target_id):
			_target_died(students[student.target_id])
			_start_turn(student)
			return
		var target: ClassicStudent = students[student.target_id]
		if _adjacent(student.cell, target.cell):
			_start_fight(student, target)
			_engage_defender(target, student)
			return
	elif student.cell == student.destination:
		_start_stand(student)
		return
	_start_turn(student)


func _start_fight(student: ClassicStudent, target: ClassicStudent) -> void:
	if student.state == ClassicStudent.State.FIGHT:
		return
	student.state = ClassicStudent.State.FIGHT
	student.target_id = target.id
	student.fight_phase = 0
	student.pattern = 16
	_face_target(student, target)


func _face_target(student: ClassicStudent, target: ClassicStudent) -> void:
	var offset: Vector2i = target.cell - student.cell
	student.direction = 0
	if offset.y > 0:
		student.direction = 1
	if offset.x < 0:
		student.direction = 2
	if offset.y < 0:
		student.direction = 3


func _fighting(student: ClassicStudent) -> void:
	if not _valid_enemy(student, student.target_id):
		_start_stand(student)
		return
	var target: ClassicStudent = students[student.target_id]
	if student.fight_phase == 0:
		if target.state != ClassicStudent.State.WALK:
			student.pattern = 17
			student.counter = 1
			student.fight_phase = 1
		return
	student.counter -= 1
	if student.counter >= 0:
		return
	match student.fight_phase:
		1:
			student.pattern = 18
			student.counter = 1
			student.fight_phase = 2
		2:
			student.pattern = 19
			student.counter = 10
			student.fight_phase = 3
			if not _contact_target(student, target) or rng.randf() < 0.5:
				return
			target.pattern = 20
			target.fight_phase = 3
			target.counter = 5
			target.health -= ClassicRules.PUNCH[student.team]
			if target.health <= 0.0:
				target.health = 0.0
				_target_died(target)
				target.state = ClassicStudent.State.DEAD
				target.pattern = 20
				target.counter = 10
				target.fight_phase = 0
				# All colors gain one MAX HP; current health is not restored.
				student.maximum_health += 1.0
				student.level += 1
				student.level_ticks = 30
				sound_requested.emit("dead", target.world_position())
			else:
				if _can_attack_priority(target) and target.priority_target_id != student.id:
					sound_requested.emit("punch", target.world_position())
					return
				target.target_id = student.id
				_face_target(target, student)
				if target.state != ClassicStudent.State.FIGHT:
					_start_fight(target, student)
				sound_requested.emit("punch", target.world_position())
		3:
			if not _contact_target(student, target):
				_start_stand(student)
				return
			student.pattern = 17
			student.fight_phase = 1
			student.counter = 1


func _dying(student: ClassicStudent) -> void:
	if student.counter > 0:
		if student.fight_phase == 1:
			student.pattern = 23 if student.counter % 2 else 24
		student.counter -= 1
		return
	if student.fight_phase == 0:
		student.pattern += 1
		student.counter = 3
		if student.pattern >= 23:
			student.fight_phase = 1
			student.counter = 12
		student.counter -= 1
		return
	student.state = ClassicStudent.State.UNUSED
	occupancy.erase(student.cell)
	if get_count(student.team) == 0:
		active[student.team] = false
		team_eliminated.emit(student.team)
		var survivors: int = active.count(true)
		if not active[player_team] or survivors == 1:
			finished = true
			match_finished.emit(active[player_team])
	_update_leader()


func _update_leader() -> void:
	var values: Array[float] = []
	var total: float = 0.0
	for team: int in 4:
		var value: float = float(get_count(team) + get_recruit_tiles(team)) if active[team] else 0.0
		if team == 1:
			value /= 2.0
		values.append(value)
		total += value
	leader = -1
	for team: int in 4:
		if values[team] > total * 0.4:
			leader = team


func _com_order(student: ClassicStudent) -> void:
	if student.team == player_team or student.state != ClassicStudent.State.SIT or student.idle_ticks < 400:
		return
	var healthy: bool = is_equal_approx(student.health, student.maximum_health)
	var best: float = INF
	var destination: Vector2i = Vector2i.ZERO
	var tile: Vector2i = Vector2i(student.cell.x / 4, student.cell.y / 4)
	for area: Dictionary in areas:
		if healthy:
			if area.owner == student.team:
				continue
			if area.kind == ClassicRules.AreaKind.BASE and not active[area.owner]:
				continue
			if leader >= 0 and student.team != leader and area.owner != leader:
				continue
		elif area.owner != student.team or area.kind == ClassicRules.AreaKind.RECRUIT:
			continue
		var offset: Vector2i = area.tile - tile
		var cost: float = absi(offset.x) + absi(offset.y) + rng.randf() * 4.0
		if cost < best:
			best = cost
			destination = area.tile
	if best < INF:
		start_walk(student, destination)
		student.idle_ticks = 0
		return
	var target_id: int = -1
	for other: ClassicStudent in students:
		if not other.is_alive() or other.team == student.team:
			continue
		if leader >= 0 and student.team != leader and other.team != leader:
			continue
		var offset: Vector2i = other.cell - student.cell
		var cost: float = absi(offset.x) + absi(offset.y) + rng.randf() * 4.0
		if cost < best:
			best = cost
			target_id = other.id
	if target_id >= 0:
		start_walk(student, Vector2i.ZERO, target_id)
		student.idle_ticks = 0


func _valid_enemy(student: ClassicStudent, target_id: int) -> bool:
	return target_id >= 0 and target_id < students.size() and students[target_id].is_alive() and students[target_id].team != student.team


func _contact_target(student: ClassicStudent, target: ClassicStudent) -> bool:
	return target.is_alive() and target.state != ClassicStudent.State.WALK and student.cell + ClassicRules.DIRECTIONS[student.direction] == target.cell


func _adjacent(a: Vector2i, b: Vector2i) -> bool:
	var offset: Vector2i = a - b
	return absi(offset.x) + absi(offset.y) == 1
