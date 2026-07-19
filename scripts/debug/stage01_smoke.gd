extends SceneTree
## Headless smoke test for Stage 1 portrait shell.
## Usage: godot --headless --path . --script scripts/debug/stage01_smoke.gd


func _initialize() -> void:
	var failed := false

	var width: int = ProjectSettings.get_setting("display/window/size/viewport_width")
	var height: int = ProjectSettings.get_setting("display/window/size/viewport_height")
	if width != 720 or height != 1280:
		push_error("Expected viewport 720x1280, got %dx%d" % [width, height])
		failed = true
	else:
		print("OK viewport_size=%dx%d" % [width, height])

	var theme_path: String = str(ProjectSettings.get_setting("gui/theme/custom", ""))
	if theme_path != "res://theme/candy_theme.tres":
		push_error("Expected gui/theme/custom=res://theme/candy_theme.tres, got %s" % theme_path)
		failed = true
	else:
		print("OK theme=%s" % theme_path)

	var orientation: int = ProjectSettings.get_setting("display/window/handheld/orientation", -1)
	if orientation != 1:
		push_error("Expected handheld/orientation=1, got %s" % orientation)
		failed = true
	else:
		print("OK orientation=%d" % orientation)

	for scene_path: String in [
		"res://scenes/main_menu.tscn",
		"res://scenes/settings_menu.tscn",
		"res://scenes/game.tscn",
	]:
		var packed: PackedScene = load(scene_path) as PackedScene
		if packed == null:
			push_error("Failed to load %s" % scene_path)
			failed = true
			continue
		var instance: Node = packed.instantiate()
		if instance == null:
			push_error("Failed to instantiate %s" % scene_path)
			failed = true
			continue
		root.add_child(instance)
		await process_frame
		print("OK loaded %s (%s)" % [scene_path, instance.name])
		instance.queue_free()
		await process_frame

	# Spot-check game handoff contracts without entering gameplay.
	var game_packed: PackedScene = load("res://scenes/game.tscn") as PackedScene
	var game: Node = game_packed.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame

	if game.get_node_or_null("Board/Path") == null:
		push_error("Missing Board/Path")
		failed = true
	if game.get_node_or_null("Board/Path/PathBorder") == null:
		push_error("Missing Board/Path/PathBorder")
		failed = true
	if game.get_node_or_null("Board/Path/PathLine") == null:
		push_error("Missing Board/Path/PathLine")
		failed = true
	if game.get_node_or_null("Board/Pads") == null:
		push_error("Missing Board/Pads")
		failed = true
	else:
		var pad_count: int = game.get_node("Board/Pads").get_child_count()
		if pad_count != 8:
			push_error("Expected 8 pads, got %d" % pad_count)
			failed = true
		else:
			print("OK pads=%d" % pad_count)
			var first_skin: Node = game.get_node_or_null("Board/Pads/Pad1/Skin")
			if first_skin == null:
				push_error("Missing Skin child on Pad1")
				failed = true
			else:
				print("OK Skin pattern on pads")

	if game.get_node_or_null("Board/Decor/SpawnMarker/Skin") == null:
		push_error("Missing Decor/SpawnMarker/Skin")
		failed = true
	else:
		print("OK Skin pattern on decor")

	if game.get_node_or_null("UI/Root/TopBar") == null or game.get_node_or_null("UI/Root/BottomBar") == null:
		push_error("Missing UI TopBar/BottomBar")
		failed = true
	else:
		print("OK HUD zones")

	game.queue_free()

	if failed:
		print("stage01_smoke FAILED")
		quit(1)
	else:
		print("stage01_smoke PASSED")
		quit(0)
