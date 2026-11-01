extends SceneTree

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func _run() -> void:
	for variant: bool in [false, true]:
		var sim: ClassicSimulation = ClassicSimulation.new()
		sim.medieval = variant
		sim.setup(0, 12345)
		sim.ai_enabled = false
		_check(sim.get_recruit_threshold(1) == (750 if variant else 500), "Orc/Green threshold")
		_check(is_equal_approx(sim.get_spawn_seconds(0) / sim.get_spawn_seconds(1), 2.0 if variant else 3.0), "Spawn speed ratio")
		sim.areas.clear()
		sim.area_at.clear()
		sim._add_area(Vector2i(5, 5), ClassicRules.AreaKind.RECRUIT, -1)
		var human: ClassicStudent = sim.students[0]
		human.cell = Vector2i(20, 20)
		human.counter = 1000
		human.state = ClassicStudent.State.SIT
		var duration: int = 216 if variant else 300
		for tick: int in duration - 1:
			if variant:
				sim._capture_areas()
			else:
				sim._sitting(human)
		_check(sim.areas[0].owner == -1, "Capture does not finish early")
		if variant:
			sim._capture_areas()
		else:
			sim._sitting(human)
		_check(sim.areas[0].owner == 0, "Capture completes at expected tick")

		for kind: int in [ClassicRules.AreaKind.HEAL, ClassicRules.AreaKind.BASE]:
			sim.areas[0].kind = kind
			sim.areas[0].owner = 2
			var elf: ClassicStudent = sim.students[6]
			elf.cell = human.cell
			elf.counter = 1000
			elf.state = ClassicStudent.State.SIT
			elf.health = 5.0
			sim._sitting(elf)
			_check(is_equal_approx(elf.health, 5.2 if variant and kind == ClassicRules.AreaKind.HEAL else 5.1), "Elf healing depends on variant and heart")

		sim.areas.clear()
		sim.area_at.clear()
		for i: int in 2:
			sim._add_area(Vector2i(i, 5), ClassicRules.AreaKind.HEAL, 1)
		_check(sim.get_team_capacity(1) == 13, "Hearts count toward orc capacity")
		for i: int in 3:
			sim._add_area(Vector2i(i, 6), ClassicRules.AreaKind.RECRUIT, 1)
		_check(sim.get_team_capacity(1) == 14, "Capacity rounds down combined tile pairs")
		sim.areas.back().owner = 0
		sim.areas[2].owner = 0
		_check(sim.get_team_capacity(1) == 13, "Lost tiles lower capacity")

		var target: ClassicStudent = sim.students[0]
		target.cell = Vector2i(30, 30)
		target.state = ClassicStudent.State.STAND
		var total: float = 0.0
		for count: int in 3:
			var orc: ClassicStudent = sim.students[3 + count]
			orc.cell = target.cell - ClassicRules.DIRECTIONS[count]
			orc.direction = count
			orc.state = ClassicStudent.State.FIGHT
			orc.target_id = target.id
			total += sim.get_punch_damage(orc, target)
			_check(total == (2 * (count + 1) + (count if variant else 0)), "Orc group damage matches N*damage + N-1")
		sim.students[3].state = ClassicStudent.State.DEAD
		_check(sim.get_punch_damage(sim.students[4], target) == 2, "Dead orcs do not support")
		sim.students[4].target_id = sim.students[9].id
		_check(sim.get_punch_damage(sim.students[5], target) == 2, "Different targets do not support")

		if not variant:
			for team: int in 4:
				sim._add_area(sim.bases[team], ClassicRules.AreaKind.BASE, team)
			for team: int in 4:
				var attacker: ClassicStudent = sim.students[team * 3]
				target = sim.students[((team + 1) % 4) * 3]
				attacker.cell = Vector2i(20, 20)
				attacker.direction = 0
				attacker.health = 5
				var old_max: float = attacker.maximum_health
				for kill: int in 2:
					target.cell = attacker.cell + Vector2i.RIGHT
					target.health = 1
					target.state = ClassicStudent.State.STAND
					for attempt: int in 100:
						attacker.state = ClassicStudent.State.FIGHT
						attacker.target_id = target.id
						attacker.fight_phase = 2
						attacker.counter = 0
						sim._fighting(attacker)
						if target.state == ClassicStudent.State.DEAD:
							break
					_check(target.state == ClassicStudent.State.DEAD, "Killing blow resolves")
				_check(attacker.maximum_health == old_max + (2 if not variant or team == 2 else 0), "Only medieval elves gain max HP on kill")
				_check(attacker.punch_bonus == (2 if variant and team == 3 else 0), "Only medieval demons gain stacking punch")
				_check(attacker.health == 5, "Kills do not instantly heal")
				attacker.state = ClassicStudent.State.UNUSED
				var spawned: ClassicStudent = sim.spawn_student(team)
				_check(spawned == attacker and spawned.punch_bonus == 0 and spawned.maximum_health == ClassicRules.HEALTH[team], "Respawn resets individual bonuses")

	var scene: PackedScene = load("res://Scenes/Classic/classic_game.tscn")
	var app: Control = scene.instantiate()
	app.medieval = true
	root.add_child(app)
	_check(app.difficulty_selector.get_item_count() == 3, "Menu offers three difficulties")
	_check(app.difficulty_selector.text == "Difficulty : Easy", "Difficulty defaults to Easy")
	for difficulty: int in 3:
		app.difficulty_selector.select(difficulty)
		app._start_match(1)
		_check(app.board.simulation.difficulty == difficulty, "Match receives selected difficulty")
		app._show_help()
		var name: String = ["EASY AI", "NORMAL AI", "EXPERT AI & BONUSES"][difficulty]
		_check(app.modal_body.text.begins_with(name), "Help reflects the active match difficulty")
		_check(("45 seconds" in app.modal_body.text) == (difficulty == ClassicSimulation.Difficulty.EXPERT), "Expert healing cooldown appears only on Expert")
		_check(("randomly fight back" in app.modal_body.text) == (difficulty == ClassicSimulation.Difficulty.NORMAL), "Normal retreat choices appear only on Normal")
		for other: int in 3:
			if other != difficulty:
				_check(not ["EASY AI", "NORMAL AI", "EXPERT AI & BONUSES"][other] in app.modal_body.text, "Other difficulty sections are excluded")
		_check("8 seconds" in app.modal_body.text and "28/32/36" in app.modal_body.text, "Shared rules appear for every difficulty")
		# Changing a menu control cannot change help for the running match.
		var other: int = (difficulty + 1) % 3
		app.difficulty_selector.select(other)
		app.difficulty_selector.item_selected.emit(other)
		_check(app.difficulty_selector.tooltip_text.begins_with(["Easy:", "Normal:", "Expert:"][other]), "Selector tooltip updates immediately")
		app._show_help()
		_check(app.modal_body.text.begins_with(name), "Help uses match state rather than a changed selector")
		app.difficulty_selector.select(difficulty)
		app._show_menu()
		_check(app.difficulty_selector.selected == difficulty, "Return to menu retains selection")
	app._start_match(1)
	_check(app.board.simulation.medieval, "Menu starts medieval rules")
	app._show_help()
	_check("twice as fast" in app.modal_body.text and "three times" not in app.modal_body.text, "Medieval help reflects rules")
	app.free()
	print("Medieval mechanics tests: %d failure(s)" % failures)
	quit(1 if failures else 0)
