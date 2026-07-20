extends SceneTree
## Headless smoke for Stage 5 campaign / endless / SaveGame.
## Usage: godot --headless --path . --script scripts/debug/stage05_smoke.gd
##
## Note: --script SceneTree entry points cannot resolve autoload identifiers at
## parse time; fetch SaveGame from /root at runtime (same pattern as scene tests).


func _initialize() -> void:
	var failed := false
	var sg: Node = root.get_node_or_null("SaveGame")
	if sg == null:
		push_error("SaveGame autoload missing at /root/SaveGame")
		_finish(true)
		return

	# --- Maps + endless params ---
	for id: String in ["map_01", "map_02", "map_03"]:
		var map: MapData = load("res://data/maps/%s.tres" % id) as MapData
		if map == null:
			push_error("missing %s" % id)
			failed = true
			continue
		if map.waves.size() < 10 or map.waves.size() > 15:
			push_error("%s waves=%d" % [id, map.waves.size()])
			failed = true
		if map.endless_hp_growth <= 1.0 or map.endless_count_growth <= 1.0:
			push_error("%s endless growth missing" % id)
			failed = true
		else:
			print("OK %s waves=%d hp=%.3f" % [id, map.waves.size(), map.endless_hp_growth])

	# --- SaveGame API ---
	var campaign: Array = sg.get("CAMPAIGN")
	if campaign == null or campaign.size() != 3:
		push_error("CAMPAIGN size")
		failed = true
	else:
		print("OK CAMPAIGN")

	if not bool(sg.call("is_unlocked", &"map_01")):
		push_error("map_01 should be unlocked")
		failed = true

	var before_best: int = int(sg.call("best_endless_wave", &"map_01"))
	var recorded: bool = bool(sg.call("record_endless_wave", &"map_01", before_best + 1))
	if not recorded or int(sg.call("best_endless_wave", &"map_01")) != before_best + 1:
		push_error("record_endless_wave failed")
		failed = true
	else:
		print("OK record_endless_wave -> %d" % int(sg.call("best_endless_wave", &"map_01")))

	sg.call("mark_beaten", &"map_01")
	if not bool(sg.call("is_beaten", &"map_01")):
		push_error("mark_beaten failed")
		failed = true
	elif not bool(sg.call("is_unlocked", &"map_02")):
		push_error("map_02 should unlock after map_01 beaten")
		failed = true
	else:
		print("OK unlock chain map_01→map_02 just_unlocked=%s" % String(sg.get("just_unlocked")))

	# --- Per-map tower roster ---
	var roster_01: Array = sg.call("available_tower_ids", &"map_01")
	var roster_02: Array = sg.call("available_tower_ids", &"map_02")
	var roster_03: Array = sg.call("available_tower_ids", &"map_03")
	if roster_01.size() != 2 or not roster_01.has(&"popper") or not roster_01.has(&"lobber"):
		push_error("map_01 should unlock popper+lobber only")
		failed = true
	elif roster_02.size() != 3 or not roster_02.has(&"chiller"):
		push_error("map_02 should add chiller")
		failed = true
	elif roster_03.size() != 4 or not roster_03.has(&"longshot"):
		push_error("map_03 should add longshot")
		failed = true
	else:
		print("OK tower roster 2/3/4")

	# --- Once-ever tip flags ---
	sg.call("mark_tip_seen", "smoke_test_tip")
	if not bool(sg.call("has_seen_tip", "smoke_test_tip")):
		push_error("mark_tip_seen/has_seen_tip failed")
		failed = true
	else:
		var tip_cfg := ConfigFile.new()
		if tip_cfg.load("user://save.cfg") != OK or not tip_cfg.has_section_key("meta", "tip_smoke_test_tip"):
			push_error("tip flag missing from save.cfg meta")
			failed = true
		else:
			print("OK tip_seen persistence")

	# Transient fields must not appear in save.cfg
	var cfg := ConfigFile.new()
	if cfg.load("user://save.cfg") == OK:
		var text := FileAccess.get_file_as_string("user://save.cfg")
		if text.contains("run_map") or text.contains("run_endless") or text.contains("just_unlocked"):
			push_error("transient fields leaked into save.cfg")
			failed = true
		elif not cfg.has_section("map_01"):
			push_error("save.cfg missing map_01 section")
			failed = true
		else:
			print("OK save.cfg shape")
	else:
		push_error("save.cfg missing after writes")
		failed = true

	# --- EndlessWaves ---
	var map1: MapData = load("res://data/maps/map_01.tres") as MapData
	var scripted := map1.waves.size()
	var gen: WaveData = EndlessWaves.generate(map1, scripted + 1)
	if gen == null or gen.spawn_groups.is_empty():
		push_error("EndlessWaves.generate empty")
		failed = true
	else:
		var total := 0
		for g: SpawnGroup in gen.spawn_groups:
			total += g.count
			if g.enemy == null:
				push_error("generated group null enemy")
				failed = true
		var tail := mini(EndlessWaves.TEMPLATE_TAIL, scripted)
		var tmpl_idx := scripted - tail # k=1 → first of the tail cycle
		var template: WaveData = map1.waves[tmpl_idx]
		var tmpl_hp := template.spawn_groups[0].enemy.hp
		var gen2: WaveData = EndlessWaves.generate(map1, scripted + 1)
		if template.spawn_groups[0].enemy.hp != tmpl_hp:
			push_error("EndlessWaves mutated template enemy")
			failed = true
		elif gen2.spawn_groups[0].enemy.hp <= tmpl_hp:
			push_error("expected scaled hp > template (got %.2f vs %.2f)" % [gen2.spawn_groups[0].enemy.hp, tmpl_hp])
			failed = true
		elif total > EndlessWaves.wave_cap():
			push_error("wave_cap exceeded: %d" % total)
			failed = true
		else:
			print("OK EndlessWaves k=1 total=%d hp=%.1f" % [total, gen2.spawn_groups[0].enemy.hp])

	# Speed cap — use same template slot as k=40
	var k := 40
	var tail := mini(EndlessWaves.TEMPLATE_TAIL, scripted)
	var tmpl_idx := scripted - tail + ((k - 1) % tail)
	var base_speed := map1.waves[tmpl_idx].spawn_groups[0].enemy.speed
	var far: WaveData = EndlessWaves.generate(map1, scripted + k)
	var scaled := far.spawn_groups[0].enemy.speed
	if scaled > base_speed * EndlessWaves.SPEED_MULT_CAP * 1.001:
		push_error("speed mult exceeded cap: %.2f vs base %.2f" % [scaled, base_speed])
		failed = true
	else:
		print("OK speed cap scaled=%.1f base=%.1f" % [scaled, base_speed])

	# --- Scenes load ---
	for scene_path: String in [
		"res://scenes/map_select.tscn",
		"res://scenes/ui/map_card.tscn",
		"res://scenes/game.tscn",
		"res://scenes/ui/result_overlay.tscn",
	]:
		if load(scene_path) == null:
			push_error("failed to load %s" % scene_path)
			failed = true
		else:
			print("OK load %s" % scene_path)

	# --- Game run-mode seams ---
	sg.set("run_map", map1)
	sg.set("run_endless", true)
	var game_ps: PackedScene = load("res://scenes/game.tscn") as PackedScene
	var game: Node = game_ps.instantiate()
	game.set_meta("smoke_silent", true)
	root.add_child(game)
	for _i: int in 6:
		await process_frame

	if not bool(game.get("endless")):
		push_error("game.endless not set from SaveGame")
		failed = true
	else:
		print("OK game endless from SaveGame")

	if not game.has_method("get_wave") or not game.has_method("enter_endless"):
		push_error("missing get_wave/enter_endless")
		failed = true
	else:
		var w15: WaveData = game.get_wave(scripted + 1)
		if w15 == null or w15.spawn_groups.is_empty():
			push_error("get_wave endless failed")
			failed = true
		else:
			print("OK get_wave endless")

	var hud: Node = game.get_node_or_null("UI/Hud")
	if hud == null or not hud.has_method("setup_run"):
		push_error("HUD.setup_run missing")
		failed = true
	else:
		print("OK HUD.setup_run")

	var overlay: Node = game.get_node_or_null("UI/ResultOverlay")
	if overlay == null or not overlay.has_method("setup"):
		push_error("ResultOverlay.setup missing")
		failed = true
	else:
		print("OK ResultOverlay.setup")

	# Autoload order: SaveGame between Events and Juice
	var project := FileAccess.get_file_as_string("res://project.godot")
	var events_i := project.find('Events="')
	var save_i := project.find('SaveGame="')
	var juice_i := project.find('Juice="')
	if events_i < 0 or save_i < 0 or juice_i < 0 or not (events_i < save_i and save_i < juice_i):
		push_error("SaveGame autoload order wrong")
		failed = true
	else:
		print("OK SaveGame autoload order")

	# MainMenu → MapSelect
	var menu_src := FileAccess.get_file_as_string("res://scripts/main_menu.gd")
	if not menu_src.contains("map_select.tscn"):
		push_error("MainMenu not wired to MapSelect")
		failed = true
	else:
		print("OK MainMenu → MapSelect")

	# MapSelect instantiates
	var ms_ps: PackedScene = load("res://scenes/map_select.tscn") as PackedScene
	var ms: Node = ms_ps.instantiate()
	root.add_child(ms)
	for _i: int in 4:
		await process_frame
	if ms.get_node_or_null("%Cards") == null:
		push_error("MapSelect Cards missing")
		failed = true
	else:
		print("OK MapSelect Cards")
	ms.queue_free()

	game.queue_free()
	await process_frame
	sg.set("run_map", null)
	sg.set("run_endless", false)
	Engine.time_scale = 1.0
	_finish(failed)


func _finish(failed: bool) -> void:
	if failed:
		print("stage05_smoke FAILED")
		quit(1)
	else:
		print("stage05_smoke PASSED")
		quit(0)
