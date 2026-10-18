class_name MedicalData
extends ItemData

@export var heal_amount := 0.0      # health restored
@export var poison_cure := 0.0      # poison removed

func use(user: Node) -> bool:
	var npc := user as Npc
	return npc != null and npc.recover(heal_amount, poison_cure)

# How much poison this would remove right now.
func poison_gain(npc: Npc) -> float:
	return minf(poison_cure, npc.poison)

# How much health this would restore right now, capped by what the colonist is missing.
func health_gain(npc: Npc) -> float:
	return minf(heal_amount, npc.max_health - npc.health)
