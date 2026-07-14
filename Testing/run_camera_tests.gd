extends SceneTree

const CAMERA_SCENE: PackedScene = preload("res://Scenes/Camera/rts_camera.tscn")

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var camera: RTSCameraController = CAMERA_SCENE.instantiate() as RTSCameraController
	root.add_child(camera)

	camera.set_zoom_level(100.0, true)
	_check(
		is_equal_approx(camera.get_zoom_level(), camera.maximum_zoom),
		"Zoom is constrained to the configured maximum"
	)

	camera.set_zoom_level(0.01, true)
	_check(
		is_equal_approx(camera.get_zoom_level(), camera.minimum_zoom),
		"Zoom is constrained to the configured minimum"
	)
	var fully_zoomed_view: Vector2 = root.get_visible_rect().size / camera.get_zoom_level()
	_check(
		fully_zoomed_view.x >= 1440.0 and fully_zoomed_view.y >= 1512.0,
		"Maximum zoom-out fits the complete platform and its depth"
	)

	camera.set_zoom_level(1.0, true)
	camera.set_target_position(Vector2(-1000.0, -1000.0), true)
	var half_view: Vector2 = root.get_visible_rect().size * 0.5
	var expected_minimum: Vector2 = camera.world_bounds.position + half_view
	_check(
		camera.global_position.is_equal_approx(expected_minimum),
		"Camera cannot pan beyond the top-left map boundary"
	)

	camera.set_target_position(Vector2(5000.0, 5000.0), true)
	var expected_maximum: Vector2 = camera.world_bounds.end - half_view
	_check(
		camera.global_position.is_equal_approx(expected_maximum),
		"Camera cannot pan beyond the bottom-right map boundary"
	)

	camera.queue_free()
	if _failures == 0:
		print("Camera tests passed.")
	quit(_failures)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
		return

	_failures += 1
	push_error("FAIL: %s" % description)
