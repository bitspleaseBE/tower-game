extends Node2D
## Stage 2 core loop + Stage 3 pooling / juice registration.

const DESIGN_SIZE := Vector2(720, 1280)
const TAP_RADIUS_PX := 56.0
const EnemyScene: PackedScene = preload("res://scenes/entities/enemy.tscn")
const ProjectileScene: PackedScene = preload("res://scenes/entities/projectile.tscn")
const BuildPadScene: PackedScene = preload("res://scenes/entities/build_pad.tscn")

## Stage 5 MapSelect will inject map_data; default is map 1.
var map_data: MapData

@onready var board: Node2D = $Board
@onready var path: Path2D = $Board/Path
@onready var path_border: Line2D = $Board/Path/PathBorder
@onready var path_line: Line2D = $Board/Path/PathLine
@onready var pads_root: Node2D = $Board/Pads
@onready var projectiles_root: Node2D = $Board/Projectiles
@onready var fx_layer: Node2D = $FxLayer
@onready var spawner: Node = $Spawner
@onready var hud: Control = $UI/Hud
@onready var build_menu: Control = $UI/BuildMenu

var coins: int = 0
var lives: int = 0
var _lost_emitted: bool = false
var _suppress_game_over: bool = false
var _enemy_pool: ObjectPool
var _projectile_pool: ObjectPool


func _ready() -> void:
	add_to_group("game")
	# Stage 5 MapSelect will inject map_data before _ready; default is map 1.
	if map_data == null:
		map_data = load("res://data/maps/map_01.tres") as MapData
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
	Juice.register_game(fx_layer, board, hud)

	coins = map_data.starting_coins
	lives = map_data.starting_lives
	Events.coins_changed.emit(coins)
	Events.lives_changed.emit(lives)
	hud.set_wave(1, map_data.waves.size())

	hud.menu_requested.connect(_go_back)
	build_menu.setup(self)
	spawner.setup(self, map_data)
	spawner.countdown_tick.connect(_on_countdown_tick)
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.enemy_leaked.connect(_on_enemy_leaked)

	spawner.start()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_back()
		return
	# Emulate-mouse-from-touch is on: handle ONLY mouse buttons (not ScreenTouch).
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	_handle_board_tap(get_global_mouse_position())


func can_afford(amount: int) -> bool:
	return coins >= amount


func spend(amount: int) -> bool:
	if coins < amount:
		return false
	coins -= amount
	Events.coins_changed.emit(coins)
	return true


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


func _go_back() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


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
	hud.show_countdown(seconds_left)


func _on_enemy_killed(_enemy: Node, bounty: int) -> void:
	earn(bounty)


func _on_enemy_leaked(enemy: Node) -> void:
	if not (enemy is Enemy) or (enemy as Enemy).data == null:
		return
	var cost: int = (enemy as Enemy).data.lives_cost
	if not _suppress_game_over:
		lives = maxi(0, lives - cost)
	Events.lives_changed.emit(lives)
	Juice.shake(4.0, 0.2)
	if lives == 0 and not _lost_emitted and not _suppress_game_over:
		_lost_emitted = true
		spawner.stop()
		Events.run_lost.emit(map_data.id)
