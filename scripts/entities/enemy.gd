class_name Enemy
extends PathFollow2D
## Critter that walks the path. Acquired via Game._spawn_enemy() from ObjectPool.

## Flat min of 1 made armor irrelevant to 1-damage rapid shots; a proportional floor
## makes armored critters genuinely punish spam towers while big single hits shrug
## armor off — the counter-play matrix of Stage 4 depends on it.
const ARMOR_MIN_DAMAGE_RATIO := 0.25
const SLOW_TINT := Color(0.749, 0.89, 1.0, 1.0) ## #BFE3FF-ish
## Candy faces sit at the bottom of the sprite (+Y). Subtract so the face tracks travel.
const FACE_FORWARD := PI * 0.5
const FACE_LOOKAHEAD_PX := 12.0

const BODY_TEXTURES := {
	&"normal": preload("res://assets/enemies/critter_normal.png"),
	&"fast": preload("res://assets/enemies/critter_fast.png"),
	&"swarm": preload("res://assets/enemies/critter_swarm.png"),
	&"armored": preload("res://assets/enemies/critter_armored.png"),
	&"boss": preload("res://assets/enemies/critter_boss.png"),
}

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
	# Deferred so Game can set visible-spawn progress before the first face sample.
	call_deferred("_face_along_path")
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
	_face_along_path()
	if wobbling:
		skin.scale = _rest_scale * Juice.wobble_scale(_walk_time)
	if progress_ratio >= 1.0:
		Events.enemy_leaked.emit(self)
		deactivate()


## Point the baked face along the path tangent. HP bar stays upright (sibling of Skin).
func _face_along_path() -> void:
	var path_node := get_parent() as Path2D
	if path_node == null or path_node.curve == null or skin == null:
		return
	var curve := path_node.curve
	var length := curve.get_baked_length()
	if length <= 1.0:
		return
	var from_p := progress
	var to_p := progress + FACE_LOOKAHEAD_PX
	if to_p > length:
		from_p = maxf(0.0, progress - FACE_LOOKAHEAD_PX)
		to_p = progress
	var dir := curve.sample_baked(minf(to_p, length)) - curve.sample_baked(from_p)
	if dir.length_squared() < 0.25:
		return
	skin.rotation = dir.angle() - FACE_FORWARD


func take_damage(amount: float, heavy := false) -> void:
	if not active or data == null:
		return
	hp -= maxf(ARMOR_MIN_DAMAGE_RATIO * amount, amount - data.armor)
	_update_hp_bar()
	Juice.flash(skin, Color(1.85, 1.85, 1.7), 0.1, get_base_tint())
	if heavy:
		Juice.punch_scale(skin, 1.45, 0.22)
	if hp <= 0.0:
		_die()
	else:
		Sound.play_sfx(&"hit")


func _die() -> void:
	if not active:
		return
	active = false
	wobbling = false
	hurtbox.set_deferred("monitorable", false)
	var bounty := data.bounty
	var game := get_tree().get_first_node_in_group("game")
	if game != null and game.has_method("bounty_for"):
		bounty = int(game.bounty_for(data))
	Events.enemy_killed.emit(self, bounty)
	Sound.play_sfx(&"kill_pop")
	Sound.play_sfx(&"coin")
	Juice.confetti(global_position)
	Juice.coin_burst(global_position)
	Juice.floater("+%d" % bounty, global_position, Color(1.0, 0.79, 0.3, 1.0))
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


func _clear_skin_children() -> void:
	# queue_free is deferred — on pool reuse that stacks old black-backed sprites.
	while skin.get_child_count() > 0:
		var child: Node = skin.get_child(0)
		skin.remove_child(child)
		child.free()


func _build_skin() -> void:
	_clear_skin_children()

	var id := data.id if data != null else &"normal"
	var radius := data.radius_px if data != null else 26.0
	var body_tex: Texture2D = BODY_TEXTURES.get(id, BODY_TEXTURES[&"normal"]) as Texture2D

	var body := Sprite2D.new()
	body.name = "Body"
	body.texture = body_tex
	# Fit to diameter 2*radius with a little presence boost so archetypes read on grass.
	var target_px := 2.0 * radius * 1.15
	var body_scale := target_px / float(maxi(body_tex.get_width(), body_tex.get_height()))
	body.scale = Vector2(body_scale, body_scale)
	skin.add_child(body)

	# Candy body sprites already include faces — skip Kenney face overlay.
	if id == &"boss":
		_add_boss_crown(radius)

	_add_bubble_highlight(radius)

	skin.scale = Vector2.ONE
	skin.position = Vector2.ZERO


func _add_boss_crown(radius: float) -> void:
	var crown := Polygon2D.new()
	crown.name = "Crown"
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


func _add_bubble_highlight(radius: float) -> void:
	## Soft specular disc (no textured black square — particle shine sprites are opaque).
	var shine := Polygon2D.new()
	shine.name = "Shine"
	shine.color = Color(1.0, 1.0, 1.0, 0.55)
	var r := maxf(4.0, radius * 0.22)
	var pts := PackedVector2Array()
	for i: int in 12:
		var a := TAU * float(i) / 12.0
		pts.append(Vector2(cos(a), sin(a)) * r)
	shine.polygon = pts
	shine.position = Vector2(-radius * 0.32, -radius * 0.35)
	skin.add_child(shine)
