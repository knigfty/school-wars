extends SceneTree

var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _fixture(medieval: bool = true, spectator: bool = true) -> ClassicSimulation:
	var sim := ClassicSimulation.new()
	sim.medieval = medieval
	sim.setup(0, 123, spectator)
	sim.ai_enabled = false
	for unit: ClassicStudent in sim.students:
		unit.state = ClassicStudent.State.UNUSED
	sim.occupancy.clear()
	for race: int in 4:
		sim._initialize_student(sim.students[race], race, Vector2i(20 + race, 20))
		sim.students[race].state = ClassicStudent.State.SIT
	return sim

func _run() -> void:
	for medieval: bool in [false, true]:
		var sim := _fixture(medieval)
		var killer: ClassicStudent = sim.students[0]
		var victim: ClassicStudent = sim.students[1]
		victim.health = 1
		sim._apply_hit(killer, victim)
		_check(sim.team_kills[0] == 1 and sim.team_deaths[1] == 1, "Lethal damage counts once in both modes")
		sim._initialize_student(victim, 1, Vector2i(21,20))
		victim.health = 1
		sim._apply_hit(killer,victim)
		_check(sim.team_kills[0] == 2 and sim.team_deaths[1] == 2, "Match totals survive unit replacement")
		sim.setup(0,123,true)
		_check(sim.team_kills == [0,0,0,0] and sim.team_deaths == [0,0,0,0] and sim.elimination_order.is_empty(), "Replay resets all cumulative results")
	# A guaranteed conversion still records the victim's death and killer's race.
	var sim := _fixture()
	var orc: ClassicStudent = sim.students[1]
	var victim: ClassicStudent = sim.students[2]
	victim.health = 1
	victim.orc_conversion_hits.assign([0,0,0])
	sim._apply_hit(orc,victim)
	_check(sim.team_kills[1] == 1 and sim.team_deaths[2] == 1 and sim.get_converted_count(1) == 1, "Conversion records one kill/death without counting its new unit as dead")
	# Placement follows elimination sequence, including ties in simulation ticks.
	sim = _fixture()
	var expected_times: Array[int] = [1080,720,180,900]
	for race: int in [2,1,3]:
		sim.ticks = expected_times[race]
		sim.students[race].state = ClassicStudent.State.UNUSED
		sim._check_elimination(race)
	sim.ticks = 1080
	var rows: Array[Dictionary] = sim.get_match_results()
	_check(rows.size() == 4 and rows[0].team == 0 and rows[1].team == 3 and rows[2].team == 1 and rows[3].team == 2, "Winner and reverse elimination order give all four placements")
	for row: Dictionary in rows:
		_check(row.survival_ticks == expected_times[row.team], "Eliminated times freeze while winner time uses final battle tick")
	var frozen: int = sim.ticks
	sim.step()
	_check(sim.ticks == frozen, "Finished match does not advance survival time")
	sim = _fixture()
	for race: int in [2,1,3]:
		sim.ticks = 180
		sim.students[race].state = ClassicStudent.State.UNUSED
		sim._check_elimination(race)
	rows = sim.get_match_results()
	_check(rows[1].team == 3 and rows[3].team == 2, "Same-tick eliminations preserve actual elimination sequence")
	await _test_dialogs()
	print("Match results tests: %d failure(s)" % failures)
	quit(1 if failures else 0)

func _test_dialogs() -> void:
	var scene: PackedScene = load("res://Scenes/Classic/classic_game.tscn")
	for medieval: bool in [false,true]:
		for spectator: bool in [false,true]:
			for won: bool in [false,true]:
				var game = scene.instantiate()
				game.medieval = medieval
				root.add_child(game)
				game.set_process(false)
				game.board.set_process(false)
				game._spectating = spectator
				game._team = -1 if spectator else 0
				game.board.simulation = _fixture(medieval, spectator)
				var sim: ClassicSimulation = game.board.simulation
				if won or spectator:
					for race: int in [2,1,3]:
						sim.ticks += 180
						sim.students[race].state = ClassicStudent.State.UNUSED
						sim._check_elimination(race)
				else:
					sim.ticks = 1350
					sim.students[0].state = ClassicStudent.State.UNUSED
					sim._check_elimination(0)
				sim.team_kills.assign([7,4,2,1])
				sim.team_deaths.assign([2,8,6,3])
				game._show_result(won)
				await process_frame
				await process_frame
				_check(game.result_stats.visible and game.result_stats.get_child_count() == 20, "Every victory/defeat/spectator dialog has header and four stat rows")
				_check(game.quit_button.text == "Return to menu", "All result screens use Return to menu")
				if not won and not spectator:
					_check("provisionally" in game.modal_body.text, "Early player defeat identifies provisional surviving places")
					_check(game.result_stats.get_child(16).text == game.board.team_names[0] + " :", "Eliminated player follows all surviving armies")
				else:
					_check(game.result_stats.get_child(4).text == game.board.team_names[0] + " :", "Winner appears first")
				# Check wide and compact layouts with the actual Godot containers/fonts.
				for width: int in [960,576]:
					game.size = Vector2(width,600)
					game._layout()
					await process_frame
					await process_frame
					var dialog: Control = game.modal.get_node("Dialog")
					_check(dialog.get_rect().end.x <= game.size.x and dialog.position.x >= 0, "Result dialog fits viewport width")
					_check(game.result_stats.get_global_rect().end.y <= game.replay_button.get_global_rect().position.y, "Stats remain above replay controls")
					_check(game.result_stats.get_global_rect().end.x <= dialog.get_global_rect().end.x, "Stat columns fit inside dialog")
				game._show_pause()
				_check(not game.result_stats.visible, "Pause/help dialogs do not leak prior results")
				game._show_menu()
				game.free()
