class_name Projectile
extends Area2D
## Homing shot from ObjectPool. Validity uses target.active + generation.

const LIFETIME_SECONDS := 1.5

@onready var skin: Node2D = $Skin

var _target: Enemy
var _target_generation: int = -1
var _damage: float = 0.0
var _speed: float = 0.0
var _heading: Vector2 = Vector2.RIGHT
var _alive_for: float = 0.0
var _launched: bool = false
var _signals_wired := false


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


func activate() -> void:
	_alive_for = 0.0
	_launched = false
	_target = null
	_target_generation = -1
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	monitoring = true
	set_deferred("monitorable", false)


func launch(target: Enemy, damage: float, speed: float) -> void:
	_target = target
	_target_generation = target.generation if target != null else -1
	_damage = damage
	_speed = speed
	_alive_for = 0.0
	_launched = true
	if _target_valid():
		_heading = (_target.global_position - global_position).normalized()


func deactivate() -> void:
	_launched = false
	_target = null
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	monitoring = false
	var game := get_tree().get_first_node_in_group("game")
	if game != null and game.has_method("release_projectile"):
		game.release_projectile(self)


func _physics_process(delta: float) -> void:
	if not _launched:
		return
	_alive_for += delta
	if _alive_for >= LIFETIME_SECONDS:
		deactivate()
		return

	if _target_valid():
		var to_target := _target.global_position - global_position
		if to_target.length_squared() > 0.001:
			_heading = to_target.normalized()
	elif _target != null:
		# Keep last heading for remainder of lifetime when target dies/recycles.
		pass
	global_position += _heading * _speed * delta


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
	enemy.take_damage(_damage)
	deactivate()


func _build_skin() -> void:
	for child: Node in skin.get_children():
		child.queue_free()
	var blob := Polygon2D.new()
	blob.color = Color(1.0, 0.84, 0.42, 1.0)
	blob.polygon = _circle_poly(8.0)
	skin.add_child(blob)


func _circle_poly(radius: float, segments: int = 12) -> PackedVector2Array:
	var points := PackedVector2Array()
	points.resize(segments)
	for i: int in segments:
		var angle := TAU * float(i) / float(segments)
		points[i] = Vector2(cos(angle), sin(angle)) * radius
	return points
