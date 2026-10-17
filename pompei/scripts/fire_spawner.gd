# fire_spawner.gd
extends Node3D

@export var fire_scene: PackedScene
@export_flags_3d_physics var ground_mask := 1

@export_group("Random Spawning")
@export var auto_spawn := true
@export var min_interval := 0.5
@export var max_interval := 0.8
@export var fires_per_burst := 5
@export var max_fires := 40            # cap to protect performance
@export var area_center := Vector3.ZERO
@export var area_size := Vector2(40, 40)  # width (X) and depth (Z)
@export var ray_height := 40.0

@export_group("Click Spawning")
@export var ray_length := 1000.0

@onready var timer: Timer = $Timer

func _ready() -> void:
	timer.one_shot = true
	timer.timeout.connect(_on_timer_timeout)
	if auto_spawn:
		_start_timer()

func _start_timer() -> void:
	timer.start(randf_range(min_interval, max_interval))

func _on_timer_timeout() -> void:
	for i in fires_per_burst:
		if get_tree().get_nodes_in_group("fires").size() >= max_fires:
			break
		_spawn_fire_random()
	_start_timer()  # schedule the next random burst

# --- Random spawning ---

func _spawn_fire_random() -> void:
	var x := randf_range(-area_size.x / 2.0, area_size.x / 2.0)
	var z := randf_range(-area_size.y / 2.0, area_size.y / 2.0)
	var top := area_center + Vector3(x, ray_height, z)
	var bottom := area_center + Vector3(x, -ray_height, z)

	var query := PhysicsRayQueryParameters3D.create(top, bottom, ground_mask)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return  # no ground at this spot, skip it

	_place_fire(hit.position)
# --- Shared ---

func _place_fire(pos: Vector3) -> void:
	var fire := fire_scene.instantiate()
	get_tree().current_scene.add_child(fire)
	fire.global_position = pos
	fire.add_to_group("fires")
