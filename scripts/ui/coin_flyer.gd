class_name CoinFlyer
extends Node2D
## Pooled golden coin that arcs to the HUD. Cosmetic only — coins already credited.

signal finished

@onready var skin: Node2D = $Skin

var _tween: Tween
var _start: Vector2
var _control: Vector2
var _end: Vector2


func _ready() -> void:
	if skin.get_child_count() == 0:
		_build_skin()


func activate(start: Vector2, control: Vector2, end: Vector2, duration: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_start = start
	_control = control
	_end = end
	global_position = start
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	modulate = Color.WHITE
	scale = Vector2.ONE
	_tween = create_tween()
	_tween.tween_method(_follow_bezier, 0.0, 1.0, duration)
	_tween.parallel().tween_property(self, "scale", Vector2(0.6, 0.6), duration)
	_tween.tween_callback(func() -> void:
		finished.emit()
	)


func _follow_bezier(t: float) -> void:
	# Quadratic bezier; world coords == screen coords (no Camera2D — see hud.coin_anchor).
	var inv := 1.0 - t
	global_position = inv * inv * _start + 2.0 * inv * t * _control + t * t * _end


func _build_skin() -> void:
	var coin := Polygon2D.new()
	coin.color = Color(1.0, 0.84, 0.42, 1.0)
	coin.polygon = _circle_poly(10.0)
	skin.add_child(coin)
	var shine := Polygon2D.new()
	shine.color = Color(1.0, 0.95, 0.7, 1.0)
	shine.polygon = _circle_poly(4.0)
	shine.position = Vector2(-2, -2)
	skin.add_child(shine)


func _circle_poly(radius: float, segments: int = 14) -> PackedVector2Array:
	var points := PackedVector2Array()
	points.resize(segments)
	for i: int in segments:
		var angle := TAU * float(i) / float(segments)
		points[i] = Vector2(cos(angle), sin(angle)) * radius
	return points
