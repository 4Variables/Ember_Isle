# npc_spawn_entry.gd
# One line of the spawn plan: "put N of this NPC in that area".
class_name NpcSpawnEntry
extends Resource

@export var npc_scene: PackedScene
@export var area_name: StringName = &"default"   # must match a SpawnArea.area_name
@export_range(1, 50) var count := 1
@export var npc_name := "Npc"                     # nodes become Npc_1, Npc_2...
@export var move_speed_override := 0.0            # 0 = use the scene's default
