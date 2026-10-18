class_name MedicalData
extends ItemData

@export var heal_amount := 30.0     # health restored
@export var poison_cure := 25.0     # poison removed

func use(user: Node) -> bool:
	var npc := user as Npc
	return npc != null and npc.recover(heal_amount, poison_cure)
