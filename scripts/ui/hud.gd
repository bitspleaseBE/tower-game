extends Control
## Top-strip HUD: lives, coins, wave, menu, and wave countdown.

signal menu_requested

@onready var lives_row: HBoxContainer = %LivesRow
@onready var coins_row: HBoxContainer = %CoinsRow
@onready var lives_label: Label = %LivesLabel
@onready var coins_label: Label = %CoinsLabel
@onready var wave_label: Label = %WaveLabel
@onready var menu_button: Button = %MenuButton
@onready var countdown_label: Label = %CountdownLabel

var _displayed_coins: float = 0.0
var _coin_tween: Tween
var _prev_lives: int = -1
var _total_waves: int = 1
var _endless: bool = false
var _best: int = 0
var _current_wave: int = 1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	countdown_label.visible = false
	coins_row.resized.connect(func() -> void:
		coins_row.pivot_offset = coins_row.size * 0.5
	)
	lives_row.resized.connect(func() -> void:
		lives_row.pivot_offset = lives_row.size * 0.5
	)
	wave_label.resized.connect(func() -> void:
		wave_label.pivot_offset = wave_label.size * 0.5
	)
	menu_button.pressed.connect(func() -> void: menu_requested.emit())
	Juice.squishify_button(menu_button)
	Juice.claim(lives_row)
	Events.coins_changed.connect(_on_coins_changed)
	Events.lives_changed.connect(_on_lives_changed)
	Events.wave_started.connect(_on_wave_started)
	Events.wave_cleared.connect(_on_wave_cleared)
	Events.endless_best.connect(_on_endless_best)


func setup_run(total_waves: int, endless: bool, best: int) -> void:
	_total_waves = total_waves
	_endless = endless
	_best = best
	_render_wave()


func set_wave(current: int, total: int) -> void:
	_current_wave = current
	_total_waves = total
	_render_wave()


func show_countdown(seconds_left: int) -> void:
	countdown_label.visible = seconds_left > 0
	if seconds_left > 0:
		countdown_label.text = "Next wave in %d…" % seconds_left
	else:
		countdown_label.visible = false


func hide_countdown() -> void:
	countdown_label.visible = false


## World/screen position of the coin counter. No Camera2D — world == screen.
func coin_anchor() -> Vector2:
	return coins_row.global_position + coins_row.size * 0.5


func pulse_coins() -> void:
	coins_row.pivot_offset = coins_row.size * 0.5
	Juice.punch_scale(coins_row, 1.18, 0.14)


func _render_wave() -> void:
	if _endless:
		if _best > 0:
			wave_label.text = "Wave %d · Best %d" % [_current_wave, _best]
		else:
			wave_label.text = "Wave %d" % _current_wave
	else:
		wave_label.text = "Wave %d/%d" % [_current_wave, _total_waves]


func _on_coins_changed(coins: int) -> void:
	if _coin_tween != null and _coin_tween.is_valid():
		_coin_tween.kill()
	var from := _displayed_coins
	_coin_tween = create_tween()
	_coin_tween.tween_method(_set_coins_display, from, float(coins), 0.3)


func _set_coins_display(value: float) -> void:
	_displayed_coins = value
	coins_label.text = "%d" % int(round(value))


func _on_lives_changed(lives: int) -> void:
	lives_label.text = "%d" % lives
	lives_row.pivot_offset = lives_row.size * 0.5
	if _prev_lives >= 0 and lives < _prev_lives:
		Juice.punch_scale(lives_row)
	_prev_lives = lives


func _on_wave_started(number: int, total: int) -> void:
	_current_wave = number
	if not _endless:
		_total_waves = total
	_render_wave()
	hide_countdown()


func _on_wave_cleared(_number: int) -> void:
	pass


func _on_endless_best(_map_id: StringName, wave: int) -> void:
	_best = wave
	_render_wave()
	wave_label.pivot_offset = wave_label.size * 0.5
	Juice.punch_scale(wave_label)
	Sound.play_sfx(&"new_best")
