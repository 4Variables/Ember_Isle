# equipment_data.gd
class_name EquipmentData
extends ItemData

enum Slot { FACE, BODY }

@export var slot: Slot = Slot.FACE
# 0.0 = no protection, 1.0 = fully immune to poison
@export_range(0.0, 1.0) var poison_resistance := 1.0

func use(user: Node) -> bool:
	var npc := user as Npc
	return npc != null and npc.equip(self)
