extends Control
class_name InventoryHandler

@export_flags_3d_physics var CollisionMask : int = 1
 
@export var ItemSlotsCount : int = 8

@export var InventoryGrid : GridContainer
@export var InventorySlotPrefab : PackedScene = preload("res://Inventory/InventorySlot.tscn")

var InventorySlots : Array[InventorySlot] = []

var Target : CitizenInventory = null

func _ready():
	# Pass lets clicks on the map fall through to the selection controller.
	mouse_filter = MOUSE_FILTER_PASS
	visible = false
	for i in ItemSlotsCount:
		var slot = InventorySlotPrefab.instantiate() as InventorySlot
		InventoryGrid.add_child(slot)
		slot.InventorySlotID = i
		slot.OnItemDropped.connect(ItemDroppedOnSlot)
		slot.OnItemEquiped.connect(ItemEquipped)
		InventorySlots.append(slot)

func ShowInventory(inventory : CitizenInventory):
	if Target != null and Target.Changed.is_connected(Refresh):
		Target.Changed.disconnect(Refresh)
	Target = inventory
	visible = Target != null
	if Target != null:
		Target.Changed.connect(Refresh)
		Refresh()

func Refresh():
	for i in InventorySlots.size():
		var item : ItemData = Target.Items[i] if i < Target.Items.size() else null
		InventorySlots[i].FillSlot(item, i == Target.EquippedSlot)

func ItemEquipped(slotID : int):
	Target.ToggleEquip(slotID)

func ItemDroppedOnSlot(fromSlotID : int, toSlotID : int):
	Target.SwapSlots(fromSlotID, toSlotID)

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	return Target != null and typeof(data) == TYPE_DICTIONARY and data["Type"] == "Item"

func _drop_data(at_position: Vector2, data: Variant) -> void:
	var item = Target.RemoveItem(data["ID"])
	if item == null:
		return
	var newItem = item.ItemModelPrefab.instantiate() as Node3D
	get_tree().current_scene.add_child(newItem)
	newItem.global_position = GetWorldMousePosition()

func GetWorldMousePosition() -> Vector3:
	var mousePos = get_viewport().get_mouse_position()
	var cam = get_viewport().get_camera_3d()
	var ray_start = cam.project_ray_origin(mousePos)
	var ray_end = ray_start + cam.project_ray_normal(mousePos) * 1000.0
	var space_state = cam.get_world_3d().direct_space_state
	
	var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end, CollisionMask)
	
	var results = space_state.intersect_ray(query)
	if (results):
		return results["position"] as Vector3 + Vector3(0.0, 0.5, 0.0)
	else:
		var citizen = Target.get_parent() as Node3D
		return citizen.global_position + Vector3(0.0, 0.5, 0.0)
