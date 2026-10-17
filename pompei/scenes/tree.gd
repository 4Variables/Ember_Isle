class_name ChoppableTree
extends StaticBody3D

signal felled(tree: ChoppableTree)

@export var wood_amount := 5            # total wood this tree yields
@export var seconds_per_wood := 1.5     # chopping time (at power 1.0) per piece of wood

var _progress := 0.0

func _ready() -> void:
	add_to_group("trees")

# Called every physics frame by the NPC. Returns wood gained this call.
func chop(amount: float) -> int:
	if wood_amount <= 0:
		return 0

	_progress += amount
	var gained := 0
	while _progress >= seconds_per_wood and wood_amount > 0:
		_progress -= seconds_per_wood
		wood_amount -= 1
		gained += 1

	if wood_amount <= 0:
		_fell()
	return gained

func _fell() -> void:
	remove_from_group("trees")        # NPCs stop targeting it immediately
	felled.emit(self)
	# Simple fall animation, then remove.
	var tw := create_tween()
	tw.tween_property(self, "rotation_degrees:x", 90.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)
