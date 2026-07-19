extends Control
## In-run pause sheet. PROCESS_MODE_ALWAYS while the tree is paused.

@onready var backdrop: ColorRect = %Backdrop
@onready var panel: PanelContainer = %PausePanel
@onready var title_label: Label = %TitleLabel
@onready var continue_button: Button = %ContinueButton
@onready var quit_button: Button = %QuitButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	continue_button.pressed.connect(_on_continue)
	quit_button.pressed.connect(_on_quit)
	Juice.squishify_button(continue_button)
	Juice.squishify_button(quit_button)


func is_open() -> bool:
	return visible


func open() -> void:
	if visible:
		return
	Sound.set_music_ducked(true)
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	get_tree().paused = true
	panel.scale = Vector2(0.6, 0.6)
	panel.pivot_offset = panel.size * 0.5
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.28)
	continue_button.grab_focus()


func close() -> void:
	if not visible:
		return
	get_tree().paused = false
	Sound.set_music_ducked(false)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_on_continue()
		get_viewport().set_input_as_handled()


func _on_continue() -> void:
	close()


func _on_quit() -> void:
	get_tree().paused = false
	Sound.set_music_ducked(false)
	get_tree().change_scene_to_file("res://scenes/map_select.tscn")
