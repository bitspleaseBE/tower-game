extends Node2D
## Placeholder for the actual game. "New Game" lands here.


func _ready() -> void:
	%BackButton.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_back()


func _on_back_button_pressed() -> void:
	_go_back()


func _go_back() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
