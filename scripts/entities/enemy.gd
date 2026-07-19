class_name Enemy
extends PathFollow2D
## Critter that walks the path. Acquired via Game._spawn_enemy() from ObjectPool.

@onready var skin: Node2D = $Skin
@onready var hurtbox: Area2D = $Hurtbox

var data: EnemyData
var hp: float = 0.0
var active := false
var generation := 0
var wobbling := false
var _walk_time: float = 0.0
var _rest_scale: Vector2 = Vector2.ONE
var _signals_wired := false


func _ready() -> void:
	loop = false
	rotates = false
	add_to_group("enemies")
	_wire_signals_once()
	# Fresh instances start inactive until activate(); pool prewarm also deactivates.
	if not active:
		visible = false
		process_mode = Node.PROCESS_MODE_DISABLED
		hurtbox.monitorable = false


func _wire_signals_once() -> void:
	if _signals_wired:
		return
	_signals_wired = true


func activate(enemy_data: EnemyData) -> void:
	generation += 1
	data = enemy_data
	hp = data.hp
	_walk_time = 0.0
	progress = 0.0
	_build_skin()
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	hurtbox.set_deferred("monitorable", true)
	Juice.claim(skin)
	_rest_scale = skin.scale
	active = true
	wobbling = true


func deactivate() -> void:
	active = false
	wobbling = false
	hurtbox.set_deferred("monitorable", false)
	Juice.release(skin)
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	var game := get_tree().get_first_node_in_group("game")
	if game != null and game.has_method("release_enemy"):
		game.release_enemy(self)


func _process(delta: float) -> void:
	if not active or data == null:
		return
	_walk_time += delta
	progress += data.speed * delta
	if wobbling:
		skin.scale = _rest_scale * Juice.wobble_scale(_walk_time)
	if progress_ratio >= 1.0:
		Events.enemy_leaked.emit(self)
		deactivate()


func take_damage(amount: float) -> void:
	if not active or data == null:
		return
	hp -= maxf(1.0, amount - data.armor)
	Juice.flash(skin)
	if hp <= 0.0:
		_die()


func _die() -> void:
	if not active:
		return
	active = false
	wobbling = false
	hurtbox.set_deferred("monitorable", false)
	Events.enemy_killed.emit(self, data.bounty)
	Juice.confetti(global_position)
	Juice.coin_burst(global_position)
	Juice.floater("+%d" % data.bounty, global_position, Color(1.0, 0.79, 0.3, 1.0))
	Juice.punch_scale(skin)
	# Wait for punch, then return to pool.
	var gen := generation
	get_tree().create_timer(0.2).timeout.connect(func() -> void:
		if generation == gen:
			deactivate()
	)


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

	skin.scale = Vector2.ONE
	skin.modulate = Color.WHITE
	skin.position = Vector2.ZERO


func _circle_poly(radius: float, segments: int = 20) -> PackedVector2Array:
	var points := PackedVector2Array()
	points.resize(segments)
	for i: int in segments:
		var angle := TAU * float(i) / float(segments)
		points[i] = Vector2(cos(angle), sin(angle)) * radius
	return points
