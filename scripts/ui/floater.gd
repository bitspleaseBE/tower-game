class_name Floater
extends Label
## Pooled floating damage/bounty text. Released via finished signal.

signal finished

var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_theme_font_size_override("font_size", 28)
	add_theme_color_override("font_outline_color", Color(0.31, 0.227, 0.357, 1.0))
	add_theme_constant_override("outline_size", 4)


func force_stop() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


func activate(text: String, world_pos: Vector2, color: Color) -> void:
	force_stop()
	self.text = text
	modulate = color
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	global_position = world_pos + Vector2(-24, -30)
	pivot_offset = size * 0.5
	z_index = 20
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "position:y", position.y - 40.0, 0.6)
	_tween.tween_property(self, "modulate:a", 0.0, 0.6)
	_tween.chain().tween_callback(func() -> void:
		finished.emit()
	)
