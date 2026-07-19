extends Control


func _ready() -> void:
	%VersionLabel.text = "v%s · bubble" % ProjectSettings.get_setting("application/config/version", "dev")
	Juice.squishify_button(%NewGameButton)
	Juice.squishify_button(%SettingsButton)
	Sound.stop_music()
	_play_intro_juice()
	%NewGameButton.grab_focus()


func _play_intro_juice() -> void:
	var title := %Title as Label
	var new_game := %NewGameButton as Button
	var settings := %SettingsButton as Button

	# Size is 0 until layout runs — defer pivots, then kick off tweens.
	await get_tree().process_frame
	title.pivot_offset = title.size / 2.0
	new_game.pivot_offset = new_game.size / 2.0
	settings.pivot_offset = settings.size / 2.0

	# Never scale menu buttons to ZERO — on web/touch a 0-scale Control has no
	# usable hit target, so New Game/Settings appear dead until (or unless) the
	# tween finishes. Animate from a near-full scale instead.
	title.scale = Vector2(0.6, 0.6)
	var title_in := create_tween()
	title_in.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	title_in.tween_property(title, "scale", Vector2.ONE, 0.4)
	title_in.finished.connect(_start_title_bob.bind(title), CONNECT_ONE_SHOT)

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
