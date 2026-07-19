class_name CoinFlyer
extends Node2D
## Pooled golden coin that arcs to the HUD. Cosmetic only — coins already credited.

signal finished

const COIN_TEX: Texture2D = preload("res://assets/ui/icon_coin.png")

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
	var coin := Sprite2D.new()
	coin.name = "Coin"
	coin.texture = COIN_TEX
	coin.modulate = Color(1.0, 0.788, 0.302, 1.0) ## #FFC94D
	var coin_scale := 20.0 / float(COIN_TEX.get_width())
	coin.scale = Vector2(coin_scale, coin_scale)
	skin.add_child(coin)
