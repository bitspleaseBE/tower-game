extends Control
## Campaign map picker. MainMenu → MapSelect → Game.
## Custom drag-scroll so the list works on mobile web (iOS Safari), where
## ScrollContainer + child Buttons often swallow touch drags. Desktop wheel
## scrolling still uses the engine ScrollContainer default.

const MapCardScene: PackedScene = preload("res://scenes/ui/map_card.tscn")
const ConfettiScene: PackedScene = preload("res://scenes/fx/confetti_cpu.tscn")
const DRAG_DEADZONE_PX := 12.0

@onready var cards_box: VBoxContainer = %Cards
@onready var cards_scroll: ScrollContainer = %CardsScroll
@onready var back_button: Button = %BackButton
@onready var unlock_fx: Node2D = %UnlockFx
@onready var title_label: Label = %Title

var _cards: Dictionary = {} ## StringName -> MapCard
var _drag_tracking := false
var _drag_active := false
var _drag_last := Vector2.ZERO
var _drag_origin := Vector2.ZERO
var _block_card_clicks := false


func _ready() -> void:
	add_to_group("map_select")
	Juice.squishify_button(back_button)
	back_button.pressed.connect(_go_menu)
	cards_scroll.follow_focus = false
	cards_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_build_cards()
	# Start at the top so map 1 isn't scrolled off after focus/layout.
	cards_scroll.scroll_vertical = 0
	_play_intro()
	_maybe_unlock_ceremony()
	_focus_first()
	Sound.set_music_ducked(true)
	Sound.play_music(&"music_game")


func should_block_card_clicks() -> bool:
	return _block_card_clicks


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_menu()


## Drag-to-scroll before child Controls eat the gesture (needed on iPhone web).
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or cards_scroll == null:
		return
	var scroll_rect := cards_scroll.get_global_rect()

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			if scroll_rect.has_point(mb.global_position):
				_drag_tracking = true
				_drag_active = false
				_block_card_clicks = false
				_drag_last = mb.global_position
				_drag_origin = mb.global_position
		else:
			if _drag_active or _block_card_clicks:
				get_viewport().set_input_as_handled()
				_block_card_clicks = true
				_clear_click_block.call_deferred()
			_drag_tracking = false
			_drag_active = false
		return

	if event is InputEventMouseMotion and _drag_tracking:
		var mm := event as InputEventMouseMotion
		if (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
			return
		var pos := mm.global_position
		if not _drag_active:
			if _drag_origin.distance_to(pos) < DRAG_DEADZONE_PX:
				return
			_drag_active = true
			_block_card_clicks = true
			_drag_last = pos
			var focused := get_viewport().gui_get_focus_owner()
			if focused != null:
				focused.release_focus()
		var dy := _drag_last.y - pos.y
		_drag_last = pos
		if absf(dy) >= 0.5:
			cards_scroll.scroll_vertical += int(round(dy))
		get_viewport().set_input_as_handled()


func _clear_click_block() -> void:
	_block_card_clicks = false


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
	_update_cards_min_size.call_deferred()


func _update_cards_min_size() -> void:
	await get_tree().process_frame
	if cards_box == null:
		return
	var total := 0.0
	var count := 0
	for child: Node in cards_box.get_children():
		var c := child as Control
		if c == null:
			continue
		total += c.get_combined_minimum_size().y
		count += 1
	if count > 1:
		total += float(cards_box.get_theme_constant("separation")) * float(count - 1)
	## Padding so the last card can scroll fully above the Menu button.
	total += 24.0
	cards_box.custom_minimum_size = Vector2(0.0, total)
	cards_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _on_play(endless: bool, map: MapData) -> void:
	if _block_card_clicks:
		return
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
	cards_scroll.ensure_control_visible(card)
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
	cards_scroll.scroll_vertical = 0
	# Don't grab button focus on touch devices — it fights drag-scroll on iOS.
	if DisplayServer.is_touchscreen_available():
		return
	for id: StringName in SaveGame.CAMPAIGN:
		var card: Node = _cards.get(id)
		if card == null:
			continue
		var play_btn: Button = card.get_node_or_null("%PlayButton") as Button
		if play_btn != null and play_btn.visible and not play_btn.disabled:
			play_btn.grab_focus()
			await get_tree().process_frame
			cards_scroll.scroll_vertical = 0
			return
	back_button.grab_focus()


func _go_menu() -> void:
	Sound.stop_music()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
