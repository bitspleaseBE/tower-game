class_name WaterPool
extends Area2D
## Short-lived puddle that re-applies slow to overlapping enemies.

const POOL_TEX: Texture2D = preload("res://assets/fx/particle_water_pool.png")

@onready var skin: Node2D = $Skin
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var _active := false
var _radius := 48.0
var _slow_factor := 0.65
var _slow_duration := 1.2
var _lifetime := 2.4
var _age := 0.0
var _circle: CircleShape2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	monitorable = false
	# Sit on the path under critters — not painted over them.
	z_index = -2
	_circle = CircleShape2D.new()
	collision_shape.shape = _circle
	if not _active:
		visible = false
		process_mode = Node.PROCESS_MODE_DISABLED
		monitoring = false


func reset() -> void:
	_active = false
	_age = 0.0
	skin.modulate = Color.WHITE
	skin.scale = Vector2.ONE


func activate(
	world_pos: Vector2,
	radius: float,
	slow_factor: float,
	slow_duration: float,
	lifetime: float,
) -> void:
	reset()
	global_position = world_pos
	_radius = radius
	_slow_factor = slow_factor
	_slow_duration = slow_duration
	_lifetime = lifetime
	_age = 0.0
	_active = true
	_circle.radius = radius
	_rebuild_skin()
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	monitoring = true
	Juice.water_splash(world_pos)


func deactivate() -> void:
	_active = false
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	monitoring = false
	var game := get_tree().get_first_node_in_group("game")
	if game != null and game.has_method("release_water_pool"):
		game.release_water_pool(self)


func _physics_process(delta: float) -> void:
	if not _active:
		return
	_age += delta
	var fade := 1.0 - clampf(_age / _lifetime, 0.0, 1.0)
	skin.modulate = Color(1.0, 1.0, 1.0, 0.35 + fade * 0.55)
	skin.scale = Vector2.ONE * (0.85 + fade * 0.2)
	for area: Area2D in get_overlapping_areas():
		var enemy := area.get_parent() as Enemy
		if enemy == null or not enemy.active:
			continue
		enemy.apply_slow(_slow_factor, _slow_duration)
	if _age >= _lifetime:
		deactivate()


func _rebuild_skin() -> void:
	while skin.get_child_count() > 0:
		var child: Node = skin.get_child(0)
		skin.remove_child(child)
		child.free()
	var spr := Sprite2D.new()
	spr.texture = POOL_TEX
	var spr_scale := (_radius * 2.2) / float(POOL_TEX.get_width())
	spr.scale = Vector2(spr_scale, spr_scale * 0.72)
	spr.modulate = Color(0.55, 0.85, 1.0, 0.85)
	skin.add_child(spr)
