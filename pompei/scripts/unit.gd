	# unit.gd
	extends CharacterBody3D

	@export var max_health := 100.0
	var health := max_health

	func _ready() -> void:
		health = max_health

	func take_damage(amount: float) -> void:
		health -= amount
		print("Health: ", health)
		if health <= 0.0:
			queue_free()   # replace with a death animation later
