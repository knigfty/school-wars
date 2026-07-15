class_name StudentVisualAnimator
extends Node2D

## Lightweight procedural animation for the reference-inspired student artwork.
## It keeps the unit scene texture-free and Web-safe while adding a readable
## walking cycle and subtle idle motion.

@export_range(1.0, 20.0, 0.5) var walk_cycle_speed: float = 7.0
@export_range(0.0, 12.0, 0.5) var leg_swing_degrees: float = 9.0
@export_range(0.0, 8.0, 0.5) var arm_swing_degrees: float = 6.0
@export_range(0.0, 4.0, 0.25) var body_bob_pixels: float = 1.5
@export_range(0.0, 0.2, 0.01) var idle_breathe_scale: float = 0.03

@onready var _student: StudentController = get_parent() as StudentController
@onready var _visuals: Node2D = get_node_or_null("../Visuals") as Node2D
@onready var _left_leg: Polygon2D = get_node_or_null("../Visuals/LeftLeg") as Polygon2D
@onready var _right_leg: Polygon2D = get_node_or_null("../Visuals/RightLeg") as Polygon2D
@onready var _left_arm: Polygon2D = get_node_or_null("../Visuals/LeftArm") as Polygon2D
@onready var _right_arm: Polygon2D = get_node_or_null("../Visuals/RightArm") as Polygon2D

var _phase: float = 0.0
var _base_visual_position: Vector2


func _ready() -> void:
	if _visuals != null:
		_base_visual_position = _visuals.position


func _process(delta: float) -> void:
	if _student == null or _visuals == null:
		return
	var speed_ratio: float = clampf(
		_student.velocity.length() / maxf(_student.stats.movement_speed, 0.01),
		0.0,
		1.0
	)
	if speed_ratio > 0.05:
		_phase += delta * walk_cycle_speed * lerpf(0.65, 1.0, speed_ratio)
		_apply_walk_cycle(speed_ratio)
	else:
		_phase += delta * 2.0
		_apply_idle_cycle()


func _apply_walk_cycle(speed_ratio: float) -> void:
	var wave: float = sin(_phase)
	var swing_scale: float = smoothstep(0.05, 1.0, speed_ratio)
	_set_rotation(_left_leg, deg_to_rad(leg_swing_degrees) * wave * swing_scale)
	_set_rotation(_right_leg, -deg_to_rad(leg_swing_degrees) * wave * swing_scale)
	_set_rotation(_left_arm, -deg_to_rad(arm_swing_degrees) * wave * swing_scale)
	_set_rotation(_right_arm, deg_to_rad(arm_swing_degrees) * wave * swing_scale)
	_visuals.position = _base_visual_position + Vector2(
		0.0,
		-absf(cos(_phase)) * body_bob_pixels * swing_scale
	)
	_visuals.scale = Vector2.ONE


func _apply_idle_cycle() -> void:
	_set_rotation(_left_leg, 0.0)
	_set_rotation(_right_leg, 0.0)
	_set_rotation(_left_arm, 0.0)
	_set_rotation(_right_arm, 0.0)
	_visuals.position = _base_visual_position
	var breathe: float = 1.0 + sin(_phase) * idle_breathe_scale
	_visuals.scale = Vector2(1.0, breathe)


func _set_rotation(node: Node2D, value: float) -> void:
	if node != null:
		node.rotation = value
