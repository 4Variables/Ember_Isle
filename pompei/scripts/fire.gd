# fire.gd
extends Node3D

@export var min_lifetime := 5.0
@export var max_lifetime := 10.0
@export var damage_per_tick := 5.0
@export var tick_time := 0.5
@export var fire_health := 3.0           # how much extinguish() it takes to put it out

@onready var hit_area: Area3D = $HitArea
@onready var firequad: MeshInstance3D = $Firequad

var damage_timer := Timer.new()
var _going_out := false

func _ready() -> void:
	add_to_group("fires")                # remove this line if you already add it in the editor

	damage_timer.wait_time = tick_time
	damage_timer.timeout.connect(_damage_overlapping)
	add_child(damage_timer)
	damage_timer.start()

	# Burns out on its own after a random lifetime
	await get_tree().create_timer(randf_range(min_lifetime, max_lifetime)).timeout
	_put_out()

func _damage_overlapping() -> void:
	for body in hit_area.get_overlapping_bodies():
		if body.has_method("take_damage"):
			body.take_damage(damage_per_tick)

# Called by NPCs. `amount` is already scaled by delta.
func extinguish(amount: float) -> void:
	if _going_out:
		return
	fire_health -= amount
	if fire_health <= 0.0:
		_put_out()

func _put_out() -> void:
	if _going_out or not is_inside_tree():
		return
	_going_out = true
	remove_from_group("fires")           # NPCs stop targeting it immediately
	damage_timer.stop()
	hit_area.monitoring = false

	var tween := create_tween()
	tween.tween_property(firequad, "scale", Vector3.ZERO, 0.5)
	await tween.finished
	queue_free()
