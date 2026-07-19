extends Node
## Hidden stress harness. Activate with ?stress=1 (web) or F9 (desktop).

const TowerScene: PackedScene = preload("res://scenes/entities/tower.tscn")
const ENEMY_TARGETS := [40, 80, 120]
const FX_INTERVAL := 0.15
const SHAKE_INTERVAL := 2.0
const OVERLAY_TICK := 0.25

var _active := false
var _enemy_target_index := 1 ## default 80
var _fx_timer := 0.0
var _shake_timer := 0.0
var _overlay_timer := 0.0
var _frame_ms: Array[float] = []
var _normal_enemy: EnemyData
var _popper: TowerData

@onready var game: Node = get_parent()
@onready var overlay: Control = $"../UI/StressOverlay"


func _ready() -> void:
	_normal_enemy = load("res://data/enemies/normal.tres") as EnemyData
	_popper = load("res://data/towers/popper.tres") as TowerData
	# StressOverlay is deeper in the tree; wait until its @onready nodes exist.
	await get_tree().process_frame
	if not is_instance_valid(overlay):
		return
	overlay.enemies_cycle_pressed.connect(_cycle_enemies)
	overlay.set_enemies_label(ENEMY_TARGETS[_enemy_target_index])
	overlay.set_active(false)
	set_process(false)

	if _should_auto_start():
		activate()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.keycode == KEY_F9:
			if _active:
				deactivate()
			else:
				activate()
			get_viewport().set_input_as_handled()


func _should_auto_start() -> bool:
	if not OS.has_feature("web"):
		return false
	var stress_val: Variant = JavaScriptBridge.eval(
		"new URLSearchParams(window.location.search).get('stress')", true
	)
	if stress_val == null:
		return false
	return str(stress_val) == "1"


func activate() -> void:
	if _active:
		return
	_active = true
	set_process(true)
	overlay.set_active(true)
	game.set_stress_mode(true)
	if game.spawner != null:
		game.spawner.stop()
	_fill_pads_max_tier()
	_top_up_enemies()
	overlay.set_enemies_label(ENEMY_TARGETS[_enemy_target_index])


func deactivate() -> void:
	_active = false
	set_process(false)
	overlay.set_active(false)


func _process(delta: float) -> void:
	if not _active:
		return
	_frame_ms.append(delta * 1000.0)
	if _frame_ms.size() > 60:
		_frame_ms.pop_front()

	_top_up_enemies()

	_fx_timer += delta
	if _fx_timer >= FX_INTERVAL:
		_fx_timer = 0.0
		_burst_fx()

	_shake_timer += delta
	if _shake_timer >= SHAKE_INTERVAL:
		_shake_timer = 0.0
		Juice.shake(4.0, 0.2)

	_overlay_timer += delta
	if _overlay_timer >= OVERLAY_TICK:
		_overlay_timer = 0.0
		_update_overlay()


func _fill_pads_max_tier() -> void:
	for node: Node in get_tree().get_nodes_in_group("build_pads"):
		var pad := node as BuildPad
		if pad == null:
			continue
		if pad.tower == null:
			var tower: Tower = TowerScene.instantiate()
			pad.add_child(tower)
			tower.setup(_popper)
			pad.tower = tower
		while pad.tower.tier < 2:
			pad.tower.upgrade()


func _top_up_enemies() -> void:
	var target: int = ENEMY_TARGETS[_enemy_target_index]
	var alive := 0
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy != null and enemy.active:
			alive += 1
	while alive < target:
		var spawned: Enemy = game._spawn_enemy(_normal_enemy)
		if spawned == null:
			break
		# Spread along the path so they aren't stacked at the entrance.
		spawned.progress = randf() * maxf(1.0, game.path.curve.get_baked_length() * 0.85)
		alive += 1


func _burst_fx() -> void:
	var curve: Curve2D = game.path.curve
	if curve == null:
		return
	var length := curve.get_baked_length()
	var pos := curve.sample_baked(randf() * length)
	# sample_baked is in path-local space; convert roughly via path global.
	pos = game.path.to_global(pos)
	Juice.confetti(pos)
	Juice.floater("+%d" % randi_range(1, 9), pos, Color(1.0, 0.79, 0.3, 1.0))
	Juice.coin_burst(pos, 2)


func _cycle_enemies() -> void:
	_enemy_target_index = (_enemy_target_index + 1) % ENEMY_TARGETS.size()
	overlay.set_enemies_label(ENEMY_TARGETS[_enemy_target_index])


func _update_overlay() -> void:
	var avg_ms := 0.0
	var worst_ms := 0.0
	if not _frame_ms.is_empty():
		for ms: float in _frame_ms:
			avg_ms += ms
			worst_ms = maxf(worst_ms, ms)
		avg_ms /= float(_frame_ms.size())

	var alive_enemies := 0
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy != null and enemy.active:
			alive_enemies += 1

	var text := "FPS %d\nAvg %.1f ms  Worst %.1f ms\nEnemies %d / target %d\nConfetti %d x %d\nFloaters %d  Coins %d\nEnemy pool L/F %d/%d\nProj pool L/F %d/%d\nNodes %d" % [
		Engine.get_frames_per_second(),
		avg_ms,
		worst_ms,
		alive_enemies,
		ENEMY_TARGETS[_enemy_target_index],
		Juice.confetti_live_count(),
		PerfBudget.PARTICLES_PER_BURST,
		Juice.floater_live_count(),
		Juice.coin_live_count(),
		game.enemy_pool_live(),
		game.enemy_pool_free(),
		game.projectile_pool_live(),
		game.projectile_pool_free(),
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
	]
	overlay.set_metrics(text)
