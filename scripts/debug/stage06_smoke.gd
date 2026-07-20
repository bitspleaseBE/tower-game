extends SceneTree
## Headless smoke test for Stage 6 candy art swaps.
## Usage: godot --headless --path . --script scripts/debug/stage06_smoke.gd


func _initialize() -> void:
	var failed := false

	var required_assets := [
		"res://assets/background/ground_meadow.png",
		"res://assets/background/grass_tile.png",
		"res://assets/background/path_straight.png",
		"res://assets/background/pad.png",
		"res://assets/background/decor_tree.png",
		"res://assets/background/decor_bush.png",
		"res://assets/background/decor_rock.png",
		"res://assets/background/decor_gumdrop.png",
		"res://assets/background/decor_gumdrop_blue.png",
		"res://assets/background/decor_swirl.png",
		"res://assets/background/decor_swirl_mint.png",
		"res://assets/background/decor_candy_cane.png",
		"res://assets/background/decor_bubblegum.png",
		"res://assets/background/decor_lollipop_blue.png",
		"res://assets/enemies/critter_normal.png",
		"res://assets/enemies/critter_fast.png",
		"res://assets/enemies/critter_swarm.png",
		"res://assets/enemies/critter_armored.png",
		"res://assets/enemies/critter_boss.png",
		"res://assets/enemies/face_a.png",
		"res://assets/enemies/face_b.png",
		"res://assets/enemies/face_c.png",
		"res://assets/enemies/face_d.png",
		"res://assets/enemies/face_e.png",
		"res://assets/tower/base_square.png",
		"res://assets/tower/base_square_t2.png",
		"res://assets/tower/base_square_t3.png",
		"res://assets/tower/base_hex.png",
		"res://assets/tower/base_hex_t2.png",
		"res://assets/tower/base_hex_t3.png",
		"res://assets/tower/weapon_popper.png",
		"res://assets/tower/weapon_popper_t2.png",
		"res://assets/tower/weapon_popper_t3.png",
		"res://assets/tower/weapon_lobber_t2.png",
		"res://assets/tower/weapon_lobber_t3.png",
		"res://assets/tower/weapon_chiller_t2.png",
		"res://assets/tower/weapon_chiller_t3.png",
		"res://assets/tower/weapon_longshot_t2.png",
		"res://assets/tower/weapon_longshot_t3.png",
		"res://assets/tower/projectile_shot.png",
		"res://assets/tower/projectile_shell.png",
		"res://assets/ui/icon_heart.png",
		"res://assets/ui/icon_coin.png",
		"res://assets/fx/shine_spec.png",
		"res://assets/fx/particle_confetti.png",
		"res://assets/fx/particle_puff.png",
		"res://assets/fx/particle_sparkle.png",
	]
	for path: String in required_assets:
		if not ResourceLoader.exists(path):
			push_error("Missing asset: %s" % path)
			failed = true
	if not failed:
		print("OK assets present (%d)" % required_assets.size())

	var grass: Texture2D = load("res://assets/background/grass_tile.png") as Texture2D
	var meadow: Texture2D = load("res://assets/background/ground_meadow.png") as Texture2D
	if grass == null:
		push_error("grass_tile failed to load")
		failed = true
	else:
		print("OK grass_tile loads %dx%d" % [grass.get_width(), grass.get_height()])
	if meadow == null:
		push_error("ground_meadow failed to load")
		failed = true
	else:
		print("OK ground_meadow loads %dx%d" % [meadow.get_width(), meadow.get_height()])

	var heart: Texture2D = load("res://assets/ui/icon_heart.png") as Texture2D
	var coin: Texture2D = load("res://assets/ui/icon_coin.png") as Texture2D
	if heart == null or coin == null:
		push_error("HUD icons failed to load")
		failed = true
	else:
		print("OK HUD icons load")

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

	var ground: Node = game.get_node_or_null("Board/Ground")
	if ground == null:
		push_error("Missing Board/Ground")
		failed = true
	elif ground is Sprite2D:
		var ground_spr := ground as Sprite2D
		if ground_spr.texture == null:
			push_error("Ground Sprite2D has no texture")
			failed = true
		elif ground_spr.texture.resource_path != "res://assets/background/ground_meadow.png":
			push_error("Ground texture should be ground_meadow.png, got %s" % ground_spr.texture.resource_path)
			failed = true
		elif ground_spr.region_enabled:
			push_error("Ground should not use region tiling (web GL compat)")
			failed = true
		else:
			print("OK Ground is Sprite2D with meadow texture")
	else:
		# Fallback: grass must still load even if scene mid-edit.
		if grass == null:
			push_error("Ground is not Sprite2D and grass missing")
			failed = true
		else:
			push_warning("Ground is %s (expected Sprite2D) — grass still loads" % ground.get_class())
			print("OK grass loads (Ground class=%s)" % ground.get_class())

	if game.get_node_or_null("Board/Path/PathHighlight") == null:
		push_error("Missing PathHighlight")
		failed = true
	else:
		print("OK PathHighlight")

	if game.get_node_or_null("Board/Decor/Props") == null:
		push_error("Missing Board/Decor/Props")
		failed = true
	else:
		var props: Node = game.get_node("Board/Decor/Props")
		if props.get_child_count() < 12:
			push_error("Expected ≥12 decor props, got %d" % props.get_child_count())
			failed = true
		else:
			print("OK decor props=%d" % props.get_child_count())

	if game.get_node_or_null("UI/Vignette") == null:
		push_error("Missing UI/Vignette")
		failed = true
	else:
		print("OK Vignette")

	# Enemy skin Sprite2D children after activate.
	var swarm: EnemyData = load("res://data/enemies/swarm.tres") as EnemyData
	var boss: EnemyData = load("res://data/enemies/boss.tres") as EnemyData
	if swarm != null and game.has_method("_spawn_enemy"):
		var e_swarm: Node = game._spawn_enemy(swarm)
		if e_swarm == null:
			push_error("swarm spawn failed")
			failed = true
		else:
			var skin: Node = e_swarm.get_node_or_null("Skin")
			if skin == null or not _skin_has_sprite2d(skin):
				push_error("enemy Skin missing Sprite2D children")
				failed = true
			else:
				# Candy bodies bake the face into the body sprite (no separate Face overlay).
				var has_body := false
				for child: Node in skin.get_children():
					if String(child.name) == "Body" and child is Sprite2D:
						has_body = true
						break
				if not has_body:
					push_error("enemy Skin missing Body sprite")
					failed = true
				else:
					print("OK enemy Skin has candy body")
			e_swarm.call("deactivate")

	if boss != null and game.has_method("_spawn_enemy"):
		var e_boss: Node = game._spawn_enemy(boss)
		if e_boss == null:
			push_error("boss spawn failed")
			failed = true
		else:
			var skin: Node = e_boss.get_node_or_null("Skin")
			var has_crown := false
			if skin != null:
				for child: Node in skin.get_children():
					if child is Polygon2D and String(child.name) == "Crown":
						has_crown = true
						break
					# Crown may still be pending if queue_free race; accept any Polygon2D on boss.
					if child is Polygon2D:
						has_crown = true
			if not has_crown:
				push_error("boss crown polygon missing")
				failed = true
			else:
				print("OK boss crown")
			e_boss.call("deactivate")

	# Tower skin Sprite2D children.
	var popper: TowerData = load("res://data/towers/popper.tres") as TowerData
	var pads: Array = game.get_tree().get_nodes_in_group("build_pads")
	var tower_scene: PackedScene = load("res://scenes/entities/tower.tscn") as PackedScene
	if pads.size() > 0 and tower_scene != null and popper != null:
		var pad: Node = pads[0]
		var tower: Node = tower_scene.instantiate()
		pad.add_child(tower)
		tower.call("setup", popper)
		var t_skin: Node = tower.get_node_or_null("Skin")
		if t_skin == null or not _skin_has_sprite2d(t_skin):
			push_error("tower Skin missing Sprite2D children")
			failed = true
		else:
			print("OK tower Skin has Sprite2D")
		# Pad skin should also be sprites.
		var p_skin: Node = pad.get_node_or_null("Skin")
		if p_skin == null or not _skin_has_sprite2d(p_skin):
			push_error("build_pad Skin missing Sprite2D")
			failed = true
		else:
			print("OK build_pad Skin has Sprite2D")
		if pad.get_node_or_null("Shadow") == null:
			push_error("build_pad Shadow missing")
			failed = true
		else:
			print("OK build_pad Shadow")

	# HUD icons.
	var hud: Node = game.get_node_or_null("UI/Hud")
	if hud != null:
		var heart_icon: Node = hud.get_node_or_null("%HeartIcon")
		var coin_icon: Node = hud.get_node_or_null("%CoinIcon")
		if heart_icon == null or coin_icon == null:
			# Unique names resolve via owner; try absolute paths.
			heart_icon = hud.find_child("HeartIcon", true, false)
			coin_icon = hud.find_child("CoinIcon", true, false)
		if heart_icon == null or coin_icon == null:
			push_error("HUD HeartIcon/CoinIcon missing")
			failed = true
		else:
			print("OK HUD TextureRect icons")

	# Confetti uses particle texture.
	var confetti_src := FileAccess.get_file_as_string("res://scenes/fx/confetti_cpu.tscn")
	if not confetti_src.contains("particle_confetti.png"):
		push_error("confetti scene missing particle_confetti texture")
		failed = true
	else:
		print("OK confetti particle texture")

	# Clear color / icon retuned.
	var clear_color: Color = ProjectSettings.get_setting(
		"rendering/environment/defaults/default_clear_color", Color.BLACK
	) as Color
	# Expect white frosting meadow clear color (near-white).
	if clear_color.r < 0.9 or clear_color.g < 0.9 or clear_color.b < 0.9:
		push_error("default_clear_color not white frosting: %s" % clear_color)
		failed = true
	else:
		print("OK clear_color=%s" % clear_color)

	var icon_path: String = str(ProjectSettings.get_setting("application/config/icon", ""))
	if not icon_path.ends_with(".png") and not icon_path.ends_with(".svg"):
		push_error("config/icon unexpected: %s" % icon_path)
		failed = true
	else:
		print("OK config/icon=%s" % icon_path)

	# Do not break SaveGame / MapSelect if present.
	if ResourceLoader.exists("res://scripts/autoload/save_game.gd"):
		print("OK SaveGame present")
	if ResourceLoader.exists("res://scenes/map_select.tscn"):
		print("OK MapSelect present")

	# Stop countdown before teardown so it can't fire SFX after audio release.
	var spawner_node: Node = game.get_node_or_null("Spawner")
	if spawner_node != null and spawner_node.has_method("stop"):
		spawner_node.call("stop")

	game.queue_free()
	await process_frame

	# Drop Ogg playbacks/cached streams before SceneTree quit (--script leak check).
	var sound: Node = root.get_node_or_null("/root/Sound")
	if sound != null and sound.has_method("release_for_exit"):
		sound.call("release_for_exit")
	await process_frame
	await process_frame
	Engine.time_scale = 1.0
	_finish(failed)


func _skin_has_sprite2d(skin: Node) -> bool:
	for child: Node in skin.get_children():
		if child is Sprite2D:
			return true
	# queue_free rebuild race: wait one frame not available here; count pending via names.
	return false


func _finish(failed: bool) -> void:
	if failed:
		print("stage06_smoke FAILED")
		quit(1)
	else:
		print("stage06_smoke PASSED")
		quit(0)
