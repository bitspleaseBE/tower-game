extends Control
## Debug-only stress metrics. Hidden unless StressTest activates it.

signal enemies_cycle_pressed

@onready var panel: PanelContainer = %Panel
@onready var metrics_label: Label = %MetricsLabel
@onready var enemies_button: Button = %EnemiesButton


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	enemies_button.custom_minimum_size = Vector2(200, 64)
	Juice.squishify_button(enemies_button)
	enemies_button.pressed.connect(func() -> void: enemies_cycle_pressed.emit())


func set_active(active: bool) -> void:
	visible = active


func set_enemies_label(count: int) -> void:
	enemies_button.text = "Enemies: %d" % count


func set_metrics(text: String) -> void:
	metrics_label.text = text
