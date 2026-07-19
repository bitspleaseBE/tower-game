extends SceneTree
## Headless smoke test for Stage 2 core loop.
## Usage: godot --headless --path . --script scripts/debug/stage02_smoke.gd

const CANONICAL_PATH: PackedVector2Array = [
	Vector2(-40, 280),
	Vector2(560, 280),
	Vector2(560, 540),
	Vector2(160, 540),
	Vector2(160, 820),
	Vector2(560, 820),
	Vector2(560, 1000),
	Vector2(760, 1000),
]

const CANONICAL_PADS: PackedVector2Array = [
	Vector2(180, 400),
	Vector2(420, 400),
	Vector2(650, 410),
	Vector2(360, 660),
	Vector2(620, 660),
	Vector2(70, 690),
	Vector2(300, 930),
	Vector2(440, 1020),
]


func _initialize() -> void:
	var failed := false

	var map: MapData = load("res://data/maps/map_01.tres") as MapData
	var popper: TowerData = load("res://data/towers/popper.tres") as TowerData
	var normal: EnemyData = load("res://data/enemies/normal.tres") as EnemyData
	var fast: EnemyData = load("res://data/enemies/fast.tres") as EnemyData

	if map == null or popper == null or normal == null or fast == null:
		push_error("Failed to load one or more Stage 2 data resources")
		failed = true
	else:
		print("OK data resources loaded")

	if map != null:
		if not _vecs_equal(map.path_points, CANONICAL_PATH):
			push_error("map_01.path_points mismatch vs Stage 1 canonical")
			failed = true
		else:
			print("OK path_points match Stage 1 canonical")
		if not _vecs_equal(map.pad_positions, CANONICAL_PADS):
			push_error("map_01.pad_positions mismatch vs Stage 1 canonical")
			failed = true
		else:
			print("OK pad_positions match Stage 1 canonical")
		if map.waves.size() != 6:
			push_error("Expected 6 waves, got %d" % map.waves.size())
			failed = true
		else:
			print("OK waves=%d" % map.waves.size())
		if map.starting_coins != 100 or map.starting_lives != 20:
			push_error("Unexpected starting economy coins=%d lives=%d" % [map.starting_coins, map.starting_lives])
			failed = true

	if popper != null:
		if popper.id != &"popper" or popper.behavior != TowerData.Behavior.SINGLE:
			push_error("popper identity/behavior wrong")
			failed = true
		if popper.cost.size() != 3 or popper.damage.size() != 3:
			push_error("popper tier arrays must be size 3")
			failed = true
		else:
			print("OK popper schema")

	var events_path: String = str(ProjectSettings.get_setting("autoload/Events", ""))
	if not events_path.contains("events.gd"):
		push_error("Events autoload missing in ProjectSettings, got: %s" % events_path)
		failed = true
	else:
		print("OK Events autoload=%s" % events_path)

	# Instantiate game briefly and check groups/scripts/structure.
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

	if game.get_script() == null:
		push_error("Game missing script")
		failed = true
	if game.get_node_or_null("Spawner") == null or game.get_node("Spawner").get_script() == null:
		push_error("Spawner missing script")
		failed = true
	else:
		print("OK Spawner script present")

	if game.get_node_or_null("UI/Hud") == null:
		push_error("Missing UI/Hud")
		failed = true
	if game.get_node_or_null("UI/BuildMenu") == null:
		push_error("Missing UI/BuildMenu")
		failed = true
	if game.get_node_or_null("UI/ResultOverlay") == null:
		push_error("Missing UI/ResultOverlay")
		failed = true
	else:
		print("OK Hud/BuildMenu/ResultOverlay")

	var pad_count := game.get_tree().get_nodes_in_group("build_pads").size()
	if pad_count != 8:
		push_error("Expected 8 build_pads in group, got %d" % pad_count)
		failed = true
	else:
		print("OK build_pads group=%d" % pad_count)

	# Entity scenes loadable.
	for scene_path: String in [
		"res://scenes/entities/enemy.tscn",
		"res://scenes/entities/projectile.tscn",
		"res://scenes/entities/tower.tscn",
		"res://scenes/entities/build_pad.tscn",
	]:
		var packed: PackedScene = load(scene_path) as PackedScene
		if packed == null:
			push_error("Failed to load %s" % scene_path)
			failed = true
		else:
			var inst: Node = packed.instantiate()
			if inst == null:
				push_error("Failed to instantiate %s" % scene_path)
				failed = true
			else:
				print("OK entity %s" % scene_path)
				inst.queue_free()

	game.queue_free()
	await process_frame
	_finish(failed)


func _vecs_equal(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	if a.size() != b.size():
		return false
	for i: int in a.size():
		if a[i] != b[i]:
			return false
	return true


func _finish(failed: bool) -> void:
	if failed:
		print("stage02_smoke FAILED")
		quit(1)
	else:
		print("stage02_smoke PASSED")
		quit(0)
