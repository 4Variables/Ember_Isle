extends Label

var target: Node3D = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()

func show_for(new_target: Node3D, prompt_text: String) -> void:
	if new_target != target:
		set_focus(target, false)
		set_focus(new_target, true)
	target = new_target
	text = prompt_text
	show()

func hide_prompt() -> void:
	set_focus(target, false)
	target = null
	hide()

func set_focus(node, value: bool) -> void:
	if node == null or not is_instance_valid(node):
		return
	if value and node.has_method("GainFocus"):
		node.GainFocus()
	elif not value and node.has_method("LoseFocus"):
		node.LoseFocus()

func _process(_delta: float) -> void:
	if target == null or not is_instance_valid(target) or not target.is_inside_tree():
		hide_prompt()
		return
	var cam := get_viewport().get_camera_3d()
	position = cam.unproject_position(target.global_position + Vector3.UP) - size / 2.0
