class_name Enemy
extends PathFollow2D
## Critter that walks the path. Spawned via Game._spawn_enemy().

@onready var skin: Node2D = $Skin
@onready var hurtbox: Area2D = $Hurtbox

var data: EnemyData
var hp: float = 0.0
var _dead: bool = false


func _ready() -> void:
	loop = false
	rotates = false
	add_to_group("enemies")


func setup(enemy_data: EnemyData) -> void:
	data = enemy_data
	hp = data.hp
	_build_skin()


func _process(delta: float) -> void:
	if _dead or data == null:
		return
	progress += data.speed * delta
	if progress_ratio >= 1.0:
		Events.enemy_leaked.emit(self)
		queue_free()


func take_damage(amount: float) -> void:
	if _dead or data == null:
		return
	hp -= maxf(1.0, amount - data.armor)
	if hp <= 0.0:
		_die()


func _die() -> void:
	_dead = true
	set_process(false)
	hurtbox.set_deferred("monitorable", false)
	Events.enemy_killed.emit(self, data.bounty)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(skin, "scale", Vector2(1.5, 1.5), 0.15)
	tween.tween_property(skin, "modulate:a", 0.0, 0.15)
	tween.chain().tween_callback(queue_free)


func _build_skin() -> void:
	for child: Node in skin.get_children():
		child.queue_free()

	var is_fast := data != null and data.id == &"fast"
	var body_color := Color(1.0, 0.62, 0.49, 1.0) if is_fast else Color(0.55, 0.82, 0.94, 1.0)
	var border_color := Color(0.95, 0.42, 0.28, 1.0) if is_fast else Color(0.35, 0.65, 0.85, 1.0)
	var radius := 18.0 if is_fast else 22.0

	var border := Polygon2D.new()
	border.color = border_color
	border.polygon = _circle_poly(radius + 4.0)
	skin.add_child(border)

	var body := Polygon2D.new()
	body.color = body_color
	body.polygon = _circle_poly(radius)
	skin.add_child(body)

	var eye_l := Polygon2D.new()
	eye_l.color = Color(0.31, 0.227, 0.357, 1.0)
	eye_l.polygon = _circle_poly(3.0)
	eye_l.position = Vector2(-6, -4)
	skin.add_child(eye_l)

	var eye_r := Polygon2D.new()
	eye_r.color = Color(0.31, 0.227, 0.357, 1.0)
	eye_r.polygon = _circle_poly(3.0)
	eye_r.position = Vector2(6, -4)
	skin.add_child(eye_r)


func _circle_poly(radius: float, segments: int = 20) -> PackedVector2Array:
	var points := PackedVector2Array()
	points.resize(segments)
	for i: int in segments:
		var angle := TAU * float(i) / float(segments)
		points[i] = Vector2(cos(angle), sin(angle)) * radius
	return points
