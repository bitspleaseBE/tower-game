extends SceneTree
## Headless smoke test for Stage 3 juice engine.
## Usage: godot --headless --path . --script scripts/debug/stage03_smoke.gd


func _initialize() -> void:
	var failed := false

	var juice_path: String = str(ProjectSettings.get_setting("autoload/Juice", ""))
	if not juice_path.contains("juice.gd"):
		push_error("Juice autoload missing, got: %s" % juice_path)
		failed = true
	else:
		print("OK Juice autoload=%s" % juice_path)

	var events_path: String = str(ProjectSettings.get_setting("autoload/Events", ""))
	if not events_path.contains("events.gd"):
		push_error("Events autoload missing")
		failed = true
	else:
		print("OK Events still registered")

	# Juice must be listed after Events in project.godot autoload order.
	var project_text := FileAccess.get_file_as_string("res://project.godot")
	var events_idx := project_text.find('Events="')
	var juice_idx := project_text.find('Juice="')
	if events_idx < 0 or juice_idx < 0 or juice_idx < events_idx:
		push_error("Juice must be registered after Events in project.godot")
		failed = true
	else:
		print("OK Juice after Events")

	var pb_script: Script = load("res://scripts/perf_budget.gd") as Script
	if pb_script == null:
		push_error("Failed to load perf_budget.gd")
		failed = true
	else:
		print("OK PerfBudget script loads")
		if PerfBudget.MAX_ENEMIES <= 0 or PerfBudget.PARTICLES_PER_BURST <= 0:
			push_error("PerfBudget caps invalid")
			failed = true
		else:
			print("OK PerfBudget caps MAX_ENEMIES=%d" % PerfBudget.MAX_ENEMIES)

	var pool_script: Script = load("res://scripts/object_pool.gd") as Script
	if pool_script == null:
		push_error("ObjectPool script missing")
		failed = true
	else:
		print("OK ObjectPool class loads")

	for path: String in [
		"res://scripts/autoload/juice.gd",
		"res://scripts/debug/stress_test.gd",
		"res://scenes/debug/stress_overlay.tscn",
		"res://scenes/ui/wave_banner.tscn",
		"res://scenes/ui/floater.tscn",
		"res://scenes/ui/coin_flyer.tscn",
		"res://scenes/fx/confetti_cpu.tscn",
	]:
		if not ResourceLoader.exists(path):
			push_error("Missing %s" % path)
			failed = true
		else:
			print("OK %s" % path)

	# Exactly one confetti winner scene (no GPU leftover).
	if ResourceLoader.exists("res://scenes/fx/confetti_gpu.tscn"):
		push_error("confetti_gpu.tscn should be deleted (CPU winner only)")
		failed = true
	else:
		print("OK single confetti winner (cpu)")

	var game_packed: PackedScene = load("res://scenes/game.tscn") as PackedScene
	if game_packed == null:
		push_error("Failed to load game.tscn")
		failed = true
		_finish(failed)
		return

	var game: Node = game_packed.instantiate()
	game.set_meta("smoke_silent", true)
	root.add_child(game)
	await process_frame
	await process_frame

	if game.get_node_or_null("FxLayer") == null:
		push_error("Game missing FxLayer")
		failed = true
	else:
		print("OK Game has FxLayer")

	if game.get_node_or_null("Board/Projectiles") == null:
		push_error("Game missing Board/Projectiles")
		failed = true
	else:
		print("OK Board/Projectiles")

	if game.get_node_or_null("UI/WaveBanner") == null:
		push_error("Missing UI/WaveBanner")
		failed = true
	else:
		print("OK WaveBanner")

	if game.get_node_or_null("StressTest") == null:
		push_error("Missing StressTest node")
		failed = true
	elif game.get_node("StressTest").get_script() == null:
		push_error("StressTest missing script")
		failed = true
	else:
		print("OK stress script present")

	if game.get_node_or_null("UI/StressOverlay") == null:
		push_error("Missing UI/StressOverlay")
		failed = true
	else:
		print("OK stress overlay present")

	# --script SceneTree may not inject autoload globals; resolve via /root.
	var juice_node: Node = root.get_node_or_null("Juice")
	if juice_node == null:
		push_error("Juice autoload node missing under /root")
		failed = true
	elif not juice_node.has_method("is_registered") or not juice_node.is_registered():
		push_error("Juice not registered after Game._ready")
		failed = true
	else:
		print("OK Juice registered")

	# Pool seam smoke: spawn + release one enemy (duck-typed — avoid pulling
	# Enemy.gd into --script compile without autoload globals).
	var normal: EnemyData = load("res://data/enemies/normal.tres") as EnemyData
	if normal != null and game.has_method("_spawn_enemy"):
		var enemy: Node = game._spawn_enemy(normal)
		if enemy == null or not bool(enemy.get("active")):
			push_error("Pooled enemy spawn failed")
			failed = true
		else:
			print("OK pooled enemy activate generation=%d" % int(enemy.get("generation")))
			enemy.call("deactivate")
			if bool(enemy.get("active")):
				push_error("Enemy still active after deactivate")
				failed = true
			else:
				print("OK enemy pool release")

	game.queue_free()
	await process_frame
	_finish(failed)


func _finish(failed: bool) -> void:
	if failed:
		print("stage03_smoke FAILED")
		quit(1)
	else:
		print("stage03_smoke PASSED")
		quit(0)
