extends Node3D

@export_flags_3d_physics var ground_collision_mask: int = 1
@export_flags_3d_physics var player_collision_mask: int = 3
@export_flags_3d_physics var item_collision_mask: int = 6
@export_flags_3d_physics var tree_collision_mask: int = 2

@export var inventory_key: Key = KEY_I

@onready var camera_3d: Camera3D = $"../rig/Camera3D"
@onready var selection_box: Control = $"../SelectionUI/SelectionBox"
@onready var inventory_hud: InventoryHandler = $"../InventoryHUD/InventoryUI"
@onready var prompt: Label = $"../PromptUI/Label"
@onready var building: BuildingSystem = $"../BuildingSystem"

const DRAG_THRESHOLD := 8.0

var selected_players: Array[CharacterBody3D] = []
var drag_start := Vector2.ZERO
var dragging := false
var pressed_in_world := false     # presses that start on UI never reach _unhandled_input
var inventory_open := false


# --- Input ---

func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(building) and building.active:
		return
	if event.is_action_pressed("Interact"):
		interact_with_nearby()
		return
		
	if event is InputEventKey:
		if event.pressed and not event.echo and event.keycode == inventory_key:
			toggle_inventory()
		return

	if event is InputEventMouseButton:
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		if event.pressed:
			_begin_press(event.position)
		else:
			_end_press(event.position)

	elif event is InputEventMouseMotion:
		_update_drag(event.position)


func _begin_press(pos: Vector2) -> void:
	drag_start = pos
	dragging = false
	pressed_in_world = true


func _end_press(pos: Vector2) -> void:
	if not pressed_in_world:
		return
	pressed_in_world = false

	if dragging:
		select_players_in_box(drag_start, pos)
	else:
		handle_click(pos)

	dragging = false
	selection_box.visible = false


func _update_drag(pos: Vector2) -> void:
	if not pressed_in_world or not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return
	if drag_start.distance_to(pos) > DRAG_THRESHOLD:
		dragging = true
	if dragging:
		selection_box.visible = true
		selection_box.update_box(drag_start, pos)


# --- Click handling ---

func handle_click(mouse_pos: Vector2) -> void:
	var player := get_player_at(mouse_pos)
	if player != null:
		if player in selected_players:
			selected_players.erase(player)
			player.set_selected(false)
		else:
			clear_selection()
			add_player(player)
		_on_selection_changed()
		return

	var item := get_item_at(mouse_pos)
	if item != null:
		for p in selected_players:
			p.pick_up(item)
		return
	
	var tree := get_tree_at(mouse_pos)          # <-- add
	if tree != null:
		for p in selected_players:
			p.chop_tree(tree)
		return
		
	var target = get_ground_position(mouse_pos)
	if target != null:
		for p in selected_players:
			p.move_to(target)


# --- Raycasts ---

func _raycast(mouse_pos: Vector2, mask: int) -> Dictionary:
	var origin := camera_3d.project_ray_origin(mouse_pos)
	var direction := camera_3d.project_ray_normal(mouse_pos)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 1000.0)
	query.collision_mask = mask
	return get_world_3d().direct_space_state.intersect_ray(query)


func get_player_at(mouse_pos: Vector2) -> CharacterBody3D:
	var result := _raycast(mouse_pos, player_collision_mask)
	if result.is_empty():
		return null

	# Walk upward in case the hit collider belongs to a child node.
	var node: Node = result["collider"]
	while node != null:
		if node is CharacterBody3D and node.is_in_group("selectable"):
			return node as CharacterBody3D
		node = node.get_parent()
	return null


func get_item_at(mouse_pos: Vector2) -> InteractableItem:
	var result := _raycast(mouse_pos, item_collision_mask)
	if result.is_empty():
		return null
	return result["collider"] as InteractableItem


func get_ground_position(mouse_pos: Vector2) -> Variant:
	var result := _raycast(mouse_pos, ground_collision_mask)
	if result.is_empty():
		return null
	return result["position"]


# --- Selection ---

func select_players_in_box(start: Vector2, finish: Vector2) -> void:
	clear_selection()
	var rect := Rect2(start, finish - start).abs()

	for node in get_tree().get_nodes_in_group("selectable"):
		var player := node as CharacterBody3D
		if player == null or camera_3d.is_position_behind(player.global_position):
			continue
		if rect.has_point(camera_3d.unproject_position(player.global_position)):
			add_player(player)

	_on_selection_changed()


func add_player(player: CharacterBody3D) -> void:
	if player in selected_players:
		return
	selected_players.append(player)
	player.set_selected(true)


func clear_selection() -> void:
	for player in selected_players:
		if is_instance_valid(player):
			player.set_selected(false)
	selected_players.clear()


func _on_selection_changed() -> void:
	# Selection never opens the inventory. It only keeps an open one in sync.
	if inventory_open:
		_refresh_inventory()


# --- Inventory ---

func toggle_inventory() -> void:
	inventory_open = not inventory_open
	_refresh_inventory()


func _refresh_inventory() -> void:
	# Drop NPCs that were freed (e.g. died) while selected
	selected_players = selected_players.filter(func(p): return is_instance_valid(p))

	if inventory_open and selected_players.size() == 1:
		inventory_hud.ShowInventory(selected_players[0].inventory)
	else:
		inventory_hud.ShowInventory(null)

func get_tree_at(mouse_pos: Vector2) -> ChoppableTree:
	var result := _raycast(mouse_pos, tree_collision_mask)
	if result.is_empty():
		return null

	# Walk upward in case the hit collider is a child of the tree root.
	var node: Node = result["collider"]
	while node != null:
		if node is ChoppableTree:
			return node as ChoppableTree
		node = node.get_parent()
	return null

func _process(_delta: float) -> void:
	_update_prompt()
func _update_prompt() -> void:
	var nearby := _get_nearby_interactable()
	if nearby != null:
		prompt.show_for(nearby, "[%s] %s" % [_interact_key_name(), nearby.interact_prompt])
	else:
		prompt.hide_prompt()
func _get_nearby_interactable() -> Node3D:
	var best: Node3D = null
	var best_distance := INF
	for citizen in selected_players:
		if not is_instance_valid(citizen):
			continue
		var candidate = citizen.interaction_area.GetNearestInteractable()
		if candidate == null:
			continue
		var distance = candidate.global_position.distance_to(citizen.global_position)
		if distance < best_distance:
			best = candidate
			best_distance = distance
	return best
func interact_with_nearby() -> void:
	for citizen in selected_players:
		if not is_instance_valid(citizen):
			continue
		var target = citizen.interaction_area.GetNearestInteractable()
		if target != null:
			citizen.interact(target)
func _interact_key_name() -> String:
	var events := InputMap.action_get_events("Interact")
	return events[0].as_text_physical_keycode() if not events.is_empty() else "E"
