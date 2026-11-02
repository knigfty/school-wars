extends SceneTree
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _run() -> void:
	for mode: int in 3:
		var sim: ClassicSimulation = ClassicSimulation.new()
		sim.medieval = true
		sim.difficulty = mode
		sim.setup(0, 123, true)
		_check(sim.spectating and sim.player_team == -1, "Spectating reserves no player race")
		var unit: ClassicStudent = sim.students[0]
		var destination: Vector2i = unit.destination
		sim.command([unit.id], Vector2i(8, 8))
		_check(unit.destination == destination, "Spectators cannot inject unit commands")
		sim.ticks = 500
		for warrior: ClassicStudent in sim.students:
			if warrior.is_alive():
				warrior.ai_spawn_wait = false
				warrior.state = ClassicStudent.State.SIT
				warrior.idle_ticks = 500
		if mode == ClassicSimulation.Difficulty.EASY:
			for race: int in 4:
				for warrior: ClassicStudent in sim.students:
					if warrior.is_alive() and warrior.team == race:
						sim._com_order(warrior)
						_check(warrior.state != ClassicStudent.State.SIT, "Every spectator race gets Easy AI orders")
						break
		else:
			sim.squad_ai.update(sim)
			var races: Dictionary = {}
			for squad: Array in sim.squad_ai.squads:
				races[squad[0].team] = true
			_check(races.size() == 4, "All four spectator races participate in squad AI")
		# Elimination must not interpret the -1 observer as the last race.
		for warrior: ClassicStudent in sim.students:
			warrior.state = ClassicStudent.State.UNUSED
		sim.occupancy.clear()
		for race: int in 4:
			sim._initialize_student(sim.students[race], race, Vector2i(20 + race, 20))
		sim.students[0].state = ClassicStudent.State.UNUSED
		sim._check_elimination(0)
		_check(not sim.finished, "First elimination does not end spectator match")
		sim.students[1].state = ClassicStudent.State.UNUSED
		sim._check_elimination(1)
		_check(not sim.finished, "Second elimination does not end spectator match")
		sim.students[2].state = ClassicStudent.State.UNUSED
		sim._check_elimination(2)
		_check(sim.finished and sim.get_winner_team() == 3, "Spectator match ends on last surviving race")
	_test_clock()
	await _test_shell()
	print("Spectator and speed tests: %d failure(s)" % failures)
	quit(1 if failures else 0)

func _test_clock() -> void:
	var board: ClassicBoard = ClassicBoard.new()
	board.medieval = true
	root.add_child(board)
	board.set_process(false)
	board.start(0, 456, ClassicSimulation.Difficulty.EXPERT, true)
	_check(board.game_speed == 1 and board.selected.is_empty(), "New spectator game starts at 1x")
	board.select_all()
	_check(board.selected.is_empty(), "Spectator select-all does not control units")
	for expected: int in [2, 4, 8, 1]:
		board.cycle_game_speed()
		_check(board.game_speed == expected, "Fast-forward cycles 2x, 4x, 8x, 1x")
	for speed: int in [1, 2, 4, 8]:
		board.start(0, 456, ClassicSimulation.Difficulty.EXPERT, true)
		board.game_speed = speed
		for frame: int in 10:
			board._process(0.1)
		_check(absi(board.simulation.ticks - 18 * speed) <= 1, "Battle clock advances at selected multiplier")
		board.paused = true
		var before: int = board.simulation.ticks
		board._process(1.0)
		_check(board.simulation.ticks == before, "Pause freezes every speed")
	# Fast playback must execute the same rules steps, rather than alter unit stats.
	board.start(0, 456, ClassicSimulation.Difficulty.EXPERT, true)
	for frame: int in 8:
		board._process(0.05)
	var snapshot: Array = []
	for unit: ClassicStudent in board.simulation.students:
		snapshot.append([unit.cell, unit.health, unit.state])
	var tick_count: int = board.simulation.ticks
	board.start(0, 456, ClassicSimulation.Difficulty.EXPERT, true)
	board.game_speed = 8
	board._process(0.05)
	var fast_snapshot: Array = []
	for unit: ClassicStudent in board.simulation.students:
		fast_snapshot.append([unit.cell, unit.health, unit.state])
	_check(board.simulation.ticks == tick_count and snapshot == fast_snapshot, "8x playback preserves identical simulation state at equal battle time")
	board.start(2, 456)
	_check(board.game_speed == 1 and not board.spectating and board.simulation.player_team == 2, "Player game restores ownership and resets speed")
	board.queue_free()

func _test_shell() -> void:
	var game = load("res://Scripts/Classic/classic_game.gd").new()
	game.medieval = true
	root.add_child(game)
	game.set_process(false)
	game.size = Vector2(960, 600)
	game._layout()
	await process_frame
	game._layout()
	_check(game.spectator_button.position.y == game.difficulty_selector.position.y and game.spectator_button.position.x >= game.difficulty_selector.get_rect().end.x, "Spectator button is right of difficulty on the same row")
	game.difficulty_selector.select(ClassicSimulation.Difficulty.EXPERT)
	game.spectator_button.pressed.emit()
	game.board.set_process(false)
	_check(game._spectating and game.board.simulation.spectating and game.board.simulation.difficulty == ClassicSimulation.Difficulty.EXPERT, "Spectator button launches chosen difficulty")
	_check(not game.recruit_bar.visible and game.recruit_label.text.contains("Spectator"), "Spectator HUD does not show a player spawning meter")
	game._process(0)
	game.speed_button.pressed.emit()
	_check(game.board.game_speed == 2 and game.speed_button.text == "2x" and game.speed_button.icon != null, "Toolbar speed button has icon and current multiplier")
	await process_frame
	game._layout()
	var actions: Control = game.hud.get_node("Actions")
	_check(game.status.get_content_width() <= game.status.size.x, "Starting population text fits beside speed control")
	_check(game.status.get_rect().end.x <= actions.position.x, "Toolbar does not overlap population label")
	_check(actions.get_rect().end.x <= game.size.x, "Toolbar fits screen")
	game._show_result(true)
	_check(game.modal_title.text == "Battle Concluded", "Spectators receive neutral match result")
	game.replay_button.pressed.emit()
	game.board.set_process(false)
	_check(game._spectating and game.board.game_speed == 1 and game.speed_button.text == "1x", "Replay preserves spectator mode and resets speed")
	game._show_menu()
	game._start_match(1)
	game.board.set_process(false)
	_check(not game._spectating and game.board.simulation.player_team == 1 and game.recruit_bar.visible, "Race button returns to normal player match")
	game._show_menu()
	game.queue_free()
