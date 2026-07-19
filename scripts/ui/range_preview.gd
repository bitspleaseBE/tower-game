class_name RangePreview
extends Node2D
## Translucent range ring shown while selecting a build option. Same look as Tower.RangeRing.

var _range_px: float = 0.0


func _ready() -> void:
	visible = false
	z_index = 5


func show_at(world_pos: Vector2, range_px: float) -> void:
	global_position = world_pos
	_range_px = range_px
	visible = true
	queue_redraw()


func hide_preview() -> void:
	visible = false
	_range_px = 0.0
	queue_redraw()


func _draw() -> void:
	if _range_px <= 0.0:
		return
	draw_circle(Vector2.ZERO, _range_px, Color(0.55, 0.82, 0.94, 0.18))
	draw_arc(Vector2.ZERO, _range_px, 0.0, TAU, 64, Color(0.55, 0.82, 0.94, 0.55), 3.0, true)
