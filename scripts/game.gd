extends Node2D
## Stage 2 core loop + Stage 3 pooling / juice + Stage 5 run modes.

const DESIGN_SIZE := Vector2(720, 1280)
const TAP_RADIUS_PX := 56.0
const EnemyScene: PackedScene = preload("res://scenes/entities/enemy.tscn")
const ProjectileScene: PackedScene = preload("res://scenes/entities/projectile.tscn")
const WaterPoolScene: PackedScene = preload("res://scenes/entities/water_pool.tscn")
const BuildPadScene: PackedScene = preload("res://scenes/entities/build_pad.tscn")
const ORNAMENT_TEXTURES := {
	&"cupcake": preload("res://assets/background/decor_cupcake.png"),
	&"sundae": preload("res://assets/background/decor_sundae.png"),
	&"donut": preload("res://assets/background/decor_donut.png"),
	&"macaron": preload("res://assets/background/decor_macaron.png"),
	&"softserve": preload("res://assets/background/decor_softserve.png"),
	&"cookie": preload("res://assets/background/decor_cookie.png"),
}

## Stage 5 MapSelect injects via SaveGame; default is map 1 for editor F5.
var map_data: MapData
var endless := false
var best_at_run_start: int = 0

@onready var board: Node2D = $Board
@onready var path: Path2D = $Board/Path
@onready var path_border: Line2D = $Board/Path/PathBorder
@onready var path_line: Line2D = $Board/Path/PathLine
@onready var path_highlight: Line2D = $Board/Path/PathHighlight
@onready var river: Sprite2D = $Board/Decor/River
@onready var bridge: Sprite2D = $Board/Decor/Bridge
@onready var spawn_marker_template: Node2D = $Board/Decor/SpawnMarker
@onready var base_marker: Node2D = $Board/Decor/BaseMarker
@onready var landmarks_root: Node2D = $Board/Landmarks
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
@onready var lane_alert: Control = get_node_or_null("UI/LaneAlert")

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
var _board_pan: Vector2 = Vector2.ZERO
var _expanded: bool = false
var _lane_paths: Array[Path2D] = []
var _spawn_markers: Array[Node2D] = []
var _pad_nodes: Array[BuildPad] = []
var _seen_lane_labels: Dictionary = {}


func _ready() -> void:
	add_to_group("game")
	if SaveGame.run_map != null:
		map_data = SaveGame.run_map
		endless = SaveGame.run_endless
	elif map_data == null:
		map_data = load("res://data/maps/map_01.tres") as MapData
		endless = false
	best_at_run_start = SaveGame.best_endless_wave(map_data.id)

	_setup_lanes()
	_build_paths()
	_place_board_dressing()
	_spawn_pads_for_wave(1)
	# Opening lanes shouldn't banner as "New path".
	for lane: LaneData in map_data.resolved_lanes():
		if lane != null and lane.unlock_wave <= 1 and not lane.label.is_empty():
			_seen_lane_labels[lane.label] = true
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
	Events.wave_lanes_previewed.connect(_on_wave_lanes_previewed)

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


func bounty_for(enemy_data: EnemyData) -> int:
	if enemy_data == null:
		return 0
	var scale := 1.0
	if map_data != null:
		scale = map_data.bounty_scale
	return maxi(1, int(round(float(enemy_data.bounty) * scale)))


func _spawn_enemy(enemy_data: EnemyData, lane: int = 0) -> Enemy:
	var node: Node = _enemy_pool.acquire()
	if node == null:
		return null
	var enemy := node as Enemy
	var path_node := get_lane_path(lane)
	if path_node != null and enemy.get_parent() != path_node:
		enemy.reparent(path_node, false)
	enemy.activate(enemy_data)
	## After a board pan, skip the off-screen lead-in so critters appear at the
	## visible edge of the path instead of walking in from above for a minute.
	var start_progress := _visible_spawn_progress(path_node)
	if start_progress > 0.0:
		enemy.progress = start_progress
	return enemy


func get_lane_path(lane: int) -> Path2D:
	if lane < 0 or lane >= _lane_paths.size():
		return path
	return _lane_paths[lane]


func get_lane_entry(lane: int) -> Vector2:
	var path_node := get_lane_path(lane)
	if path_node == null or path_node.curve == null or path_node.curve.get_baked_length() <= 0.0:
		var lanes := map_data.resolved_lanes()
		if lane < 0 or lane >= lanes.size():
			return Vector2.ZERO
		var pts := _lane_points_for_phase(lanes[lane])
		if pts.is_empty():
			return Vector2.ZERO
		return pts[0]
	return path_node.curve.sample_baked(_visible_spawn_progress(path_node))


func get_lane_label(lane: int) -> String:
	var lanes := map_data.resolved_lanes()
	if lane < 0 or lane >= lanes.size():
		return ""
	return lanes[lane].label


func is_lane_unlocked(lane: int) -> bool:
	var lanes := map_data.resolved_lanes()
	if lane < 0 or lane >= lanes.size():
		return false
	var data: LaneData = lanes[lane]
	if data.unlock_wave > _current_wave:
		return false
	if data.phase1_point_count > 0 and not _expanded and data.unlock_wave > 1:
		return false
	return true


func lane_count() -> int:
	return map_data.resolved_lanes().size()


func subtitle_for_lanes(lane_indices: Array, labels: Array) -> String:
	if labels.is_empty():
		return ""
	var first_time: Array[String] = []
	for i: int in labels.size():
		var lab: String = String(labels[i])
		if lab.is_empty():
			continue
		if not _seen_lane_labels.has(lab):
			first_time.append(lab)
			_seen_lane_labels[lab] = true
	if not first_time.is_empty():
		if first_time.size() == 1:
			return "New path: %s!" % first_time[0]
		return "New paths!"
	if labels.size() == 1:
		var one: String = String(labels[0])
		return "From the %s!" % one if not one.is_empty() else ""
	if labels.size() >= 2:
		return "Both sides!"
	return ""


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
	var base := ((get_viewport_rect().size - DESIGN_SIZE) * 0.5).max(Vector2.ZERO)
	board.position = base - _board_pan
	Juice.sync_shake_rest()


func _setup_lanes() -> void:
	var lanes := map_data.resolved_lanes()
	_lane_paths.clear()
	_spawn_markers.clear()
	# Lane 0 reuses the scene Path2D.
	_lane_paths.append(path)
	for i: int in range(1, lanes.size()):
		var clone := Path2D.new()
		clone.name = "Path%d" % (i + 1)
		clone.z_index = path.z_index
		var border := path_border.duplicate() as Line2D
		border.name = "PathBorder"
		var line := path_line.duplicate() as Line2D
		line.name = "PathLine"
		var highlight: Line2D = null
		if path_highlight != null:
			highlight = path_highlight.duplicate() as Line2D
			highlight.name = "PathHighlight"
		clone.add_child(border)
		clone.add_child(line)
		if highlight != null:
			clone.add_child(highlight)
		board.add_child(clone)
		_lane_paths.append(clone)
	_setup_markers(lanes)


func _setup_markers(lanes: Array[LaneData]) -> void:
	if spawn_marker_template != null:
		spawn_marker_template.visible = false
	for child: Node in _spawn_markers:
		if is_instance_valid(child):
			child.queue_free()
	_spawn_markers.clear()
	for i: int in lanes.size():
		var marker: Node2D
		if spawn_marker_template != null:
			marker = spawn_marker_template.duplicate() as Node2D
		else:
			marker = Node2D.new()
		marker.name = "SpawnMarker%d" % (i + 1)
		marker.visible = false
		board.get_node("Decor").add_child(marker)
		_spawn_markers.append(marker)
	_place_markers()


func _lane_points_for_phase(lane: LaneData) -> PackedVector2Array:
	if lane.points.is_empty():
		return PackedVector2Array()
	if not _expanded and lane.phase1_point_count > 0:
		var n := mini(lane.phase1_point_count, lane.points.size())
		return lane.points.slice(0, n)
	return lane.points


## Progress along a lane curve where it first enters the visible board (below the HUD).
## 0 when the natural path start is already on-screen.
func _visible_spawn_progress(path_node: Path2D) -> float:
	if path_node == null or path_node.curve == null:
		return 0.0
	var curve := path_node.curve
	var length := curve.get_baked_length()
	if length <= 1.0:
		return 0.0
	## Board-space Y of the top of the playfield after pan (leave room under the HUD).
	var top_y := _board_pan.y + 130.0
	var start := curve.sample_baked(0.0)
	if start.y >= top_y:
		return 0.0
	var step := 10.0
	var prev := start
	var d := step
	while d <= length:
		var pt := curve.sample_baked(d)
		if pt.y >= top_y:
			var dy := pt.y - prev.y
			var t := 1.0 if absf(dy) < 0.01 else clampf((top_y - prev.y) / dy, 0.0, 1.0)
			return minf(length * 0.95, (d - step) + step * t)
		prev = pt
		d += step
	return 0.0


func _build_paths() -> void:
	## Fillet sharp corners so the sugar road reads organic (concept pink ribbon),
	## while map .tres keeps the canonical corner waypoints for lint/smoke.
	var lanes := map_data.resolved_lanes()
	for i: int in lanes.size():
		var lane: LaneData = lanes[i]
		var path_node := _lane_paths[i]
		var border: Line2D = path_node.get_node_or_null("PathBorder") as Line2D
		var line: Line2D = path_node.get_node_or_null("PathLine") as Line2D
		var highlight: Line2D = path_node.get_node_or_null("PathHighlight") as Line2D
		var unlocked := lane.unlock_wave <= maxi(1, _current_wave)
		if lane.unlock_wave > 1 and not _expanded and map_data.expansion_wave > 0:
			unlocked = false
		if not unlocked or lane.points.size() < 2:
			path_node.visible = false
			if border:
				border.points = PackedVector2Array()
			if line:
				line.points = PackedVector2Array()
			if highlight:
				highlight.points = PackedVector2Array()
			path_node.curve = Curve2D.new()
			continue
		path_node.visible = true
		var pts := _lane_points_for_phase(lane)
		var drawn := _fillet_path_points(pts, 72.0, 7)
		var curve := Curve2D.new()
		for point: Vector2 in drawn:
			curve.add_point(point)
		path_node.curve = curve
		if border:
			border.points = drawn
		if line:
			line.points = drawn
		if highlight:
			highlight.points = drawn
	_place_markers()


func _place_markers() -> void:
	var lanes := map_data.resolved_lanes()
	var base_pos := Vector2.ZERO
	for i: int in lanes.size():
		var lane: LaneData = lanes[i]
		var pts := _lane_points_for_phase(lane)
		var unlocked := lane.unlock_wave <= maxi(1, _current_wave)
		if lane.unlock_wave > 1 and not _expanded and map_data.expansion_wave > 0:
			unlocked = false
		if i < _spawn_markers.size():
			var marker: Node2D = _spawn_markers[i]
			if unlocked and pts.size() >= 1:
				marker.visible = true
				marker.position = get_lane_entry(i)
			else:
				marker.visible = false
		if unlocked and pts.size() >= 1:
			base_pos = pts[pts.size() - 1]
	if base_marker != null:
		if base_pos != Vector2.ZERO:
			base_marker.visible = true
			base_marker.position = base_pos
		elif map_data.path_points.size() >= 1:
			base_marker.visible = true
			base_marker.position = map_data.path_points[map_data.path_points.size() - 1]


func _place_board_dressing() -> void:
	## River / bridge / dessert ornaments are map-authored so levels can differ.
	if river != null:
		if map_data.river_position != Vector2.ZERO:
			river.visible = true
			river.position = map_data.river_position
			river.scale = map_data.river_scale
			river.z_index = -2
		else:
			river.visible = false
	if bridge != null:
		if map_data.bridge_position != Vector2.ZERO:
			bridge.visible = true
			bridge.position = map_data.bridge_position
			bridge.scale = map_data.bridge_scale
			bridge.rotation = map_data.bridge_rotation
			bridge.z_index = -1
		else:
			bridge.visible = false
	_spawn_ornaments()


func _spawn_ornaments() -> void:
	if landmarks_root == null:
		return
	for child: Node in landmarks_root.get_children():
		child.queue_free()
	for ornament: MapOrnament in map_data.ornaments:
		if ornament == null or ornament.position == Vector2.ZERO:
			continue
		if _min_dist_to_path(ornament.position) < 120.0:
			push_warning(
				"Ornament %s at %s too close to path — skipped" % [ornament.kind, ornament.position]
			)
			continue
		var tex: Texture2D = ORNAMENT_TEXTURES.get(ornament.kind) as Texture2D
		if tex == null:
			push_warning("Unknown ornament kind: %s" % ornament.kind)
			continue
		var holder := Node2D.new()
		holder.name = "Ornament_%s" % String(ornament.kind)
		holder.position = ornament.position
		holder.rotation = ornament.rotation
		var spr := Sprite2D.new()
		var s := ornament.scale if ornament.scale > 0.05 else 0.7
		spr.scale = Vector2(s, s)
		spr.texture = tex
		holder.add_child(spr)
		landmarks_root.add_child(holder)


func _min_dist_to_path(pos: Vector2) -> float:
	var best := INF
	for lane: LaneData in map_data.resolved_lanes():
		var pts := lane.points if not lane.points.is_empty() else map_data.path_points
		if pts.size() < 2:
			continue
		for i: int in range(pts.size() - 1):
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var ab := b - a
			var len_sq := ab.length_squared()
			var t := 0.0 if len_sq < 0.001 else clampf((pos - a).dot(ab) / len_sq, 0.0, 1.0)
			best = minf(best, pos.distance_to(a + ab * t))
	if best == INF:
		return 9999.0
	return best


func _fillet_path_points(pts: PackedVector2Array, radius: float, arc_steps: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	if pts.size() < 2:
		return pts
	if pts.size() == 2:
		out.append(pts[0])
		out.append(pts[1])
		return out
	out.append(pts[0])
	for i: int in range(1, pts.size() - 1):
		var a: Vector2 = pts[i - 1]
		var b: Vector2 = pts[i]
		var c: Vector2 = pts[i + 1]
		var ba := a - b
		var bc := c - b
		var len_ba := ba.length()
		var len_bc := bc.length()
		if len_ba < 1.0 or len_bc < 1.0:
			out.append(b)
			continue
		var r := minf(radius, minf(len_ba, len_bc) * 0.42)
		var dir_ba := ba / len_ba
		var dir_bc := bc / len_bc
		var p0 := b + dir_ba * r
		var p1 := b + dir_bc * r
		out.append(p0)
		## Quadratic arc through the corner for a soft whipped-cream bend.
		for s: int in range(1, arc_steps):
			var t := float(s) / float(arc_steps)
			var ab := p0.lerp(b, t)
			var bc_pt := b.lerp(p1, t)
			out.append(ab.lerp(bc_pt, t))
		out.append(p1)
	out.append(pts[pts.size() - 1])
	return out


func _spawn_pads_for_wave(wave_number: int) -> void:
	if _pad_nodes.size() != map_data.pad_positions.size():
		_pad_nodes.resize(map_data.pad_positions.size())
	for i: int in map_data.pad_positions.size():
		if _pad_nodes[i] != null and is_instance_valid(_pad_nodes[i]):
			continue
		if map_data.pad_unlock_wave(i) > wave_number:
			continue
		var pad: BuildPad = BuildPadScene.instantiate()
		pad.name = "Pad%d" % (i + 1)
		pad.position = map_data.pad_positions[i]
		pads_root.add_child(pad)
		_pad_nodes[i] = pad
		if wave_number > 1:
			Juice.punch_scale(pad.skin, 1.25, 0.2)


func _run_expansion() -> void:
	if _expanded or map_data.expansion_wave <= 0:
		return
	_expanded = true
	if wave_banner != null and wave_banner.has_method("announce"):
		wave_banner.announce("The Big Melt!")
	Juice.shake(8.0, 0.35)
	var target_pan := Vector2(0.0, map_data.expansion_pan)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(_set_board_pan, _board_pan, target_pan, 1.5)
	await tween.finished
	_build_paths()
	_spawn_pads_for_wave(_current_wave + 1)
	Sound.play_sfx(&"wave_start")


func _set_board_pan(pan: Vector2) -> void:
	_board_pan = pan
	_recenter_board()


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
	_build_paths()
	_spawn_pads_for_wave(number)
	if endless:
		SaveGame.record_endless_wave(map_data.id, number)


func run_expansion_if_needed() -> void:
	if _expanded or map_data.expansion_wave <= 0:
		return
	await _run_expansion()


func _on_wave_lanes_previewed(lane_indices: Array, labels: Array) -> void:
	_pulse_spawn_markers(lane_indices)
	if lane_alert != null and lane_alert.has_method("show_lanes"):
		lane_alert.show_lanes(self, lane_indices)
	if wave_banner != null and wave_banner.has_method("set_pending_subtitle"):
		wave_banner.set_pending_subtitle(subtitle_for_lanes(lane_indices, labels))


func _pulse_spawn_markers(lane_indices: Array) -> void:
	for i: int in _spawn_markers.size():
		var marker: Node2D = _spawn_markers[i]
		if marker == null or not marker.visible:
			continue
		var skin: Node2D = marker.get_node_or_null("Skin") as Node2D
		var target: Node2D = skin if skin != null else marker
		var bang: Label = marker.get_node_or_null("Bang") as Label
		if lane_indices.has(i):
			Juice.punch_scale(target, 1.35, 0.25)
			if bang == null:
				bang = Label.new()
				bang.name = "Bang"
				bang.text = "!"
				bang.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				bang.position = Vector2(-10, -48)
				bang.add_theme_font_size_override("font_size", 28)
				bang.add_theme_color_override("font_color", Color(1.0, 0.42, 0.62, 1.0))
				bang.add_theme_color_override("font_outline_color", Color(0.31, 0.23, 0.36, 1.0))
				bang.add_theme_constant_override("outline_size", 4)
				marker.add_child(bang)
			bang.visible = true
			var tween := bang.create_tween().set_loops(6)
			tween.tween_property(bang, "position:y", -56.0, 0.2)
			tween.tween_property(bang, "position:y", -48.0, 0.2)
		else:
			target.scale = Vector2.ONE
			if bang != null:
				bang.visible = false


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
