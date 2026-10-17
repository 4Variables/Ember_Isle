extends Control

@onready var volume_slider: HSlider = $MarginContainer/PanelContainer/Panel/VBoxContainer/VolumeSlider
@onready var language_option: OptionButton = $MarginContainer/PanelContainer/Panel/VBoxContainer/MarginContainer2/LanguageOption
@onready var title_label: Label = $MarginContainer/PanelContainer/Panel/VBoxContainer/MarginContainer/TitleLabel
@onready var volume_label: Label = $MarginContainer/PanelContainer/Panel/VBoxContainer/VolumeLabel
@onready var language_label: Label = $MarginContainer/PanelContainer/Panel/VBoxContainer/LanguageLabel
@onready var close_button: Button = $MarginContainer/PanelContainer/Panel/VBoxContainer/CloseButton

const SETTINGS_PATH = "user://settings.cfg"

var settings := ConfigFile.new()


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Load saved settings, if available.
	settings.load(SETTINGS_PATH)

	# English is the default language.
	var saved_language: String = settings.get_value(
		"settings", "language", "en"
	)
	TranslationServer.set_locale(saved_language)

	# Populate the language dropdown.
	language_option.clear()
	language_option.add_item("English", 0)
	language_option.add_item("Turkish", 1)

	# Select the saved language.
	language_option.select(1 if saved_language == "tr" else 0)

	# Restore the saved volume (0-100).
	var saved_volume: float = settings.get_value(
		"settings", "volume", 80.0
	)
	volume_slider.value = saved_volume
	_apply_volume(saved_volume)

	# Update interface text using translation keys.
	_update_text()

	# Connect signals through code.
	volume_slider.value_changed.connect(_on_volume_changed)
	language_option.item_selected.connect(_on_language_selected)


func _apply_volume(value: float) -> void:
	var master_bus := AudioServer.get_bus_index("Master")

	if value <= 0.0:
		AudioServer.set_bus_mute(master_bus, true)
	else:
		AudioServer.set_bus_mute(master_bus, false)
		AudioServer.set_bus_volume_db(
			master_bus, linear_to_db(value / 100.0)
		)


func _on_volume_changed(value: float) -> void:
	_apply_volume(value)

	settings.set_value("settings", "volume", value)
	settings.save(SETTINGS_PATH)


func _on_language_selected(index: int) -> void:
	# Item 0 = English; item 1 = Turkish.
	var selected_language := "en" if index == 0 else "tr"

	TranslationServer.set_locale(selected_language)

	settings.set_value("settings", "language", selected_language)
	settings.save(SETTINGS_PATH)

	# Refresh the popup labels after changing languages.
	_update_text()


func _update_text() -> void:
	# tr() retrieves the matching English or Turkish translation.
	title_label.text = tr("SETTINGS")
	volume_label.text = tr("VOLUME")
	language_label.text = tr("LANGUAGE")
	close_button.text = tr("CLOSE")


func _on_close_pressed() -> void:
	# Save any settings here if necessary.

	# Remember the main menu before removing this scene.
	var main_menu = get_tree().root.get_node_or_null(
		"MainMenu"
	)

	# Remove the settings scene.
	queue_free()

	# Restore the main menu.
	if main_menu:
		main_menu.show()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
