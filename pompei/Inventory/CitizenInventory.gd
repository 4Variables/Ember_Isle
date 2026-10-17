extends Node
class_name CitizenInventory

signal Changed

@export var ItemSlotsCount : int = 20

var Items : Array[ItemData] = []
var EquippedSlot : int = -1

func _ready():
	Items.resize(ItemSlotsCount)

func AddItem(item : ItemData) -> bool:
	for i in Items.size():
		if Items[i] == null:
			Items[i] = item
			Changed.emit()
			return true
	return false

func RemoveItem(slotID : int) -> ItemData:
	var item = Items[slotID]
	Items[slotID] = null
	if EquippedSlot == slotID:
		EquippedSlot = -1
	Changed.emit()
	return item

func SwapSlots(fromID : int, toID : int):
	var temp = Items[toID]
	Items[toID] = Items[fromID]
	Items[fromID] = temp
	if EquippedSlot == fromID:
		EquippedSlot = toID
	elif EquippedSlot == toID:
		EquippedSlot = fromID
	Changed.emit()

func ToggleEquip(slotID : int):
	EquippedSlot = -1 if (slotID == EquippedSlot or Items[slotID] == null) else slotID
	Changed.emit()
