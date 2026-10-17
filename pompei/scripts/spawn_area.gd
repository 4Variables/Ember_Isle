# spawn_area.gd
# Drop this in a building/room/street. Name it via area_name ("hospital", "lobby"...).
class_name SpawnArea
extends Marker3D

@export var area_name: StringName = &"default"
@export var radius := 2.0                # NPCs spawn randomly inside this circle
@export var snap_to_navmesh := true

func _ready() -> void:
	add_to_group("spawn_areas")

func get_spawn_position() -> Vector3:
	var angle := randf() * TAU
	var dist := sqrt(randf()) * radius   # sqrt = uniform spread over the disc
	var pos := global_position + Vector3(cos(angle), 0.0, sin(angle)) * dist
	if snap_to_navmesh:
		var map := get_world_3d().navigation_map
		if NavigationServer3D.map_get_iteration_id(map) > 0:
			pos = NavigationServer3D.map_get_closest_point(map, pos)
	return pos

func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray(["Give this area a unique area_name."]) if area_name == &"default" else PackedStringArray()
