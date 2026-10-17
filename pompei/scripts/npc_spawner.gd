# npc_spawner.gd
class_name NpcSpawner
extends Node

signal npc_spawned(npc: Npc, area: SpawnArea)
signal all_spawned

@export var entries: Array[NpcSpawnEntry] = []
@export var spawn_on_ready := true
@export var spawn_parent: Node               # where NPCs are added; defaults to this node's parent
@export var spawn_height := 0.0              # metres above the ground (or above the area's y if no ground is hit)
@export var snap_to_ground := true           # raycast down to find the ground first
@export_flags_3d_physics var ground_mask := 1

var spawned: Array[Npc] = []

func _ready() -> void:
	if spawn_on_ready:
		# wait so SpawnAreas are in the tree and the navmesh has synced
		await get_tree().physics_frame
		await get_tree().physics_frame
		spawn_all()
	
func spawn_all() -> void:
	var areas := _collect_areas()
	var parent := spawn_parent if spawn_parent else get_parent()
	print("Spawner: %d entries, %d areas %s, parent=%s" % [entries.size(), areas.size(), areas.keys(), parent])
	for entry in entries:
		if entry == null or entry.npc_scene == null:
			push_warning("NpcSpawner: entry missing npc_scene, skipped.")
			continue
		if not areas.has(entry.area_name):
			push_warning("NpcSpawner: no SpawnArea named '%s', skipped." % entry.area_name)
			continue
		print("Entry '%s': count=%d area=%s" % [entry.npc_name, entry.count, entry.area_name])
		var area: SpawnArea = areas[entry.area_name]
		for i in entry.count:
			_spawn_one(entry, area, parent, i + 1)

	all_spawned.emit()

@export var ray_start_height := 3.0      # ray starts this far above the area's y (avoids hitting roofs/trees)
@export var drop_margin := 0.5           # NPC is placed this far above ground, then dropped onto it
var _spawn_counter := 0
func _spawn_one(entry: NpcSpawnEntry, area: SpawnArea, parent: Node, index: int) -> void:
	_spawn_counter += 1

	var npc := entry.npc_scene.instantiate() as Npc
	if npc == null:
		push_error("NpcSpawner: npc_scene root must use npc.gd (class Npc).")
		return

	npc.name = "%s_%s_%d" % [entry.npc_name, entry.area_name, index]
	if entry.move_speed_override > 0.0:
		npc.move_speed = entry.move_speed_override

	parent.add_child(npc)
	npc.global_position = _get_spawn_point(area, npc)
	npc.rotation.y = randf() * TAU

	# Slide the real collision shape down until it touches the ground
	if snap_to_ground:
		var collision := npc.move_and_collide(Vector3.DOWN * (drop_margin + ray_start_height + 1.0))
		if collision:
			print("  dropped %.2fm onto %s" % [collision.get_travel().length(), collision.get_collider()])
		npc.velocity = Vector3.ZERO

	spawned.append(npc)
	npc_spawned.emit(npc, area)
	print("Spawned %s at %s" % [npc.name, npc.global_position])

func _get_spawn_point(area: SpawnArea, npc: Npc) -> Vector3:
	var pos := area.get_spawn_position()
	var ground_y := pos.y

	if snap_to_ground:
		var space := npc.get_world_3d().direct_space_state
		var query := PhysicsRayQueryParameters3D.create(
			pos + Vector3.UP * ray_start_height,
			pos + Vector3.DOWN * 100.0,
			ground_mask)
		query.exclude = [npc.get_rid()]
		var hit := space.intersect_ray(query)
		if hit:
			ground_y = hit.position.y
			print("  ground hit: %s at y=%.2f" % [hit.collider, ground_y])
		else:
			push_warning("NpcSpawner: no ground under %s, using area y." % pos)

	pos.y = ground_y + drop_margin + spawn_height
	return pos
	
func _collect_areas() -> Dictionary:
	var result := {}
	for n in get_tree().get_nodes_in_group("spawn_areas"):
		var a := n as SpawnArea
		if a == null:
			continue
		if result.has(a.area_name):
			push_warning("Duplicate SpawnArea name '%s'; using the first." % a.area_name)
			continue
		result[a.area_name] = a
	return result

func despawn_all() -> void:
	for n in spawned:
		if is_instance_valid(n):
			n.queue_free()
	spawned.clear()
