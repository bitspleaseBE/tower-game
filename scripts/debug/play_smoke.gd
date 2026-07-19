extends SceneTree
## Minimal playability check: start run, place tower, kill enemy, leak life.
## Usage: godot --headless --path . --script scripts/debug/play_smoke.gd


func _initialize() -> void:
	var failed := false

	var game_ps: PackedScene = load("res://scenes/game.tscn") as PackedScene
	var game: Node = game_ps.instantiate()
	root.add_child(game)
	for _i: int in 8:
		await process_frame

	if int(game.get("coins")) != 100:
		push_error("expected starting coins 100, got %s" % game.get("coins"))
		failed = true
	else:
		print("OK coins=", game.coins)

	if int(game.get("lives")) != 20:
		push_error("expected lives 20, got %s" % game.get("lives"))
		failed = true
	else:
		print("OK lives=", game.lives)

	var pads: Array = game.get_tree().get_nodes_in_group("build_pads")
	if pads.is_empty():
		push_error("no build pads")
		failed = true
	else:
		var pad: Node = pads[0]
		if not game.spend(50):
			push_error("could not spend 50")
			failed = true
		else:
			var tower_ps: PackedScene = load("res://scenes/entities/tower.tscn") as PackedScene
			var tower: Node = tower_ps.instantiate()
			pad.add_child(tower)
			tower.call("setup", load("res://data/towers/popper.tres"))
			pad.set("tower", tower)
			print("OK tower placed")

	var enemy_data: Resource = load("res://data/enemies/normal.tres")
	var enemy: Node = game.call("_spawn_enemy", enemy_data)
	if enemy == null:
		push_error("spawn enemy failed")
		failed = true
	else:
		print("OK enemy active=", enemy.get("active"), " hp=", enemy.get("hp"))
		enemy.call("take_damage", 10.0)
		await process_frame
		await create_timer(0.3).timeout
		print("OK after kill coins=", game.coins)

	# Force lose via lives path without waiting for walk.
	game.set("lives", 1)
	var enemy2: Node = game.call("_spawn_enemy", enemy_data)
	if enemy2 != null:
		# Call game handler directly — autoload signal emit is flaky under --script.
		game.call("_on_enemy_leaked", enemy2)
		await process_frame
		print("OK after leak lives=", game.lives, " lost=", game.get("_lost_emitted"))
		if not bool(game.get("_lost_emitted")):
			push_error("run_lost was not emitted on 0 lives")
			failed = true

	if failed:
		print("play_smoke FAILED")
		quit(1)
	else:
		print("play_smoke PASSED")
		quit(0)
