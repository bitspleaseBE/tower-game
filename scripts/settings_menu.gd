extends Control


func _ready() -> void:
	%FullscreenCheck.set_pressed_no_signal(Settings.fullscreen)
	%VolumeSlider.set_value_no_signal(Settings.master_volume)
	Juice.squishify_button(%BackButton)
	%FullscreenCheck.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_back()


func _on_fullscreen_check_toggled(toggled_on: bool) -> void:
	Settings.set_fullscreen(toggled_on)


func _on_volume_slider_value_changed(value: float) -> void:
	# Slider drag is a user gesture — unlock so volume previews can play.
	Sound.unlock_audio()
	Settings.set_master_volume(value)


func _on_back_button_pressed() -> void:
	_go_back()


func _go_back() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
