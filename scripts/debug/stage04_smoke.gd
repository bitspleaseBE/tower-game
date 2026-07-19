extends SceneTree
## Headless smoke test for Stage 4 tower roster.
## Usage: godot --headless --path . --script scripts/debug/stage04_smoke.gd


func _initialize() -> void:
	var failed := false

	# --- Data resources ---
	var map: MapData = load("res://data/maps/map_01.tres") as MapData
	var popper: TowerData = load("res://data/towers/popper.tres") as TowerData
	var lobber: TowerData = load("res://data/towers/lobber.tres") as TowerData
	var chiller: TowerData = load("res://data/towers/chiller.tres") as TowerData
	var longshot: TowerData = load("res://data/towers/longshot.tres") as TowerData
	var swarm: EnemyData = load("res://data/enemies/swarm.tres") as EnemyData
	var armored: EnemyData = load("res://data/enemies/armored.tres") as EnemyData
	var boss: EnemyData = load("res://data/enemies/boss.tres") as EnemyData

	if map == null:
		push_error("map_01.tres failed to load")
		failed = true
	elif map.waves.size() < 12 or map.waves.size() > 15:
		push_error("Expected 12–15 waves, got %d" % map.waves.size())
		failed = true
	else:
		print("OK waves=%d" % map.waves.size())

	if popper == null or lobber == null or chiller == null or longshot == null:
		push_error("Missing tower .tres")
		failed = true
	else:
		if popper.behavior != TowerData.Behavior.SINGLE:
			push_error("popper behavior wrong")
			failed = true
		if lobber.behavior != TowerData.Behavior.SPLASH or lobber.splash_radius_px.size() != 3:
			push_error("lobber splash schema wrong")
			failed = true
		if chiller.behavior != TowerData.Behavior.SLOW or chiller.slow_factor.size() != 3:
			push_error("chiller slow schema wrong")
			failed = true
		if longshot.behavior != TowerData.Behavior.SNIPER or longshot.projectile_speed < 1400.0:
			push_error("longshot sniper schema wrong")
			failed = true
		print("OK tower roster behaviors")

	if swarm == null or armored == null or boss == null:
		push_error("Missing enemy archetypes")
		failed = true
	else:
		if swarm.radius_px <= 0.0 or armored.armor < 1.0 or not boss.is_boss:
			push_error("enemy archetype fields wrong")
			failed = true
		else:
			print("OK enemy archetypes swarm/armored/boss")

	# Behavior enum complete.
	if TowerData.Behavior.SINGLE != 0 or TowerData.Behavior.SNIPER != 3:
		push_error("TowerData.Behavior enum incomplete")
		failed = true
	else:
		print("OK Behavior enum SINGLE..SNIPER")

	# Juice.wiggle public API.
	var juice_script: Script = load("res://scripts/autoload/juice.gd") as Script
	if juice_script == null or not juice_script.has_method("wiggle"):
		# Autoload script methods show via instance; check source.
		var juice_src := FileAccess.get_file_as_string("res://scripts/autoload/juice.gd")
		if not juice_src.contains("func wiggle("):
			push_error("Juice.wiggle missing")
			failed = true
		else:
			print("OK Juice.wiggle in source")
	else:
		print("OK Juice.wiggle method")

	# open_manage present (Task 0).
	var bm_src := FileAccess.get_file_as_string("res://scripts/ui/build_menu.gd")
	if not bm_src.contains("open_manage"):
		push_error("BuildMenu.open_manage missing")
		failed = true
	else:
		print("OK open_manage present")

	# Armor constant.
	var enemy_src := FileAccess.get_file_as_string("res://scripts/entities/enemy.gd")
	if not enemy_src.contains("ARMOR_MIN_DAMAGE_RATIO"):
		push_error("ARMOR_MIN_DAMAGE_RATIO missing")
		failed = true
	else:
		print("OK ARMOR_MIN_DAMAGE_RATIO")

	# Instantiate game and exercise roster seams.
	var game_packed: PackedScene = load("res://scenes/game.tscn") as PackedScene
	if game_packed == null:
		push_error("Failed to load game.tscn")
		failed = true
		_finish(failed)
		return

	var game: Node = game_packed.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame

	if game.get_node_or_null("Board/RangePreview") == null:
		push_error("Missing Board/RangePreview")
		failed = true
	else:
		print("OK RangePreview")

	if game.get_node_or_null("UI/BuildMenu") == null:
		push_error("Missing BuildMenu")
		failed = true
	else:
		print("OK BuildMenu")

	# Spawn each archetype + boss, apply slow, armor floor check.
	if swarm != null and game.has_method("_spawn_enemy"):
		var e_swarm: Node = game._spawn_enemy(swarm)
		if e_swarm == null or not bool(e_swarm.get("active")):
			push_error("swarm spawn failed")
			failed = true
		else:
			e_swarm.call("apply_slow", 0.5, 1.0)
			if float(e_swarm.get("_slow_factor")) > 0.51:
				push_error("apply_slow did not set factor")
				failed = true
			else:
				print("OK swarm slow")
			e_swarm.call("deactivate")

	if armored != null:
		var e_arm: Node = game._spawn_enemy(armored)
		if e_arm == null:
			push_error("armored spawn failed")
			failed = true
		else:
			var hp_before: float = float(e_arm.get("hp"))
			e_arm.call("take_damage", 1.0) # armor 2 → floor 0.25
			var hp_after: float = float(e_arm.get("hp"))
			var dealt := hp_before - hp_after
			if dealt < 0.24 or dealt > 0.26:
				push_error("armor floor wrong: dealt %s expected ~0.25" % dealt)
				failed = true
			else:
				print("OK armor floor dealt=%.2f" % dealt)
			e_arm.call("deactivate")

	if boss != null:
		var e_boss: Node = game._spawn_enemy(boss)
		if e_boss == null:
			push_error("boss spawn failed")
			failed = true
		else:
			var hp_bar: Node = e_boss.get_node_or_null("HpBar")
			if hp_bar == null or not bool(hp_bar.visible):
				push_error("boss HpBar missing/invisible")
				failed = true
			else:
				print("OK boss HpBar visible")
			e_boss.call("deactivate")

	# Place all four towers, upgrade once, sell one.
	var pads: Array = game.get_tree().get_nodes_in_group("build_pads")
	var tower_scene: PackedScene = load("res://scenes/entities/tower.tscn") as PackedScene
	var roster: Array = [popper, lobber, chiller, longshot]
	if pads.size() >= 4 and tower_scene != null:
		game.set("free_build", true)
		for i: int in 4:
			var pad: Node = pads[i]
			var tower: Node = tower_scene.instantiate()
			pad.add_child(tower)
			tower.call("setup", roster[i])
			pad.set("tower", tower)
			tower.call("upgrade")
		print("OK built+upgraded 4 tower types")
		# Fire a few frames so behaviors run without error.
		for _i: int in 10:
			await process_frame
		print("OK tower behaviors ticked")

	# Projectile lob mode exists.
	var proj_src := FileAccess.get_file_as_string("res://scripts/entities/projectile.gd")
	if not proj_src.contains("launch_lob") or not proj_src.contains("enum Mode"):
		push_error("projectile HOMING/LOB missing")
		failed = true
	else:
		print("OK projectile HOMING/LOB")

	# time_scale reset path exists.
	var game_src := FileAccess.get_file_as_string("res://scripts/game.gd")
	if not game_src.contains("Engine.time_scale = 1.0"):
		push_error("game.gd missing time_scale reset")
		failed = true
	else:
		print("OK time_scale reset in game")

	var result_src := FileAccess.get_file_as_string("res://scripts/ui/result_overlay.gd")
	if not result_src.contains("Engine.time_scale = 1.0"):
		push_error("result_overlay missing time_scale reset")
		failed = true
	else:
		print("OK time_scale reset in ResultOverlay")

	# free_build flag.
	if not game_src.contains("free_build"):
		push_error("free_build missing on game")
		failed = true
	else:
		print("OK free_build")

	# Stress full-roster hook.
	var stress_src := FileAccess.get_file_as_string("res://scripts/debug/stress_test.gd")
	if not stress_src.contains("_activate_full_roster") and not stress_src.contains("full_roster"):
		push_error("full roster stress preset missing")
		failed = true
	else:
		print("OK full-roster stress")

	game.queue_free()
	await process_frame
	Engine.time_scale = 1.0
	_finish(failed)


func _finish(failed: bool) -> void:
	if failed:
		print("stage04_smoke FAILED")
		quit(1)
	else:
		print("stage04_smoke PASSED")
		quit(0)
