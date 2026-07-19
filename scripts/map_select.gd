extends Control
## Campaign map picker. MainMenu → MapSelect → Game.

const MapCardScene: PackedScene = preload("res://scenes/ui/map_card.tscn")
const ConfettiScene: PackedScene = preload("res://scenes/fx/confetti_cpu.tscn")

@onready var cards_box: VBoxContainer = %Cards
@onready var back_button: Button = %BackButton
@onready var unlock_fx: Node2D = %UnlockFx
@onready var title_label: Label = %Title

var _cards: Dictionary = {} ## StringName -> MapCard


func _ready() -> void:
	Juice.squishify_button(back_button)
	back_button.pressed.connect(_go_menu)
	_build_cards()
	_play_intro()
	_maybe_unlock_ceremony()
	_focus_first()
	Sound.set_music_ducked(true)
	Sound.play_music(&"music_game")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_menu()


func _build_cards() -> void:
	for child: Node in cards_box.get_children():
		child.queue_free()
	_cards.clear()
	var prev_name := ""
	for i: int in SaveGame.CAMPAIGN.size():
		var id: StringName = SaveGame.CAMPAIGN[i]
		var map: MapData = load("res://data/maps/%s.tres" % String(id)) as MapData
		var card: PanelContainer = MapCardScene.instantiate()
		cards_box.add_child(card)
		var unlocked := SaveGame.is_unlocked(id)
		var beaten := SaveGame.is_beaten(id)
		var best := SaveGame.best_endless_wave(id)
		card.setup(map, unlocked, beaten, best, prev_name)
		card.play_pressed.connect(_on_play.bind(map))
		_cards[id] = card
		if map != null:
			prev_name = map.display_name


func _on_play(endless: bool, map: MapData) -> void:
	SaveGame.run_map = map
	SaveGame.run_endless = endless
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _play_intro() -> void:
	await get_tree().process_frame
	var i := 0
	for id: StringName in SaveGame.CAMPAIGN:
		var card: Control = _cards.get(id) as Control
		if card == null:
			continue
		card.pivot_offset = card.size * 0.5
		card.scale = Vector2.ZERO
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_interval(0.08 * float(i))
		tween.tween_property(card, "scale", Vector2.ONE, 0.35)
		i += 1


func _maybe_unlock_ceremony() -> void:
	var unlocked_id: StringName = SaveGame.just_unlocked
	if unlocked_id == &"":
		return
	SaveGame.just_unlocked = &""
	var card: Control = _cards.get(unlocked_id) as Control
	if card == null:
		return
	await get_tree().create_timer(0.5).timeout
	card.pivot_offset = card.size * 0.5
	Juice.punch_scale(card, 1.12, 0.28)
	Sound.play_sfx(&"unlock")
	unlock_fx.global_position = card.global_position + card.size * 0.5
	if unlock_fx.get_child_count() == 0:
		var burst: Node = ConfettiScene.instantiate()
		burst.process_mode = Node.PROCESS_MODE_ALWAYS
		unlock_fx.add_child(burst)
	var confetti: Node = unlock_fx.get_child(0)
	if confetti.has_method("activate"):
		confetti.call("activate", unlock_fx.global_position)
	_pop_unlocked_label(card)


func _pop_unlocked_label(card: Control) -> void:
	var label := Label.new()
	label.text = "Unlocked!"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(1, 0.42, 0.506, 1))
	add_child(label)
	label.global_position = card.global_position + Vector2(card.size.x * 0.5 - 70.0, -8.0)
	label.pivot_offset = label.size * 0.5
	label.scale = Vector2(0.4, 0.4)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2.ONE, 0.3)
	tween.tween_interval(0.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.25)
	tween.tween_callback(label.queue_free)


func _focus_first() -> void:
	await get_tree().process_frame
	for id: StringName in SaveGame.CAMPAIGN:
		var card: Node = _cards.get(id)
		if card == null:
			continue
		var play_btn: Button = card.get_node_or_null("%PlayButton") as Button
		if play_btn != null and play_btn.visible and not play_btn.disabled:
			play_btn.grab_focus()
			return
	back_button.grab_focus()


func _go_menu() -> void:
	Sound.stop_music()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
