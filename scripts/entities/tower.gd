class_name Tower
extends Node2D
## Auto-targeting tower. Stats from TowerData; Skin + RangeRing are visual only.

@onready var skin: Node2D = $Skin
@onready var range_ring: Node2D = $RangeRing
@onready var range_area: Area2D = $RangeArea
@onready var range_shape: CollisionShape2D = $RangeArea/CollisionShape2D

var data: TowerData
var tier: int = 0
var total_spent: int = 0
var _cooldown: float = 0.0
var _range_circle: CircleShape2D
var _current_target: Enemy
var _retarget_timer: float = 0.0
const RETARGET_INTERVAL := 0.1


func _ready() -> void:
	add_to_group("towers")
	range_area.collision_layer = 0
	range_area.collision_mask = 1
	range_area.monitoring = true
	_range_circle = CircleShape2D.new()
	range_shape.shape = _range_circle
	range_ring.visible = false
	range_ring.set_meta("range_px", 0.0)
	range_ring.draw.connect(_on_range_ring_draw)


func setup(tower_data: TowerData) -> void:
	data = tower_data
	tier = 0
	total_spent = data.cost[0]
	_apply_tier_visuals()
	Juice.claim(skin)
	Juice.bounce_in(skin)


func upgrade() -> void:
	if tier >= 2:
		return
	tier += 1
	total_spent += data.cost[tier]
	_apply_tier_visuals()
	Juice.claim(skin)
	Juice.upgrade_fx(self)


func sell_refund() -> int:
	return floori(float(total_spent) * data.sell_refund_ratio)


func show_range(show: bool) -> void:
	range_ring.visible = show
	if show:
		range_ring.queue_redraw()


func _physics_process(delta: float) -> void:
	if data == null:
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	_retarget_timer = maxf(0.0, _retarget_timer - delta)

	if not _target_still_valid():
		_current_target = null

	if _retarget_timer <= 0.0 or _current_target == null:
		_current_target = _pick_target()
		_retarget_timer = RETARGET_INTERVAL

	if _cooldown > 0.0:
		return

	match data.behavior:
		TowerData.Behavior.SLOW:
			if _has_any_in_range():
				_fire_slow_pulse()
				_cooldown = data.fire_interval[tier]
		_:
			if _current_target == null:
				return
			_fire(_current_target)
			_cooldown = data.fire_interval[tier]


func _target_still_valid() -> bool:
	if _current_target == null or not is_instance_valid(_current_target):
		return false
	if not _current_target.active:
		return false
	var range_px: float = data.range_px[tier]
	return global_position.distance_to(_current_target.global_position) <= range_px


func _pick_target() -> Enemy:
	var best: Enemy = null
	var best_progress := -1.0
	for area: Area2D in range_area.get_overlapping_areas():
		var enemy := area.get_parent() as Enemy
		if enemy == null or not enemy.active:
			continue
		if enemy.progress > best_progress:
			best_progress = enemy.progress
			best = enemy
	return best


func _has_any_in_range() -> bool:
	for area: Area2D in range_area.get_overlapping_areas():
		var enemy := area.get_parent() as Enemy
		if enemy != null and enemy.active:
			return true
	return false


func _fire(target: Enemy) -> void:
	match data.behavior:
		TowerData.Behavior.SPLASH:
			_fire_lob(target)
		TowerData.Behavior.SNIPER:
			_fire_homing(target, true)
		_:
			_fire_homing(target, false)


func _fire_homing(target: Enemy, heavy: bool) -> void:
	var game := get_tree().get_first_node_in_group("game")
	if game == null or not game.has_method("acquire_projectile"):
		return
	var projectile: Projectile = game.acquire_projectile()
	if projectile == null:
		return
	var barrel_tip := global_position + Vector2(0, -28)
	projectile.global_position = barrel_tip
	projectile.launch(target, data.damage[tier], data.projectile_speed, heavy)
	if heavy:
		Juice.muzzle_flash(barrel_tip)
	Juice.squash(skin)


func _fire_lob(target: Enemy) -> void:
	var game := get_tree().get_first_node_in_group("game")
	if game == null or not game.has_method("acquire_projectile"):
		return
	var projectile: Projectile = game.acquire_projectile()
	if projectile == null:
		return
	var barrel_tip := global_position + Vector2(0, -20)
	projectile.global_position = barrel_tip
	var splash: float = data.splash_radius_px[tier] if tier < data.splash_radius_px.size() else 70.0
	projectile.launch_lob(target.global_position, data.damage[tier], data.projectile_speed, splash)
	Juice.squash(skin, Vector2(1.15, 0.75), 0.18)


func _fire_slow_pulse() -> void:
	var factor: float = data.slow_factor[tier] if tier < data.slow_factor.size() else 0.65
	var duration: float = data.slow_duration[tier] if tier < data.slow_duration.size() else 1.2
	var dmg: float = data.damage[tier]
	for area: Area2D in range_area.get_overlapping_areas():
		var enemy := area.get_parent() as Enemy
		if enemy == null or not enemy.active:
			continue
		enemy.apply_slow(factor, duration)
		if dmg > 0.0:
			enemy.take_damage(dmg)
	Juice.frost_pulse(global_position, data.range_px[tier])
	Juice.squash(skin, Vector2(1.1, 0.9), 0.12)


func _apply_tier_visuals() -> void:
	var range_px: float = data.range_px[tier]
	_range_circle.radius = range_px
	range_ring.set_meta("range_px", range_px)
	range_ring.queue_redraw()
	_rebuild_skin()


func _rebuild_skin() -> void:
	for child: Node in skin.get_children():
		child.queue_free()

	var scale_factor := 1.0 + float(tier) * 0.08
	var id := data.id if data != null else &"popper"

	match id:
		&"lobber":
			_build_lobber_skin(scale_factor)
		&"chiller":
			_build_chiller_skin(scale_factor)
		&"longshot":
			_build_longshot_skin(scale_factor)
		_:
			_build_popper_skin(scale_factor)

	_add_tier_stripes(scale_factor)
	skin.scale = Vector2.ONE
	skin.position = Vector2.ZERO
	skin.modulate = Color.WHITE


func _build_popper_skin(scale_factor: float) -> void:
	# Round base + short stubby barrel, pink/coral.
	var base_r := 22.0 * scale_factor
	var base := Polygon2D.new()
	base.color = Color(1.0, 0.56, 0.69, 1.0)
	base.polygon = _rounded_poly(base_r)
	skin.add_child(base)

	var top := Polygon2D.new()
	top.color = Color(1.0, 0.72, 0.82, 1.0)
	top.polygon = _rounded_poly(base_r * 0.72)
	top.position = Vector2(0, -4)
	skin.add_child(top)

	var barrel := Polygon2D.new()
	barrel.color = Color(0.31, 0.227, 0.357, 1.0)
	barrel.polygon = PackedVector2Array([
		Vector2(-5, -8), Vector2(5, -8), Vector2(4, -28 * scale_factor), Vector2(-4, -28 * scale_factor),
	])
	skin.add_child(barrel)


func _build_lobber_skin(scale_factor: float) -> void:
	# Squat wide dome + fat up-angled tube, sunny #FFD66B.
	var base_r := 26.0 * scale_factor
	var base := Polygon2D.new()
	base.color = Color(1.0, 0.839, 0.42, 1.0)
	base.polygon = _rounded_poly(base_r, 16)
	base.scale = Vector2(1.15, 0.75)
	skin.add_child(base)

	var dome := Polygon2D.new()
	dome.color = Color(1.0, 0.92, 0.65, 1.0)
	dome.polygon = _rounded_poly(base_r * 0.7, 14)
	dome.position = Vector2(0, -6)
	skin.add_child(dome)

	var tube := Polygon2D.new()
	tube.color = Color(0.75, 0.45, 0.2, 1.0)
	tube.polygon = PackedVector2Array([
		Vector2(-8, -4), Vector2(8, -4), Vector2(14, -32 * scale_factor), Vector2(2, -34 * scale_factor),
	])
	skin.add_child(tube)


func _build_chiller_skin(scale_factor: float) -> void:
	# Hexagonal crystal with 3 small orbit dots, sky #8DD0F0.
	var base_r := 22.0 * scale_factor
	var crystal := Polygon2D.new()
	crystal.color = Color(0.553, 0.816, 0.941, 1.0)
	crystal.polygon = _regular_poly(6, base_r)
	skin.add_child(crystal)

	var core := Polygon2D.new()
	core.color = Color(0.75, 0.92, 1.0, 1.0)
	core.polygon = _regular_poly(6, base_r * 0.55)
	skin.add_child(core)

	for i: int in 3:
		var dot := Polygon2D.new()
		dot.color = Color(0.4, 0.7, 0.95, 1.0)
		dot.polygon = _rounded_poly(4.0 * scale_factor, 10)
		var angle := TAU * float(i) / 3.0 - PI * 0.5
		dot.position = Vector2(cos(angle), sin(angle)) * (base_r + 8.0)
		skin.add_child(dot)


func _build_longshot_skin(scale_factor: float) -> void:
	# Narrow tall base + one long thin barrel, lilac #BFA0E8.
	var base_r := 16.0 * scale_factor
	var base := Polygon2D.new()
	base.color = Color(0.749, 0.627, 0.91, 1.0)
	base.polygon = _rounded_poly(base_r, 14)
	base.scale = Vector2(0.7, 1.25)
	skin.add_child(base)

	var barrel := Polygon2D.new()
	barrel.color = Color(0.4, 0.3, 0.55, 1.0)
	barrel.polygon = PackedVector2Array([
		Vector2(-3, -10), Vector2(3, -10), Vector2(2, -48 * scale_factor), Vector2(-2, -48 * scale_factor),
	])
	skin.add_child(barrel)

	var tip := Polygon2D.new()
	tip.color = Color(0.9, 0.8, 1.0, 1.0)
	tip.polygon = _rounded_poly(4.0 * scale_factor, 8)
	tip.position = Vector2(0, -48 * scale_factor)
	skin.add_child(tip)


func _add_tier_stripes(scale_factor: float) -> void:
	for s: int in tier + 1:
		var stripe := Polygon2D.new()
		stripe.color = Color(1.0, 0.84, 0.42, 1.0)
		var y := 10.0 * scale_factor + float(s) * 5.0
		stripe.polygon = PackedVector2Array([
			Vector2(-10, y), Vector2(10, y), Vector2(10, y + 3), Vector2(-10, y + 3),
		])
		skin.add_child(stripe)


func _on_range_ring_draw() -> void:
	var range_px: float = float(range_ring.get_meta("range_px", 0.0))
	if range_px <= 0.0:
		return
	range_ring.draw_circle(Vector2.ZERO, range_px, Color(0.55, 0.82, 0.94, 0.18))
	range_ring.draw_arc(Vector2.ZERO, range_px, 0.0, TAU, 64, Color(0.55, 0.82, 0.94, 0.55), 3.0, true)


func _rounded_poly(radius: float, segments: int = 20) -> PackedVector2Array:
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
