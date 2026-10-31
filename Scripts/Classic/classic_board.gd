class_name ClassicBoard
extends Control

signal selection_changed
signal announcement(text: String)
signal match_finished(won: bool)

const STUDENTS: Texture2D = preload("res://Assets/Classic/students.png")
const TILES: Texture2D = preload("res://Assets/Classic/tiles.png")
const CUES: Dictionary = {
	"select": preload("res://Assets/Classic/select.wav"),
	"tomove": preload("res://Assets/Classic/tomove.wav"),
	"punch": preload("res://Assets/Classic/punch.wav"),
	"dead": preload("res://Assets/Classic/dead.wav"),
	"message": preload("res://Assets/Classic/message.wav"),
	"cancel": preload("res://Assets/Classic/cancel.wav"),
}

var student_texture: Texture2D = STUDENTS
var team_names: Array[String] = ClassicRules.TEAM_NAMES.duplicate()

var _frame_cache: Dictionary = {}

var medieval: bool = false
var simulation: ClassicSimulation
var selected: Array[int] = []
var camera_center: Vector2 = Vector2(0, 384)
var view_zoom: float = 1.5
var paused: bool = false
var muted: bool = false
var _accumulator: float = 0.0
var _selecting: bool = false
var _panning: bool = false
var _start: Vector2
var _pointer: Vector2
var _marker: Vector2
var _marker_target: int = -1
var _marker_life: float = 0.0
var _audio: Array[AudioStreamPlayer] = []
var _audio_index: int = 0


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if student_texture != STUDENTS else CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for i: int in 8:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.volume_db = -10.0
		add_child(player)
		_audio.append(player)


func start(team: int, map_seed: int, difficulty: int = ClassicSimulation.Difficulty.EASY) -> void:
	simulation = ClassicSimulation.new()
	simulation.medieval = medieval
	simulation.difficulty = clampi(difficulty, ClassicSimulation.Difficulty.EASY, ClassicSimulation.Difficulty.EXPERT)
	simulation.setup(team, map_seed)
	simulation.sound_requested.connect(_on_sound)
	simulation.team_eliminated.connect(_on_eliminated)
	simulation.match_finished.connect(func(won: bool) -> void: match_finished.emit(won))
	selected.clear()
	_marker_target = -1
	_marker_life = 0.0
	_accumulator = 0.0
	view_zoom = 1.5
	camera_center = ClassicRules.cell_to_world(Vector2(simulation.bases[team] * 4)) + Vector2(0, 18)
	_clamp_camera()
	paused = false
	visible = true
	queue_redraw()


func _process(delta: float) -> void:
	if not visible or simulation == null:
		return
	if not paused:
		# Drop wall-clock backlog after tab suspension; never fast-forward a match.
		_accumulator += minf(delta, 0.2)
		while _accumulator >= 1.0 / 18.0:
			_accumulator -= 1.0 / 18.0
			simulation.step()
		for id: int in selected.duplicate():
			if not simulation.students[id].is_alive():
				selected.erase(id)
		_marker_life = maxf(0.0, _marker_life - delta)
	queue_redraw()


func world_to_screen(world: Vector2) -> Vector2:
	return (world - camera_center) * view_zoom + size * 0.5


func screen_to_world(screen: Vector2) -> Vector2:
	return (screen - size * 0.5) / view_zoom + camera_center


func set_camera(world: Vector2) -> void:
	camera_center = world
	_clamp_camera()
	queue_redraw()


func cancel_selection() -> void:
	if not selected.is_empty():
		_on_sound("cancel", camera_center)
	selected.clear()
	_selecting = false
	_panning = false
	selection_changed.emit()
	queue_redraw()


func set_muted(value: bool) -> void:
	muted = value
	if muted:
		stop_audio()


func stop_audio() -> void:
	for player: AudioStreamPlayer in _audio:
		player.stop()
		player.stream = null


func _exit_tree() -> void:
	stop_audio()


func select_all() -> void:
	selected.clear()
	for student: ClassicStudent in simulation.students:
		if student.is_alive() and student.team == simulation.player_team:
			selected.append(student.id)
	selection_changed.emit()
	_on_sound("select", camera_center)


func _gui_input(event: InputEvent) -> void:
	if simulation == null or paused or simulation.finished:
		return
	if event is InputEventMouseButton:
		_pointer = event.position
		if event.button_index == MOUSE_BUTTON_RIGHT or (event.button_index == MOUSE_BUTTON_LEFT and Input.is_physical_key_pressed(KEY_SPACE)):
			_panning = event.pressed
			_selecting = false
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if not event.pressed and _panning:
				_panning = false
			elif event.pressed:
				if not selected.is_empty():
					_issue_order(event.position)
					_selecting = false
				else:
					_selecting = true
					_start = event.position
			elif _selecting:
				_finish_selection(event.position)
				_selecting = false
			accept_event()
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var focus: Vector2 = screen_to_world(event.position)
			view_zoom = clampf(view_zoom + (0.15 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -0.15), 0.5, 3.0)
			camera_center = focus - (event.position - size * 0.5) / view_zoom
			_clamp_camera()
			accept_event()
	elif event is InputEventMouseMotion:
		_pointer = event.position
		if _panning:
			camera_center -= event.relative / view_zoom
			_clamp_camera()
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_EXIT or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_selecting = false
		_panning = false
		_accumulator = 0.0


func _finish_selection(point: Vector2) -> void:
	if _start.distance_to(point) >= 6.0:
		var rect: Rect2 = Rect2(_start, point - _start).abs().grow(10.0)
		selected.clear()
		for student: ClassicStudent in simulation.students:
			if student.is_alive() and student.team == simulation.player_team:
				if rect.has_point(world_to_screen(student.world_position()) + Vector2(0, -12) * view_zoom):
					selected.append(student.id)
	elif selected.is_empty():
		var id: int = pick_student(point, false)
		if id >= 0 and simulation.students[id].team == simulation.player_team:
			selected.append(id)
	selection_changed.emit()
	if not selected.is_empty():
		_on_sound("select", camera_center)


func _issue_order(point: Vector2) -> void:
	var cell: Vector2i = ClassicRules.world_to_cell(screen_to_world(point))
	if not ClassicRules.in_grid(cell):
		return
	var tile: Vector2i = Vector2i(cell.x / 4, cell.y / 4)
	_marker_target = pick_student(point, true)
	simulation.command(selected, tile, _marker_target)
	selected.clear()
	_marker = ClassicRules.cell_to_world(Vector2(tile * 4)) + Vector2(0, 24)
	_marker_life = 0.7
	_on_sound("tomove", camera_center)
	selection_changed.emit()


func pick_student(point: Vector2, enemies_only: bool) -> int:
	var picked: int = -1
	var depth: float = -INF
	for student: ClassicStudent in simulation.students:
		if not student.is_alive() or (enemies_only and student.team == simulation.player_team):
			continue
		var pos: Vector2 = world_to_screen(student.world_position())
		var rect: Rect2 = Rect2(pos + Vector2(-12, -32) * view_zoom, Vector2(24, 44) * view_zoom)
		if rect.has_point(point) and pos.y >= depth:
			picked = student.id
			depth = pos.y
	return picked


func _clamp_camera() -> void:
	var half: Vector2 = size * 0.5 / view_zoom
	camera_center.x = clampf(camera_center.x, minf(0.0, -840.0 + half.x), maxf(0.0, 840.0 - half.x))
	camera_center.y = clampf(camera_center.y, minf(384.0, -80.0 + half.y), maxf(384.0, 848.0 - half.y))


func student_frame(index: int) -> AtlasTexture:
	if not _frame_cache.has(index):
		var frame: AtlasTexture = AtlasTexture.new()
		frame.atlas = student_texture
		var frame_size: Vector2 = student_texture.get_size() / 20.0
		frame.region = Rect2(Vector2(index % 20, floori(float(index) / 20.0)) * frame_size, frame_size)
		frame.filter_clip = true
		_frame_cache[index] = frame
	return _frame_cache[index]


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("454545"))
	if simulation == null:
		return
	var corners: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in [Vector2.ZERO, Vector2(768, 384), Vector2(0, 768), Vector2(-768, 384)]:
		corners.append(world_to_screen(point))
	draw_colored_polygon(corners, Color("cccccc"))
	for area: Dictionary in simulation.areas:
		var index: int = (int(area.kind) - 1) * 5 + int(area.owner) + 1
		var origin: Vector2 = ClassicRules.cell_to_world(Vector2(area.tile * 4))
		var rect: Rect2 = Rect2(world_to_screen(origin + Vector2(-48, 0)), Vector2(96, 48) * view_zoom)
		draw_texture_rect_region(TILES, rect, Rect2(Vector2(index % 5 * 96, index / 5 * 48), Vector2(96, 48)))
	# Reserved grid-cell depth matches the Flash display list and avoids overlap flicker.
	var ordered: Array[ClassicStudent] = students_in_depth_order()
	for student: ClassicStudent in ordered:
		var pos: Vector2 = world_to_screen(student.world_position())
		if not Rect2(Vector2(-100, -100), size + Vector2(200, 200)).has_point(pos):
			continue
		var index: int = student.team * 100 + student.direction * 25 + student.pattern
		draw_texture_rect(student_frame(index), Rect2(pos + Vector2(-16, -34) * view_zoom, Vector2(32, 48) * view_zoom), false)
		var health_pos: Vector2 = pos + Vector2(-student.maximum_health * 0.5, -34) * view_zoom
		draw_rect(Rect2(health_pos, Vector2(student.maximum_health, 1) * view_zoom), Color("ed1d24"))
		if student.is_alive():
			draw_rect(Rect2(health_pos, Vector2(student.health, 1) * view_zoom), Color("66ff00"))
		if student.id in selected and student.is_alive():
			draw_string(ThemeDB.fallback_font, pos + Vector2(-4, -39) * view_zoom, "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 13 * view_zoom, Color.WHITE)
		if student.level_ticks > 0 and not student.event_text.is_empty():
			var text_offset: float = -20.0
			if simulation.medieval:
				text_offset = -ThemeDB.fallback_font.get_string_size(student.event_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x * 0.5
			draw_string(ThemeDB.fallback_font, pos + Vector2(text_offset, -45) * view_zoom, student.event_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9 * view_zoom, Color.WHITE)
	if not selected.is_empty() and not _selecting:
		var enemy: int = pick_student(_pointer, true)
		if enemy >= 0:
			_draw_target_arrow(enemy, Color("ff3333"))
		else:
			var cell: Vector2i = ClassicRules.world_to_cell(screen_to_world(_pointer))
			if ClassicRules.in_grid(cell):
				_draw_cursor(ClassicRules.cell_to_world(Vector2(Vector2i(cell.x / 4, cell.y / 4) * 4)), Color("ff3333"))
	if _marker_life > 0.0:
		var color: Color = Color(1, 0.2, 0.2, _marker_life / 0.7)
		if _marker_target >= 0:
			if simulation.students[_marker_target].is_alive():
				_draw_target_arrow(_marker_target, color)
		else:
			_draw_cursor(_marker - Vector2(0, 24), color)

	if _selecting and _start.distance_to(_pointer) >= 6.0:
		var rect: Rect2 = Rect2(_start, _pointer - _start).abs()
		draw_rect(rect, Color(0.4, 1, 0.2, 0.08))
		draw_rect(rect, Color("66ff00"), false, 1.0)


func students_in_depth_order() -> Array[ClassicStudent]:
	var ordered: Array[ClassicStudent] = []
	for student: ClassicStudent in simulation.students:
		if student.state != ClassicStudent.State.UNUSED:
			ordered.append(student)
	ordered.sort_custom(func(a: ClassicStudent, b: ClassicStudent) -> bool:
		var depth_a: int = (a.cell.x + a.cell.y) * 64 + a.cell.x
		var depth_b: int = (b.cell.x + b.cell.y) * 64 + b.cell.x
		return depth_a < depth_b)
	return ordered


func _draw_target_arrow(id: int, color: Color) -> void:
	var tip: Vector2 = world_to_screen(simulation.students[id].world_position() + Vector2(0, -36))
	var scale: float = view_zoom
	draw_line(tip - Vector2(0, 16) * scale, tip - Vector2(0, 5) * scale, color, 3.0)
	draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-5, -7) * scale, tip + Vector2(5, -7) * scale]), color)


func _draw_cursor(origin: Vector2, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in [Vector2.ZERO, Vector2(48, 24), Vector2(0, 48), Vector2(-48, 24), Vector2.ZERO]:
		points.append(world_to_screen(origin + point))
	draw_polyline(points, color, 2.0)


func _on_sound(cue: String, world: Vector2) -> void:
	if muted or _audio.is_empty() or not CUES.has(cue):
		return
	if not Rect2(Vector2.ZERO, size).has_point(world_to_screen(world)):
		return
	var player: AudioStreamPlayer = _audio[_audio_index]
	_audio_index = (_audio_index + 1) % _audio.size()
	player.stream = CUES[cue]
	player.play()


func _on_eliminated(team: int) -> void:
	announcement.emit("%s is annihilated." % team_names[team])
	_on_sound("message", camera_center)
