class_name Enemy
extends PathFollow2D
## Critter that walks the path. Acquired via Game._spawn_enemy() from ObjectPool.

## Flat min of 1 made armor irrelevant to 1-damage rapid shots; a proportional floor
## makes armored critters genuinely punish spam towers while big single hits shrug
## armor off — the counter-play matrix of Stage 4 depends on it.
const ARMOR_MIN_DAMAGE_RATIO := 0.25
const SLOW_TINT := Color(0.749, 0.89, 1.0, 1.0) ## #BFE3FF-ish

@onready var skin: Node2D = $Skin
@onready var hurtbox: Area2D = $Hurtbox
@onready var hurtbox_shape: CollisionShape2D = $Hurtbox/CollisionShape2D
@onready var hp_bar: Node2D = $HpBar
@onready var hp_bar_back: ColorRect = $HpBar/Back
@onready var hp_bar_fill: ColorRect = $HpBar/Fill

var data: EnemyData
var hp: float = 0.0
var max_hp: float = 0.0
var active := false
var generation := 0
var wobbling := false
var _walk_time: float = 0.0
var _rest_scale: Vector2 = Vector2.ONE
var _signals_wired := false
var _slow_factor := 1.0
var _slow_time_left := 0.0
var _hurt_circle: CircleShape2D


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
		if hp_bar:
			hp_bar.visible = false


func _wire_signals_once() -> void:
	if _signals_wired:
		return
	_signals_wired = true


## Single pool-reset entry point — Stage 5+ must funnel every reuse through here.
func reset_for(enemy_data: EnemyData) -> void:
	data = enemy_data
	max_hp = data.hp
	hp = data.hp
	_slow_factor = 1.0
	_slow_time_left = 0.0
	_walk_time = 0.0
	progress = 0.0
	skin.scale = Vector2.ONE
	skin.rotation = 0.0
	skin.position = Vector2.ZERO
	_build_skin()
	_ensure_hurtbox_shape()
	_hurt_circle.radius = data.radius_px
	_update_tint()
	_update_hp_bar()
	hp_bar.visible = data.is_boss
	hp_bar.position = Vector2(-32.0, -(data.radius_px + 22.0))


func activate(enemy_data: EnemyData) -> void:
	generation += 1
	reset_for(enemy_data)
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	hurtbox.set_deferred("monitorable", true)
	Juice.claim(skin)
	_rest_scale = skin.scale
	active = true
	wobbling = true
	if data.is_boss:
		_play_boss_entrance()


func deactivate() -> void:
	active = false
	wobbling = false
	_slow_factor = 1.0
	_slow_time_left = 0.0
	hurtbox.set_deferred("monitorable", false)
	Juice.release(skin)
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	if hp_bar:
		hp_bar.visible = false
	var game := get_tree().get_first_node_in_group("game")
	if game != null and game.has_method("release_enemy"):
		game.release_enemy(self)


func apply_slow(factor: float, duration: float) -> void:
	if not active:
		return
	# Keep strongest slow; refresh duration. Never stack multiplicatively.
	_slow_factor = minf(_slow_factor, factor)
	_slow_time_left = maxf(_slow_time_left, duration)
	_update_tint()


func get_base_tint() -> Color:
	return SLOW_TINT if _slow_factor < 1.0 else Color.WHITE


func _process(delta: float) -> void:
	if not active or data == null:
		return
	if _slow_time_left > 0.0:
		_slow_time_left = maxf(0.0, _slow_time_left - delta)
		if _slow_time_left <= 0.0:
			_slow_factor = 1.0
			_update_tint()
	_walk_time += delta
	progress += data.speed * _slow_factor * delta
	if wobbling:
		skin.scale = _rest_scale * Juice.wobble_scale(_walk_time)
	if progress_ratio >= 1.0:
		Events.enemy_leaked.emit(self)
		deactivate()


func take_damage(amount: float, heavy := false) -> void:
	if not active or data == null:
		return
	hp -= maxf(ARMOR_MIN_DAMAGE_RATIO * amount, amount - data.armor)
	_update_hp_bar()
	Juice.flash(skin, Color(6, 6, 6), 0.1, get_base_tint())
	if heavy:
		Juice.punch_scale(skin, 1.45, 0.22)
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


func _update_tint() -> void:
	skin.modulate = get_base_tint()
	# Keep Juice claim rest in sync so punch/squash restore the status tint.
	if Juice.has_method("set_claim_modulate"):
		Juice.set_claim_modulate(skin, skin.modulate)


func _update_hp_bar() -> void:
	if hp_bar == null or data == null:
		return
	hp_bar.visible = data.is_boss and active
	if not data.is_boss:
		return
	var ratio := 0.0 if max_hp <= 0.0 else clampf(hp / max_hp, 0.0, 1.0)
	hp_bar_fill.size = Vector2(64.0 * ratio, 8.0)


func _ensure_hurtbox_shape() -> void:
	# Shared .tscn CircleShape2D must not be mutated across pooled instances.
	if _hurt_circle == null:
		_hurt_circle = CircleShape2D.new()
		hurtbox_shape.shape = _hurt_circle


func _play_boss_entrance() -> void:
	Juice.shake(5.0, 0.25)
	skin.scale = _rest_scale * 1.4
	var tween := skin.create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(skin, "scale", _rest_scale, 0.35)
	hp_bar.modulate.a = 0.0
	var bar_tween := hp_bar.create_tween()
	bar_tween.tween_property(hp_bar, "modulate:a", 1.0, 0.3)


func _build_skin() -> void:
	for child: Node in skin.get_children():
		child.queue_free()

	var id := data.id if data != null else &"normal"
	var radius := data.radius_px if data != null else 26.0

	match id:
		&"swarm":
			_build_swarm_skin(radius)
		&"armored":
			_build_armored_skin(radius)
		&"boss":
			_build_boss_skin(radius)
		&"fast":
			_build_blob_skin(radius, Color(1.0, 0.62, 0.49, 1.0), Color(0.95, 0.42, 0.28, 1.0), true)
		_:
			_build_blob_skin(radius, Color(0.55, 0.82, 0.94, 1.0), Color(0.35, 0.65, 0.85, 1.0), true)

	skin.scale = Vector2.ONE
	skin.position = Vector2.ZERO


func _build_blob_skin(radius: float, body_color: Color, border_color: Color, two_eyes: bool) -> void:
	var border := Polygon2D.new()
	border.color = border_color
	border.polygon = _circle_poly(radius + 4.0)
	skin.add_child(border)

	var body := Polygon2D.new()
	body.color = body_color
	body.polygon = _circle_poly(radius)
	skin.add_child(body)

	if two_eyes:
		_add_eye(Vector2(-radius * 0.28, -radius * 0.18), maxf(2.5, radius * 0.12))
		_add_eye(Vector2(radius * 0.28, -radius * 0.18), maxf(2.5, radius * 0.12))
	else:
		_add_eye(Vector2(0, -radius * 0.15), maxf(2.5, radius * 0.18))


func _build_swarm_skin(radius: float) -> void:
	# Tiny pale-pink dot with a single eye.
	_build_blob_skin(radius, Color(1.0, 0.82, 0.88, 1.0), Color(0.95, 0.55, 0.7, 1.0), false)


func _build_armored_skin(radius: float) -> void:
	# Octagonal grape body with a thicker darker candy-shell rim.
	var rim := Polygon2D.new()
	rim.color = Color(0.45, 0.35, 0.62, 1.0)
	rim.polygon = _regular_poly(8, radius + 5.0)
	skin.add_child(rim)

	var body := Polygon2D.new()
	body.color = Color(0.608, 0.541, 0.796, 1.0) ## #9B8ACB
	body.polygon = _regular_poly(8, radius)
	skin.add_child(body)

	_add_eye(Vector2(-radius * 0.3, -radius * 0.15), 3.5)
	_add_eye(Vector2(radius * 0.3, -radius * 0.15), 3.5)


func _build_boss_skin(radius: float) -> void:
	# Big deep-magenta blob with a 3-spike candy crown.
	_build_blob_skin(radius, Color(0.72, 0.22, 0.55, 1.0), Color(0.45, 0.1, 0.35, 1.0), true)

	var crown := Polygon2D.new()
	crown.color = Color(1.0, 0.84, 0.42, 1.0)
	var tip_y := -(radius + 10.0)
	crown.polygon = PackedVector2Array([
		Vector2(-radius * 0.7, -radius * 0.55),
		Vector2(-radius * 0.45, tip_y),
		Vector2(-radius * 0.2, -radius * 0.55),
		Vector2(0.0, tip_y - 4.0),
		Vector2(radius * 0.2, -radius * 0.55),
		Vector2(radius * 0.45, tip_y),
		Vector2(radius * 0.7, -radius * 0.55),
		Vector2(radius * 0.55, -radius * 0.35),
		Vector2(-radius * 0.55, -radius * 0.35),
	])
	skin.add_child(crown)


func _add_eye(pos: Vector2, radius: float) -> void:
	var eye := Polygon2D.new()
	eye.color = Color(0.31, 0.227, 0.357, 1.0)
	eye.polygon = _circle_poly(radius)
	eye.position = pos
	skin.add_child(eye)


func _circle_poly(radius: float, segments: int = 20) -> PackedVector2Array:
	var points := PackedVector2Array()
	points.resize(segments)
	for i: int in segments:
		var angle := TAU * float(i) / float(segments)
		points[i] = Vector2(cos(angle), sin(angle)) * radius
	return points


func _regular_poly(sides: int, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	points.resize(sides)
	for i: int in sides:
		var angle := -PI * 0.5 + TAU * float(i) / float(sides)
		points[i] = Vector2(cos(angle), sin(angle)) * radius
	return points
