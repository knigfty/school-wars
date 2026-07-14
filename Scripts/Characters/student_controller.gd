class_name StudentController
extends CharacterBody2D

## Command-driven student motor and close-contact combatant. Player input stays
## in the selection/command layer; this unit only consumes movement and targets.

signal movement_started
signal movement_stopped
signal health_changed(current_health: float, maximum_health: float)
signal attack_performed(attacker: StudentController, target: StudentController, damage: float)
signal defeated(student: StudentController, killer: StudentController)

const STUDENT_GROUP: StringName = &"students"
const ATTACK_FLASH_DURATION: float = 0.12

@export var stats: StudentStats
@export var team: TeamDefinition

var current_health: float = 0.0
var maximum_health: float = 0.0

var _move_intent: Vector2 = Vector2.ZERO
var _was_moving: bool = false
var _attack_target: StudentController
var _attack_cooldown_remaining: float = 0.0
var _attack_flash_remaining: float = 0.0
var _attack_flash_direction: Vector2 = Vector2.RIGHT
var _damage_contributors: Dictionary = {}
var _last_attacker: WeakRef
var _is_defeated: bool = false


func _ready() -> void:
	add_to_group(STUDENT_GROUP)
	if stats == null:
		push_error("%s requires a StudentStats resource." % name)
		set_physics_process(false)
		return
	if team == null or not team.is_configured():
		push_error("%s requires a configured TeamDefinition." % name)
		set_physics_process(false)
		return
	maximum_health = team.starting_health
	current_health = maximum_health
	_apply_team_visuals()
	queue_redraw()


func _physics_process(delta: float) -> void:
	_attack_cooldown_remaining = maxf(_attack_cooldown_remaining - delta, 0.0)
	_attack_flash_remaining = maxf(_attack_flash_remaining - delta, 0.0)
	var combat_target: StudentController = _resolve_combat_target()
	if combat_target != null:
		var target_offset: Vector2 = combat_target.global_position - global_position
		if target_offset.length() <= stats.attack_range:
			_move_intent = Vector2.ZERO
			_perform_attack(combat_target)
		elif combat_target == _attack_target:
			_move_intent = _get_crisscross_direction(target_offset)

	var target_velocity: Vector2 = _move_intent * stats.movement_speed
	var change_rate: float = (
		stats.acceleration
		if not _move_intent.is_zero_approx()
		else stats.deceleration
	)
	velocity = velocity.move_toward(target_velocity, change_rate * delta)
	move_and_slide()
	_update_movement_signals()
	if _attack_flash_remaining > 0.0:
		queue_redraw()


func set_move_intent(direction: Vector2) -> void:
	_move_intent = direction.limit_length(1.0)


func get_move_intent() -> Vector2:
	return _move_intent


func stop_immediately() -> void:
	_move_intent = Vector2.ZERO
	velocity = Vector2.ZERO
	_update_movement_signals()


func set_attack_target(target: StudentController) -> void:
	if target == null or not is_enemy(target):
		return
	_attack_target = target


func clear_attack_target() -> void:
	_attack_target = null
	_move_intent = Vector2.ZERO


func get_attack_target() -> StudentController:
	return _attack_target


func is_enemy(other: StudentController) -> bool:
	return (
		other != null
		and other != self
		and not other.is_defeated()
		and other.get_team_id() != get_team_id()
	)


func take_damage(amount: float, attacker: StudentController = null) -> void:
	if _is_defeated or amount <= 0.0:
		return
	if attacker != null and is_enemy(attacker):
		_damage_contributors[attacker.get_instance_id()] = weakref(attacker)
		_last_attacker = weakref(attacker)
	current_health = maxf(current_health - amount, 0.0)
	health_changed.emit(current_health, maximum_health)
	queue_redraw()
	if is_zero_approx(current_health):
		_defeat()


func on_enemy_takedown(_enemy: StudentController) -> void:
	if team == null or team.takedown_max_health_gain <= 0.0 or _is_defeated:
		return
	maximum_health += team.takedown_max_health_gain
	current_health = minf(
		current_health + team.takedown_max_health_gain,
		maximum_health
	)
	health_changed.emit(current_health, maximum_health)
	queue_redraw()


func get_attack_damage() -> float:
	return team.damage_per_second / maxf(stats.attacks_per_second, 0.01)


func get_attack_damage_per_second() -> float:
	return team.damage_per_second


func get_health_ratio() -> float:
	return clampf(current_health / maxf(maximum_health, 0.01), 0.0, 1.0)


func is_defeated() -> bool:
	return _is_defeated


func get_team_id() -> StringName:
	return team.team_id if team != null else &""


func get_team_color() -> Color:
	return team.color if team != null else Color.WHITE


func _resolve_combat_target() -> StudentController:
	if _attack_target != null:
		if is_instance_valid(_attack_target) and is_enemy(_attack_target):
			return _attack_target
		_attack_target = null
		_move_intent = Vector2.ZERO
	var move_order: StudentMoveOrderComponent = get_node_or_null(
		"MoveOrder"
	) as StudentMoveOrderComponent
	if move_order != null and move_order.has_active_order():
		return null
	return _find_contact_enemy()


func _find_contact_enemy() -> StudentController:
	var nearest_enemy: StudentController
	var nearest_distance: float = stats.attack_range
	for node: Node in get_tree().get_nodes_in_group(STUDENT_GROUP):
		var candidate: StudentController = node as StudentController
		if not is_enemy(candidate):
			continue
		var distance: float = global_position.distance_to(candidate.global_position)
		if distance <= nearest_distance:
			nearest_enemy = candidate
			nearest_distance = distance
	return nearest_enemy


func _get_crisscross_direction(offset: Vector2) -> Vector2:
	var diagonal_down_amount: float = (offset.x + offset.y) * 0.5
	var diagonal_up_amount: float = (offset.x - offset.y) * 0.5
	if absf(diagonal_down_amount) >= absf(diagonal_up_amount):
		return Vector2(
			signf(diagonal_down_amount),
			signf(diagonal_down_amount)
		).normalized()
	return Vector2(
		signf(diagonal_up_amount),
		-signf(diagonal_up_amount)
	).normalized()


func _perform_attack(target: StudentController) -> void:
	if _attack_cooldown_remaining > 0.0 or target == null:
		return
	var damage: float = get_attack_damage()
	_attack_cooldown_remaining = 1.0 / maxf(stats.attacks_per_second, 0.01)
	_attack_flash_remaining = ATTACK_FLASH_DURATION
	_attack_flash_direction = (target.global_position - global_position).normalized()
	attack_performed.emit(self, target, damage)
	target.take_damage(damage, self)
	queue_redraw()


func _defeat() -> void:
	if _is_defeated:
		return
	_is_defeated = true
	set_physics_process(false)
	var killer: StudentController
	if _last_attacker != null:
		killer = _last_attacker.get_ref() as StudentController
	for value: Variant in _damage_contributors.values():
		var contributor_ref: WeakRef = value as WeakRef
		if contributor_ref == null:
			continue
		var contributor: StudentController = contributor_ref.get_ref() as StudentController
		if contributor != null and is_instance_valid(contributor):
			contributor.on_enemy_takedown(self)
	defeated.emit(self, killer)
	queue_free()


func _update_movement_signals() -> void:
	var is_moving: bool = not velocity.is_zero_approx()
	if is_moving == _was_moving:
		return
	_was_moving = is_moving
	if is_moving:
		movement_started.emit()
	else:
		movement_stopped.emit()


func _apply_team_visuals() -> void:
	var outline: Polygon2D = get_node_or_null("Visuals/Outline") as Polygon2D
	var body: Polygon2D = get_node_or_null("Visuals/Body") as Polygon2D
	var team_mark: Polygon2D = get_node_or_null("Visuals/TeamMark") as Polygon2D
	var cap: Polygon2D = get_node_or_null("Visuals/Cap") as Polygon2D
	if outline != null:
		outline.color = team.color.lightened(0.42)
	if body != null:
		body.color = team.color.darkened(0.3)
	if team_mark != null:
		team_mark.color = team.color
	if cap != null:
		cap.color = team.color.darkened(0.2)


func _draw() -> void:
	if maximum_health <= 0.0:
		return
	var bar_background: Rect2 = Rect2(Vector2(-20.0, -36.0), Vector2(40.0, 5.0))
	draw_rect(bar_background.grow(1.0), Color(0.02, 0.02, 0.025, 0.9), true)
	var ratio: float = get_health_ratio()
	var health_color: Color = Color("68e34f").lerp(Color("e44242"), 1.0 - ratio)
	draw_rect(
		Rect2(bar_background.position, Vector2(bar_background.size.x * ratio, 5.0)),
		health_color,
		true
	)
	if _attack_flash_remaining > 0.0:
		draw_line(
			_attack_flash_direction * 12.0,
			_attack_flash_direction * 31.0,
			Color(1.0, 0.83, 0.25, _attack_flash_remaining / ATTACK_FLASH_DURATION),
			4.0
		)
