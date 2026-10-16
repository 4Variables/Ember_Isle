# fire.gd
extends Node3D

@export var min_lifetime := 5.0
@export var max_lifetime := 10.0
@export var damage_per_tick := 5.0
@export var tick_time := 0.5

@onready var hit_area: Area3D = $HitArea
@onready var firequad: MeshInstance3D = $Firequad

var damage_timer := Timer.new()

func _ready() -> void:
	# Damage tick timer
	damage_timer.wait_time = tick_time
	damage_timer.timeout.connect(_damage_overlapping)
	add_child(damage_timer)
	damage_timer.start()

	# Lifetime
	await get_tree().create_timer(randf_range(min_lifetime, max_lifetime)).timeout
	_extinguish()

func _damage_overlapping() -> void:
	for body in hit_area.get_overlapping_bodies():
		if body.has_method("take_damage"):
			body.take_damage(damage_per_tick)

func _extinguish() -> void:
	if not is_inside_tree():
		return
	damage_timer.stop()
	hit_area.monitoring = false   # no more damage while fading
	
	var tween := create_tween()
	tween.tween_property(firequad, "scale", Vector3.ZERO, 0.5)  # shrink away
	await tween.finished
	queue_free()
