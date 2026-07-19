class_name BuildPad
extends Node2D
## Empty build site. Taps resolved by Game hit-testing (no Area2D).

@onready var skin: Node2D = $Skin

var tower: Tower = null


func _ready() -> void:
	add_to_group("build_pads")
	_build_skin()
	Juice.claim(skin)
	_start_breathe()


func pulse() -> void:
	Juice.punch_scale(skin, 1.15, 0.12)


func _build_skin() -> void:
	for child: Node in skin.get_children():
		child.queue_free()

	var border := Polygon2D.new()
	border.color = Color(0.749, 0.627, 0.91, 1.0) # #BFA0E8
	border.polygon = _circle_poly(36.0)
	skin.add_child(border)

	var fill := Polygon2D.new()
	fill.color = Color(0.902, 0.851, 0.969, 1.0) # #E6D9F7
	fill.polygon = _circle_poly(32.0)
	skin.add_child(fill)


func _start_breathe() -> void:
	var phase := randf() * 1.8
	var tween := create_tween()
	tween.tween_interval(phase)
	tween.tween_callback(func() -> void:
		var breathe := create_tween()
		breathe.set_loops()
		breathe.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		breathe.tween_property(skin, "scale", Vector2(1.04, 1.04), 0.9)
		breathe.tween_property(skin, "scale", Vector2.ONE, 0.9)
	)


func _circle_poly(radius: float, segments: int = 24) -> PackedVector2Array:
	var points := PackedVector2Array()
	points.resize(segments)
	for i: int in segments:
		var angle := TAU * float(i) / float(segments)
		points[i] = Vector2(cos(angle), sin(angle)) * radius
	return points
