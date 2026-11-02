extends PanelContainer

## Read-only selection HUD. Retains the last snapshot for five seconds after deselection.
const HIDE_DELAY: float = 5.0
var _labels: Array[Label] = []
var _remaining: float = 0.0


func _init() -> void:
	name = "CharacterInfo"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 2)
	add_child(grid)
	for index: int in 6:
		var label: Label = Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size", 10)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(label)
		_labels.append(label)
	minimum_size_changed.connect(_align_bottom)
	reset()


func reset() -> void:
	_remaining = 0.0
	hide()


func refresh(sim: ClassicSimulation, selected: Array[int], delta: float) -> void:
	var units: Array[ClassicStudent] = []
	for id: int in selected:
		if id >= 0 and id < sim.students.size() and sim.students[id].is_alive():
			units.append(sim.students[id])
	if units.is_empty():
		_remaining = maxf(0.0, _remaining - delta)
		if _remaining <= 0.0:
			hide()
		return
	_remaining = HIDE_DELAY
	show()
	for label: Label in _labels:
		label.text = ""
	if units.size() > 1:
		_labels[0].text = "Number of units: %d" % units.size()
		return
	var unit: ClassicStudent = units[0]
	var base_punch: float = ClassicRules.PUNCH[unit.team]
	var punch: float = base_punch + (unit.punch_bonus if sim.medieval else 0)
	# Include active combat bonuses without invoking the damage getter, which mutates timers.
	if sim.medieval and unit.team == 0 and (sim.ticks < unit.home_punch_until or (unit.state == ClassicStudent.State.FIGHT and sim._on_owned_tile(unit))):
		punch += 1.0
	if sim.medieval and unit.team == 1 and unit.state == ClassicStudent.State.FIGHT and unit.target_id >= 0 and unit.target_id < sim.students.size():
		var target: ClassicStudent = sim.students[unit.target_id]
		punch += sim.get_orc_group_bonus(unit, target)
	if sim.medieval and unit.team == 1 and unit.is_converted:
		punch = minf(punch, ClassicRules.CONVERTED_ORC_MAX_PUNCH)
	_labels[0].text = "HP: %s/%s" % [_number(unit.health), _number(unit.maximum_health)]
	_labels[1].text = "PUNCH: %s" % _split(base_punch, punch)
	_labels[2].text = "RANGE: %s" % _split(1.0, sim.get_attack_range(unit))
	_labels[3].text = "MOVEMENT SPEED: %s×" % _split(1.0, sim.get_movement_multiplier(unit))
	# Repeating attack cycle: two 2-tick windup phases and an 11-tick recovery.
	var attack_rate: float = sim.get_attack_speed(unit)
	_labels[4].text = "ATTACK SPEED: %s/s" % _split(attack_rate, attack_rate)


func _split(base: float, total: float) -> String:
	var gained: float = total - base
	return "%s %s %s" % [_number(base), "+" if gained >= 0.0 else "−", _number(absf(gained))]


func _number(value: float) -> String:
	return ("%.2f" % value).trim_suffix("0").trim_suffix("0").trim_suffix(".")


func _align_bottom() -> void:
	# Reflow when platform font metrics change after entering the theme tree.
	if get_parent() != null and get_parent().get_parent() != null and get_parent().get_parent().has_method("_layout"):
		get_parent().get_parent().call_deferred("_layout")
