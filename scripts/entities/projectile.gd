class_name Projectile
extends Area2D
## Pooled shot: HOMING (Popper/Longshot) or LOB (Lobber splash).

const LIFETIME_SECONDS := 1.5
const LOB_ARC_HEIGHT := 56.0
const SHOT_TEX: Texture2D = preload("res://assets/tower/projectile_shot.png")
const SHELL_TEX: Texture2D = preload("res://assets/tower/projectile_shell.png")

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
	if collision_shape:
		collision_shape.set_deferred("disabled", false)
	if heavy:
		# Longshot tracer read: stretched Skin along flight heading.
		skin.scale = Vector2(1.8, 0.55)
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
		# Overshoot guard: at ~1500 px/s a 60 Hz step is ~25 px — snap-hit.
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
	Juice.splash_ring(dest)
	Juice.confetti(dest)
	deactivate()


func _resolve_homing_hit(enemy: Enemy) -> void:
	if not _launched:
		return
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
	for child: Node in skin.get_children():
		child.queue_free()
	var tex: Texture2D = SHELL_TEX if mode == Mode.LOB else SHOT_TEX
	var spr := Sprite2D.new()
	spr.name = "Sprite"
	spr.texture = tex
	var target_px := 28.0 if mode == Mode.LOB else 18.0
	var spr_scale := target_px / float(tex.get_width())
	spr.scale = Vector2(spr_scale, spr_scale)
	skin.add_child(spr)
