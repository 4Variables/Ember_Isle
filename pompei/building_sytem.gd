class_name BuildingSystem
extends Node3D
## Valheim-style building: B toggles build mode, Tab / 1-9 pick a piece,
## Q / E rotate, Left Click places, Right Click / Esc leaves build mode.
## Add this node to your level and fill in `pieces`.

signal mode_changed(active: bool)
signal piece_placed(piece: Node3D, data: BuildPieceData)

@export var pieces: Array[BuildPieceData] = []

@export_group("Physics layers")
## What the mouse ray can land on. Add your "buildings" layer here to allow stacking.
@export_flags_3d_physics var ground_mask := 1
## What blocks placement (buildings, NPCs, trees...). Do NOT include the terrain layer.
@export_flags_3d_physics var blocking_mask := 2 | 4

@export_group("Behaviour")
@export var max_distance := 200.0
@export var snap_radius := 0.6                 # how close two snap points must be to snap
@export var snap_search_radius := 8.0          # only consider pieces this close
@export var valid_color := Color(0.2, 1.0, 0.3, 0.45)
@export var invalid_color := Color(1.0, 0.2, 0.2, 0.45)

@export_group("Navigation")
## Optional: rebaked (debounced) after each placement so NPCs path around new walls.
@export var navigation_region: NavigationRegion3D

var active := false          # other scripts (selection, move commands) should check this
var index := 0

var _ghost: Node3D
var _ghost_mat: StandardMaterial3D
var _yaw := 0.0
var _can_place := false
var _last_valid := false
var _shape := BoxShape3D.new()
var _rebake_timer: Timer


func _ready() -> void:
	_ghost_mat = StandardMaterial3D.new()
	_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_mat.albedo_color = valid_color

	_rebake_timer = Timer.new()
	_rebake_timer.one_shot = true
	_rebake_timer.wait_time = 0.5
	_rebake_timer.timeout.connect(_do_rebake)
	add_child(_rebake_timer)


# --- Public API ---

func set_active(value: bool) -> void:
	if value == active:
		return
	if value and pieces.is_empty():
		push_warning("BuildingSystem: no pieces assigned.")
		return
	active = value
	if active:
		_rebuild_ghost()
	else:
		_clear_ghost()
	mode_changed.emit(active)


func select_piece(i: int) -> void:
	if pieces.is_empty():
		return
	index = wrapi(i, 0, pieces.size())
	if active:
		_rebuild_ghost()


# --- Input ---

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_B:
			set_active(not active)
			get_viewport().set_input_as_handled()
			return
		if not active:
			return
		match event.keycode:
			KEY_ESCAPE:
				set_active(false)
			KEY_TAB:
				select_piece(index + 1)
			KEY_Q:
				_rotate(-1)
			KEY_E:
				_rotate(1)
			_:
				# number keys 1-9
				if event.keycode >= KEY_1 and event.keycode <= KEY_9:
					select_piece(event.keycode - KEY_1)
				else:
					return
		get_viewport().set_input_as_handled()

	elif active and event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_try_place()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			set_active(false)
			get_viewport().set_input_as_handled()


func _rotate(dir: int) -> void:
	_yaw += deg_to_rad(pieces[index].rotation_step_deg) * dir


# --- Ghost ---

func _rebuild_ghost() -> void:
	_clear_ghost()
	var data := pieces[index]
	if data.scene == null:
		return
	_shape.size = data.footprint

	_ghost = data.scene.instantiate() as Node3D
	_ghost.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(_ghost)

	var nodes: Array[Node] = [_ghost]
	nodes.append_array(_ghost.find_children("*", "", true, false))
	for n in nodes:
		if n is CollisionObject3D:
			n.collision_layer = 0
			n.collision_mask = 0
		if n is GeometryInstance3D:
			n.material_override = _ghost_mat
			n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_last_valid = true
	_set_ghost_valid(false)


func _clear_ghost() -> void:
	if is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = null


func _set_ghost_valid(valid: bool) -> void:
	if valid == _last_valid:
		return
	_last_valid = valid
	_ghost_mat.albedo_color = valid_color if valid else invalid_color


func _process(_delta: float) -> void:
	if not active or not is_instance_valid(_ghost):
		return
	_update_ghost()


func _update_ghost() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var data := pieces[index]
	var mouse := get_viewport().get_mouse_position()
	var from := cam.project_ray_origin(mouse)
	var to := from + cam.project_ray_normal(mouse) * max_distance

	var query := PhysicsRayQueryParameters3D.create(from, to, ground_mask)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		_ghost.visible = false
		_can_place = false
		return

	_ghost.visible = true
	var pos: Vector3 = hit.position
	if data.grid_size > 0.0:
		pos.x = snappedf(pos.x, data.grid_size)
		pos.z = snappedf(pos.z, data.grid_size)

	_ghost.global_transform = Transform3D(Basis(Vector3.UP, _yaw), pos)

	if data.snap_to_other_pieces:
		_apply_piece_snap()

	_can_place = _is_valid(data, hit.normal)
	_set_ghost_valid(_can_place)


# --- Snapping (ghost "Snap*" Marker3Ds jump to nearby placed pieces' Marker3Ds) ---

func _snap_points(root: Node) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for n in root.find_children("Snap*", "Marker3D", true, false):
		out.append(n as Node3D)
	return out


func _apply_piece_snap() -> void:
	var ghost_points := _snap_points(_ghost)
	if ghost_points.is_empty():
		return

	var best_offset := Vector3.ZERO
	var best_dist := snap_radius
	var found := false

	for piece in get_tree().get_nodes_in_group("build_pieces"):
		if piece.global_position.distance_to(_ghost.global_position) > snap_search_radius:
			continue
		for other in _snap_points(piece):
			for mine in ghost_points:
				var offset := other.global_position - mine.global_position
				var d := offset.length()
				if d < best_dist:
					best_dist = d
					best_offset = offset
					found = true

	if found:
		_ghost.global_position += best_offset


# --- Validity ---

func _is_valid(data: BuildPieceData, ground_normal: Vector3) -> bool:
	# Slope
	var slope := rad_to_deg(ground_normal.angle_to(Vector3.UP))
	if slope > data.max_slope_deg:
		return false

	# Anything in the way?
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = _shape
	params.transform = _ghost.global_transform * Transform3D(Basis(), data.footprint_offset)
	params.collision_mask = blocking_mask
	params.collide_with_bodies = true
	params.collide_with_areas = false
	return get_world_3d().direct_space_state.intersect_shape(params, 1).is_empty()


# --- Placing ---

func _try_place() -> void:
	if not _can_place or not is_instance_valid(_ghost) or not _ghost.visible:
		return
	var data := pieces[index]
	var piece := data.scene.instantiate() as Node3D
	get_tree().current_scene.add_child(piece)
	piece.global_transform = _ghost.global_transform
	piece.add_to_group("build_pieces")
	piece_placed.emit(piece, data)

	if navigation_region:
		_rebake_timer.start()   # restarts if you're placing quickly

	_can_place = false          # re-evaluated next frame (new piece now blocks this spot)


func _do_rebake() -> void:
	if navigation_region:
		navigation_region.bake_navigation_mesh()   # threaded by default
