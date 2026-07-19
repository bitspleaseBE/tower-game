class_name Tower
extends Node2D
## Auto-targeting tower. Stats from TowerData; Skin + RangeRing are visual only.

const ProjectileScene: PackedScene = preload("res://scenes/entities/projectile.tscn")

@onready var skin: Node2D = $Skin
@onready var range_ring: Node2D = $RangeRing
@onready var range_area: Area2D = $RangeArea
@onready var range_shape: CollisionShape2D = $RangeArea/CollisionShape2D

var data: TowerData
var tier: int = 0
var total_spent: int = 0
var _cooldown: float = 0.0
var _range_circle: CircleShape2D


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
	_play_build_bounce()


func upgrade() -> void:
	if tier >= 2:
		return
	tier += 1
	total_spent += data.cost[tier]
	_apply_tier_visuals()


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
	if _cooldown > 0.0:
		return
	var target := _pick_target()
	if target == null:
		return
	_fire(target)
	_cooldown = data.fire_interval[tier]


func _pick_target() -> Enemy:
	var best: Enemy = null
	var best_progress := -1.0
	for area: Area2D in range_area.get_overlapping_areas():
		var enemy := area.get_parent() as Enemy
		if enemy == null or not is_instance_valid(enemy):
			continue
		if enemy.progress > best_progress:
			best_progress = enemy.progress
			best = enemy
	return best


func _fire(target: Enemy) -> void:
	var projectile: Projectile = ProjectileScene.instantiate()
	var barrel_tip := global_position + Vector2(0, -28)
	var host: Node = get_tree().get_first_node_in_group("game")
	if host == null:
		host = get_parent()
	host.add_child(projectile)
	projectile.global_position = barrel_tip
	projectile.launch(target, data.damage[tier], data.projectile_speed)
	_play_recoil()


func _apply_tier_visuals() -> void:
	var range_px: float = data.range_px[tier]
	_range_circle.radius = range_px
	range_ring.set_meta("range_px", range_px)
	range_ring.queue_redraw()
	_rebuild_skin()


func _rebuild_skin() -> void:
	for child: Node in skin.get_children():
		child.queue_free()

	var scale_factor := 1.0 + float(tier) * 0.12
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

	# Barrel
	var barrel := Polygon2D.new()
	barrel.color = Color(0.31, 0.227, 0.357, 1.0)
	barrel.polygon = PackedVector2Array([
		Vector2(-5, -8), Vector2(5, -8), Vector2(4, -30 * scale_factor), Vector2(-4, -30 * scale_factor),
	])
	skin.add_child(barrel)

	# Tier stripes
	for s: int in tier + 1:
		var stripe := Polygon2D.new()
		stripe.color = Color(1.0, 0.84, 0.42, 1.0)
		var y := 8.0 + float(s) * 5.0
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


func _play_build_bounce() -> void:
	skin.scale = Vector2(0.5, 0.5)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(skin, "scale", Vector2.ONE, 0.25)


func _play_recoil() -> void:
	var tween := create_tween()
	tween.tween_property(skin, "position:y", 4.0, 0.04)
	tween.tween_property(skin, "position:y", 0.0, 0.08)


func _rounded_poly(radius: float, segments: int = 20) -> PackedVector2Array:
	var points := PackedVector2Array()
	points.resize(segments)
	for i: int in segments:
		var angle := TAU * float(i) / float(segments)
		points[i] = Vector2(cos(angle), sin(angle)) * radius
	return points
