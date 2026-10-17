extends Control

const SETTINGS_SCENE = preload("res://user_interface/settings_popup.tscn")

var settings_popup: Control

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Create the settings popup, but keep it hidden initially.
	settings_popup = SETTINGS_SCENE.instantiate()
	add_child(settings_popup)
	settings_popup.hide()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_settings_pressed() -> void:
	# Hide the main menu and show settings.
	hide()
	
	# Create and display the settings scene.
	settings_popup = SETTINGS_SCENE.instantiate()
	get_tree().root.add_child(settings_popup)

	# Center the settings panel on the screen.
	settings_popup.set_anchors_and_offsets_preset(
		Control.PRESET_CENTER
	)


func _on_exit_pressed() -> void:
	get_tree().quit()
	
	
func show_main_menu() -> void:
	# Restore the main menu when settings are closed.
	show()
