extends Node2D
## Stage 2 core loop + Stage 3 pooling / juice + Stage 5 run modes.

const DESIGN_SIZE := Vector2(720, 1280)
const TAP_RADIUS_PX := 56.0
const EnemyScene: PackedScene = preload("res://scenes/entities/enemy.tscn")
const ProjectileScene: PackedScene = preload("res://scenes/entities/projectile.tscn")
const WaterPoolScene: PackedScene = preload("res://scenes/entities/water_pool.tscn")
const BuildPadScene: PackedScene = preload("res://scenes/entities/build_pad.tscn")

## Stage 5 MapSelect injects via SaveGame; default is map 1 for editor F5.
var map_data: MapData
var endless := false
var best_at_run_start: int = 0

@onready var board: Node2D = $Board
@onready var path: Path2D = $Board/Path
@onready var path_border: Line2D = $Board/Path/PathBorder
@onready var path_line: Line2D = $Board/Path/PathLine
@onready var path_highlight: Line2D = $Board/Path/PathHighlight
@onready var pads_root: Node2D = $Board/Pads
@onready var projectiles_root: Node2D = $Board/Projectiles
@onready var fx_layer: Node2D = $FxLayer
@onready var spawner: Node = $Spawner
@onready var hud: Control = $UI/Hud
@onready var build_menu: Control = $UI/BuildMenu
@onready var result_overlay: Control = $UI/ResultOverlay
@onready var pause_overlay: Control = $UI/PauseOverlay
@onready var wave_banner: Control = $UI/WaveBanner
@onready var coach: Control = $UI/Coach

var coins: int = 0
var lives: int = 0
var free_build: bool = false
var _lost_emitted: bool = false
var _suppress_game_over: bool = false
var _enemy_pool: ObjectPool
var _projectile_pool: ObjectPool
var _water_pool_pool: ObjectPool
var _pools_root: Node2D
var _current_wave: int = 1


func _ready() -> void:
	add_to_group("game")
	if SaveGame.run_map != null:
		map_data = SaveGame.run_map
		endless = SaveGame.run_endless
	elif map_data == null:
		map_data = load("res://data/maps/map_01.tres") as MapData
		endless = false
	best_at_run_start = SaveGame.best_endless_wave(map_data.id)

	_build_path()
	_spawn_pads()
	_recenter_board()
	get_viewport().size_changed.connect(_recenter_board)

	_enemy_pool = ObjectPool.new(
		EnemyScene, path, PerfBudget.ENEMY_PREWARM, PerfBudget.MAX_ENEMIES, ObjectPool.GrowPolicy.GROW_WARN
	)
	_projectile_pool = ObjectPool.new(
		ProjectileScene,
		projectiles_root,
		PerfBudget.PROJECTILE_PREWARM,
		PerfBudget.MAX_PROJECTILES,
		ObjectPool.GrowPolicy.GROW_WARN
	)
	_pools_root = Node2D.new()
	_pools_root.name = "WaterPools"
	board.add_child(_pools_root)
	_water_pool_pool = ObjectPool.new(
		WaterPoolScene,
		_pools_root,
		PerfBudget.WATER_POOL_PREWARM,
		PerfBudget.MAX_WATER_POOLS,
		ObjectPool.GrowPolicy.DROP
	)
	Juice.register_game(fx_layer, board, hud)

	coins = map_data.starting_coins
	lives = map_data.starting_lives
	Events.coins_changed.emit(coins)
	Events.lives_changed.emit(lives)
	hud.setup_run(map_data.waves.size(), endless, best_at_run_start)
	if result_overlay.has_method("setup"):
		result_overlay.setup(self)

	hud.menu_requested.connect(_on_menu_requested)
	hud.early_call_pressed.connect(_on_early_call_pressed)
	build_menu.setup(self)
	spawner.setup(self, map_data)
	spawner.countdown_tick.connect(_on_countdown_tick)
	spawner.early_call_available.connect(_on_early_call_available)
	spawner.early_call_hidden.connect(_on_early_call_hidden)
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.enemy_leaked.connect(_on_enemy_leaked)
	Events.wave_started.connect(_on_wave_started)

	# Headless smokes set meta `smoke_silent` before add_child to avoid Ogg
	# playback ObjectDB noise on SceneTree.quit().
	if get_meta("smoke_silent", false):
		return

	Sound.set_music_ducked(false)
	Sound.play_music(&"music_game")
	if coach != null and coach.has_method("setup"):
		coach.setup(self)
	spawner.start()


func get_wave(n: int) -> WaveData:
	if n <= map_data.waves.size():
		return map_data.waves[n - 1]
	return EndlessWaves.generate(map_data, n)


func enter_endless() -> void:
	endless = true
	hud.setup_run(map_data.waves.size(), true, SaveGame.best_endless_wave(map_data.id))
	if wave_banner != null and wave_banner.has_method("announce"):
		wave_banner.announce("Endless!")
	spawner.resume_endless()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_menu_requested()
		get_viewport().set_input_as_handled()
		return
	# Emulate-mouse-from-touch is on: handle ONLY mouse buttons (not ScreenTouch).
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	_handle_board_tap(get_global_mouse_position())


func can_afford(amount: int) -> bool:
	if free_build:
		return true
	return coins >= amount


func spend(amount: int) -> bool:
	if free_build:
		return true
	if coins < amount:
		return false
	coins -= amount
	Events.coins_changed.emit(coins)
	return true


func pulse_coin_hud() -> void:
	if hud != null and hud.has_method("pulse_coins"):
		hud.pulse_coins()


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	Sound.stop_sfx()
	Sound.stop_music()


func earn(amount: int) -> void:
	coins += amount
	Events.coins_changed.emit(coins)


func _spawn_enemy(enemy_data: EnemyData) -> Enemy:
	var node: Node = _enemy_pool.acquire()
	if node == null:
		return null
	var enemy := node as Enemy
	enemy.activate(enemy_data)
	return enemy


func release_enemy(enemy: Enemy) -> void:
	if _enemy_pool != null:
		_enemy_pool.release(enemy)


func acquire_projectile() -> Projectile:
	var node: Node = _projectile_pool.acquire()
	if node == null:
		return null
	var projectile := node as Projectile
	projectile.activate()
	return projectile


func release_projectile(projectile: Projectile) -> void:
	if _projectile_pool != null:
		_projectile_pool.release(projectile)


func acquire_water_pool() -> WaterPool:
	var node: Node = _water_pool_pool.acquire()
	if node == null:
		return null
	return node as WaterPool


func release_water_pool(pool: WaterPool) -> void:
	if _water_pool_pool != null:
		_water_pool_pool.release(pool)


func enemy_pool_live() -> int:
	return 0 if _enemy_pool == null else _enemy_pool.live_count()


func enemy_pool_free() -> int:
	return 0 if _enemy_pool == null else _enemy_pool.free_count()


func projectile_pool_live() -> int:
	return 0 if _projectile_pool == null else _projectile_pool.live_count()


func projectile_pool_free() -> int:
	return 0 if _projectile_pool == null else _projectile_pool.free_count()


func set_stress_mode(enabled: bool) -> void:
	_suppress_game_over = enabled
	if enabled:
		lives = 999999
		Events.lives_changed.emit(lives)


func _on_menu_requested() -> void:
	# End-of-run sheet owns the tree pause — don't stack a second overlay.
	if result_overlay != null and result_overlay.visible:
		return
	if pause_overlay != null and pause_overlay.has_method("is_open") and pause_overlay.is_open():
		pause_overlay.close()
		return
	if pause_overlay != null and pause_overlay.has_method("open"):
		pause_overlay.open()


func _go_back() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/map_select.tscn")


func _recenter_board() -> void:
	board.position = ((get_viewport_rect().size - DESIGN_SIZE) * 0.5).max(Vector2.ZERO)
	Juice.sync_shake_rest()


func _build_path() -> void:
	var curve := Curve2D.new()
	for point: Vector2 in map_data.path_points:
		curve.add_point(point)
	path.curve = curve
	path_border.points = map_data.path_points
	path_line.points = map_data.path_points
	if path_highlight != null:
		path_highlight.points = map_data.path_points


func _spawn_pads() -> void:
	for i: int in map_data.pad_positions.size():
		var pad: BuildPad = BuildPadScene.instantiate()
		pad.name = "Pad%d" % (i + 1)
		pad.position = map_data.pad_positions[i]
		pads_root.add_child(pad)


func _handle_board_tap(world_pos: Vector2) -> void:
	var nearest: BuildPad = null
	var nearest_dist := TAP_RADIUS_PX
	for node: Node in get_tree().get_nodes_in_group("build_pads"):
		var pad := node as BuildPad
		if pad == null:
			continue
		var dist := pad.global_position.distance_to(world_pos)
		if dist <= nearest_dist:
			nearest_dist = dist
			nearest = pad

	if nearest == null:
		build_menu.close()
		_hide_all_range_rings()
		return

	Juice.punch_scale(nearest.skin, 1.15, 0.12)
	if nearest.tower == null:
		build_menu.open_build(nearest)
	else:
		build_menu.open_manage(nearest)


func _hide_all_range_rings() -> void:
	for node: Node in get_tree().get_nodes_in_group("towers"):
		var tower := node as Tower
		if tower:
			tower.show_range(false)


func _on_countdown_tick(seconds_left: int) -> void:
	# Timer UI lives on the Next-wave button; only soft-tick the last few seconds.
	if seconds_left > 0 and seconds_left <= 5:
		Sound.play_sfx(&"countdown_tick")


func _on_early_call_available(seconds_left: int, bonus: int) -> void:
	hud.show_early_call(seconds_left, bonus)


func _on_early_call_hidden() -> void:
	hud.hide_early_call()


func _on_early_call_pressed() -> void:
	var bonus: int = spawner.request_early_call()
	if bonus <= 0:
		return
	earn(bonus)
	Sound.play_sfx(&"coin")
	# Mint — distinct from gold kill-bounty floaters.
	Juice.floater("+%d" % bonus, Vector2(360, 900), Color(0.35, 0.92, 0.78, 1.0))
	hud.pulse_coins()


func _on_wave_started(number: int, _total: int) -> void:
	_current_wave = number
	if endless:
		SaveGame.record_endless_wave(map_data.id, number)


func _on_enemy_killed(_enemy: Node, bounty: int) -> void:
	earn(bounty)


func _on_enemy_leaked(enemy: Node) -> void:
	if not (enemy is Enemy) or (enemy as Enemy).data == null:
		return
	var cost: int = (enemy as Enemy).data.lives_cost
	if not _suppress_game_over:
		lives = maxi(0, lives - cost)
	Events.lives_changed.emit(lives)
	Sound.play_sfx(&"leak")
	Juice.shake(4.0, 0.2)
	if lives == 0 and not _lost_emitted and not _suppress_game_over:
		_lost_emitted = true
		spawner.stop()
		Events.run_lost.emit(map_data.id)
