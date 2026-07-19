extends Control
## Bottom-sheet build / manage menu for one-thumb play.

const TowerScene: PackedScene = preload("res://scenes/entities/tower.tscn")
const COIN_ICON: Texture2D = preload("res://assets/ui/icon_coin.png")
const TOWER_SWATCHES := {
	&"popper": Color(1.0, 0.56, 0.69, 1.0),
	&"lobber": Color(1.0, 0.839, 0.42, 1.0),
	&"chiller": Color(0.553, 0.816, 0.941, 1.0),
	&"longshot": Color(0.749, 0.627, 0.91, 1.0),
}

@export var towers: Array[TowerData] = []

@onready var panel: PanelContainer = %SheetPanel
@onready var title_label: Label = %TitleLabel
@onready var options_row: HBoxContainer = %Options
@onready var hint_label: Label = %HintLabel
@onready var primary_button: Button = %PrimaryButton
@onready var sell_button: Button = %SellButton

var _pad: BuildPad
var _mode: StringName = &""
var _game: Node
var _open: bool = false
var _option_buttons: Array[Button] = []
var _range_preview: RangePreview
var _prev_affordable: Array[bool] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = true
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	if towers.is_empty():
		towers = [
			load("res://data/towers/popper.tres") as TowerData,
			load("res://data/towers/lobber.tres") as TowerData,
			load("res://data/towers/chiller.tres") as TowerData,
			load("res://data/towers/longshot.tres") as TowerData,
		]
	_build_option_buttons()
	_set_sheet_hidden_instant()
	primary_button.pressed.connect(_on_primary_pressed)
	sell_button.pressed.connect(_on_sell_pressed)
	Juice.squishify_button(primary_button)
	Juice.squishify_button(sell_button)
	_setup_coin_button(primary_button)
	_setup_coin_button(sell_button)
	Events.coins_changed.connect(_on_coins_changed)
	Events.tower_upgraded.connect(_on_tower_upgraded_juice)
	Events.tower_sold.connect(_on_tower_sold_juice)


func setup(game: Node) -> void:
	_game = game
	_range_preview = game.get_node_or_null("Board/RangePreview") as RangePreview


func is_open() -> bool:
	return _open


func open_build(pad: BuildPad) -> void:
	_clear_range()
	_pad = pad
	_mode = &"build"
	title_label.text = "Build"
	hint_label.visible = true
	hint_label.text = "Tap to build"
	options_row.visible = true
	primary_button.visible = false
	sell_button.visible = false
	_refresh_build_options()
	_slide_in()
	_stagger_option_pop()


func open_manage(pad: BuildPad) -> void:
	_clear_range()
	_clear_selection()
	_pad = pad
	_mode = &"manage"
	title_label.text = "Manage"
	hint_label.visible = false
	options_row.visible = false
	primary_button.visible = true
	sell_button.visible = true
	if pad.tower:
		pad.tower.show_range(true)
	_refresh_manage_buttons()
	_slide_in()


func close() -> void:
	if not _open:
		_set_sheet_hidden_instant()
		return
	_clear_range()
	_clear_selection()
	_open = false
	_pad = null
	_mode = &""
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(panel, "offset_top", 280.0, 0.18)
	tween.parallel().tween_property(panel, "offset_bottom", 280.0, 0.18)
	tween.tween_callback(func() -> void:
		panel.visible = false
	)


func _build_option_buttons() -> void:
	for child: Node in options_row.get_children():
		child.queue_free()
	_option_buttons.clear()
	_prev_affordable.clear()

	for i: int in towers.size():
		var tower_data: TowerData = towers[i]
		var btn := Button.new()
		btn.toggle_mode = false
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 128)
		btn.focus_mode = Control.FOCUS_NONE
		btn.text = "" # Content is laid out below — avoids swatch/text overlap.
		btn.clip_text = true

		var content := VBoxContainer.new()
		content.name = "Content"
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.set_anchors_preset(Control.PRESET_FULL_RECT)
		content.offset_left = 6.0
		content.offset_top = 10.0
		content.offset_right = -6.0
		content.offset_bottom = -12.0
		content.alignment = BoxContainer.ALIGNMENT_CENTER
		content.add_theme_constant_override("separation", 4)
		btn.add_child(content)

		var swatch_row := CenterContainer.new()
		swatch_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(swatch_row)

		var icon := Panel.new()
		icon.name = "Swatch"
		icon.custom_minimum_size = Vector2(28, 28)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = TOWER_SWATCHES.get(tower_data.id, Color.WHITE)
		style.corner_radius_top_left = 14
		style.corner_radius_top_right = 14
		style.corner_radius_bottom_left = 14
		style.corner_radius_bottom_right = 14
		icon.add_theme_stylebox_override("panel", style)
		swatch_row.add_child(icon)

		var name_lbl := Label.new()
		name_lbl.name = "NameLabel"
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_lbl.text = tower_data.display_name
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 22)
		name_lbl.add_theme_color_override("font_color", Color.WHITE)
		content.add_child(name_lbl)

		var cost_row := HBoxContainer.new()
		cost_row.name = "CostRow"
		cost_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cost_row.alignment = BoxContainer.ALIGNMENT_CENTER
		cost_row.add_theme_constant_override("separation", 4)
		content.add_child(cost_row)

		var cost_lbl := Label.new()
		cost_lbl.name = "CostLabel"
		cost_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cost_lbl.text = str(tower_data.cost[0])
		cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost_lbl.add_theme_font_size_override("font_size", 26)
		cost_lbl.add_theme_color_override("font_color", Color.WHITE)
		cost_row.add_child(cost_lbl)

		cost_row.add_child(_make_coin_icon(22.0))

		btn.pressed.connect(_on_option_pressed.bind(i))
		Juice.squishify_button(btn)
		options_row.add_child(btn)
		_option_buttons.append(btn)
		_prev_affordable.append(false)


func _option_cost_label(btn: Button) -> Label:
	return btn.find_child("CostLabel", true, false) as Label


func _option_name_label(btn: Button) -> Label:
	return btn.find_child("NameLabel", true, false) as Label


func _slide_in() -> void:
	_open = true
	panel.visible = true
	panel.offset_top = 280.0
	panel.offset_bottom = 280.0
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "offset_top", -280.0, 0.28)
	tween.parallel().tween_property(panel, "offset_bottom", -12.0, 0.28)


func _set_sheet_hidden_instant() -> void:
	_open = false
	panel.offset_top = 280.0
	panel.offset_bottom = 280.0
	panel.visible = false


func _stagger_option_pop() -> void:
	for i: int in _option_buttons.size():
		var btn: Button = _option_buttons[i]
		btn.pivot_offset = btn.size * 0.5
		btn.scale = Vector2(0.85, 0.85)
		var tween := btn.create_tween()
		tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_interval(0.05 * float(i))
		tween.tween_property(btn, "scale", Vector2.ONE, 0.22)


func _on_coins_changed(_coins: int) -> void:
	if not _open:
		return
	if _mode == &"build":
		_refresh_build_options()
	elif _mode == &"manage":
		_refresh_manage_buttons()


func _is_free_build() -> bool:
	return _game != null and bool(_game.get("free_build"))


func _can_afford_option(tower_data: TowerData) -> bool:
	if _is_free_build():
		return true
	return _game != null and _game.can_afford(tower_data.cost[0])


func _refresh_build_options() -> void:
	for i: int in _option_buttons.size():
		var tower_data: TowerData = towers[i]
		var btn: Button = _option_buttons[i]
		var name_lbl := _option_name_label(btn)
		var cost_lbl := _option_cost_label(btn)
		if name_lbl != null:
			name_lbl.text = tower_data.display_name
		if cost_lbl != null:
			cost_lbl.text = str(tower_data.cost[0])
		# Greyed ≠ disabled — unaffordable options must still receive taps.
		btn.disabled = false
		var affordable := _can_afford_option(tower_data)
		btn.modulate = Color(1, 1, 1, 1.0) if affordable else Color(1, 1, 1, 0.55)
		if affordable and i < _prev_affordable.size() and not _prev_affordable[i]:
			btn.pivot_offset = btn.size * 0.5
			var pop := btn.create_tween()
			pop.tween_property(btn, "scale", Vector2(1.06, 1.06), 0.08)
			pop.tween_property(btn, "scale", Vector2.ONE, 0.1)
		if i < _prev_affordable.size():
			_prev_affordable[i] = affordable
		else:
			_prev_affordable.append(affordable)


func _setup_coin_button(btn: Button) -> void:
	btn.expand_icon = true
	btn.add_theme_constant_override("icon_max_width", 28)
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func _make_coin_icon(size_px: float) -> TextureRect:
	var coin := TextureRect.new()
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin.texture = COIN_ICON
	coin.custom_minimum_size = Vector2(size_px, size_px)
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin.modulate = Color(1.0, 0.788, 0.302, 1.0)
	return coin


func _refresh_manage_buttons() -> void:
	if _pad == null or _pad.tower == null:
		return
	var tower: Tower = _pad.tower
	sell_button.icon = COIN_ICON
	sell_button.text = "Sell +%d" % tower.sell_refund()
	sell_button.custom_minimum_size = Vector2(0, 88)
	sell_button.theme_type_variation = &"ButtonSecondary"
	if tower.tier >= 2:
		primary_button.icon = null
		primary_button.text = "MAX"
		primary_button.disabled = true
	else:
		var next_cost: int = tower.data.cost[tower.tier + 1]
		primary_button.icon = COIN_ICON
		primary_button.text = "Upgrade — %d" % next_cost
		primary_button.disabled = not _is_free_build() and (_game == null or not _game.can_afford(next_cost))
	primary_button.custom_minimum_size = Vector2(0, 88)


func _on_option_pressed(index: int) -> void:
	if _mode != &"build" or _game == null or _pad == null:
		return
	if index < 0 or index >= towers.size():
		return
	var tower_data: TowerData = towers[index]

	# One tap builds — range flashes on the pad as the sheet closes.
	if _range_preview != null:
		_range_preview.show_at(_pad.global_position, tower_data.range_px[0])

	if not _can_afford_option(tower_data):
		Juice.wiggle(_option_buttons[index])
		if _game.has_method("pulse_coin_hud"):
			_game.pulse_coin_hud()
		elif _game.get("hud") != null and _game.hud.has_method("pulse_coins"):
			_game.hud.pulse_coins()
		return
	if not _game.spend(tower_data.cost[0]):
		Juice.wiggle(_option_buttons[index])
		return
	var tower: Tower = TowerScene.instantiate()
	_pad.add_child(tower)
	tower.setup(tower_data)
	_pad.tower = tower
	Sound.play_sfx(&"build_place")
	Events.tower_built.emit(tower, _pad)
	close()


func _on_primary_pressed() -> void:
	if _game == null or _pad == null:
		return
	if _mode == &"manage" and _pad.tower:
		var tower: Tower = _pad.tower
		if tower.tier >= 2:
			return
		var cost: int = tower.data.cost[tower.tier + 1]
		if not _game.spend(cost):
			return
		tower.upgrade()
		Sound.play_sfx(&"upgrade")
		Events.tower_upgraded.emit(tower)
		_refresh_manage_buttons()


func _on_sell_pressed() -> void:
	if _game == null or _pad == null or _pad.tower == null:
		return
	var tower: Tower = _pad.tower
	var refund: int = tower.sell_refund()
	var pad_skin: Node2D = _pad.skin if _pad.get("skin") != null else null
	tower.show_range(false)
	tower.queue_free()
	_pad.tower = null
	_game.earn(refund)
	Sound.play_sfx(&"sell")
	Events.tower_sold.emit(_pad, refund)
	if pad_skin != null:
		Juice.sell_fx(_pad.global_position, pad_skin)
	close()


func _on_tower_upgraded_juice(tower: Node) -> void:
	# upgrade_fx already called from Tower.upgrade(); keep hook for future.
	if tower is Tower:
		pass


func _on_tower_sold_juice(_pad_node: Node, _refund: int) -> void:
	pass


func _clear_selection() -> void:
	for btn: Button in _option_buttons:
		btn.self_modulate = Color.WHITE
	if _range_preview != null:
		_range_preview.hide_preview()


func _clear_range() -> void:
	if _pad != null and _pad.tower != null:
		_pad.tower.show_range(false)
	if _range_preview != null:
		_range_preview.hide_preview()
