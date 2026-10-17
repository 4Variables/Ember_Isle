
extends Control

var start_pos := Vector2.ZERO
var end_pos := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func update_box(start: Vector2, finish: Vector2) -> void:
	start_pos = start
	end_pos = finish
	queue_redraw()


func _draw() -> void:
	if not visible:
		return

	var rect = Rect2(start_pos, end_pos - start_pos).abs()

	draw_rect(rect, Color(0.2, 0.7, 1.0, 0.15), true)
	draw_rect(rect, Color(0.2, 0.7, 1.0, 0.9), false, 2.0)
