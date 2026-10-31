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
	_test_orders()
	_test_fight()
	_test_determinism_and_occupancy()
	await _test_shell()
	if failures == 0:
		print("Classic SWF rules, simulation invariants, and shell tests passed.")
	quit(failures)


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
				_check(a.get_count(team) <= 12, "Population stays within cap during AI play")
		for id: int in 48:
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
		app.board.select_all()
		_check(app.board.selected.size() == 3, "Select all respects chosen school")
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


func _check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: %s" % description)
