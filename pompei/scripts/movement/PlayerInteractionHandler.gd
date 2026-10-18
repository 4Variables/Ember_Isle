class_name InteractionArea
extends Area3D

@export var ItemTypes : Array[ItemData] = []
@export var Inventory : CitizenInventory

var PickupTarget : InteractableItem = null

func _ready() -> void:
	# Assumes this node is a direct child of the Npc
	var npc := get_parent() as Npc
	if npc:
		npc.movement_completed.connect(_on_movement_completed)

func SetPickupTarget(item : InteractableItem) -> void:
	PickupTarget = item

func _on_movement_completed(_npc) -> void:
	var item := PickupTarget
	PickupTarget = null
	if item == null or not is_instance_valid(item):
		return   # a normal move, not a pickup
	TryPickup(item)

func TryPickup(item : InteractableItem):
	if item.is_queued_for_deletion():
		return
	for type in ItemTypes:
		if type.ItemModelPrefab != null and type.ItemModelPrefab.resource_path == item.scene_file_path:
			if Inventory.AddItem(type):
				item.queue_free()
			return
	printerr("Item not found")

func GetNearestInteractable() -> Node3D:
	var nearest : Node3D = null
	var nearestDistance : float = INF
	for body in get_overlapping_bodies():
		if not (body is InteractableItem):
			continue
		if body.is_queued_for_deletion():
			continue
		var distance = body.global_position.distance_to(global_position)
		if distance < nearestDistance:
			nearestDistance = distance
			nearest = body
	return nearest
