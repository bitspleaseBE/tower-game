class_name Projectile
extends Area2D
## Pooled shot: HOMING (Popper/Longshot) or LOB (Lobber splash).
## Visual: chewing-gum bubble with blue / pink / purple / white swirl that pops on hit.

const LIFETIME_SECONDS := 1.5
const LOB_ARC_HEIGHT := 56.0
const SOFT_TEX: Texture2D = preload("res://assets/fx/particle_soft.png")

const GUM_BLUE := Color(0.55, 0.82, 0.98, 1.0)
const GUM_PINK := Color(1.0, 0.56, 0.72, 1.0)
const GUM_PURPLE := Color(0.78, 0.58, 0.95, 1.0)
const GUM_WHITE := Color(1.0, 0.98, 1.0, 1.0)
const GUM_PALETTE: Array[Color] = [GUM_BLUE, GUM_PINK, GUM_PURPLE, GUM_WHITE]

enum Mode { HOMING, LOB }

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


## Called on every pool acquire — wipe mode, skin, collision, and flight state.
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


func launch(target: Enemy, damage: float, speed: float, heavy := false) -> void:
	mode = Mode.HOMING
	_build_skin()
	_target = target
	_target_generation = target.generation if target != null else -1
	_damage = damage
	_speed = speed
	_alive_for = 0.0
	_launched = true
	_heavy_impact = heavy
	_wobble_phase = randf() * TAU
	if collision_shape:
		collision_shape.set_deferred("disabled", false)
	if heavy:
		# Longshot: slightly stretched gum slug, still reads as a bubble.
		skin.scale = Vector2(1.35, 0.85)
	if _target_valid():
		_heading = (_target.global_position - global_position).normalized()


func launch_lob(dest: Vector2, damage: float, speed: float, splash_radius: float) -> void:
	mode = Mode.LOB
	_build_skin()
	_target = null
	_target_generation = -1
	_damage = damage
	_speed = speed
	_splash_radius = splash_radius
	_lob_start = global_position
	_lob_dest = dest
	var distance := _lob_start.distance_to(_lob_dest)
	_lob_flight_time = clampf(distance / maxf(speed, 1.0), 0.25, 0.6)
	_lob_elapsed = 0.0
	_alive_for = 0.0
	_launched = true
	_heavy_impact = false
	_wobble_phase = randf() * TAU
	# Mortar must not clip enemies en route — damage only at detonation.
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	monitoring = false


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
	_wobble_phase += delta * 9.0
	var wobble := 1.0 + sin(_wobble_phase) * 0.08
	var base := Vector2(1.35, 0.85) if _heavy_impact else Vector2.ONE
	skin.scale = base * wobble

	if mode == Mode.LOB:
		_process_lob(delta)
		return

	_alive_for += delta
	if _alive_for >= LIFETIME_SECONDS:
		deactivate()
		return

	if _target_valid():
		var to_target := _target.global_position - global_position
		var dist := to_target.length()
		var step := _speed * delta
		# Overshoot guard: snap-hit when this frame's step reaches the target.
		if step >= dist and dist > 0.001:
			global_position = _target.global_position
			_resolve_homing_hit(_target)
			return
		if to_target.length_squared() > 0.001:
			_heading = to_target.normalized()
	elif _target != null:
		pass
	global_position += _heading * _speed * delta


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
	Juice.bubble_pop(dest, _bubble_color, true)
	Juice.confetti(dest)
	deactivate()


func _resolve_homing_hit(enemy: Enemy) -> void:
	if not _launched:
		return
	Juice.bubble_pop(global_position, _bubble_color, _heavy_impact)
	enemy.take_damage(_damage, _heavy_impact)
	deactivate()


func _target_valid() -> bool:
	return (
		_target != null
		and is_instance_valid(_target)
		and _target.active
		and _target.generation == _target_generation
	)


func _on_area_entered(area: Area2D) -> void:
	if not _launched or mode != Mode.HOMING:
		return
	var enemy := area.get_parent() as Enemy
	if enemy == null or not enemy.active:
		return
	_resolve_homing_hit(enemy)


func _build_skin() -> void:
	while skin.get_child_count() > 0:
		var child: Node = skin.get_child(0)
		skin.remove_child(child)
		child.free()

	var target_px := 40.0 if mode == Mode.LOB else 30.0
	_bubble_color = GUM_PALETTE[randi() % GUM_PALETTE.size()]
	var swirl: Array[Color] = [
		GUM_BLUE,
		GUM_PINK,
		GUM_PURPLE,
		GUM_WHITE,
	]
	swirl.shuffle()

	var bubble := Node2D.new()
	bubble.name = "Bubble"
	var radius := target_px * 0.5
	var c0: Color = _bubble_color
	var c1: Color = swirl[0]
	var c2: Color = swirl[1]
	var c3: Color = swirl[2]
	bubble.set_meta("r", radius)
	bubble.set_meta("c0", c0)
	bubble.set_meta("c1", c1)
	bubble.set_meta("c2", c2)
	bubble.set_meta("c3", c3)
	bubble.draw.connect(func() -> void:
		var r: float = float(bubble.get_meta("r"))
		var base: Color = bubble.get_meta("c0") as Color
		var a: Color = bubble.get_meta("c1") as Color
		var b: Color = bubble.get_meta("c2") as Color
		var c: Color = bubble.get_meta("c3") as Color
		# Opaque gum body + candy swirl lobes + glossy rim.
		bubble.draw_circle(Vector2.ZERO, r, base)
		bubble.draw_circle(Vector2(-r * 0.28, -r * 0.18), r * 0.55, Color(a.r, a.g, a.b, 0.85))
		bubble.draw_circle(Vector2(r * 0.32, r * 0.22), r * 0.42, Color(b.r, b.g, b.b, 0.8))
		bubble.draw_circle(Vector2(r * 0.05, -r * 0.08), r * 0.28, Color(c.r, c.g, c.b, 0.75))
		bubble.draw_arc(Vector2.ZERO, r * 0.92, 0.0, TAU, 32, Color(1.0, 1.0, 1.0, 0.35), 2.0, true)
		bubble.draw_circle(Vector2(-r * 0.35, -r * 0.4), r * 0.18, Color(1.0, 1.0, 1.0, 0.75))
	)
	bubble.queue_redraw()
	skin.add_child(bubble)

	# Soft outer halo so the bubble still reads as floaty gum.
	var halo := _soft_disc(target_px * 1.15, Color(_bubble_color.r, _bubble_color.g, _bubble_color.b, 0.35))
	halo.name = "Halo"
	halo.z_index = -1
	skin.add_child(halo)


func _soft_disc(diameter_px: float, tint: Color) -> Sprite2D:
	var spr := Sprite2D.new()
	spr.texture = SOFT_TEX
	var spr_scale := diameter_px / float(SOFT_TEX.get_width())
	spr.scale = Vector2(spr_scale, spr_scale)
	spr.modulate = tint
	return spr
