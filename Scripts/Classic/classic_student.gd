class_name ClassicStudent
extends RefCounted

enum State { UNUSED, DEAD, WALK, STAND, SIT, WAIT, FIGHT }

var id: int
var team: int
var cell: Vector2i
var previous_cell: Vector2i
var destination: Vector2i
var target_id: int = -1
# Explicit player focus survives retaliation until the target dies or a new order.
var priority_target_id: int = -1
var approach_cell: Vector2i = Vector2i(-1, -1)
var state: State = State.UNUSED
var direction: int = 0
var pattern: int = 10
var counter: int = 0
var walk_tick: float = 0.0
var fight_phase: int = 0
var idle_ticks: int = 0
var lifetime: int = 0
# Per-victim successful damage: attacker ID -> tick and attacker lifetime.
var damage_contributors: Dictionary = {}
var punch_bonus: int = 0
var level: int = 0
var level_ticks: int = 0
var event_text: String = ""
var health: float
var maximum_health: float
var history: Array[Vector2i] = []


func is_alive() -> bool:
	return state > State.DEAD


func world_position() -> Vector2:
	if state == State.WALK:
		return ClassicRules.cell_to_world(Vector2(previous_cell).lerp(Vector2(cell), float(walk_tick) / 6.0))
	return ClassicRules.cell_to_world(Vector2(cell))


func show_event(message: String) -> void:
	event_text = message
	level_ticks = 30
