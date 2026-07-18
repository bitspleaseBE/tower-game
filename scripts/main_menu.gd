extends Control


func _ready() -> void:
	%VersionLabel.text = "v%s" % ProjectSettings.get_setting("application/config/version", "dev")
	%NewGameButton.grab_focus()


func _on_new_game_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _on_settings_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/settings_menu.tscn")
