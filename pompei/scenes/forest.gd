@tool
extends Node3D

@export var green_colors: Array[Color] = [
	Color("3f7d3a"),
	Color("4f9a43"),
	Color("5fb04e"),
	Color("2f6b35"),
	Color("6fbf5a"),
]

@export_tool_button("Apply Colors") var apply_button = apply_colors

var _count := 0


func apply_colors() -> void:
	if green_colors.is_empty():
		push_warning("Forest: green_colors is empty.")
		return
	_count = 0
	_process_node(self)
	print("Forest: colored %d surfaces. Now save the scene." % _count)


func _process_node(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			_color_mesh(child)
		_process_node(child)


func _color_mesh(mi: MeshInstance3D) -> void:
	if mi.mesh == null:
		return
	for i in mi.mesh.get_surface_count():
		if mi.get_surface_override_material(i) == null:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = green_colors.pick_random()
			mi.set_surface_override_material(i, mat)
			_count += 1
