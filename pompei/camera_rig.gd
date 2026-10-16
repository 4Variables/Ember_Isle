
extends Node3D

@export_group("Movement")
@export var move_speed: float = 20.0
@export var use_arrow_keys: bool = false
@export var edge_scroll: bool = true
@export var edge_margin: float = 20.0
@export var map_limit: Vector2 = Vector2(50.0, 50.0)
@export var movement_smoothing: float = 12.0

@export_group("Orbit")
@export_range(0.0, 360.0) var yaw_degrees: float = 45.0
@export_range(20.0, 100.0) var pitch_degrees: float = 55.0
@export var min_pitch: float = 25.0
@export var max_pitch: float = 85.0
@export var rotate_speed: float = 0.3
@export var key_rotate_speed: float = 90.0
@export var orbit_smoothing: float = 12.0

@export_group("Zoom")
@export var zoom_step: float = 3.0
@export var min_zoom: float = 8.0
@export var max_zoom: float = 100.0
@export var zoom_smoothing: float = 10.0
@export var zoom_reference: float = 20.0

@onready var camera: Camera3D = $Camera3D

var _yaw: float
var _pitch: float
var _zoom: float

var _target_yaw: float
var _target_pitch: float
var _target_zoom: float

var _target_position: Vector3
var _orbiting: bool = false


func _ready() -> void:
	_yaw = deg_to_rad(yaw_degrees)
	_pitch = deg_to_rad(
		clampf(pitch_degrees, min_pitch, max_pitch)
	)

	_target_yaw = _yaw
	_target_pitch = _pitch

	_zoom = _current_zoom()
	_zoom = clampf(_zoom, min_zoom, max_zoom)
	_target_zoom = _zoom

	_target_position = global_position

	_apply_camera()


func _process(delta: float) -> void:
	_handle_movement(delta)
	_handle_key_rotation(delta)

	# Smooth camera movement.
	var move_t := 1.0 - exp(-movement_smoothing * delta)
	var orbit_t := 1.0 - exp(-orbit_smoothing * delta)
	var zoom_t := 1.0 - exp(-zoom_smoothing * delta)

	global_position = global_position.lerp(
		_target_position, move_t
	)

	_yaw = lerp_angle(_yaw, _target_yaw, orbit_t)
	_pitch = lerpf(_pitch, _target_pitch, orbit_t)
	_zoom = lerpf(_zoom, _target_zoom, zoom_t)

	_apply_camera()


# --------------------------------------------------
# CAMERA
# --------------------------------------------------

func _apply_camera() -> void:
	rotation.y = _yaw

	var distance: float = _zoom
	if camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		distance = 60.0

	camera.position = Vector3(
		0.0,
		sin(_pitch) * distance,
		cos(_pitch) * distance
	)

	camera.rotation = Vector3(-_pitch, 0.0, 0.0)

	if camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		camera.size = _zoom

	camera.far = maxf(camera.far, 500.0)


func _current_zoom() -> float:
	if camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		return camera.size

	return 20.0


# --------------------------------------------------
# MOVEMENT: WASD + OPTIONAL ARROWS + EDGE SCROLL
# --------------------------------------------------

func _handle_movement(delta: float) -> void:
	var dir := Vector2.ZERO

	if Input.is_physical_key_pressed(KEY_W):
		dir.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		dir.y += 1.0
	if Input.is_physical_key_pressed(KEY_A):
		dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		dir.x += 1.0

	if use_arrow_keys:
		if Input.is_physical_key_pressed(KEY_UP):
			dir.y -= 1.0
		if Input.is_physical_key_pressed(KEY_DOWN):
			dir.y += 1.0
		if Input.is_physical_key_pressed(KEY_LEFT):
			dir.x -= 1.0
		if Input.is_physical_key_pressed(KEY_RIGHT):
			dir.x += 1.0

	# Mouse-edge scrolling.
	if edge_scroll and get_window().has_focus():
		var mouse := get_viewport().get_mouse_position()
		var viewport_size := get_viewport().get_visible_rect().size
		var bounds := Rect2(Vector2.ZERO, viewport_size)

		if bounds.has_point(mouse):
			if mouse.x <= edge_margin:
				dir.x -= 1.0
			elif mouse.x >= viewport_size.x - edge_margin:
				dir.x += 1.0

			if mouse.y <= edge_margin:
				dir.y -= 1.0
			elif mouse.y >= viewport_size.y - edge_margin:
				dir.y += 1.0

	if dir.is_zero_approx():
		return

	dir = dir.normalized()

	# Move relative to the camera's yaw, not the world axes.
	var forward := Vector3(
		-sin(_yaw), 0.0, -cos(_yaw)
	)
	var right := Vector3(
		cos(_yaw), 0.0, -sin(_yaw)
	)

	var move_direction := (
		right * dir.x + forward * -dir.y
	).normalized()

	# Move faster when zoomed out, slower when zoomed in.
	var zoom_factor := _target_zoom / zoom_reference

	_target_position += (
		move_direction
		* move_speed
		* zoom_factor
		* delta
	)

	# Keep the rig inside the playable map.
	_target_position.x = clampf(
		_target_position.x,
		-map_limit.x,
		map_limit.x
	)

	_target_position.z = clampf(
		_target_position.z,
		-map_limit.y,
		map_limit.y
	)


# --------------------------------------------------
# ROTATION: Q / E
# --------------------------------------------------

func _handle_key_rotation(delta: float) -> void:
	var rotation_input := 0.0

	if Input.is_physical_key_pressed(KEY_Q):
		rotation_input += 1.0

	if Input.is_physical_key_pressed(KEY_E):
		rotation_input -= 1.0

	_target_yaw += deg_to_rad(
		key_rotate_speed * rotation_input * delta
	)


# --------------------------------------------------
# MOUSE: WHEEL ZOOM + MIDDLE-MOUSE ORBIT
# --------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					_target_zoom = clampf(
						_target_zoom - zoom_step,
						min_zoom,
						max_zoom
					)

			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					_target_zoom = clampf(
						_target_zoom + zoom_step,
						min_zoom,
						max_zoom
					)

			MOUSE_BUTTON_MIDDLE:
				_orbiting = event.pressed

	elif event is InputEventMouseMotion and _orbiting:
		_target_yaw -= (
			event.relative.x * deg_to_rad(rotate_speed)
		)

		_target_pitch = clampf(
			_target_pitch
			+ event.relative.y * deg_to_rad(rotate_speed),
			deg_to_rad(min_pitch),
			deg_to_rad(max_pitch)
		)
