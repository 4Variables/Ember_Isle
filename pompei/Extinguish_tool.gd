# extinguish_tool.gd
class_name ExtinguishTool
extends Resource

@export var display_name := "Extinguisher"
@export var power := 2.0        # fire intensity removed per second
@export var reach := 2.0        # how close the NPC must stand
@export var capacity := -1.0    # seconds of use; -1 = unlimited

var remaining := -2.0  # lazily initialised from capacity

func is_usable() -> bool:
	_init_remaining()
	return remaining == -1.0 or remaining > 0.0

# Spends charge and returns how much fire intensity to remove this frame
func use(delta: float) -> float:
	_init_remaining()
	if remaining != -1.0:
		remaining = maxf(remaining - delta, 0.0)
	return power * delta

func _init_remaining() -> void:
	if remaining == -2.0:
		remaining = capacity
