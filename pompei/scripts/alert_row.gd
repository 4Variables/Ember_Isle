class_name AlertRow
extends PanelContainer

@onready var icon: TextureRect = $HBoxContainer/Icon
@onready var message: Label = $HBoxContainer/Message

var _blink: Tween

func show_alert(npc_name: String, critical: bool) -> void:
	if critical:
		message.text = "%s is badly poisoned!" % npc_name
		message.modulate = Color.YELLOW
	else:
		message.text = "%s is being poisoned" % npc_name
		message.modulate = Color(1, 1, 1, 0.8)
	icon.visible = critical
	_set_blinking(critical)


func _set_blinking(on: bool) -> void:
	if _blink:
		_blink.kill()
		_blink = null
	icon.modulate.a = 1.0
	if on:
		_blink = create_tween().set_loops()
		_blink.tween_property(icon, "modulate:a", 0.15, 0.4)
		_blink.tween_property(icon, "modulate:a", 1.0, 0.4)
