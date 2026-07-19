class_name BuildPad
extends Node2D
## Empty build site. Taps resolved by Game hit-testing (no Area2D).

const PAD_TEX: Texture2D = preload("res://assets/background/pad.png")

@onready var skin: Node2D = $Skin

var tower: Tower = null
var _shadow: Polygon2D


func _ready() -> void:
	add_to_group("build_pads")
	_ensure_shadow()
	_build_skin()
	Juice.claim(skin)
	_start_breathe()


func pulse() -> void:
	Juice.punch_scale(skin, 1.15, 0.12)


func _ensure_shadow() -> void:
	if _shadow != null and is_instance_valid(_shadow):
		return
	_shadow = Polygon2D.new()
	_shadow.name = "Shadow"
	_shadow.z_index = -1
	_shadow.color = Color(0, 0, 0, 0.25)
	_shadow.position = Vector2(0, 16)
	_shadow.polygon = _ellipse_poly(30.0, 12.0)
	add_child(_shadow)
	move_child(_shadow, 0)


func _build_skin() -> void:
	while skin.get_child_count() > 0:
		var child: Node = skin.get_child(0)
		skin.remove_child(child)
		child.free()

	var pad := Sprite2D.new()
	pad.name = "Pad"
	pad.texture = PAD_TEX
	var pad_scale := 84.0 / float(PAD_TEX.get_width())
	pad.scale = Vector2(pad_scale, pad_scale)
	skin.add_child(pad)

	var shine := Polygon2D.new()
	shine.name = "Shine"
	shine.color = Color(1.0, 1.0, 1.0, 0.5)
	shine.polygon = _ellipse_poly(8.0, 8.0, 12)
	shine.position = Vector2(-14.0, -14.0)
	skin.add_child(shine)


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


func _ellipse_poly(rx: float, ry: float, segments: int = 20) -> PackedVector2Array:
	var points := PackedVector2Array()
	points.resize(segments)
	for i: int in segments:
		var angle := TAU * float(i) / float(segments)
		points[i] = Vector2(cos(angle) * rx, sin(angle) * ry)
	return points
