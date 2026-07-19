class_name Projectile
extends Area2D
## Homing shot. Instantiated by Tower; freed on hit or lifetime expiry.

const LIFETIME_SECONDS := 1.5

@onready var skin: Node2D = $Skin

var _target: Enemy
var _damage: float = 0.0
var _speed: float = 0.0
var _heading: Vector2 = Vector2.RIGHT
var _alive_for: float = 0.0
var _launched: bool = false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	area_entered.connect(_on_area_entered)
	_build_skin()


func launch(target: Enemy, damage: float, speed: float) -> void:
	_target = target
	_damage = damage
	_speed = speed
	_launched = true
	if is_instance_valid(target):
		_heading = (target.global_position - global_position).normalized()


func _physics_process(delta: float) -> void:
	if not _launched:
		return
	_alive_for += delta
	if _alive_for >= LIFETIME_SECONDS:
		queue_free()
		return

	if is_instance_valid(_target):
		var to_target := _target.global_position - global_position
		if to_target.length_squared() > 0.001:
			_heading = to_target.normalized()
	global_position += _heading * _speed * delta


func _on_area_entered(area: Area2D) -> void:
	var enemy := area.get_parent() as Enemy
	if enemy == null:
		return
	enemy.take_damage(_damage)
	queue_free()


func _build_skin() -> void:
	for child: Node in skin.get_children():
		child.queue_free()
	var blob := Polygon2D.new()
	blob.color = Color(1.0, 0.84, 0.42, 1.0)
	blob.polygon = _circle_poly(8.0)
	skin.add_child(blob)


func _circle_poly(radius: float, segments: int = 12) -> PackedVector2Array:
	var points := PackedVector2Array()
	points.resize(segments)
	for i: int in segments:
		var angle := TAU * float(i) / float(segments)
		points[i] = Vector2(cos(angle), sin(angle)) * radius
	return points
