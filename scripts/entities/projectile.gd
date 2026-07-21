class_name Projectile
extends Area2D
## Pooled shot: HOMING / LOB / STREAM / PIERCE. Skins: gum bubble, balloon, laser, water drop.

const LIFETIME_SECONDS := 1.5
const STREAM_LIFETIME := 0.55
const LOB_ARC_HEIGHT := 56.0
const SOFT_TEX: Texture2D = preload("res://assets/fx/particle_soft.png")
const LASER_TEX: Texture2D = preload("res://assets/tower/projectile_laser.png")
const BALLOON_TEX: Texture2D = preload("res://assets/tower/projectile_balloon.png")
const WATER_DROP_TEX: Texture2D = preload("res://assets/fx/particle_water_drop.png")

const GUM_BLUE := Color(0.55, 0.82, 0.98, 1.0)
const GUM_PINK := Color(1.0, 0.56, 0.72, 1.0)
const GUM_PURPLE := Color(0.78, 0.58, 0.95, 1.0)
const GUM_WHITE := Color(1.0, 0.98, 1.0, 1.0)
const GUM_PALETTE: Array[Color] = [GUM_BLUE, GUM_PINK, GUM_PURPLE, GUM_WHITE]

enum Mode { HOMING, LOB, STREAM, PIERCE }

@onready var skin: Node2D = $Skin
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var mode: Mode = Mode.HOMING
var _target: Enemy
var _target_generation: int = -1
var _damage: float = 0.0
var _speed: float = 0.0
var _heading: Vector2 = Vector2.RIGHT
var _alive_for: float = 0.0
var _launched: bool = false
var _signals_wired := false
var _splash_radius: float = 0.0
var _lob_start: Vector2 = Vector2.ZERO
var _lob_dest: Vector2 = Vector2.ZERO
var _lob_flight_time: float = 0.4
var _lob_elapsed: float = 0.0
var _heavy_impact: bool = false
var _bubble_color: Color = GUM_PINK
var _wobble_phase: float = 0.0
var _slow_factor: float = 0.65
var _slow_duration: float = 1.2
var _pool_radius: float = 48.0
var _pool_lifetime: float = 2.4
var _stun_duration: float = 0.0
var _max_travel: float = 0.0
var _traveled: float = 0.0
var _pierce_hits: Dictionary = {} ## instance_id -> true; each enemy takes pierce damage once


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	_wire_signals_once()
	if skin.get_child_count() == 0:
		_build_skin()
	if not _launched:
		visible = false
		process_mode = Node.PROCESS_MODE_DISABLED
		monitoring = false


func _wire_signals_once() -> void:
	if _signals_wired:
		return
	_signals_wired = true
	area_entered.connect(_on_area_entered)


func reset() -> void:
	mode = Mode.HOMING
	_target = null
	_target_generation = -1
	_damage = 0.0
	_speed = 0.0
	_heading = Vector2.RIGHT
	_alive_for = 0.0
	_launched = false
	_splash_radius = 0.0
	_lob_elapsed = 0.0
	_lob_flight_time = 0.4
	_heavy_impact = false
	_bubble_color = GUM_PINK
	_wobble_phase = 0.0
	_slow_factor = 0.65
	_slow_duration = 1.2
	_pool_radius = 48.0
	_pool_lifetime = 2.4
	_stun_duration = 0.0
	_max_travel = 0.0
	_traveled = 0.0
	_pierce_hits.clear()
	skin.position = Vector2.ZERO
	skin.scale = Vector2.ONE
	skin.modulate = Color.WHITE
	skin.rotation = 0.0
	if collision_shape:
		collision_shape.set_deferred("disabled", false)


func activate() -> void:
	reset()
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	monitoring = true
	set_deferred("monitorable", false)


func launch(target: Enemy, damage: float, speed: float, heavy := false, splash_radius := 0.0) -> void:
	mode = Mode.HOMING
	_heavy_impact = heavy
	_build_skin()
	_target = target
	_target_generation = target.generation if target != null else -1
	_damage = damage
	_speed = speed
	_splash_radius = splash_radius
	_alive_for = 0.0
	_launched = true
	_wobble_phase = randf() * TAU
	if collision_shape:
		collision_shape.set_deferred("disabled", false)
	if heavy:
		skin.scale = Vector2(1.0, 1.55)
	if _target_valid():
		_heading = (_target.global_position - global_position).normalized()
		_orient_skin_to_heading()


func launch_lob(dest: Vector2, damage: float, speed: float, splash_radius: float, stun_duration := 0.0) -> void:
	mode = Mode.LOB
	_heavy_impact = false
	_build_skin()
	_target = null
	_target_generation = -1
	_damage = damage
	_speed = speed
	_splash_radius = splash_radius
	_stun_duration = stun_duration
	_lob_start = global_position
	_lob_dest = dest
	var distance := _lob_start.distance_to(_lob_dest)
	_lob_flight_time = clampf(distance / maxf(speed, 1.0), 0.25, 0.6)
	_lob_elapsed = 0.0
	_alive_for = 0.0
	_launched = true
	_wobble_phase = randf() * TAU
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	monitoring = false


func launch_stream(
	heading: Vector2,
	target: Enemy,
	speed: float,
	slow_factor: float,
	slow_duration: float,
	pool_radius: float,
	pool_lifetime: float,
	damage := 0.0,
) -> void:
	mode = Mode.STREAM
	_heavy_impact = false
	_build_skin()
	_target = target
	_target_generation = target.generation if target != null else -1
	_damage = damage
	_speed = speed
	_heading = heading.normalized() if heading.length_squared() > 0.001 else Vector2.UP
	_slow_factor = slow_factor
	_slow_duration = slow_duration
	_pool_radius = pool_radius
	_pool_lifetime = pool_lifetime
	_alive_for = 0.0
	_launched = true
	_wobble_phase = randf() * TAU
	_orient_skin_to_heading()
	if collision_shape:
		collision_shape.set_deferred("disabled", false)
	monitoring = true


func launch_pierce(heading: Vector2, damage: float, speed: float, max_travel: float) -> void:
	mode = Mode.PIERCE
	_heavy_impact = true
	_build_skin()
	_target = null
	_target_generation = -1
	_damage = damage
	_speed = speed
	_heading = heading.normalized() if heading.length_squared() > 0.001 else Vector2.UP
	_max_travel = max_travel
	_traveled = 0.0
	_pierce_hits.clear()
	_alive_for = 0.0
	_launched = true
	_wobble_phase = randf() * TAU
	skin.scale = Vector2(1.0, 1.55)
	_orient_skin_to_heading()
	if collision_shape:
		collision_shape.set_deferred("disabled", false)
	monitoring = true


func deactivate() -> void:
	_launched = false
	_target = null
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	monitoring = false
	if collision_shape:
		collision_shape.set_deferred("disabled", false)
	var game := get_tree().get_first_node_in_group("game")
	if game != null and game.has_method("release_projectile"):
		game.release_projectile(self)


func _physics_process(delta: float) -> void:
	if not _launched:
		return

	if mode == Mode.LOB:
		_wobble_phase += delta * 9.0
		skin.scale = Vector2.ONE * (1.0 + sin(_wobble_phase) * 0.08)
		_process_lob(delta)
		return

	if mode == Mode.STREAM:
		_process_stream(delta)
		return

	if mode == Mode.PIERCE:
		_process_pierce(delta)
		return

	# HOMING
	_wobble_phase += delta * 9.0
	if _heavy_impact:
		skin.scale = Vector2(1.0, 1.55) * (1.0 + sin(_wobble_phase) * 0.04)
		_orient_skin_to_heading()
	else:
		skin.scale = Vector2.ONE * (1.0 + sin(_wobble_phase) * 0.08)

	_alive_for += delta
	if _alive_for >= LIFETIME_SECONDS:
		deactivate()
		return

	if _target_valid():
		var to_target := _target.global_position - global_position
		var dist := to_target.length()
		var step := _speed * delta
		if step >= dist and dist > 0.001:
			global_position = _target.global_position
			_resolve_homing_hit(_target)
			return
		if to_target.length_squared() > 0.001:
			_heading = to_target.normalized()
	global_position += _heading * _speed * delta


func _process_stream(delta: float) -> void:
	_alive_for += delta
	_wobble_phase += delta * 14.0
	skin.scale = Vector2.ONE * (0.85 + sin(_wobble_phase) * 0.1)
	# Light home so the hose tracks a moving critter.
	if _target_valid():
		var to_target := (_target.global_position - global_position).normalized()
		_heading = _heading.lerp(to_target, clampf(8.0 * delta, 0.0, 1.0)).normalized()
		var dist := global_position.distance_to(_target.global_position)
		var step := _speed * delta
		if step >= dist and dist > 0.001:
			global_position = _target.global_position
			_resolve_stream_impact()
			return
	_orient_skin_to_heading()
	global_position += _heading * _speed * delta
	if _alive_for >= STREAM_LIFETIME:
		_resolve_stream_impact()


func _process_pierce(delta: float) -> void:
	_alive_for += delta
	_wobble_phase += delta * 9.0
	skin.scale = Vector2(1.0, 1.55) * (1.0 + sin(_wobble_phase) * 0.04)
	var step := _speed * delta
	global_position += _heading * step
	_traveled += step
	if _traveled >= _max_travel or _alive_for >= LIFETIME_SECONDS:
		deactivate()


func _process_lob(delta: float) -> void:
	_lob_elapsed += delta
	var t := clampf(_lob_elapsed / _lob_flight_time, 0.0, 1.0)
	global_position = _lob_start.lerp(_lob_dest, t)
	skin.position.y = -sin(t * PI) * LOB_ARC_HEIGHT
	if t >= 1.0:
		_detonate_splash()


func _detonate_splash() -> void:
	if not _launched:
		return
	_launched = false
	var dest := _lob_dest
	var radius_sq := _splash_radius * _splash_radius
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or not enemy.active:
			continue
		if enemy.global_position.distance_squared_to(dest) <= radius_sq:
			enemy.take_damage(_damage)
			# Tier-3 lobber: splash also pins critters in place for a beat.
			if _stun_duration > 0.0 and enemy.active:
				enemy.apply_slow(0.05, _stun_duration)
	Juice.bubble_pop(dest, GUM_BLUE, true)
	Juice.confetti(dest)
	deactivate()


func _resolve_homing_hit(enemy: Enemy) -> void:
	if not _launched:
		return
	_launched = false
	if _heavy_impact:
		Juice.laser_hit(global_position)
	else:
		Juice.bubble_pop(global_position, _bubble_color, false)
	enemy.take_damage(_damage, _heavy_impact)
	# Tier-3 popper: the hit bursts, splashing damage onto nearby critters.
	if _splash_radius > 0.0:
		var hit_pos := global_position
		var radius_sq := _splash_radius * _splash_radius
		for node: Node in get_tree().get_nodes_in_group("enemies"):
			var other := node as Enemy
			if other == null or other == enemy or not other.active:
				continue
			if other.global_position.distance_squared_to(hit_pos) <= radius_sq:
				other.take_damage(_damage)
		Juice.bubble_pop(hit_pos, _bubble_color, true)
		Juice.confetti(hit_pos)
	set_deferred("monitoring", false)
	call_deferred("deactivate")


func _resolve_pierce_hit(enemy: Enemy) -> void:
	## Damages each enemy once, then keeps flying — no deactivate on hit.
	var key := enemy.get_instance_id()
	if _pierce_hits.has(key):
		return
	_pierce_hits[key] = true
	Juice.laser_hit(global_position)
	enemy.take_damage(_damage, true)


func _resolve_stream_impact() -> void:
	if not _launched:
		return
	_launched = false
	var hit_pos := global_position
	if _target_valid():
		hit_pos = _target.global_position
		_target.apply_slow(_slow_factor, _slow_duration)
		# Tier-3 chiller: trailing droplet stings once per pulse.
		if _damage > 0.0:
			_target.take_damage(_damage)
	_spawn_water_pool(hit_pos)
	set_deferred("monitoring", false)
	call_deferred("deactivate")


func _spawn_water_pool(world_pos: Vector2) -> void:
	if _pool_radius <= 0.5:
		return
	var game := get_tree().get_first_node_in_group("game")
	if game == null or not game.has_method("acquire_water_pool"):
		return
	var pool: WaterPool = game.acquire_water_pool()
	if pool == null:
		return
	pool.activate(world_pos, _pool_radius, _slow_factor, _slow_duration, _pool_lifetime)


func _target_valid() -> bool:
	return (
		_target != null
		and is_instance_valid(_target)
		and _target.active
		and _target.generation == _target_generation
	)


func _on_area_entered(area: Area2D) -> void:
	if not _launched:
		return
	var enemy := area.get_parent() as Enemy
	if enemy == null or not enemy.active:
		return
	if mode == Mode.HOMING:
		_resolve_homing_hit(enemy)
	elif mode == Mode.STREAM:
		_resolve_stream_impact()
	elif mode == Mode.PIERCE:
		_resolve_pierce_hit(enemy)


func _orient_skin_to_heading() -> void:
	# Sprites point up (-Y) at rotation 0.
	skin.rotation = _heading.angle() + PI * 0.5


func _build_skin() -> void:
	while skin.get_child_count() > 0:
		var child: Node = skin.get_child(0)
		skin.remove_child(child)
		child.free()

	if mode == Mode.STREAM:
		_build_water_drop_skin()
		return
	if mode == Mode.LOB:
		_build_balloon_skin()
		return
	if _heavy_impact:
		_build_laser_skin()
		return
	_build_gum_bubble_skin()


func _build_gum_bubble_skin() -> void:
	var target_px := 30.0
	_bubble_color = GUM_PALETTE[randi() % GUM_PALETTE.size()]
	var swirl: Array[Color] = [GUM_BLUE, GUM_PINK, GUM_PURPLE, GUM_WHITE]
	swirl.shuffle()

	var bubble := Node2D.new()
	bubble.name = "Bubble"
	var radius := target_px * 0.5
	bubble.set_meta("r", radius)
	bubble.set_meta("c0", _bubble_color)
	bubble.set_meta("c1", swirl[0])
	bubble.set_meta("c2", swirl[1])
	bubble.set_meta("c3", swirl[2])
	bubble.draw.connect(func() -> void:
		var r: float = float(bubble.get_meta("r"))
		var base: Color = bubble.get_meta("c0") as Color
		var a: Color = bubble.get_meta("c1") as Color
		var b: Color = bubble.get_meta("c2") as Color
		var c: Color = bubble.get_meta("c3") as Color
		bubble.draw_circle(Vector2.ZERO, r, base)
		bubble.draw_circle(Vector2(-r * 0.28, -r * 0.18), r * 0.55, Color(a.r, a.g, a.b, 0.85))
		bubble.draw_circle(Vector2(r * 0.32, r * 0.22), r * 0.42, Color(b.r, b.g, b.b, 0.8))
		bubble.draw_circle(Vector2(r * 0.05, -r * 0.08), r * 0.28, Color(c.r, c.g, c.b, 0.75))
		bubble.draw_arc(Vector2.ZERO, r * 0.92, 0.0, TAU, 32, Color(1.0, 1.0, 1.0, 0.35), 2.0, true)
		bubble.draw_circle(Vector2(-r * 0.35, -r * 0.4), r * 0.18, Color(1.0, 1.0, 1.0, 0.75))
	)
	bubble.queue_redraw()
	skin.add_child(bubble)
	var halo := _soft_disc(target_px * 1.15, Color(_bubble_color.r, _bubble_color.g, _bubble_color.b, 0.35))
	halo.name = "Halo"
	halo.z_index = -1
	skin.add_child(halo)


func _build_laser_skin() -> void:
	var spr := Sprite2D.new()
	spr.name = "Laser"
	spr.texture = LASER_TEX
	var spr_scale := 36.0 / float(LASER_TEX.get_height())
	spr.scale = Vector2(spr_scale * 0.85, spr_scale)
	skin.add_child(spr)
	var glow := _soft_disc(22.0, Color(1.0, 0.25, 0.35, 0.45))
	glow.name = "Glow"
	glow.z_index = -1
	skin.add_child(glow)


func _build_balloon_skin() -> void:
	var spr := Sprite2D.new()
	spr.name = "Balloon"
	spr.texture = BALLOON_TEX
	var spr_scale := 40.0 / float(BALLOON_TEX.get_width())
	spr.scale = Vector2(spr_scale, spr_scale)
	skin.add_child(spr)


func _build_water_drop_skin() -> void:
	var spr := Sprite2D.new()
	spr.name = "Drop"
	spr.texture = WATER_DROP_TEX
	var spr_scale := 22.0 / float(WATER_DROP_TEX.get_width())
	spr.scale = Vector2(spr_scale, spr_scale)
	spr.modulate = Color(0.7, 0.92, 1.0, 0.95)
	skin.add_child(spr)


func _soft_disc(diameter_px: float, tint: Color) -> Sprite2D:
	var spr := Sprite2D.new()
	spr.texture = SOFT_TEX
	var spr_scale := diameter_px / float(SOFT_TEX.get_width())
	spr.scale = Vector2(spr_scale, spr_scale)
	spr.modulate = tint
	return spr
