extends SceneTree
## Headless smoke test for Stage 7 audio (Sound autoload + assets + buses).
## Usage: godot --headless --path . --script scripts/debug/stage07_smoke.gd
##
## Note: --script SceneTree entry points cannot resolve autoload identifiers at
## parse time; fetch Settings/Sound from /root at runtime (same as stage05).


func _initialize() -> void:
	var failed := false
	# Autoload _ready (Sound↔Settings signal connect) runs after SceneTree._initialize.
	await process_frame
	await process_frame

	var project := FileAccess.get_file_as_string("res://project.godot")
	var juice_i := project.find('Juice="')
	var sound_i := project.find('Sound="')
	if sound_i < 0:
		push_error("Sound autoload missing from project.godot")
		failed = true
	elif juice_i >= 0 and sound_i < juice_i:
		push_error("Sound must register after Juice in project.godot")
		failed = true
	else:
		print("OK Sound autoload after Juice")

	if not project.contains('buses/default_bus_layout="res://default_bus_layout.tres"'):
		push_error("default_bus_layout not wired in project.godot")
		failed = true
	else:
		print("OK bus layout wired")

	var master := AudioServer.get_bus_index("Master")
	var music := AudioServer.get_bus_index("Music")
	var sfx := AudioServer.get_bus_index("SFX")
	if master < 0 or music < 0 or sfx < 0:
		push_error("Missing buses Master/Music/SFX indices=%s/%s/%s" % [master, music, sfx])
		failed = true
	else:
		print("OK buses Master=%d Music=%d SFX=%d" % [master, music, sfx])

	if PerfBudget.MAX_SFX_VOICES != 8:
		push_error("MAX_SFX_VOICES expected 8, got %d" % PerfBudget.MAX_SFX_VOICES)
		failed = true
	else:
		print("OK MAX_SFX_VOICES=%d" % PerfBudget.MAX_SFX_VOICES)

	var hook_ids := [
		&"ui_tap", &"build_place", &"upgrade", &"sell",
		&"shot_popper", &"shot_lobber", &"shot_chiller", &"shot_longshot",
		&"hit", &"kill_pop", &"coin", &"leak", &"countdown_tick",
		&"wave_start", &"win", &"lose", &"unlock", &"new_best", &"music_game",
	]
	var missing: Array[StringName] = []
	for id: StringName in hook_ids:
		var path := "res://assets/audio/%s.ogg" % String(id)
		if not ResourceLoader.exists(path):
			missing.append(id)
	if not missing.is_empty():
		push_error("Missing audio assets: %s" % str(missing))
		failed = true
	else:
		print("OK all %d hook samples present" % hook_ids.size())

	var settings: Node = root.get_node_or_null("Settings")
	var sound: Node = root.get_node_or_null("Sound")
	if settings == null or sound == null:
		push_error("Settings/Sound autoload missing at /root")
		_finish(true)
		return

	if not settings.has_signal("volume_changed"):
		push_error("Settings.volume_changed signal missing")
		failed = true
	else:
		print("OK Settings.volume_changed")

	sound.call("unlock_audio")
	if not bool(sound.call("is_unlocked")):
		push_error("Sound.unlock_audio failed")
		failed = true
	else:
		print("OK Sound unlocked")

	sound.call("set_enabled_from_settings")
	settings.call("set_master_volume", 0.0)
	if not AudioServer.is_bus_mute(master):
		push_error("Master should mute at volume 0")
		failed = true
	else:
		print("OK mute-at-zero")
	settings.call("set_master_volume", 1.0)
	if AudioServer.is_bus_mute(master):
		push_error("Master still muted after volume restore")
		failed = true
	else:
		print("OK volume restore")

	sound.call("play_sfx", &"ui_tap")
	sound.call("play_music", &"music_game")
	sound.call("set_music_ducked", true)
	sound.call("set_music_ducked", false)
	sound.call("stop_sfx")
	sound.call("stop_music")
	print("OK Sound API calls")

	var juice_src := FileAccess.get_file_as_string("res://scripts/autoload/juice.gd")
	if not juice_src.contains('Sound.play_sfx(&"ui_tap")'):
		push_error("ui_tap not wired in Juice.squishify_button path")
		failed = true
	else:
		print("OK ui_tap wired via Juice")

	var game_src := FileAccess.get_file_as_string("res://scripts/game.gd")
	if not game_src.contains("play_music") or not game_src.contains("stop_sfx"):
		push_error("Game music/SFX lifecycle hooks missing")
		failed = true
	else:
		print("OK Game music lifecycle")

	_finish(failed)


func _finish(failed: bool) -> void:
	if failed:
		print("stage07_smoke FAILED")
	else:
		print("stage07_smoke PASSED")
	quit(1 if failed else 0)
