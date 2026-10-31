extends SceneTree

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var sim: ClassicSimulation = ClassicSimulation.new()
	sim.setup(0, 12345)
	sim.ai_enabled = false
	for team: int in 4:
		_check(sim.get_count(team) == 3, "Three starting students per school")
		_check(sim.bases[team].x in [0, 15] and sim.bases[team].y in [0, 15], "Randomized corner bases")
		_check(is_equal_approx(sim.get_spawn_seconds(team), 500.0 / 36 if team == 1 else 1500.0 / 36), "Source recruitment threshold")
	var tiles: Dictionary = {}
	for area: Dictionary in sim.areas:
		_check(not tiles.has(area.tile), "Area placement is unique")
		tiles[area.tile] = true
		for other: Dictionary in sim.areas:
			var offset: Vector2i = area.tile - other.tile
			_check(absi(offset.x) + absi(offset.y) != 1, "Areas have no orthogonal neighbors")
	for x: int in [0, 5, 30, 63]:
		for y: int in [0, 12, 40, 63]:
			var cell: Vector2i = Vector2i(x, y)
			_check(ClassicRules.world_to_cell(ClassicRules.cell_to_world(Vector2(cell)) + Vector2(0, 1)) == cell, "Isometric picking round trip")
	var recruit: Dictionary = {}
	var healing: Dictionary = {}
	for area: Dictionary in sim.areas:
		if area.kind == ClassicRules.AreaKind.RECRUIT:
			recruit = area
		elif area.kind == ClassicRules.AreaKind.HEAL:
			healing = area
	_check(not recruit.is_empty() and not healing.is_empty(), "Seed contains both strategic tile kinds")
	var student: ClassicStudent = sim.students[0]
	var old_cell: Vector2i = student.cell
	sim.occupancy.erase(old_cell)
	student.cell = recruit.tile * 4
	sim.occupancy[student.cell] = student.id
	student.state = ClassicStudent.State.SIT
	student.counter = 1000
	student.health = 5.0
	for tick: int in 299:
		sim._sitting(student)
	_check(recruit.owner == -1, "Capture requires all 300 seated ticks")
	sim._sitting(student)
	_check(recruit.owner == student.team, "Fist captured at 300 ticks")
	_check(student.health == 5.0, "Fist tiles never heal")
	_check(sim.get_spawn_seconds(student.team) < 1500.0 / 36, "Fist accelerates recruitment by progress rate")
	student.cell = healing.tile * 4
	healing.owner = student.team
	student.counter = 1000
	sim._sitting(student)
	_check(is_equal_approx(student.health, 5.1), "Owned hearts heal 0.1 per seated tick")
	healing.owner = -1
	sim._sitting(student)
	_check(is_equal_approx(student.health, 5.1), "Neutral hearts do not heal")
	var saved_progress: int = healing.progress[student.team]
	student.cell = old_cell
	sim._sitting(student)
	_check(healing.progress[student.team] == saved_progress, "Leaving retains partial capture progress")
	student.cell = healing.tile * 4
	student.state = ClassicStudent.State.WALK
	var before: int = healing.progress[student.team]
	# Normal ticks only call sitting() for seated students.
	student.walk_tick = 0
	sim.step()
	_check(healing.progress[student.team] == before, "Walking does not capture")
	var cap_sim: ClassicSimulation = ClassicSimulation.new()
	cap_sim.setup(0, 99)
	for i: int in 20:
		cap_sim.spawn_student(0)
	_check(cap_sim.get_count(0) == 12, "All schools enforce the twelve-unit cap")
	cap_sim.active[1] = false
	_check(cap_sim.spawn_student(1) == null, "Eliminated schools cannot recruit")
	_test_blocked_focus_retaliation()
	_test_new_orders_and_capacity()
	_test_close_on_surrounded_target()
	_test_surround()
	_test_orders()
	_test_fight()
	_test_determinism_and_occupancy()
	await _test_shell()
	if failures == 0:
		print("Classic SWF rules, simulation invariants, and shell tests passed.")
	quit(failures)


func _test_blocked_focus_retaliation() -> void:
	var sim: ClassicSimulation = ClassicSimulation.new()
	sim.setup(0, 101)
	sim.ai_enabled = false
	sim.occupancy.clear()
	for unit: ClassicStudent in sim.students:
		unit.state = ClassicStudent.State.UNUSED
	var focus: ClassicStudent = sim.students[3]
	focus.team = 1
	focus.cell = Vector2i(20, 20)
	focus.state = ClassicStudent.State.STAND
	focus.health = 1000
	var cells: Array[Vector2i] = [Vector2i(21, 20), Vector2i(20, 21), Vector2i(19, 20), Vector2i(20, 19)]
	for i: int in 4:
		var blocker: ClassicStudent = sim.students[8 + i]
		blocker.team = 0
		blocker.cell = cells[i]
		blocker.state = ClassicStudent.State.STAND
		sim.occupancy[blocker.cell] = blocker.id
	sim.occupancy[focus.cell] = focus.id
	var fifth: ClassicStudent = sim.students[0]
	fifth.team = 0
	fifth.cell = Vector2i(22, 20)
	fifth.state = ClassicStudent.State.WAIT
	fifth.health = 1000
	fifth.maximum_health = 1000
	fifth.priority_target_id = focus.id
	fifth.target_id = focus.id
	sim.occupancy[fifth.cell] = fifth.id
	var enemy: ClassicStudent = sim.students[6]
	enemy.team = 2
	enemy.cell = Vector2i(23, 20)
	enemy.state = ClassicStudent.State.STAND
	enemy.health = 1000
	sim.occupancy[enemy.cell] = enemy.id
	_check(not sim._can_attack_priority(fifth), "Fifth student cannot hit through occupied attack positions")
	sim.start_walk(enemy, Vector2i.ZERO, fifth.id)
	_check(fifth.state == ClassicStudent.State.FIGHT and fifth.target_id == enemy.id, "Blocked fifth student engages adjacent attacker")
	_check(fifth.priority_target_id == focus.id, "Local defense retains original focus order")
	for tick: int in 200:
		if enemy.health < 1000:
			break
		sim._fighting(fifth)
	_check(enemy.health < 1000, "Blocked fifth student actually damages adjacent attacker")
	# Also exercise the successful-hit path without the engagement notification.
	fifth.state = ClassicStudent.State.WAIT
	fifth.target_id = focus.id
	for tick: int in 200:
		if fifth.health < 1000:
			break
		sim._fighting(enemy)
	_check(fifth.health < 1000 and fifth.target_id == enemy.id, "Taking a hit overrides unreachable focus for retaliation")
	enemy.state = ClassicStudent.State.DEAD
	sim._fighting(fifth)
	sim._start_sit(fifth)
	_check(fifth.target_id == focus.id, "Student resumes original focus after local attacker dies")


func _test_new_orders_and_capacity() -> void:
	var sim: ClassicSimulation = ClassicSimulation.new()
	sim.setup(0, 55)
	var neutral: Array[Dictionary] = []
	for area: Dictionary in sim.areas:
		if area.kind != ClassicRules.AreaKind.BASE:
			neutral.append(area)
	_check(sim.get_team_capacity(1) == 12, "Green starts with capacity 12")
	neutral[0].owner = 1
	_check(sim.get_team_capacity(1) == 12, "One captured tile gives no capacity bonus")
	neutral[1].owner = 1
	_check(sim.get_team_capacity(1) == 13 and sim.get_team_capacity(0) == 12, "Two captured tiles increase only Green capacity")
	# Capacity depends on ownership, not a change to the recruitment formula.
	_check(is_equal_approx(sim.get_spawn_seconds(1), 500.0 / (2 + sim.get_recruit_tiles(1)) / 18.0), "Green recruitment formula unchanged")
	for i: int in 20:
		sim.spawn_student(1)
	_check(sim.get_count(1) == 13, "Green can recruit above the old twelve-unit cap")
	for team: int in [0, 2, 3]:
		for i: int in 12:
			sim.spawn_student(team)
	_check(sim.students.size() == 49 and sim.get_count(1) == 13, "Shared pool supports Green bonus beyond 48 total students")
	neutral[1].owner = -1
	_check(sim.get_team_capacity(1) == 12 and sim.get_count(1) == 13 and sim.spawn_student(1) == null, "Territory loss preserves existing units but blocks excess recruitment")
	var mover: ClassicStudent = sim.students[0]
	var target: ClassicStudent = sim.students[3]
	sim.occupancy.clear()
	mover.cell = Vector2i(10, 10)
	mover.previous_cell = Vector2i(9, 10)
	mover.state = ClassicStudent.State.WALK
	mover.walk_tick = 5
	mover.target_id = target.id
	mover.priority_target_id = target.id
	target.cell = Vector2i(15, 10)
	target.state = ClassicStudent.State.DEAD
	sim._target_died(target)
	_check(mover.target_id == -1 and mover.destination == target.cell, "Target death converts pursuit to last-position move")
	sim._walking(mover)
	_check(mover.state == ClassicStudent.State.WALK and mover.cell == Vector2i(11, 10), "Pursuer continues moving after target dies")


func _test_close_on_surrounded_target() -> void:
	for barrier: bool in [false, true]:
		var sim: ClassicSimulation = ClassicSimulation.new()
		sim.setup(0, 333)
		sim.ai_enabled = false
		sim.occupancy.clear()
		for unit: ClassicStudent in sim.students:
			unit.state = ClassicStudent.State.UNUSED
		var target: ClassicStudent = sim.students[10]
		target.team = 1
		target.cell = Vector2i(20, 20)
		target.state = ClassicStudent.State.STAND
		target.health = 100000
		sim.occupancy[target.cell] = target.id
		var ids: Array[int] = []
		for i: int in 6:
			var unit: ClassicStudent = sim.students[i]
			unit.team = 0
			unit.state = ClassicStudent.State.STAND
			unit.health = 1000
			unit.cell = target.cell + ClassicRules.DIRECTIONS[i] if i < 4 else Vector2i(10, 19 + i)
			unit.previous_cell = unit.cell
			sim.occupancy[unit.cell] = unit.id
			ids.append(i)
		if barrier:
			# An occupied wall forces a detour around y=27, away from the target.
			for y: int in range(0, 27):
				sim.occupancy[Vector2i(15, y)] = -100
		sim.command(ids, Vector2i(5, 5), target.id)
		for tick: int in 600:
			for id: int in ids:
				var unit: ClassicStudent = sim.students[id]
				if unit.state == ClassicStudent.State.WALK:
					sim._walking(unit)
				elif unit.state == ClassicStudent.State.WAIT:
					unit.counter -= 1
					if unit.counter < 0:
						sim._start_turn(unit)
		var seen: Dictionary = {}
		for id: int in ids:
			var unit: ClassicStudent = sim.students[id]
			_check(not seen.has(unit.cell), "Six attackers never overlap")
			seen[unit.cell] = true
			var distance: int = absi(unit.cell.x - target.cell.x) + absi(unit.cell.y - target.cell.y)
			_check(distance == (1 if id < 4 else 2), "Extra attackers close to second ring with blocked=%s" % barrier)
			_check(unit.priority_target_id == target.id, "Closing retains focused target")
		# Free one attack side and verify a queued unit takes it.
		var departed: ClassicStudent = sim.students[0]
		sim.occupancy.erase(departed.cell)
		departed.state = ClassicStudent.State.UNUSED
		for tick: int in 150:
			for id: int in [4, 5]:
				var unit: ClassicStudent = sim.students[id]
				if unit.state == ClassicStudent.State.WALK:
					sim._walking(unit)
				elif unit.state == ClassicStudent.State.WAIT:
					unit.counter -= 1
					if unit.counter < 0:
						sim._start_turn(unit)
		_check(sim._adjacent(sim.students[4].cell, target.cell) or sim._adjacent(sim.students[5].cell, target.cell), "Queued attacker fills newly open attack position")


func _test_surround() -> void:
	for scenario: int in 5:
		var sim: ClassicSimulation = ClassicSimulation.new()
		sim.setup(0, 900 + scenario)
		sim.ai_enabled = false
		sim.occupancy.clear()
		for unit: ClassicStudent in sim.students:
			unit.state = ClassicStudent.State.UNUSED
		var target: ClassicStudent = sim.students[10]
		target.team = 1
		target.cell = Vector2i(20, 20) if scenario != 2 else Vector2i(0, 20)
		target.health = 100000
		target.state = ClassicStudent.State.STAND
		sim.occupancy[target.cell] = target.id
		if scenario == 1:
			var blocker: ClassicStudent = sim.students[11]
			blocker.team = 2
			blocker.cell = target.cell + Vector2i.UP
			blocker.state = ClassicStudent.State.STAND
			sim.occupancy[blocker.cell] = blocker.id
		var ids: Array[int] = []
		var count: int = 6 if scenario == 3 else 4
		for i: int in count:
			var unit: ClassicStudent = sim.students[i]
			unit.team = 0
			unit.cell = Vector2i(10, 17 + i)
			unit.previous_cell = unit.cell
			unit.health = 1000
			unit.maximum_health = 1000
			unit.state = ClassicStudent.State.STAND
			sim.occupancy[unit.cell] = unit.id
			ids.append(unit.id)
		sim.command(ids, Vector2i(5, 5), target.id)
		for tick: int in 600:
			if scenario == 4 and tick == 90:
				sim.occupancy.erase(target.cell)
				target.cell = Vector2i(25, 25)
				sim.occupancy[target.cell] = target.id
			for id: int in ids:
				var unit: ClassicStudent = sim.students[id]
				match unit.state:
					ClassicStudent.State.WALK:
						sim._walking(unit)
					ClassicStudent.State.WAIT, ClassicStudent.State.STAND:
						unit.counter -= 1
						if unit.counter < 0:
							sim.start_walk(unit, Vector2i.ZERO, target.id)
					ClassicStudent.State.FIGHT:
						sim._fighting(unit)
			var seen: Dictionary = {}
			for unit: ClassicStudent in sim.students:
				if unit.state != ClassicStudent.State.UNUSED:
					_check(not seen.has(unit.cell), "Surround routing never overlaps occupied cells")
					seen[unit.cell] = unit.id
			_check(seen == sim.occupancy, "Surround routing preserves reservations")
		var sides: int = 0
		for id: int in ids:
			var unit: ClassicStudent = sim.students[id]
			if sim._adjacent(unit.cell, target.cell) and unit.state == ClassicStudent.State.FIGHT:
				sides += 1
		_check(sides == (3 if scenario in [1, 2] else 4), "Attackers fill every accessible target side, scenario %d" % scenario)
		_check(target.health < 100000, "Surrounding attackers land damage, scenario %d" % scenario)
		if scenario == 3:
			for id: int in ids:
				var offset: Vector2i = sim.students[id].cell - target.cell
				_check(absi(offset.x) + absi(offset.y) <= 2, "All six initially distant attackers reach target vicinity")


func _test_orders() -> void:
	var sim: ClassicSimulation = ClassicSimulation.new()
	sim.setup(0, 43)
	var attacker: ClassicStudent = sim.students[0]
	var defender: ClassicStudent = sim.students[3]
	attacker.cell = Vector2i(20, 20)
	defender.cell = Vector2i(21, 20)
	defender.previous_cell = Vector2i(22, 20)
	defender.state = ClassicStudent.State.WALK
	defender.walk_tick = 2
	sim.start_walk(attacker, Vector2i.ZERO, defender.id)
	_check(defender.state == ClassicStudent.State.WALK and defender.walk_tick == 2, "Engaged moving defender finishes its step")
	_check(defender.target_id == attacker.id, "Moving defender remembers attacker")
	defender.walk_tick = 5
	sim._walking(defender)
	_check(defender.state == ClassicStudent.State.FIGHT and defender.target_id == attacker.id, "Moving defender retaliates after step")
	var focus: ClassicStudent = sim.students[6]
	focus.cell = Vector2i(20, 21)
	var ids: Array[int] = [attacker.id]
	sim.command(ids, Vector2i(5, 5), focus.id)
	_check(attacker.target_id == focus.id and attacker.priority_target_id == focus.id, "Explicit attack replaces existing fight target")
	_check(attacker.direction == 1, "Retargeted fighter faces new focus")
	sim._engage_defender(attacker, defender)
	_check(attacker.target_id == focus.id, "Retaliation cannot replace explicit focus")
	var health_before: float = attacker.health
	sim._start_fight(defender, attacker)
	for tick: int in 200:
		if attacker.health < health_before:
			break
		sim._fighting(defender)
	_check(attacker.health < health_before and attacker.target_id == focus.id, "Taking damage preserves explicit focus")
	attacker.state = ClassicStudent.State.STAND
	sim._start_sit(attacker)
	_check(attacker.target_id == focus.id, "Blocked focus retries the same target instead of choosing another")
	focus.state = ClassicStudent.State.DEAD
	sim._fighting(attacker)
	_check(attacker.state == ClassicStudent.State.STAND, "Godot immediate recovery after target death retained")
	sim.command(ids, Vector2i(6, 6))
	_check(attacker.priority_target_id == -1, "Movement order clears explicit focus")
	var board: ClassicBoard = ClassicBoard.new()
	board.size = Vector2(960, 600)
	board.simulation = sim
	attacker.state = ClassicStudent.State.STAND
	board.selected.assign([attacker.id])
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = board.world_to_screen(ClassicRules.cell_to_world(Vector2(defender.cell)) + Vector2(0, -10))
	board._gui_input(press)
	_check(board.selected.is_empty() and attacker.target_id == defender.id, "Mouse-down immediately issues enemy focus order")
	_check(board._marker_target == defender.id, "Enemy order confirms with target arrow")
	press.pressed = false
	board._gui_input(press)
	_check(board.selected.is_empty(), "Mouse-up after order does not select again")
	board.free()


func _test_fight() -> void:
	var sim: ClassicSimulation = ClassicSimulation.new()
	sim.setup(0, 43)
	sim.ai_enabled = false
	var attacker: ClassicStudent = sim.students[0]
	var target: ClassicStudent = sim.students[3]
	attacker.cell = Vector2i(20, 20)
	target.cell = Vector2i(21, 20)
	attacker.health = 10.0
	target.health = 1.0
	sim._start_fight(attacker, target)
	for i: int in 300:
		if not target.is_alive():
			break
		sim._fighting(attacker)
	_check(target.state == ClassicStudent.State.DEAD, "Punches resolve combat and enter death animation")
	_check(attacker.maximum_health == 21 and attacker.level == 1, "Killer gains exactly one maximum HP")
	_check(attacker.health == 10, "Level-up does not restore current HP")
	_check(sim.get_count(target.team) == 3, "Dying student counts until death animation completes")
	for i: int in 28:
		sim._dying(target)
	_check(target.state == ClassicStudent.State.DEAD, "Death animation keeps its slot for 28 complete ticks")
	sim._dying(target)
	_check(target.state == ClassicStudent.State.UNUSED, "Death releases its slot on the twenty-ninth tick")
	for i: int in 40:
		if target.state == ClassicStudent.State.DEAD:
			sim._dying(target)
	_check(target.state == ClassicStudent.State.UNUSED, "Death animation releases unit slot")
	_check(sim.get_count(target.team) == 2, "Dead unit removed from population")
	# A terminal death stops spawning and produces exactly one result.
	var terminal: ClassicSimulation = ClassicSimulation.new()
	terminal.setup(0, 7)
	var results: Array[bool] = []
	terminal.match_finished.connect(func(won: bool) -> void: results.append(won))
	for unit: ClassicStudent in terminal.students:
		if unit.team == 0 and unit.is_alive():
			unit.state = ClassicStudent.State.DEAD
			unit.fight_phase = 1
			unit.counter = 0
			terminal._dying(unit)
	_check(not terminal.active[0] and terminal.finished, "Last student permanently eliminates player")
	_check(results == [false], "Defeat emitted once")
	var stopped_at: int = terminal.ticks
	terminal.step()
	_check(terminal.ticks == stopped_at, "Finished simulation stops")


func _test_determinism_and_occupancy() -> void:
	for map_seed: int in [9, 81, 613]:
		var a: ClassicSimulation = ClassicSimulation.new()
		var b: ClassicSimulation = ClassicSimulation.new()
		a.setup(0, map_seed)
		b.setup(0, map_seed)
		# AI controls all four schools for this long-running invariant check.
		a.player_team = -1
		b.player_team = -1
		for tick: int in 6000:
			a.step()
			b.step()
			if tick % 100 == 0:
				var occupied: Dictionary = {}
				for unit: ClassicStudent in a.students:
					if unit.state != ClassicStudent.State.UNUSED:
						_check(ClassicRules.in_grid(unit.cell), "Unit stays inside 64x64 grid")
						_check(not occupied.has(unit.cell), "Reserved unit cells never overlap")
						occupied[unit.cell] = unit.id
				_check(occupied == a.occupancy, "Occupancy has no stale reservations")
			for team: int in 4:
				_check(a.get_count(team) <= (25 if team == 1 else 12), "Population stays within cap during AI play")
		_check(a.students.size() == b.students.size(), "Dynamic pool size replays deterministically")
		for id: int in a.students.size():
			_check(a.students[id].cell == b.students[id].cell and a.students[id].health == b.students[id].health and a.students[id].state == b.students[id].state, "Seed and ticks deterministically replay")


func _test_shell() -> void:
	var scene: PackedScene = load("res://Scenes/Classic/classic_game.tscn")
	var app: Control = scene.instantiate()
	root.add_child(app)
	app._muted = true
	await process_frame
	_check(app.menu.visible and not app.hud.visible, "Classic menu is default launch view")
	_check(app.cards.size() == 4, "Four native keyboard-accessible team buttons")
	for team: int in 4:
		app._start_match(team)
		_check(app.board.simulation.player_team == team, "Every team starts a playable match")
		app.board.simulation.recruit_progress[team] = ClassicRules.RECRUIT_THRESHOLD[team] / 2
		app._update_recruitment()
		_check(is_equal_approx(app.recruit_bar.value, 0.5), "Recruit bar follows real team-specific timer")
		_check(app.selection_label.text == "L-click to select · R-click drag to pan · Wheel to zoom", "Exact gameplay tips are displayed")
		_check(app.recruit_panel.position.y + app.recruit_panel.size.y <= app.hint_panel.position.y, "Recruitment bar is above gameplay tips")
		app.board.simulation.recruit_progress[team] = 0
		app.board.select_all()
		_check(app.board.selected.size() == 3, "Select all respects chosen school")
		var space: InputEventKey = InputEventKey.new()
		space.keycode = KEY_SPACE
		space.pressed = true
		app._unhandled_key_input(space)
		_check(app.board.selected.is_empty(), "Space clears selection")
		var before_spawn: int = app.board.simulation.get_count(team)
		app.board.simulation.recruit_progress[team] = ClassicRules.RECRUIT_THRESHOLD[team]
		app.board.simulation.step()
		app._update_recruitment()
		_check(app.board.simulation.get_count(team) == before_spawn + 1 and app.recruit_bar.value < 0.01, "Recruit bar restarts when actual recruitment cycle spawns a unit")
		app._show_help()
		await process_frame
		_check(app.board.paused and app.modal.visible, "Help pauses simulation")
		var dialog: Control = app.modal.get_node("Dialog")
		_check(dialog.get_rect().end.y <= app.size.y, "Help dialog stays inside viewport")
		app._resume()
		_check(not app.board.paused and not app.modal.visible, "Resume closes overlay")
		app._show_result(true)
		_check(app.modal_title.text == "You win !!" and app.board.paused, "Classic result freezes match")
		app._show_menu()
		_check(app.menu.visible and not app.board.visible, "Menu safely disposes active view")
	app.queue_free()
	await process_frame
	var medieval_app: Control = scene.instantiate()
	medieval_app.medieval = true
	root.add_child(medieval_app)
	medieval_app._muted = true
	await process_frame
	_check(medieval_app.menu_title.text == "MEDIEVAL WARS", "Medieval variant has independent title")
	_check(medieval_app.board.team_names == ["Humans", "Orcs", "Elves", "Demons"], "Medieval races retain team order")
	_check(medieval_app.board.student_texture == medieval_app.MEDIEVAL_STUDENTS, "Race atlas is used in menu and match")
	_check(is_instance_valid(medieval_app.extras_button), "Variant has return navigation")
	for team: int in 4:
		medieval_app._start_match(team)
		_check(medieval_app.board.simulation.get_count(team) == 3, "Every race starts with unchanged gameplay")
		medieval_app._show_menu()
	medieval_app.queue_free()
	await process_frame


func _check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: %s" % description)
