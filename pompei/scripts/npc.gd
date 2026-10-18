class_name Npc
extends CharacterBody3D

enum State { IDLE, MOVING_TO_FIRE, EXTINGUISHING, COMMANDED , MOVING_TO_TREE, CHOPPING}

signal movement_completed(citizen: CharacterBody3D)
signal poison_changed(value: float, max_value: float)

@export var chop_reach := 2.5
@export var chop_power := 1.0            # chop() amount per second
@export var auto_continue_chopping := true  # look for the next tree when one is felled

# --- Equipment ---
var equipment := {}   # EquipmentData.Slot -> EquipmentData
# --- Poison ---
@export var poison_rate := 2.0            # poison gained per second with no protection
@export var poison_recovery_rate := 5.0   # poison lost per second when fully protected
@export var max_poison := 100.0
@export var poison_threshold := 50.0      # above this, health starts dropping
@export var poison_damage_per_sec := 3.0

var poison := 0.0

var target_tree: ChoppableTree

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

@export var wood_item: ItemData

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
	target_fire = null
	target_tree = null
	state = State.COMMANDED
	navigation_agent_3d.target_position = target
	if show_marker:
		_show_move_marker	(target)
	else:
		_hide_move_marker()

func interact(target: Node3D) -> void:
	if target is InteractableItem:
		interaction_area.TryPickup(target as InteractableItem)


func pick_up(item: InteractableItem) -> void:
	move_to(item.global_position)
	interaction_area.SetPickupTarget(item)

# Health.
func take_damage(amount: float) -> void:
	health -= amount
	if health <= 0.0:
		queue_free()   # replace with a death animation later
		
var _print_timer := 0.0

# Returns false if there was nothing to treat, so the item isn't used up.
func recover(health_amount: float, poison_amount := 0.0) -> bool:
	var old_health := health
	var old_poison := poison
	health = minf(health + health_amount, max_health)
	poison = maxf(poison - poison_amount, 0.0)
	if health == old_health and poison == old_poison:
		return false
	poison_changed.emit(poison, max_poison)
	return true

# Main Loop
func _physics_process(delta: float) -> void:
	_process_poison(delta)
	if not is_inside_tree():
		return   # died from poison this frame
	
	_print_timer -= delta
	if _print_timer <= 0.0:
		_print_timer = 1.0   # once per second
		print("[%s] Health: %.1f | Poison: %.1f" % [name, health, poison])
		
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
		State.MOVING_TO_TREE:
			_process_moving_to_tree()
		State.CHOPPING:
			_process_chopping(delta)

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

# --- Chopping ---

func _process_moving_to_tree() -> void:
	if not _tree_valid():
		_on_tree_gone()
		return
	if _flat_distance_to(target_tree) <= chop_reach:
		state = State.CHOPPING
		_stop_horizontal()
		return
	navigation_agent_3d.target_position = target_tree.global_position
	# Gave up: path ended but we're still out of reach (tree unreachable)
	if navigation_agent_3d.is_navigation_finished():
		_stop_horizontal()
		target_tree = null
		state = State.IDLE
		return
	_steer_toward(navigation_agent_3d.get_next_path_position())

func _has_free_slot() -> bool:
	return inventory.Items.has(null)
	
func _process_chopping(delta: float) -> void:
	_stop_horizontal()
	if not _tree_valid():
		_on_tree_gone()
		return
	if _flat_distance_to(target_tree) > chop_reach * 1.2:
		state = State.MOVING_TO_TREE
		return
	
	if not _has_free_slot():
		_on_inventory_full()
		return
			
	_face(target_tree.global_position)
	var wood := target_tree.chop(chop_power * delta)
	for i in wood:
		if not inventory.AddItem(wood_item):
			_on_inventory_full()
			break


func _tree_valid() -> bool:
	return is_instance_valid(target_tree) and target_tree.is_in_group("trees")

func _on_tree_gone() -> void:
	var next := _find_nearest_tree() if auto_continue_chopping else null
	if next:
		target_tree = next
		state = State.MOVING_TO_TREE
	else:
		target_tree = null
		state = State.IDLE
		_scan_timer = 0.0

func _find_nearest_tree() -> ChoppableTree:
	var best: ChoppableTree = null
	var best_dist := sight_range
	for t in get_tree().get_nodes_in_group("trees"):
		var d := global_position.distance_to(t.global_position)
		if d < best_dist:
			best_dist = d
			best = t
	return best
	
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

func chop_tree(tree: ChoppableTree) -> void:
	interaction_area.PickupTarget = null
	target_fire = null
	_hide_move_marker()
	target_tree = tree
	state = State.MOVING_TO_TREE

func _on_inventory_full() -> void:
	print("[%s] inventory full" % name)
	target_tree = null
	state = State.IDLE

# --- Equipment ---
func equip(item: EquipmentData) -> bool:
	var old: EquipmentData = equipment.get(item.slot)
	if old:
		if not inventory.AddItem(old):   # no room to swap out the old item
			return false
	equipment[item.slot] = item
	return true

func unequip(slot: EquipmentData.Slot) -> bool:
	var old: EquipmentData = equipment.get(slot)
	if not old:
		return false
	if not inventory.AddItem(old):
		return false
	equipment.erase(slot)
	return true

func get_poison_resistance() -> float:
	var total := 0.0
	for slot in equipment:
		total += equipment[slot].poison_resistance
	return clampf(total, 0.0, 1.0)

# --- Poison ---

func _process_poison(delta: float) -> void:
	var resistance := get_poison_resistance()

	if resistance < 1.0:
		poison += poison_rate * (1.0 - resistance) * delta
	else:
		poison -= poison_recovery_rate * delta
	poison = clampf(poison, 0.0, max_poison)
	poison_changed.emit(poison, max_poison)

	if poison > poison_threshold:
		# Damage scales from 0 at the threshold to full at max poison
		var severity := (poison - poison_threshold) / (max_poison - poison_threshold)
		take_damage(poison_damage_per_sec * severity * delta)
