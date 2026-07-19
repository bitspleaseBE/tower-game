extends Control
## Bottom-sheet build / manage menu for one-thumb play.

const TowerScene: PackedScene = preload("res://scenes/entities/tower.tscn")

@onready var panel: PanelContainer = %SheetPanel
@onready var title_label: Label = %TitleLabel
@onready var primary_button: Button = %PrimaryButton
@onready var sell_button: Button = %SellButton

var _pad: BuildPad
var _mode: StringName = &""
var _game: Node
var _open: bool = false
var _popper: TowerData


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = true
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_popper = load("res://data/towers/popper.tres") as TowerData
	_set_sheet_hidden_instant()
	primary_button.pressed.connect(_on_primary_pressed)
	sell_button.pressed.connect(_on_sell_pressed)
	Events.coins_changed.connect(_on_coins_changed)


func setup(game: Node) -> void:
	_game = game


func is_open() -> bool:
	return _open


func open_build(pad: BuildPad) -> void:
	_clear_range()
	_pad = pad
	_mode = &"build"
	title_label.text = "Build"
	sell_button.visible = false
	_refresh_build_button()
	_slide_in()


func open_manage(pad: BuildPad) -> void:
	_clear_range()
	_pad = pad
	_mode = &"manage"
	title_label.text = "Manage"
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
	_open = false
	_pad = null
	_mode = &""
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(panel, "offset_top", 200.0, 0.18)
	tween.parallel().tween_property(panel, "offset_bottom", 200.0, 0.18)
	tween.tween_callback(func() -> void:
		panel.visible = false
	)


func _slide_in() -> void:
	_open = true
	panel.visible = true
	panel.offset_top = 200.0
	panel.offset_bottom = 200.0
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "offset_top", -200.0, 0.28)
	tween.parallel().tween_property(panel, "offset_bottom", -12.0, 0.28)


func _set_sheet_hidden_instant() -> void:
	_open = false
	panel.offset_top = 200.0
	panel.offset_bottom = 200.0
	panel.visible = false


func _on_coins_changed(_coins: int) -> void:
	if not _open:
		return
	if _mode == &"build":
		_refresh_build_button()
	elif _mode == &"manage":
		_refresh_manage_buttons()


func _refresh_build_button() -> void:
	var cost: int = _popper.cost[0]
	primary_button.text = "%s — %d●" % [_popper.display_name, cost]
	primary_button.disabled = _game == null or not _game.can_afford(cost)
	primary_button.custom_minimum_size = Vector2(0, 88)


func _refresh_manage_buttons() -> void:
	if _pad == null or _pad.tower == null:
		return
	var tower: Tower = _pad.tower
	sell_button.text = "Sell +%d●" % tower.sell_refund()
	sell_button.custom_minimum_size = Vector2(0, 88)
	sell_button.theme_type_variation = &"ButtonSecondary"
	if tower.tier >= 2:
		primary_button.text = "MAX"
		primary_button.disabled = true
	else:
		var next_cost: int = tower.data.cost[tower.tier + 1]
		primary_button.text = "Upgrade — %d●" % next_cost
		primary_button.disabled = _game == null or not _game.can_afford(next_cost)
	primary_button.custom_minimum_size = Vector2(0, 88)


func _on_primary_pressed() -> void:
	if _game == null or _pad == null:
		return
	if _mode == &"build":
		var cost: int = _popper.cost[0]
		if not _game.spend(cost):
			return
		var tower: Tower = TowerScene.instantiate()
		_pad.add_child(tower)
		tower.setup(_popper)
		_pad.tower = tower
		Events.tower_built.emit(tower, _pad)
		close()
	elif _mode == &"manage" and _pad.tower:
		var tower: Tower = _pad.tower
		if tower.tier >= 2:
			return
		var cost: int = tower.data.cost[tower.tier + 1]
		if not _game.spend(cost):
			return
		tower.upgrade()
		Events.tower_upgraded.emit(tower)
		_refresh_manage_buttons()


func _on_sell_pressed() -> void:
	if _game == null or _pad == null or _pad.tower == null:
		return
	var tower: Tower = _pad.tower
	var refund: int = tower.sell_refund()
	tower.show_range(false)
	tower.queue_free()
	_pad.tower = null
	_game.earn(refund)
	Events.tower_sold.emit(_pad, refund)
	close()


func _clear_range() -> void:
	if _pad != null and _pad.tower != null:
		_pad.tower.show_range(false)
