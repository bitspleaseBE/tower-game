class_name Tower
extends Node2D
## Auto-targeting tower. Stats from TowerData; Skin + RangeRing are visual only.

const BASE_SQUARE: Texture2D = preload("res://assets/tower/base_square.png")
const BASE_HEX: Texture2D = preload("res://assets/tower/base_hex.png")
const WEAPON_TEXTURES := {
	&"popper": preload("res://assets/tower/weapon_popper.png"),
	&"lobber": preload("res://assets/tower/weapon_lobber.png"),
	&"chiller": preload("res://assets/tower/weapon_chiller.png"),
	&"longshot": preload("res://assets/tower/weapon_longshot.png"),
}
const STREAM_DROPLETS := 4
const STREAM_SPEED := 420.0
const POOL_RADIUS := [42.0, 50.0, 58.0]
const POOL_LIFETIME := [2.2, 2.6, 3.0]

@onready var skin: Node2D = $Skin
@onready var range_ring: Node2D = $RangeRing
@onready var range_area: Area2D = $RangeArea
@onready var range_shape: CollisionShape2D = $RangeArea/CollisionShape2D

## Kenney weapon sprites face up (-Y) at rotation 0; Godot angles are from +X.
const WEAPON_FORWARD_OFFSET := PI * 0.5

var data: TowerData
var tier: int = 0
var total_spent: int = 0
var _cooldown: float = 0.0
var _range_circle: CircleShape2D
var _current_target: Enemy
var _retarget_timer: float = 0.0
var _weapon: Sprite2D
const RETARGET_INTERVAL := 0.1
const AIM_TURN_SPEED := 10.0 ## rad/s — Popper / Lobber
const AIM_TURN_SPEED_SNIPER := 16.0 ## rad/s — Longshot tracks faster
const AIM_ALIGN_RAD := 0.12 ## ~7° — must be on target before firing


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

	_aim_toward(_current_target, delta)

	if _cooldown > 0.0:
		return

	match data.behavior:
		TowerData.Behavior.SLOW:
			if _current_target == null:
				return
			if not _is_aimed_at(_current_target):
				return
			_fire_water_stream(_current_target)
			_cooldown = data.fire_interval[tier]
		_:
			if _current_target == null:
				return
			# Hold fire while the barrel is still swinging onto the target.
			if not _is_aimed_at(_current_target):
				return
			_fire(_current_target)
			_cooldown = data.fire_interval[tier]


func _aim_toward(target: Enemy, delta: float) -> void:
	if _weapon == null or target == null or not is_instance_valid(target) or not target.active:
		return
	var desired := _desired_aim(target)
	var turn := AIM_TURN_SPEED_SNIPER if data.behavior == TowerData.Behavior.SNIPER else AIM_TURN_SPEED
	_weapon.rotation = rotate_toward(_weapon.rotation, desired, turn * delta)


func _desired_aim(target: Enemy) -> float:
	var to := target.global_position - _weapon.global_position
	if to.length_squared() < 0.25:
		return _weapon.rotation
	return to.angle() + WEAPON_FORWARD_OFFSET


func _is_aimed_at(target: Enemy) -> bool:
	if _weapon == null or target == null or not is_instance_valid(target):
		return false
	return absf(angle_difference(_weapon.rotation, _desired_aim(target))) <= AIM_ALIGN_RAD


func _barrel_tip(length: float) -> Vector2:
	if _weapon == null:
		return global_position + Vector2(0.0, -length)
	var forward := Vector2.UP.rotated(_weapon.rotation)
	return _weapon.global_position + forward * length


func _target_still_valid() -> bool:
	if _current_target == null or not is_instance_valid(_current_target):
		return false
	if not _current_target.active:
		return false
	var range_px: float = data.range_px[tier]
	return global_position.distance_to(_current_target.global_position) <= range_px


func _pick_target() -> Enemy:
	## Closest in range — each tower tracks what's near it, not the path leader.
	var best: Enemy = null
	var best_dist_sq := INF
	var origin := global_position
	for area: Area2D in range_area.get_overlapping_areas():
		var enemy := area.get_parent() as Enemy
		if enemy == null or not enemy.active:
			continue
		var dist_sq := origin.distance_squared_to(enemy.global_position)
		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
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
	var barrel_tip := _barrel_tip(28.0)
	projectile.global_position = barrel_tip
	projectile.launch(target, data.damage[tier], data.projectile_speed, heavy)
	Sound.play_sfx(&"shot_longshot" if heavy else &"shot_popper")
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
	var barrel_tip := _barrel_tip(20.0)
	projectile.global_position = barrel_tip
	var splash: float = data.splash_radius_px[tier] if tier < data.splash_radius_px.size() else 70.0
	projectile.launch_lob(target.global_position, data.damage[tier], data.projectile_speed, splash)
	Sound.play_sfx(&"shot_lobber")
	Juice.squash(skin, Vector2(1.15, 0.75), 0.18)


func _fire_water_stream(target: Enemy) -> void:
	var game := get_tree().get_first_node_in_group("game")
	if game == null or not game.has_method("acquire_projectile"):
		return
	var factor: float = data.slow_factor[tier] if tier < data.slow_factor.size() else 0.65
	var duration: float = data.slow_duration[tier] if tier < data.slow_duration.size() else 1.2
	var pool_r: float = POOL_RADIUS[mini(tier, POOL_RADIUS.size() - 1)]
	var pool_life: float = POOL_LIFETIME[mini(tier, POOL_LIFETIME.size() - 1)]
	var barrel_tip := _barrel_tip(26.0)
	var heading := Vector2.UP.rotated(_weapon.rotation if _weapon != null else 0.0)
	var fired := 0
	for i: int in STREAM_DROPLETS:
		var projectile: Projectile = game.acquire_projectile()
		if projectile == null:
			break
		projectile.global_position = barrel_tip + heading * float(i) * 7.0
		# Only the trailing droplet leaves a puddle — the rest are stream body.
		var puddle_r := pool_r if i == STREAM_DROPLETS - 1 else 0.0
		projectile.launch_stream(heading, target, STREAM_SPEED, factor, duration, puddle_r, pool_life)
		fired += 1
	if fired <= 0:
		return
	Sound.play_sfx(&"shot_chiller")
	Juice.squash(skin, Vector2(1.12, 0.88), 0.12)


func _apply_tier_visuals() -> void:
	var range_px: float = data.range_px[tier]
	_range_circle.radius = range_px
	range_ring.set_meta("range_px", range_px)
	range_ring.queue_redraw()
	_rebuild_skin()


func _rebuild_skin() -> void:
	var prev_aim := _weapon.rotation if _weapon != null else 0.0
	while skin.get_child_count() > 0:
		var child: Node = skin.get_child(0)
		skin.remove_child(child)
		child.free()
	_weapon = null

	var scale_factor := 1.0 + float(tier) * 0.08
	var id := data.id if data != null else &"popper"
	var footprint := 58.0 * scale_factor

	var base := Sprite2D.new()
	base.name = "Base"
	base.texture = BASE_HEX if id == &"chiller" else BASE_SQUARE
	var base_scale := footprint / float(base.texture.get_width())
	base.scale = Vector2(base_scale, base_scale)
	base.self_modulate = Color.WHITE
	skin.add_child(base)

	_weapon = Sprite2D.new()
	_weapon.name = "Weapon"
	_weapon.texture = WEAPON_TEXTURES.get(id, WEAPON_TEXTURES[&"popper"]) as Texture2D
	var weapon_scale := (footprint * 1.1) / float(_weapon.texture.get_width())
	_weapon.scale = Vector2(weapon_scale, weapon_scale)
	_weapon.position = Vector2(0.0, -8.0 * scale_factor)
	_weapon.self_modulate = Color.WHITE
	_weapon.rotation = prev_aim
	skin.add_child(_weapon)

	_add_tier_stripes(scale_factor)
	_add_bubble_highlight(scale_factor)

	skin.scale = Vector2.ONE
	skin.position = Vector2.ZERO
	skin.modulate = Color.WHITE


func _add_tier_stripes(scale_factor: float) -> void:
	for s: int in tier + 1:
		var stripe := Polygon2D.new()
		stripe.color = Color(1.0, 0.84, 0.42, 1.0)
		var y := 10.0 * scale_factor + float(s) * 5.0
		stripe.polygon = PackedVector2Array([
			Vector2(-10, y), Vector2(10, y), Vector2(10, y + 3), Vector2(-10, y + 3),
		])
		skin.add_child(stripe)


func _add_bubble_highlight(scale_factor: float) -> void:
	var shine := Polygon2D.new()
	shine.name = "Shine"
	shine.color = Color(1.0, 1.0, 1.0, 0.55)
	var r := 5.0 * scale_factor
	var pts := PackedVector2Array()
	for i: int in 12:
		var a := TAU * float(i) / 12.0
		pts.append(Vector2(cos(a), sin(a)) * r)
	shine.polygon = pts
	shine.position = Vector2(-12.0 * scale_factor, -14.0 * scale_factor)
	skin.add_child(shine)


func _on_range_ring_draw() -> void:
	var range_px: float = float(range_ring.get_meta("range_px", 0.0))
	if range_px <= 0.0:
		return
	range_ring.draw_circle(Vector2.ZERO, range_px, Color(0.55, 0.82, 0.94, 0.18))
	range_ring.draw_arc(Vector2.ZERO, range_px, 0.0, TAU, 64, Color(0.55, 0.82, 0.94, 0.55), 3.0, true)
