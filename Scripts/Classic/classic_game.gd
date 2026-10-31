extends Control

## Application shell for the faithful ruleset. Legacy main.tscn stays runnable.
const MENU_ART: Texture2D = preload("res://Assets/Classic/menu.png")

const MEDIEVAL_ART: Texture2D = preload("res://Assets/Medieval/menu.jpg")
const MEDIEVAL_STUDENTS: Texture2D = preload("res://Assets/Medieval/races2.png")
const RACE_NAMES: Array[String] = ["Humans", "Orcs", "Elves", "Demons"]

var medieval: bool = false
var extras_button: Button
var menu_title: Label
var menu_subtitle: Label
var difficulty_selector: OptionButton
var _pop_time: float = 0.0
var _reduce_motion: bool = false
var board: ClassicBoard
var minimap: ClassicMinimap
var menu: Control
var hud: Control
var modal: Control
var cards: Array[Button] = []
var status: RichTextLabel
var selection_label: Label
var recruit_panel: PanelContainer
var recruit_bar: ProgressBar
var recruit_label: Label
var hint_panel: PanelContainer
var announcement_label: Label
var modal_title: Label
var modal_body: Label
var modal_scroll: ScrollContainer
var resume_button: Button
var replay_button: Button
var quit_button: Button
var _announcement_time: float = 0.0
var _team: int = 0
var _seed: int = 0
var _muted: bool = false
var _dialog_height: float = 280.0


func _ready() -> void:
	if OS.has_feature("web"):
		medieval = bool(JavaScriptBridge.eval("window.location.pathname == '/v2' || window.location.pathname.startsWith('/v2/')"))
		_reduce_motion = bool(JavaScriptBridge.eval("window.matchMedia('(prefers-reduced-motion: reduce)').matches"))
		if medieval:
			JavaScriptBridge.eval("document.title = 'Medieval Wars'")
	_build_theme()
	board = ClassicBoard.new()
	board.medieval = medieval
	if medieval:
		board.student_texture = MEDIEVAL_STUDENTS
		board.team_names.assign(RACE_NAMES)
	add_child(board)
	_full_rect(board)
	board.match_finished.connect(_show_result)
	board.announcement.connect(_announce)
	board.selection_changed.connect(_update_selection)
	_build_menu()
	_build_hud()
	_build_modal()
	resized.connect(_layout)
	_layout()
	_show_menu()


func _build_theme() -> void:
	var ui_theme: Theme = Theme.new()
	ui_theme.default_font_size = 16
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color("343434") if state == "normal" else Color("515151")
		style.border_color = Color("777777") if state != "focus" else Color("a8ed9c")
		style.set_border_width_all(1)
		style.set_corner_radius_all(5)
		style.content_margin_left = 16
		style.content_margin_right = 16
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		ui_theme.set_stylebox(state, "Button", style)
	theme = ui_theme


func _build_menu() -> void:
	menu = Control.new()
	add_child(menu)
	_full_rect(menu)
	var background: ColorRect = ColorRect.new()
	background.color = Color("999999")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(background)
	_full_rect(background)
	var art: TextureRect = TextureRect.new()
	art.name = "OriginalTitleArt"
	art.texture = MEDIEVAL_ART if medieval else MENU_ART
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED if medieval else TextureRect.STRETCH_SCALE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(art)
	if medieval:
		var shade: ColorRect = ColorRect.new()
		shade.name = "TitleShade"
		shade.color = Color(0, 0, 0, 0.32)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		menu.add_child(shade)
		menu_title = _label("MEDIEVAL WARS", 56)
		menu_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		menu_title.add_theme_color_override("font_color", Color("f6e4b5"))
		menu_title.add_theme_color_override("font_shadow_color", Color.BLACK)
		menu_title.add_theme_constant_override("shadow_offset_x", 3)
		menu_title.add_theme_constant_override("shadow_offset_y", 4)
		menu.add_child(menu_title)
		menu_subtitle = _label("FOUR RACES. ONE BATTLEFIELD.", 15)
		menu_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		menu_subtitle.add_theme_color_override("font_color", Color("f6e4b5"))
		menu.add_child(menu_subtitle)
	if medieval:
		difficulty_selector = OptionButton.new()
		difficulty_selector.name = "DifficultySelector"
		difficulty_selector.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for difficulty_name: String in ["Easy", "Normal", "Expert"]:
			difficulty_selector.add_item("Difficulty : " + difficulty_name)
		difficulty_selector.select(ClassicSimulation.Difficulty.EASY)
		difficulty_selector.tooltip_text = "Easy: original AI. Normal: coordinated race squads. Expert: faster decisions and whole-map awareness for all AI teams."
		menu.add_child(difficulty_selector)
	extras_button = _button("School Wars" if medieval else "Extras", _navigate_variant)
	extras_button.name = "ExtrasButton"
	menu.add_child(extras_button)
	for team: int in 4:
		var button: Button = Button.new()
		button.name = "%sSchool" % board.team_names[team]
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.tooltip_text = "%s: %d HP · %d punch · 12 starting capacity" % [board.team_names[team], ClassicRules.HEALTH[team], ClassicRules.PUNCH[team]]
		button.pressed.connect(_start_match.bind(team))
		menu.add_child(button)
		cards.append(button)
		var icon: TextureRect = TextureRect.new()
		icon.name = "Portrait"
		var atlas: AtlasTexture = AtlasTexture.new()
		atlas.atlas = board.student_texture
		var index: int = team * 100 + 10
		var frame_size: Vector2 = board.student_texture.get_size() / 20.0
		atlas.region = Rect2(Vector2(index % 20, floori(float(index) / 20.0)) * frame_size, frame_size)
		atlas.filter_clip = true
		icon.texture = atlas
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if medieval else CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(icon)
		var title: Label = _label(board.team_names[team], 20)
		title.name = "SchoolName"
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.add_child(title)
		var trait_label: Label = _label(["All-rounder", "Fast recruitment", "High health", "Strong punch"][team], 12)
		trait_label.name = "Trait"
		trait_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		trait_label.modulate = ClassicRules.COLORS[team].lightened(0.55)
		button.add_child(trait_label)
	var footer: Label = _label("Choose your race. Eliminate the other three races." if medieval else "Choose your school colour. Eliminate the other three schools.", 13)
	footer.name = "Footer"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_color_override("font_color", Color("252525"))
	menu.add_child(footer)


func _build_hud() -> void:
	hud = Control.new()
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)
	_full_rect(hud)
	var bar: Panel = Panel.new()
	bar.name = "TopBar"
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("panel", _panel(Color(0.04, 0.04, 0.04, 0.92)))
	hud.add_child(bar)
	var title: Label = _label("MEDIEVAL WARS" if medieval else "SCHOOL WARS", 17)
	title.position = Vector2(18, 12)
	bar.add_child(title)
	status = RichTextLabel.new()
	status.bbcode_enabled = true
	status.scroll_active = false
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status.add_theme_font_size_override("normal_font_size", 14)
	bar.add_child(status)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.name = "Actions"
	buttons.add_theme_constant_override("separation", 6)
	hud.add_child(buttons)
	buttons.add_child(_button("?", _show_help))
	buttons.add_child(_button("Pause", _show_pause))
	var sound: Button = _button("Sound: on", func() -> void:
		_muted = not _muted
		board.set_muted(_muted))
	sound.pressed.connect(func() -> void: sound.text = "Sound: off" if _muted else "Sound: on")
	buttons.add_child(sound)
	buttons.add_child(_button("Quit", _show_quit))
	selection_label = _label("Drag around students to select.", 14)
	selection_label.name = "SelectionHint"
	hint_panel = PanelContainer.new()
	hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hint_style: StyleBoxFlat = _panel(Color(0.04, 0.04, 0.04, 0.86))
	hint_style.content_margin_left = 10
	hint_style.content_margin_right = 10
	hint_style.content_margin_top = 6
	hint_style.content_margin_bottom = 6
	hint_panel.add_theme_stylebox_override("panel", hint_style)
	hint_panel.add_child(selection_label)
	hud.add_child(hint_panel)
	hint_panel.hide()
	recruit_panel = PanelContainer.new()
	recruit_panel.name = "RecruitmentProgress"
	recruit_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var recruit_style: StyleBoxFlat = _panel(Color(0.04, 0.04, 0.04, 0.9))
	recruit_style.content_margin_left = 7
	recruit_style.content_margin_right = 7
	recruit_style.content_margin_top = 3
	recruit_style.content_margin_bottom = 3
	recruit_panel.add_theme_stylebox_override("panel", recruit_style)
	var recruit_box: VBoxContainer = VBoxContainer.new()
	recruit_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	recruit_panel.add_child(recruit_box)
	recruit_label = _label("Spawning", 10)
	recruit_box.add_child(recruit_label)
	recruit_bar = ProgressBar.new()
	recruit_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	recruit_bar.custom_minimum_size = Vector2(0, 7)
	recruit_bar.add_theme_font_size_override("font_size", 8)
	recruit_bar.max_value = 1.0
	recruit_bar.step = 0.0
	recruit_bar.show_percentage = false
	recruit_bar.add_theme_stylebox_override("background", _panel(Color("303030")))
	recruit_box.add_child(recruit_bar)
	hud.add_child(recruit_panel)
	minimap = ClassicMinimap.new()
	minimap.board = board
	hud.add_child(minimap)
	announcement_label = _label("", 18)
	announcement_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	announcement_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	announcement_label.add_theme_constant_override("shadow_offset_x", 2)
	announcement_label.add_theme_constant_override("shadow_offset_y", 2)
	hud.add_child(announcement_label)


func _build_modal() -> void:
	modal = Control.new()
	add_child(modal)
	_full_rect(modal)
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0, 0, 0, 0.65)
	modal.add_child(shade)
	_full_rect(shade)
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "Dialog"
	panel.add_theme_stylebox_override("panel", _panel(Color("242424")))
	modal.add_child(panel)
	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	panel.add_child(margin)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	margin.add_child(box)
	modal_title = _label("Paused", 30)
	box.add_child(modal_title)
	modal_body = _label("", 15)
	modal_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal_scroll = ScrollContainer.new()
	modal_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	modal_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	modal_scroll.add_child(modal_body)
	box.add_child(modal_scroll)
	resume_button = _button("Resume", _resume)
	box.add_child(resume_button)
	replay_button = _button("Play again", func() -> void: _start_match(_team))
	box.add_child(replay_button)
	quit_button = _button("Return to school selection", _show_menu)
	box.add_child(quit_button)


func _layout() -> void:
	if menu == null:
		return
	var art: Control = menu.get_node("OriginalTitleArt")
	art.size = Vector2(size.x, size.y * 0.64)
	extras_button.position = Vector2(size.x - 168, 24)
	extras_button.size = Vector2(140, 44)
	extras_button.pivot_offset = extras_button.size * 0.5
	if medieval:
		menu.get_node("TitleShade").size = art.size
		menu_title.position = Vector2(20, size.y * 0.25)
		menu_title.size = Vector2(size.x - 40, 80)
		menu_subtitle.position = Vector2(20, size.y * 0.25 + 85)
		menu_subtitle.size = Vector2(size.x - 40, 30)
		difficulty_selector.size = Vector2(minf(190, size.x - 40), 38)
		difficulty_selector.position = Vector2((size.x - difficulty_selector.size.x) * 0.5, size.y * 0.52 - 19)
	var width: float = minf(size.x - 64, 820)
	var card_width: float = (width - 36) / 4
	var card_height: float = size.y * 0.28
	for i: int in cards.size():
		var button: Button = cards[i]
		button.position = Vector2((size.x - width) * 0.5 + i * (card_width + 12), size.y * 0.66)
		button.size = Vector2(card_width, card_height)
		var icon: Control = button.get_node("Portrait")
		icon.position = Vector2((card_width - 48) * 0.5, 8)
		icon.size = Vector2(48, 72)
		var title: Control = button.get_node("SchoolName")
		title.position = Vector2(0, card_height - 62)
		title.size = Vector2(card_width, 28)
		var trait_label: Control = button.get_node("Trait")
		trait_label.position = Vector2(0, card_height - 31)
		trait_label.size = Vector2(card_width, 22)
	var footer: Control = menu.get_node("Footer")
	footer.position = Vector2(0, size.y - 30)
	footer.size = Vector2(size.x, 24)
	if hud == null:
		return
	hud.get_node("TopBar").size = Vector2(size.x, 52)
	status.position = Vector2(176, 15)
	status.size = Vector2(maxf(270, size.x - 540), 30)
	hud.get_node("Actions").position = Vector2(size.x - 330, 7)
	hud.get_node("Actions").size = Vector2(318, 38)
	hint_panel.position = Vector2(size.x - minf(size.x - 28, 520) - 14, size.y - 46)
	hint_panel.size = Vector2(minf(size.x - 28, 520), 32)
	recruit_panel.position = Vector2(14, size.y - 62)
	recruit_panel.size = Vector2(225, 48)
	minimap.position = size - Vector2(190, 122)
	minimap.size = Vector2(176, 104)
	announcement_label.position = Vector2(0, 68)
	announcement_label.size = Vector2(size.x, 40)
	if modal != null:
		var dialog: Control = modal.get_node("Dialog")
		dialog.position = Vector2((size.x - 560) * 0.5, (size.y - _dialog_height) * 0.5)
		dialog.size = Vector2(560, _dialog_height)


func _start_match(team: int) -> void:
	_team = team
	recruit_bar.add_theme_stylebox_override("fill", _panel(ClassicRules.COLORS[_team].lightened(0.3)))
	_seed = int(Time.get_unix_time_from_system() * 1000000.0) ^ Time.get_ticks_usec()
	board.muted = _muted
	board.start(team, _seed, difficulty_selector.selected if medieval else ClassicSimulation.Difficulty.EASY)
	menu.hide()
	modal.hide()
	hud.show()
	_announcement_time = 0.0
	announcement_label.text = ""
	_update_selection()
	_update_recruitment()
	board.grab_focus()


func _show_menu() -> void:
	board.paused = true
	board.stop_audio()
	board.hide()
	hud.hide()
	modal.hide()
	menu.show()
	cards[0].grab_focus()


func _show_dialog(title: String, body: String, can_resume: bool, can_replay: bool) -> void:
	board.paused = true
	board.stop_audio()
	board.cancel_selection()
	modal_title.text = title
	modal_body.text = body.replace("Green", "Orcs").replace("school", "race").replace("student", "warrior") if medieval else body
	_dialog_height = 460.0 if title == "How to play" else 280.0
	# Bound text layout before wrapping, including platforms with different font metrics.
	modal_scroll.custom_minimum_size.y = 140.0 if title == "How to play" else 32.0
	modal_scroll.scroll_vertical = 0
	resume_button.visible = can_resume
	replay_button.visible = can_replay
	modal.show()
	_layout()
	if can_resume:
		resume_button.grab_focus()
	else:
		replay_button.grab_focus()


func _show_help() -> void:
	if medieval:
		_show_dialog("How to play", "CONTROLS\n• L-click or drag a box to select; click a tile to move or an enemy to focus.\n• R-click drag / Space-drag: pan · Wheel: zoom · A: select all · Esc: pause\n\nCAPTURE & HEAL\n• Seated warriors capture spades and hearts; more allies capture faster.\n• Human capture times: 1/2/3/4/5/6+ seated warriors take 12/9/6/4/2/1 seconds. Other races: 16.7 seconds divided by seated warriors.\n• Partial capture progress stays when you leave. Bases can be captured only after their current owner is eliminated.\n• Captured bases change colour and independently spawn your race at your current rate, sharing your team capacity.\n• Owned spades speed spawning. Owned hearts and bases heal seated warriors at 1.8 HP/sec.\n• Elves heal at 3.6 HP/sec on owned hearts; base healing is unchanged.\n\nSPAWNING & COMBAT\n• Orcs spawn twice as fast. All races start with 12 capacity.\n• Orcs gain +1 capacity per two owned spades; hearts do not count. Losing spades lowers the cap without removing warriors.\n• Melee warriors surround enemies; upgraded humans and elves can attack from farther away.\n• Each additional orc engaged on the same target deals +1 punch damage.\n• Humans: 1st kill +2 max HP; 2nd kill +2 punch; 3rd kill unlocks 3-cell reach.\n• Orc killing blows: 50% chance to spawn a fresh orc at the death location, even above capacity.\n• Elves: +1 max HP per kill or damaging assist within 3 seconds. At 30/35/40 max HP, reach becomes 2/3/4 cells.\n• Demons: +1 punch per kill or damaging assist within 3 seconds. At 8/12/18 punch, movement speed is +20%/+30%/+40%.\n• Assist credit is once per death; HP bonuses do not instantly heal. Bonuses reset on respawn. Eliminate all opponents to win.", true, false)
		return
	_show_dialog("How to play", "CONTROLS\n• L-click to select · R-click drag to pan · Wheel to zoom\n• Drag a box to select a squad; click a tile to move or an enemy to focus attacks.\n• Space: clear selection · Space-drag: pan\n• A: select all · Esc: cancel / pause · Minimap: click or drag\n\nCAPTURE & HEAL\n• Sit on spade or heart tiles to capture them; more seated allies capture faster.\n• One student takes about 16.7 seconds. Moving or fighting does not count.\n• Grey = neutral; colours = owner. Partial progress stays when you leave.\n• Spades speed team spawning, even after you leave. They do not boost damage.\n• Friendly hearts and bases heal seated students: 1.8 HP/sec.\n• Bases cannot be captured. Capture and healing rates are equal for all teams.\n\nSPAWNING & COMBAT\n• The spawn bar shows the next cycle; full capacity or a blocked base prevents spawning.\n• Green spawns three times as fast. All teams start with 12 capacity.\n• Green gains +1 capacity per two owned spade/heart tiles. Lost tiles lower the cap without removing units.\n• Four attackers can surround a target; others close in and wait for openings.\n• Out-of-range attackers can fight back nearby, then resume their focus order.\n• Kill: +1 max HP, no instant heal. Eliminate all opponents to win.", true, false)


func _show_pause() -> void:
	_show_dialog("Paused", "Take your time. The schoolyard will wait.", true, false)


func _show_quit() -> void:
	_show_dialog("Leave this match?", "Returning to school selection ends the current match.", true, false)


func _resume() -> void:
	modal.hide()
	board.paused = false


func _show_result(won: bool) -> void:
	_show_dialog("You win !!" if won else "You lose...", "%s school eliminated all three opponents." % board.team_names[_team] if won else "Your last student has been defeated. Choose a school and try again.", false, true)


func _announce(text: String) -> void:
	announcement_label.text = text
	_announcement_time = 5.0


func _update_selection() -> void:
	selection_label.text = "L-click to select · R-click drag to pan · Wheel to zoom"


func _update_recruitment() -> void:
	var sim: ClassicSimulation = board.simulation
	if sim == null:
		return
	var threshold: int = sim.get_recruit_threshold(_team)
	var progress: int = sim.get_next_spawn_progress(_team)
	recruit_bar.value = clampf(float(progress) / threshold, 0.0, 1.0)
	var population: int = sim.get_count(_team)
	var capacity: int = sim.get_team_capacity(_team)
	if not sim.active[_team]:
		recruit_label.text = "Spawning ended"
	elif population >= capacity:
		recruit_label.text = "Capacity full · %d/%d" % [population, capacity]
	else:
		var free_base_cell: bool = sim.has_spawn_space(_team)
		if not free_base_cell:
			recruit_label.text = "Base blocked · clear space to recruit"
		else:
			var seconds: float = float(threshold + 1 - progress) / (2 + sim.get_recruit_tiles(_team)) / 18.0
			recruit_label.text = "Spawning · next cycle in %.1fs" % seconds


func _process(delta: float) -> void:
	if menu.visible and not medieval and not _reduce_motion:
		_pop_time += delta
		var pop: float = 1.0 + 0.07 * maxf(0.0, sin(_pop_time * 3.0))
		extras_button.scale = Vector2.ONE * pop
	if not hud.visible or board.simulation == null:
		return
	var segments: Array[String] = []
	for team: int in 4:
		var color: Color = ClassicRules.COLORS[team].lightened(0.45)
		var label: String = "%s %d/%d" % [board.team_names[team], board.simulation.get_count(team), board.simulation.get_team_capacity(team)]
		if team == _team:
			label = "[b]" + label + "[/b]"
		segments.append("[color=#%s]%s[/color]" % [color.to_html(false), label])
	status.text = "   ".join(segments)
	if not board.paused:
		_announcement_time = maxf(0.0, _announcement_time - delta)
		if _announcement_time <= 0.0:
			announcement_label.text = ""
	_update_selection()
	_update_recruitment()


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo or menu.visible:
		return
	if event.keycode == KEY_ESCAPE:
		if modal.visible and not board.simulation.finished:
			_resume()
		elif not board.selected.is_empty():
			board.cancel_selection()
		elif not board.simulation.finished:
			_show_pause()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_SPACE and not modal.visible:
		board.cancel_selection()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_A and not modal.visible:
		board.select_all()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(hud) and hud.visible and not modal.visible:
		_show_pause()


func _navigate_variant() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.location.assign('/')" if medieval else "window.location.assign('/v2')")


func _button(text: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(action)
	return button


func _label(text: String, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _panel(color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(7)
	return style


func _full_rect(control: Control) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
