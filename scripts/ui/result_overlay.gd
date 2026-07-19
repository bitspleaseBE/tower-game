extends Control
## Win / lose overlay. PROCESS_MODE_ALWAYS so it works while the tree is paused.

@onready var backdrop: ColorRect = %Backdrop
@onready var panel: PanelContainer = %ResultPanel
@onready var title_label: Label = %TitleLabel
@onready var retry_button: Button = %RetryButton
@onready var menu_button: Button = %MenuButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	retry_button.pressed.connect(_on_retry)
	menu_button.pressed.connect(_on_menu)
	Juice.squishify_button(retry_button)
	Juice.squishify_button(menu_button)
	Events.run_won.connect(_on_run_won)
	Events.run_lost.connect(_on_run_lost)


func _on_run_won(_map_id: StringName) -> void:
	_show_result("Path defended!")


func _on_run_lost(_map_id: StringName) -> void:
	_show_result("The critters got through!")


func _show_result(text: String) -> void:
	title_label.text = text
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	get_tree().paused = true
	panel.scale = Vector2(0.6, 0.6)
	panel.pivot_offset = panel.size * 0.5
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.35)


func _on_retry() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
