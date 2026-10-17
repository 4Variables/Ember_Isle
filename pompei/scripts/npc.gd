class_name Npc
extends CharacterBody3D

enum State { IDLE, MOVING_TO_FIRE, EXTINGUISHING, COMMANDED }

signal movement_completed(citizen: CharacterBody3D)

@export var move_speed := 8.0
@export var stop_distance := 0.2         # how close counts as "arrived" for commands
@export var sight_range := 25.0          # how far it notices fires
@export var reach := 2.0                 # how close it must be to extinguish
@export var extinguish_power := 1.0      # passed to fire.extinguish() per second
@export var scan_interval := 0.4
@export var gravity := 20.0
@export var max_health := 100.0
@export var auto_extinguish := true      # set false to disable the fire AI
var _move_marker: MeshInstance3D
var _marker_tween: Tween

@export var ring_radius := 0.6
@export var ring_thickness := 0.06
@export var ring_height := -0.9          # local Y of the NPC's feet (see note below)
@export var ring_color := Color(0.3, 0.8, 1.0, 0.9)
var _selection_ring: MeshInstance3D

@onready var navigation_agent_3d: NavigationAgent3D = $NavigationAgent3D
@onready var interaction_area: Area3D = $InteractionArea
@onready var inventory: CitizenInventory = $Inventory

var health := 0.0
var state := State.IDLE
var target_fire: Node3D
var _scan_timer := 0.0

func _ready() -> void:
	health = max_health
	add_to_group("selectable")
	navigation_agent_3d.target_desired_distance = stop_distance
	_create_selection_ring()
	_create_move_marker()
	#print("[%s] ready at %s" % [name, global_position])

func _create_move_marker() -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = 0.35
	ring.outer_radius = 0.5

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.2, 1.0, 0.4, 0.85)

	_move_marker = MeshInstance3D.new()
	_move_marker.mesh = ring
	_move_marker.material_override = mat
	_move_marker.top_level = true      # don't follow the NPC
	_move_marker.visible = false
	add_child(_move_marker)
	
func _show_move_marker(pos: Vector3) -> void:
	_move_marker.global_position = pos + Vector3.UP * 0.05   # lift slightly to avoid z-fighting
	_move_marker.scale = Vector3(1.0, 0.1, 1.0)               # flatten the torus
	_move_marker.visible = true

	# gentle pulse
	if _marker_tween:
		_marker_tween.kill()
	_marker_tween = create_tween().set_loops()
	_marker_tween.tween_property(_move_marker, "scale", Vector3(1.3, 0.1, 1.3), 0.5)
	_marker_tween.tween_property(_move_marker, "scale", Vector3(1.0, 0.1, 1.0), 0.5)

func _hide_move_marker() -> void:
	if _marker_tween:
		_marker_tween.kill()
	_move_marker.visible = false
	
# Player Specific Commands.
func set_selected(value: bool) -> void:
	_selection_ring.visible = value

func move_to(target: Vector3, show_marker := true) -> void:
	interaction_area.PickupTarget = null
	target_fire = null
	state = State.COMMANDED
	navigation_agent_3d.target_position = target
	if show_marker:
		_show_move_marker(target)
	else:
		_hide_move_marker()


func pick_up(item: InteractableItem) -> void:
	move_to(item.global_position)
	interaction_area.SetPickupTarget(item)

# Health.
func take_damage(amount: float) -> void:
	health -= amount
	print("Health: ", health)
	if health <= 0.0:
		queue_free()   # replace with a death animation later
		
# Main Loop
func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	match state:
		State.IDLE:
			_process_idle(delta)
		State.COMMANDED:
			_process_commanded()
		State.MOVING_TO_FIRE:
			_process_moving_to_fire()
		State.EXTINGUISHING:
			_process_extinguishing(delta)

	move_and_slide()

func _process_idle(delta: float) -> void:
	_stop_horizontal()
	if not auto_extinguish:
		return
	_scan_timer -= delta
	if _scan_timer <= 0.0:
		_scan_timer = scan_interval
		_look_for_fire()

# --- Commanded movement ---
func _process_commanded() -> void:
	if navigation_agent_3d.is_navigation_finished():
		_finish_command()
		return

	var next := navigation_agent_3d.get_next_path_position()
	var flat_next := Vector3(next.x, global_position.y, next.z)
	if global_position.distance_to(flat_next) < 0.05 and navigation_agent_3d.is_target_reached():
		_finish_command()
		return

	_steer_toward(next)

func _finish_command() -> void:
	_stop_horizontal()
	_hide_move_marker()
	state = State.IDLE
	_scan_timer = 0.0
	movement_completed.emit(self)   # emitted once, not every frame

# --- 1. Perceive fire ---
func _look_for_fire() -> void:
	var best: Node3D = null
	var best_dist := sight_range
	for f in get_tree().get_nodes_in_group("fires"):
		var d := global_position.distance_to(f.global_position)
		if d < best_dist:
			best_dist = d
			best = f
	if best:
		target_fire = best
		state = State.MOVING_TO_FIRE

# --- 2. Go to fire ---

func _process_moving_to_fire() -> void:
	if not _fire_valid():
		_go_idle()
		return
	if _flat_distance_to(target_fire) <= reach:
		state = State.EXTINGUISHING
		_stop_horizontal()
		return
	navigation_agent_3d.target_position = target_fire.global_position
	_steer_toward(navigation_agent_3d.get_next_path_position())
	
# --- 3. Put it out ---

func _process_extinguishing(delta: float) -> void:
	_stop_horizontal()
	if not _fire_valid():
		_go_idle()
		return
	if _flat_distance_to(target_fire) > reach * 1.2:
		state = State.MOVING_TO_FIRE
		return

	_face(target_fire.global_position)
	target_fire.extinguish(extinguish_power * delta)

# --- Helpers ---

func _fire_valid() -> bool:
	return is_instance_valid(target_fire) and target_fire.is_in_group("fires")

func _go_idle() -> void:
	target_fire = null
	state = State.IDLE
	_scan_timer = 0.0

func _steer_toward(path_pos: Vector3) -> void:
	var dir := path_pos - global_position
	dir.y = 0.0
	dir = dir.normalized()
	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed
	_face(global_position + dir)

func _flat_distance_to(n: Node3D) -> float:
	var a := global_position
	var b := n.global_position
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))

func _stop_horizontal() -> void:
	velocity.x = move_toward(velocity.x, 0.0, move_speed)
	velocity.z = move_toward(velocity.z, 0.0, move_speed)

func _face(pos: Vector3) -> void:
	var look := Vector3(pos.x, global_position.y, pos.z)
	if look.distance_squared_to(global_position) > 0.01:
		look_at(look, Vector3.UP)

func _create_selection_ring() -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = ring_radius - ring_thickness
	ring.outer_radius = ring_radius + ring_thickness

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = ring_color
	mat.no_depth_test = false

	_selection_ring = MeshInstance3D.new()
	_selection_ring.mesh = ring
	_selection_ring.material_override = mat
	_selection_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_selection_ring.scale = Vector3(1.0, 0.1, 1.0)     # flatten into a disc-like ring
	_selection_ring.position = Vector3(0.0, ring_height, 0.0)
	_selection_ring.visible = false
	add_child(_selection_ring)
