extends Area3D

@export var ItemTypes : Array[ItemData] = []
@export var Inventory : CitizenInventory

var NearbyBodies : Array[InteractableItem]
var PickupTarget : InteractableItem = null

func _ready() -> void:
	body_entered.connect(OnObjectEnteredArea)
	body_exited.connect(OnObjectExitedArea)

func SetPickupTarget(item : InteractableItem):
	PickupTarget = item
	if item != null and NearbyBodies.has(item):
		TryPickup(item)

func TryPickup(item : InteractableItem):
	PickupTarget = null
	if item.is_queued_for_deletion():
		return
	for type in ItemTypes:
		if type.ItemModelPrefab != null and type.ItemModelPrefab.resource_path == item.scene_file_path:
			if Inventory.AddItem(type):
				NearbyBodies.erase(item)
				item.queue_free()
			return
	printerr("Item not found")

func OnObjectEnteredArea(body: Node3D):
	if (body is InteractableItem):
		body.GainFocus()
		NearbyBodies.append(body)
		if body == PickupTarget:
			TryPickup(body)

func OnObjectExitedArea(body: Node3D):
	if (body is InteractableItem and NearbyBodies.has(body)):
		body.LoseFocus()
		NearbyBodies.erase(body)
