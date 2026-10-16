# npc.gd
class_name Npc
extends CharacterBody3D

# Default behaviour:
#   1. look for a nearby fire
#   2. check inventory for something that can put it out
#   3. if nothing usable, find one in the environment and pick it up
#   4. go to the fire and use it
enum State { IDLE, FETCHING_ITEM, MOVING_TO_FIRE, EXTINGUISHING }

@export var move_speed := 4.0
@export var sight_range := 25.0          # how far it notices fires
@export var item_search_range := 40.0    # how far it looks for tools
@export var pickup_range := 1.2
@export var scan_interval := 0.4
@export var retry_delay := 2.0           # wait before retrying when no tool exists
@export var gravity := 20.0
@export var inventory: Array[ExtinguishTool] = []

@onready var nav: NavigationAgent3D = $NavigationAgent3D

var state := State.IDLE
var target_fire: Node3D
var target_item: ExtinguisherPickup
var current_tool: ExtinguishTool
var _scan_timer := 0.0

func _ready() -> void:
	# Duplicate so NPCs sharing one .tres don't share ammo
	var own: Array[ExtinguishTool] = []
	for t in inventory:
		own.append(t.duplicate())
	inventory = own

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	match state:
		State.IDLE:
			_scan_timer -= delta
			if _scan_timer <= 0.0:
				_scan_timer = scan_interval
				_look_for_fire()
			_stop_horizontal()
		State.FETCHING_ITEM:
			_process_fetching()
		State.MOVING_TO_FIRE:
			_process_moving_to_fire()
		State.EXTINGUISHING:
			_process_extinguishing(delta)

	move_and_slide()

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
		_plan()

# --- 2 & 3. Decide: use inventory, or go get something ---

func _plan() -> void:
	_release_item()
	_drop_empty_tools()

	current_tool = _pick_tool()
	if current_tool:
		state = State.MOVING_TO_FIRE
		return

	var item := _find_item()
	if item:
		target_item = item
		item.claimed_by = self
		state = State.FETCHING_ITEM
	else:
		_go_idle(retry_delay)  # nothing to fight with, try again later

func _pick_tool() -> ExtinguishTool:
	var best: ExtinguishTool = null
	for t in inventory:
		if t.is_usable() and (best == null or t.power > best.power):
			best = t
	return best

func _drop_empty_tools() -> void:
	for i in range(inventory.size() - 1, -1, -1):
		if not inventory[i].is_usable():
			inventory.remove_at(i)

func _find_item() -> ExtinguisherPickup:
	var best: ExtinguisherPickup = null
	var best_dist := item_search_range
	for n in get_tree().get_nodes_in_group("extinguisher_items"):
		var item := n as ExtinguisherPickup
		if item == null or not item.is_available_to(self):
			continue
		var d := global_position.distance_to(item.global_position)
		if d < best_dist:
			best_dist = d
			best = item
	return best

# --- Fetch item from the environment ---

func _process_fetching() -> void:
	if not _fire_valid():
		_go_idle()
		return
	if not is_instance_valid(target_item) or not target_item.is_available_to(self):
		_plan()  # item was taken or vanished, find another
		return

	if _flat_distance_to(target_item) <= pickup_range:
		inventory.append(target_item.take())
		target_item = null
		_plan()  # now we have a tool, this heads to the fire
		return

	_move_toward(target_item.global_position)

# --- Go to fire ---

func _process_moving_to_fire() -> void:
	if not _fire_valid():
		_go_idle()
		return
	if _flat_distance_to(target_fire) <= current_tool.reach:
		state = State.EXTINGUISHING
		_stop_horizontal()
		return
	_move_toward(target_fire.global_position)

# --- Use tool ---

func _process_extinguishing(delta: float) -> void:
	_stop_horizontal()
	if not _fire_valid():
		_go_idle()
		return

	if not current_tool.is_usable():
		_plan()  # swap to another tool, or fetch a new one
		return
	if _flat_distance_to(target_fire) > current_tool.reach * 1.2:
		state = State.MOVING_TO_FIRE
		return

	_face(target_fire.global_position)
	target_fire.extinguish(current_tool.use(delta))

# --- Helpers ---

func _fire_valid() -> bool:
	return is_instance_valid(target_fire) and target_fire.is_in_group("fires")

func _go_idle(delay := 0.0) -> void:
	_release_item()
	target_fire = null
	current_tool = null
	state = State.IDLE
	_scan_timer = delay

func _release_item() -> void:
	if is_instance_valid(target_item) and target_item.claimed_by == self:
		target_item.claimed_by = null
	target_item = null

func _move_toward(pos: Vector3) -> void:
	nav.target_position = pos
	var dir := nav.get_next_path_position() - global_position
	dir.y = 0.0
	dir = dir.normalized()
	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed
	_face(pos)

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
