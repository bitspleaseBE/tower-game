extends Control

const MAX_GREETING_NAME_LEN := 24


func _ready() -> void:
	%VersionLabel.text = "v%s · bubble" % ProjectSettings.get_setting("application/config/version", "dev")
	_apply_greeting(_read_welcome_name())
	Juice.squishify_button(%NewGameButton)
	Juice.squishify_button(%SettingsButton)
	Sound.stop_music()
	_play_intro_juice()
	%NewGameButton.grab_focus()


func _read_welcome_name() -> String:
	## Web: ?name=Emiel. Desktop/editor: --name=Emiel (user args).
	var raw := ""
	if OS.has_feature("web"):
		var val: Variant = JavaScriptBridge.eval(
			"new URLSearchParams(window.location.search).get('name')", true
		)
		if val != null:
			raw = str(val)
	else:
		for arg: String in OS.get_cmdline_user_args():
			if arg.begins_with("--name="):
				raw = arg.substr(7)
				break
			elif arg == "--name":
				# next token, if any — Godot doesn't pair these; skip
				pass
	return _sanitize_welcome_name(raw)


func _sanitize_welcome_name(raw: String) -> String:
	var name := raw.strip_edges().replace("\n", " ").replace("\r", " ").replace("\t", " ")
	while name.find("  ") >= 0:
		name = name.replace("  ", " ")
	name = name.strip_edges()
	if name.is_empty() or name.to_lower() == "null":
		return ""
	if name.length() > MAX_GREETING_NAME_LEN:
		name = name.substr(0, MAX_GREETING_NAME_LEN).strip_edges()
	return name


func _apply_greeting(player_name: String) -> void:
	var greeting := %GreetingLabel as Label
	if player_name.is_empty():
		greeting.visible = false
		return
	greeting.text = "Hi %s" % player_name
	greeting.visible = true


func _play_intro_juice() -> void:
	var title := %Title as Label
	var greeting := %GreetingLabel as Label
	var new_game := %NewGameButton as Button
	var settings := %SettingsButton as Button

	# Size is 0 until layout runs — defer pivots, then kick off tweens.
	await get_tree().process_frame
	title.pivot_offset = title.size / 2.0
	new_game.pivot_offset = new_game.size / 2.0
	settings.pivot_offset = settings.size / 2.0
	if greeting.visible:
		greeting.pivot_offset = greeting.size / 2.0

	# Never scale menu buttons to ZERO — on web/touch a 0-scale Control has no
	# usable hit target, so New Game/Settings appear dead until (or unless) the
	# tween finishes. Animate from a near-full scale instead.
	title.scale = Vector2(0.6, 0.6)
	var title_in := create_tween()
	title_in.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	title_in.tween_property(title, "scale", Vector2.ONE, 0.4)
	title_in.finished.connect(_start_title_bob.bind(title), CONNECT_ONE_SHOT)

	if greeting.visible:
		greeting.scale = Vector2(0.7, 0.7)
		greeting.modulate.a = 0.0
		var greet_in := create_tween()
		greet_in.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		greet_in.tween_interval(0.12)
		greet_in.tween_property(greeting, "modulate:a", 1.0, 0.2)
		greet_in.parallel().tween_property(greeting, "scale", Vector2.ONE, 0.28)

	for i: int in [0, 1]:
		var btn: Button = new_game if i == 0 else settings
		btn.scale = Vector2(0.85, 0.85)
		btn.disabled = false
		var pop := create_tween()
		pop.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		pop.tween_interval(0.08 * float(i))
		pop.tween_property(btn, "scale", Vector2.ONE, 0.28)


func _start_title_bob(title: Label) -> void:
	var base_y := title.position.y
	var bob := create_tween()
	bob.set_loops()
	bob.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(title, "position:y", base_y - 6.0, 1.0)
	bob.tween_property(title, "position:y", base_y + 6.0, 2.0)
	bob.tween_property(title, "position:y", base_y, 1.0)


func _on_new_game_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/map_select.tscn")


func _on_settings_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/settings_menu.tscn")
