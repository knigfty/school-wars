extends SceneTree

const INFO = preload("res://Scripts/Classic/character_info_panel.gd")
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	var sim: ClassicSimulation = ClassicSimulation.new()
	sim.medieval = true
	sim.setup(0, 123)
	var panel = INFO.new()
	root.add_child(panel)
	var unit: ClassicStudent = sim.students[0]
	unit.state = ClassicStudent.State.STAND
	unit.team = 0
	unit.health = 5
	unit.maximum_health = 22
	unit.punch_bonus = 2
	unit.level = 3
	var single: Array[int] = [unit.id]
	panel.refresh(sim, single, 0)
	_check(panel.visible, "Single selection shows info")
	_check(panel._labels[0].text == "HP: 5/22", "Current and maximum HP")
	_check(panel._labels[1].text == "PUNCH: 4 + 2", "Base and gained punch")
	_check(panel._labels[2].text == "RANGE: 1 + 2", "Live human range progression")
	_check(panel._labels[4].text == "ATTACK SPEED: 1.2 + 0/s", "Attack cycle rate")
	unit.state = ClassicStudent.State.FIGHT
	unit.cell = sim.bases[0] * 4
	var timer_before: int = unit.home_punch_until
	panel.refresh(sim, single, 0)
	_check(panel._labels[1].text == "PUNCH: 4 + 3", "Territorial punch is included")
	_check(unit.home_punch_until == timer_before, "Inspecting stats does not change combat timers")
	unit.state = ClassicStudent.State.STAND
	unit.team = 3
	unit.punch_bonus = 20
	sim.difficulty = ClassicSimulation.Difficulty.EXPERT
	panel.refresh(sim, single, 0)
	_check(panel._labels[3].text == "MOVEMENT SPEED: 1 + 0.5×", "Demon movement gains follow difficulty scaling")
	unit.team = 0
	unit.health = 4.5
	panel.refresh(sim, single, 0)
	_check(panel._labels[0].text == "HP: 4.5/22", "Stats update while selected")
	var empty: Array[int] = []
	panel.refresh(sim, empty, 4.9)
	_check(panel.visible, "Snapshot remains before five seconds")
	var other: ClassicStudent = sim.students[1]
	other.state = ClassicStudent.State.STAND
	other.health = 7
	other.maximum_health = 10
	var next: Array[int] = [other.id]
	panel.refresh(sim, next, 0)
	_check(panel._labels[0].text == "HP: 7/10", "New selection replaces snapshot immediately")
	var multiple: Array[int] = [unit.id, other.id]
	panel.refresh(sim, multiple, 0)
	_check(panel._labels[0].text == "Number of units: 2" and panel._labels[1].text.is_empty(), "Multi selection replaces stats with count")
	panel.refresh(sim, empty, 5.0)
	_check(not panel.visible, "Deselect hides at five seconds")
	panel.refresh(sim, single, 0)
	unit.state = ClassicStudent.State.DEAD
	panel.refresh(sim, single, 5.0)
	_check(not panel.visible, "Dead selections expire")
	panel.refresh(sim, next, 0)
	panel.reset()
	_check(not panel.visible, "New match resets info")
	panel.queue_free()
	# Instantiate the actual medieval shell to check integration and layout.
	var game = load("res://Scripts/Classic/classic_game.gd").new()
	game.medieval = true
	root.add_child(game)
	game.size = Vector2(960, 600)
	game._layout()
	game._start_match(0)
	game.board.selected.assign([0])
	game._update_selection()
	await process_frame
	_check(game.character_info.visible, "Board selection reaches panel")
	_check(game.character_info.position.x >= game.recruit_panel.get_rect().end.x, "Info sits after spawning box")
	_check(game.character_info.get_rect().end.x <= game.minimap.position.x, "Info clears minimap")
	_check(game.character_info.get_rect().end.y == game.recruit_panel.get_rect().end.y, "Panel aligns to spawning box bottom")
	game._show_menu()
	_check(not game.character_info.visible, "Returning to menu clears info")
	game.queue_free()
	print("Character info checks: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(1 if failures else 0)
