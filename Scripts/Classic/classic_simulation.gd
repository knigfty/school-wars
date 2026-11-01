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
var last_spawn_base: Array[Vector2i] = []
var player_team: int = 0
var ticks: int = 0
var leader: int = -1
var finished: bool = false
var ai_enabled: bool = true
# Selection is retained per match; Easy preserves the original individual AI.
enum Difficulty { EASY, NORMAL, EXPERT }
var difficulty: int = Difficulty.EASY
const SQUAD_AI = preload("res://Scripts/Classic/medieval_squad_ai.gd")
var squad_ai = SQUAD_AI.new()
# Opt-in variant rules; classic remains the default.
var medieval: bool = false
const HUMAN_CAPTURE_SECONDS: Array[int] = [12, 9, 6, 4, 2, 1]
const AI_START_DELAY_TICKS: int = 400


func setup(team: int, map_seed: int) -> void:
	squad_ai = SQUAD_AI.new()
	player_team = clampi(team, 0, 3)
	rng.seed = map_seed
	students.clear()
	areas.clear()
	occupancy.clear()
	area_at.clear()
	bases.assign([Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO])
	active.assign([true, true, true, true])
	recruit_progress.assign([0, 0, 0, 0])
	last_spawn_base.assign([Vector2i(-1, -1), Vector2i(-1, -1), Vector2i(-1, -1), Vector2i(-1, -1)])
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
	areas.append({"tile": tile, "kind": kind, "owner": owner, "progress": [0.0, 0.0, 0.0, 0.0], "spawn_progress": 0})


func get_count(team: int) -> int:
	var count: int = 0
	for student: ClassicStudent in students:
		if student.state != ClassicStudent.State.UNUSED and student.team == team:
			count += 1
	return count


func get_converted_count(team: int) -> int:
	var count: int = 0
	if medieval and team == 1:
		for unit: ClassicStudent in students:
			if unit.state != ClassicStudent.State.UNUSED and unit.team == team and unit.is_converted:
				count += 1
	return count


func get_regular_count(team: int) -> int:
	return get_count(team) - get_converted_count(team)


func get_recruit_tiles(team: int) -> int:
	var count: int = 0
	for area: Dictionary in areas:
		if area.kind == ClassicRules.AreaKind.RECRUIT and area.owner == team:
			count += 1
	return count


func get_recruit_threshold(team: int) -> int:
	return 750 if medieval and team == 1 else ClassicRules.RECRUIT_THRESHOLD[team]


func get_conquered_base_count(team: int) -> int:
	var count: int = 0
	if medieval:
		for area: Dictionary in areas:
			if area.kind == ClassicRules.AreaKind.BASE and area.owner == team and area.tile != bases[team]:
				count += 1
	return count


func get_spawn_seconds(team: int) -> float:
	return float(get_recruit_threshold(team)) / float(2 + get_recruit_tiles(team)) / 18.0


func get_team_capacity(team: int) -> int:
	var captured: int = 0
	if team == 1:
		for area: Dictionary in areas:
			if area.owner == team and area.kind != ClassicRules.AreaKind.BASE:
				captured += 1
	return ClassicRules.TEAM_CAP + captured / 2 + get_conquered_base_count(team) * 6


func _target_died(target: ClassicStudent) -> void:
	for unit: ClassicStudent in students:
		if unit.target_id == target.id:
			unit.destination = target.cell
			unit.target_id = -1
		if unit.priority_target_id == target.id:
			unit.priority_target_id = -1


func spawn_student(team: int, base_tile: Vector2i = Vector2i(-1, -1)) -> ClassicStudent:
	if not active[team] or get_regular_count(team) >= get_team_capacity(team):
		return null
	if base_tile == Vector2i(-1, -1):
		base_tile = bases[team]
	if medieval and base_tile not in get_spawn_bases(team):
		return null
	var slots: Array[Vector2i] = []
	for y: int in 4:
		for x: int in 4:
			var cell: Vector2i = base_tile * 4 + Vector2i(x, y)
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
		_initialize_student(student, team, slots[rng.randi_range(0, slots.size() - 1)])
		return student
	return null


func _initialize_student(student: ClassicStudent, team: int, cell: Vector2i) -> void:
	student.is_converted = false
	student.ai_retreating = false
	student.ai_flee_until = 0
	student.ai_flee_ready_at = 0
	student.last_attacked_tick = -1000000
	student.ai_hold_ground_until = 0
	student.ai_heal_tile = Vector2i(-1, -1)
	student.ai_heal_decide_at = 0
	student.ai_heal_ready_at = 0
	student.lifetime += 1
	student.damage_contributors.clear()
	student.team = team
	student.cell = cell
	student.previous_cell = cell
	student.destination = cell
	student.health = ClassicRules.HEALTH[team]
	student.maximum_health = student.health
	student.punch_bonus = 0
	student.level = 0
	student.level_ticks = 0
	student.event_text = ""
	student.walk_tick = 0.0
	student.direction = rng.randi_range(0, 3)
	student.target_id = -1
	student.priority_target_id = -1
	student.approach_cell = Vector2i(-1, -1)
	student.pattern = 10
	student.counter = rng.randi_range(10, 29)
	student.fight_phase = 0
	student.idle_ticks = 0
	student.history.clear()
	student.state = ClassicStudent.State.STAND
	occupancy[cell] = student.id


func step() -> void:
	if finished:
		return
	ticks += 1
	if medieval:
		for attacker: ClassicStudent in students:
			if attacker.state == ClassicStudent.State.FIGHT and attacker.target_id >= 0:
				var victim: ClassicStudent = students[attacker.target_id]
				if victim.is_alive() and victim.team != attacker.team and _within_attack_range(attacker, victim):
					victim.last_attacked_tick = ticks
	if uses_squad_ai():
		squad_ai.update(self)
	if medieval:
		_capture_areas()
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
	if ai_enabled and not uses_squad_ai():
		_com_order(students[ticks % students.size()])
	for color: int in 4:
		if active[color]:
			recruit_progress[color] += 2 + get_recruit_tiles(color)
			var threshold: int = get_recruit_threshold(color)
			if medieval:
				recruit_progress[color] = mini(recruit_progress[color], threshold)
				if recruit_progress[color] >= threshold:
					var base: Vector2i = get_priority_spawn_base(color)
					if base.x >= 0 and spawn_student(color, base) != null:
						recruit_progress[color] = 0
						last_spawn_base[color] = base
			elif recruit_progress[color] > threshold:
				recruit_progress[color] -= threshold
				spawn_student(color)


func command(ids: Array[int], tile: Vector2i, target_id: int = -1) -> void:
	if finished or not ClassicRules.in_grid(tile * 4):
		return
	for id: int in ids:
		if id < 0 or id >= students.size():
			continue
		var student: ClassicStudent = students[id]
		if student.is_alive() and student.team == player_team:
			student.approach_cell = Vector2i(-1, -1)
			student.priority_target_id = target_id if _valid_enemy(student, target_id) else -1
			if student.state == ClassicStudent.State.FIGHT:
				student.state = ClassicStudent.State.STAND
			start_walk(student, tile, target_id)


func start_walk(student: ClassicStudent, tile: Vector2i, target_id: int = -1) -> void:
	student.target_id = target_id if _valid_enemy(student, target_id) else -1
	if student.target_id >= 0:
		var target: ClassicStudent = students[student.target_id]
		student.destination = target.cell
		if _within_attack_range(student, target):
			_start_fight(student, target)
			_engage_defender(target, student)
			return
	else:
		student.destination = tile * 4 + Vector2i(rng.randi_range(0, 3), rng.randi_range(0, 3))
	student.history.clear()
	if student.state != ClassicStudent.State.WALK:
		student.pattern = rng.randi_range(0, 9)
		_start_turn(student)


func _holds_player_tile(student: ClassicStudent) -> bool:
	return medieval and difficulty == Difficulty.EXPERT and student.team == player_team and not _valid_enemy(student, student.priority_target_id)


func _may_engage(student: ClassicStudent, target: ClassicStudent) -> bool:
	return not _holds_player_tile(student) or Vector2i(student.cell.x / 4, student.cell.y / 4) == Vector2i(target.cell.x / 4, target.cell.y / 4)


func _stop_cross_tile_pursuit(student: ClassicStudent) -> bool:
	if _valid_enemy(student, student.target_id) and not _may_engage(student, students[student.target_id]):
		student.target_id = -1
		student.destination = student.cell
		_start_stand(student)
		return true
	return false


func _can_attack_priority(student: ClassicStudent) -> bool:
	if not _valid_enemy(student, student.priority_target_id):
		return false
	var priority: ClassicStudent = students[student.priority_target_id]
	return _within_attack_range(student, priority) and priority.state != ClassicStudent.State.WALK


func _engage_defender(target: ClassicStudent, attacker: ClassicStudent) -> void:
	if target.ai_retreating or not _may_engage(target, attacker):
		return
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
		if medieval and not _within_attack_range(target, attacker):
			start_walk(target, Vector2i.ZERO, attacker.id)
		else:
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
	if uses_squad_ai() and student.team != player_team:
		student.state = ClassicStudent.State.SIT
		student.counter = 40
		student.pattern = 13
		return
	var targets: Array[ClassicStudent] = []
	for other: ClassicStudent in students:
		if not other.is_alive() or other.team == student.team or not _may_engage(student, other):
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


func can_heal(student: ClassicStudent) -> bool:
	if student.state != ClassicStudent.State.SIT:
		return false
	if not medieval or student.team != 2:
		return true
	for attacker: ClassicStudent in students:
		if attacker.state == ClassicStudent.State.FIGHT and attacker.target_id == student.id and attacker.team != student.team and _within_attack_range(attacker, student):
			student.last_attacked_tick = ticks
	return ticks - student.last_attacked_tick >= 3 * ClassicRules.TICKS_PER_SECOND


func _sitting(student: ClassicStudent) -> void:
	var tile: Vector2i = Vector2i(student.cell.x / 4, student.cell.y / 4)
	if area_at.has(tile):
		var area: Dictionary = areas[area_at[tile]]
		if not medieval and area.kind >= ClassicRules.AreaKind.RECRUIT and area.owner != student.team:
			area.progress[student.team] += 1.0
			if area.progress[student.team] >= ClassicRules.CAPTURE_TICKS - 0.000001:
				area.owner = student.team
				for color: int in 4:
					if color != student.team:
						area.progress[color] = 0
				_update_leader()
		if area.owner == student.team and area.kind != ClassicRules.AreaKind.RECRUIT and can_heal(student):
			student.health = minf(student.maximum_health, student.health + ClassicRules.HEAL_PER_TICK * (2.0 if medieval and student.team == 2 and area.kind == ClassicRules.AreaKind.HEAL else 1.0))
	student.counter -= 1
	student.idle_ticks += 1
	if student.counter < 0:
		_start_sit(student)


func _focus_step(student: ClassicStudent) -> void:
	var target: ClassicStudent = students[student.priority_target_id]
	if _within_attack_range(student, target):
		_start_fight(student, target)
		_engage_defender(target, student)
		return
	# Each pursuing ally reserves a distinct attack position around this target.
	var claimed: Dictionary = {}
	for ally: ClassicStudent in students:
		if ally.id == student.id or not ally.is_alive() or ally.team != student.team:
			continue
		if ally.priority_target_id != target.id or ally.target_id != target.id:
			continue
		if _within_attack_range(ally, target):
			claimed[ally.cell] = true
		elif _cell_in_range(ally.approach_cell, target.cell, get_attack_range(ally)):
			if not occupancy.has(ally.approach_cell) or occupancy[ally.approach_cell] == ally.id:
				claimed[ally.approach_cell] = true
	var goals: Dictionary = {}
	for cell: Vector2i in _attack_positions(student, target.cell):
		if ClassicRules.in_grid(cell) and not occupancy.has(cell) and not claimed.has(cell):
			goals[cell] = true
	# Keep a reachable assignment stable, but allow reassignment when blocked.
	var preferred: Vector2i = student.approach_cell
	var candidates: Array[Dictionary] = []
	if goals.has(preferred):
		candidates.append({preferred: true})
	candidates.append(goals)
	for destinations: Dictionary in candidates:
		if destinations.is_empty():
			continue
		var queue: Array[Vector2i] = [student.cell]
		var parent: Dictionary = {student.cell: student.cell}
		var cursor: int = 0
		while cursor < queue.size():
			var cell: Vector2i = queue[cursor]
			cursor += 1
			if destinations.has(cell):
				student.approach_cell = cell
				student.destination = target.cell
				var next: Vector2i = cell
				while parent[next] != student.cell:
					next = parent[next]
				for index: int in 4:
					if student.cell + ClassicRules.DIRECTIONS[index] == next:
						_reserve_step(student, index)
						return
			for direction: Vector2i in ClassicRules.DIRECTIONS:
				var next: Vector2i = cell + direction
				if not ClassicRules.in_grid(next) or occupancy.has(next) or parent.has(next):
					continue
				parent[next] = cell
				queue.append(next)
	# All melee slots may be claimed or unreachable. Still close to the nearest
	# reachable free cell instead of leaving extra attackers at their origin.
	if _close_on_focus(student, target.cell):
		return
	student.approach_cell = Vector2i(-1, -1)
	student.state = ClassicStudent.State.WAIT
	student.counter = 2
	student.pattern = 10


func _close_on_focus(student: ClassicStudent, target_cell: Vector2i) -> bool:
	var queue: Array[Vector2i] = [student.cell]
	var parent: Dictionary = {student.cell: student.cell}
	var cursor: int = 0
	var best: Vector2i = student.cell
	var best_distance: int = absi(best.x - target_cell.x) + absi(best.y - target_cell.y)
	if best_distance <= 2:
		return false
	while cursor < queue.size():
		var cell: Vector2i = queue[cursor]
		cursor += 1
		var distance: int = absi(cell.x - target_cell.x) + absi(cell.y - target_cell.y)
		if distance < best_distance:
			best = cell
			best_distance = distance
			# Adjacent cells were handled above; two cells away is the closest queue.
			if best_distance <= 2:
				break
		for direction: Vector2i in ClassicRules.DIRECTIONS:
			var next: Vector2i = cell + direction
			if not ClassicRules.in_grid(next) or occupancy.has(next) or parent.has(next):
				continue
			parent[next] = cell
			queue.append(next)
	if best == student.cell:
		return false
	var next: Vector2i = best
	while parent[next] != student.cell:
		next = parent[next]
	student.approach_cell = Vector2i(-1, -1)
	student.destination = target_cell
	for index: int in 4:
		if student.cell + ClassicRules.DIRECTIONS[index] == next:
			_reserve_step(student, index)
			return true
	return false


func _reserve_step(student: ClassicStudent, direction: int) -> void:
	student.direction = direction
	occupancy.erase(student.cell)
	student.previous_cell = student.cell
	student.cell += ClassicRules.DIRECTIONS[direction]
	occupancy[student.cell] = student.id
	student.walk_tick = maxf(0.0, student.walk_tick - 6.0) if medieval and student.state == ClassicStudent.State.WALK else 0.0
	student.state = ClassicStudent.State.WALK


func _start_turn(student: ClassicStudent) -> void:
	if _stop_cross_tile_pursuit(student):
		return
	if student.target_id == student.priority_target_id and _valid_enemy(student, student.priority_target_id):
		_focus_step(student)
		return
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
			if medieval and _within_attack_range(student, students[student.target_id]):
				_start_fight(student, students[student.target_id])
				_engage_defender(students[student.target_id], student)
				return
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
		if student.target_id >= 0 and _holds_player_tile(student) and Vector2i(next.x / 4, next.y / 4) != Vector2i(student.cell.x / 4, student.cell.y / 4):
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
	student.walk_tick = maxf(0.0, student.walk_tick - 6.0) if medieval and student.state == ClassicStudent.State.WALK else 0.0
	student.state = ClassicStudent.State.WALK


func _walking(student: ClassicStudent) -> void:
	student.walk_tick += get_movement_multiplier(student)
	student.pattern = (student.pattern + 1) % 10
	if student.walk_tick < 6:
		return
	if _stop_cross_tile_pursuit(student):
		return
	if student.target_id >= 0:
		if not _valid_enemy(student, student.target_id):
			_target_died(students[student.target_id])
			_start_turn(student)
			return
		var target: ClassicStudent = students[student.target_id]
		if _within_attack_range(student, target):
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
	if _stop_cross_tile_pursuit(student):
		return
	if not _valid_enemy(student, student.target_id):
		_start_stand(student)
		return
	var target: ClassicStudent = students[student.target_id]
	if medieval and not _within_attack_range(student, target):
		student.state = ClassicStudent.State.STAND
		start_walk(student, Vector2i.ZERO, target.id)
		return
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
			# Snapshot before damage: the fourth kill unlocks cleave for future swings.
			var secondary: ClassicStudent = null
			if medieval and student.team == 0 and student.level >= 4:
				for other: ClassicStudent in students:
					if other.is_alive() and other.team != student.team and other.id != target.id and other.state != ClassicStudent.State.WALK and _may_engage(student, other) and _adjacent(other.cell, target.cell) and _within_attack_range(student, other):
						secondary = other
						break
			_apply_hit(student, target)
			if secondary != null and secondary.is_alive():
				_apply_hit(student, secondary)
		3:
			if not _contact_target(student, target):
				_start_stand(student)
				return
			student.pattern = 17
			student.fight_phase = 1
			student.counter = 1


func _apply_hit(student: ClassicStudent, target: ClassicStudent) -> void:
	target.pattern = 20
	target.fight_phase = 3
	target.counter = 5
	if medieval:
		target.damage_contributors[student.id] = {"tick": ticks, "lifetime": student.lifetime, "team": student.team}
		target.last_attacked_tick = ticks
	target.health -= get_punch_damage(student, target)
	if target.health <= 0.0:
		target.health = 0.0
		_target_died(target)
		target.state = ClassicStudent.State.DEAD
		target.pattern = 20
		target.counter = 10
		target.fight_phase = 0
		var conversion_chance: float = get_orc_conversion_chance(target)
		_reward_defeat(student, target)
		sound_requested.emit("dead", target.world_position())
		if medieval and student.team == 1 and rng.randf() < conversion_chance:
			_convert_to_orc(target)
			student.show_event("ORCS RISE!")
	else:
		if target.ai_retreating or not _may_engage(target, student):
			sound_requested.emit("punch", target.world_position())
			return
		if _can_attack_priority(target) and target.priority_target_id != student.id:
			sound_requested.emit("punch", target.world_position())
			return
		target.target_id = student.id
		_face_target(target, student)
		if medieval and not _within_attack_range(target, student):
			target.state = ClassicStudent.State.STAND
			start_walk(target, Vector2i.ZERO, student.id)
		elif target.state != ClassicStudent.State.FIGHT:
			_start_fight(target, student)
		sound_requested.emit("punch", target.world_position())


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
	_check_elimination(student.team)
	_update_leader()


func _check_elimination(team: int) -> void:
	if active[team] and get_count(team) == 0:
		active[team] = false
		team_eliminated.emit(team)
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


func uses_squad_ai() -> bool:
	return ai_enabled and medieval and difficulty != Difficulty.EASY


func _com_order(student: ClassicStudent) -> void:
	if student.team == player_team or student.state != ClassicStudent.State.SIT or student.idle_ticks < AI_START_DELAY_TICKS:
		return
	var healthy: bool = is_equal_approx(student.health, student.maximum_health)
	var best: float = INF
	var destination: Vector2i = Vector2i.ZERO
	var tile: Vector2i = Vector2i(student.cell.x / 4, student.cell.y / 4)
	for area: Dictionary in areas:
		if healthy:
			if area.owner == student.team:
				continue
			if area.kind == ClassicRules.AreaKind.BASE:
				if (medieval and not can_capture_area(area, student.team)) or (not medieval and not active[area.owner]):
					continue
			if leader >= 0 and student.team != leader and area.owner != leader:
				if not (medieval and area.kind == ClassicRules.AreaKind.BASE and can_capture_area(area, student.team)):
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
	if medieval and get_attack_range(student) > 1:
		return target.is_alive() and target.state != ClassicStudent.State.WALK and _within_attack_range(student, target)
	return target.is_alive() and target.state != ClassicStudent.State.WALK and student.cell + ClassicRules.DIRECTIONS[student.direction] == target.cell


func _adjacent(a: Vector2i, b: Vector2i) -> bool:
	var offset: Vector2i = a - b
	return absi(offset.x) + absi(offset.y) == 1


func get_punch_damage(student: ClassicStudent, target: ClassicStudent) -> float:
	var damage: float = ClassicRules.PUNCH[student.team]
	if not medieval:
		return damage
	damage += student.punch_bonus
	if difficulty == Difficulty.EXPERT and student.team == 0 and student.is_alive() and student.state != ClassicStudent.State.WALK:
		var tile: Vector2i = Vector2i(student.cell.x / 4, student.cell.y / 4)
		if area_at.has(tile) and areas[area_at[tile]].owner == student.team:
			damage += 1.0
	if student.team == 1:
		# Stable first attacker: each additional engaged orc adds ONE damage,
		# rather than multiplying the full group bonus across every attacker.
		for ally: ClassicStudent in students:
			if ally.id < student.id and ally.team == 1 and ally.state == ClassicStudent.State.FIGHT and ally.target_id == target.id and _contact_target(ally, target):
				damage += 1.0
				break
	return damage


func get_spawn_bases(team: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not medieval:
		result.append(bases[team])
		return result
	for area: Dictionary in areas:
		if area.kind == ClassicRules.AreaKind.BASE and area.owner == team:
			result.append(area.tile)
	return result


func has_spawn_space(team: int) -> bool:
	var spawn_bases: Array[Vector2i] = get_spawn_bases(team)
	if medieval:
		spawn_bases.assign([get_priority_spawn_base(team)])
	for tile: Vector2i in spawn_bases:
		if tile.x < 0:
			continue
		for y: int in 4:
			for x: int in 4:
				if not occupancy.has(tile * 4 + Vector2i(x, y)):
					return true
	return false


func get_next_spawn_progress(team: int) -> int:
	return recruit_progress[team]


func get_priority_spawn_base(team: int) -> Vector2i:
	var owned: Array[Vector2i] = get_spawn_bases(team)
	if owned.is_empty():
		return Vector2i(-1, -1)
	# Keep round-robin order, but never let a full base starve other owned bases.
	var previous: int = owned.find(last_spawn_base[team])
	for offset: int in range(1, owned.size() + 1):
		var tile: Vector2i = owned[(previous + offset) % owned.size()]
		for y: int in 4:
			for x: int in 4:
				if not occupancy.has(tile * 4 + Vector2i(x, y)):
					return tile
	# All bases are full: retain the next turn and hold the ready timer.
	return owned[(previous + 1) % owned.size()]


func get_orc_conversion_chance(victim: ClassicStudent) -> float:
	var count: int = 0
	for id: int in victim.damage_contributors:
		var record: Dictionary = victim.damage_contributors[id]
		if record.get("team", students[id].team) == 1 and ticks - int(record.tick) <= 3 * ClassicRules.TICKS_PER_SECOND:
			count += 1
	return minf(1.0, count * 0.25)


func can_capture_area(area: Dictionary, team: int) -> bool:
	if area.owner == team:
		return false
	if area.kind != ClassicRules.AreaKind.BASE:
		return true
	if not medieval or area.owner < 0:
		return false
	# Original home bases remain protected until their original race is eliminated.
	# Once conquered, other teams may contest the base while its owner lives.
	var original_owner: int = bases.find(area.tile)
	if original_owner < 0:
		original_owner = area.owner
	return original_owner >= 0 and not active[original_owner] and get_count(original_owner) == 0


func _capture_areas() -> void:
	# Snapshot seated counts once per tick, independent of unit processing order.
	var seated: Dictionary = {}
	for student: ClassicStudent in students:
		if student.state != ClassicStudent.State.SIT:
			continue
		var tile: Vector2i = Vector2i(student.cell.x / 4, student.cell.y / 4)
		if not area_at.has(tile):
			continue
		if not seated.has(tile):
			seated[tile] = [0, 0, 0, 0]
		seated[tile][student.team] += 1
	for area: Dictionary in areas:
		if not seated.has(area.tile):
			continue
		for team: int in 4:
			var count: int = seated[area.tile][team]
			if count == 0 or not can_capture_area(area, team):
				continue
			var gain: float = float(count)
			if team == 0:
				var seconds: int = HUMAN_CAPTURE_SECONDS[mini(count, HUMAN_CAPTURE_SECONDS.size()) - 1]
				gain = float(ClassicRules.CAPTURE_TICKS) / (seconds * ClassicRules.TICKS_PER_SECOND)
			area.progress[team] += gain
			if area.progress[team] >= ClassicRules.CAPTURE_TICKS - 0.000001:
				area.owner = team
				area.progress = [0.0, 0.0, 0.0, 0.0]
				area.spawn_progress = 0
				_update_leader()
				break


func get_attack_range(student: ClassicStudent) -> int:
	if not medieval:
		return 1
	if student.team == 0 and student.level >= 3:
		return 3
	if student.team == 2:
		if student.maximum_health >= 36.0:
			return 4
		if student.maximum_health >= 32.0:
			return 3
		if student.maximum_health >= 28.0:
			return 2
	return 1


func get_movement_multiplier(student: ClassicStudent) -> float:
	if medieval and student.team == 3:
		var punch: float = ClassicRules.PUNCH[student.team] + student.punch_bonus
		if punch >= 18.0:
			return 1.4
		if punch >= 12.0:
			return 1.3
		if punch >= 8.0:
			return 1.2
	return 1.0


func _cell_in_range(cell: Vector2i, target: Vector2i, reach: int) -> bool:
	var delta: Vector2i = target - cell
	var distance: int = absi(delta.x) + absi(delta.y)
	return distance > 0 and distance <= reach


func _within_attack_range(student: ClassicStudent, target: ClassicStudent) -> bool:
	return _cell_in_range(student.cell, target.cell, get_attack_range(student))


func _attack_positions(student: ClassicStudent, target_cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var reach: int = get_attack_range(student)
	if reach == 1:
		for direction: Vector2i in ClassicRules.DIRECTIONS:
			result.append(target_cell + direction)
	else:
		for y: int in range(-reach, reach + 1):
			for x: int in range(-reach, reach + 1):
				var cell: Vector2i = target_cell + Vector2i(x, y)
				if _cell_in_range(cell, target_cell, reach):
					result.append(cell)
	return result


func _reward_defeat(killer: ClassicStudent, victim: ClassicStudent) -> void:
	killer.level += 1
	if not medieval:
		killer.show_event("Level up!")
		killer.maximum_health += 1.0
		return
	if killer.team == 0:
		if killer.level == 1:
			killer.maximum_health += 2.0
			killer.show_event("+2 HP")
		elif killer.level == 2:
			killer.punch_bonus += 2
			killer.show_event("+2 PUNCH")
		elif killer.level == 3:
			killer.show_event("+3 RANGE")
		elif killer.level == 4:
			killer.show_event("+1 TARGET")
	# Damage records include the killing blow, so each contributor is rewarded once.
	for id: int in victim.damage_contributors:
		var record: Dictionary = victim.damage_contributors[id]
		var contributor: ClassicStudent = students[id]
		if not contributor.is_alive() or contributor.lifetime != record.lifetime or ticks - int(record.tick) > 3 * ClassicRules.TICKS_PER_SECOND:
			continue
		if contributor.team == 2:
			contributor.show_event("%d + 1 HP" % int(contributor.maximum_health))
			contributor.maximum_health += 1.0
		elif contributor.team == 3:
			contributor.show_event("%d + 1 PUNCH" % int(ClassicRules.PUNCH[contributor.team] + contributor.punch_bonus))
			contributor.punch_bonus += 1
	victim.damage_contributors.clear()


func _convert_to_orc(victim: ClassicStudent) -> void:
	var former_team: int = victim.team
	var cell: Vector2i = victim.cell
	victim.state = ClassicStudent.State.UNUSED
	occupancy.erase(cell)
	# Fresh ID avoids transferring selection or orders aimed at the dead enemy.
	var converted: ClassicStudent = ClassicStudent.new()
	converted.id = students.size()
	students.append(converted)
	_initialize_student(converted, 1, cell)
	converted.is_converted = true
	_check_elimination(former_team)
	_update_leader()
