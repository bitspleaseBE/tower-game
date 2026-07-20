extends Control
## Short candy toast for recurring feedback (leaks, etc.). Never pauses.

@onready var panel: PanelContainer = %ToastPanel
@onready var label: Label = %ToastLabel

var _hide_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	Juice.claim(panel)


func show_toast(text: String, hold := 1.6) -> void:
	label.text = text
	visible = true
	if _hide_tween != null and _hide_tween.is_valid():
		_hide_tween.kill()
	panel.modulate.a = 1.0
	await get_tree().process_frame
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2(0.5, 0.5)
	var pop := create_tween()
	pop.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(panel, "scale", Vector2.ONE, 0.28)
	_hide_tween = create_tween()
	_hide_tween.tween_interval(hold)
	_hide_tween.tween_property(panel, "modulate:a", 0.0, 0.25)
	_hide_tween.tween_callback(func() -> void:
		visible = false
		panel.modulate.a = 1.0
	)
