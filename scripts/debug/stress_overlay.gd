extends Control
## Debug-only stress metrics. Hidden unless StressTest activates it.

signal enemies_cycle_pressed
signal speed_cycle_pressed
signal free_build_pressed
signal roster_preset_pressed

@onready var panel: PanelContainer = %Panel
@onready var metrics_label: Label = %MetricsLabel
@onready var enemies_button: Button = %EnemiesButton
@onready var speed_button: Button = %SpeedButton
@onready var free_build_button: Button = %FreeBuildButton
@onready var roster_button: Button = %RosterButton


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	enemies_button.custom_minimum_size = Vector2(200, 56)
	speed_button.custom_minimum_size = Vector2(200, 56)
	free_build_button.custom_minimum_size = Vector2(200, 56)
	roster_button.custom_minimum_size = Vector2(200, 56)
	Juice.squishify_button(enemies_button)
	Juice.squishify_button(speed_button)
	Juice.squishify_button(free_build_button)
	Juice.squishify_button(roster_button)
	enemies_button.pressed.connect(func() -> void: enemies_cycle_pressed.emit())
	speed_button.pressed.connect(func() -> void: speed_cycle_pressed.emit())
	free_build_button.pressed.connect(func() -> void: free_build_pressed.emit())
	roster_button.pressed.connect(func() -> void: roster_preset_pressed.emit())


func set_active(active: bool) -> void:
	visible = active


func set_enemies_label(count: int) -> void:
	enemies_button.text = "Enemies: %d" % count


func set_speed_label(scale: float) -> void:
	speed_button.text = "Speed: ×%d" % int(scale)


func set_free_build_label(enabled: bool) -> void:
	free_build_button.text = "Free build: %s" % ("ON" if enabled else "OFF")


func set_metrics(text: String) -> void:
	metrics_label.text = text
