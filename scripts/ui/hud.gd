extends Control
## Top-strip HUD: lives, coins, wave, menu, and wave countdown.

signal menu_requested

@onready var lives_label: Label = %LivesLabel
@onready var coins_label: Label = %CoinsLabel
@onready var wave_label: Label = %WaveLabel
@onready var menu_button: Button = %MenuButton
@onready var countdown_label: Label = %CountdownLabel

var _displayed_coins: float = 0.0
var _coin_tween: Tween
var _prev_lives: int = -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	countdown_label.visible = false
	coins_label.resized.connect(func() -> void:
		coins_label.pivot_offset = coins_label.size * 0.5
	)
	lives_label.resized.connect(func() -> void:
		lives_label.pivot_offset = lives_label.size * 0.5
	)
	menu_button.pressed.connect(func() -> void: menu_requested.emit())
	Juice.squishify_button(menu_button)
	Juice.claim(lives_label)
	Events.coins_changed.connect(_on_coins_changed)
	Events.lives_changed.connect(_on_lives_changed)
	Events.wave_started.connect(_on_wave_started)
	Events.wave_cleared.connect(_on_wave_cleared)


func set_wave(current: int, total: int) -> void:
	wave_label.text = "Wave %d/%d" % [current, total]


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
	return coins_label.global_position + coins_label.size * 0.5


func pulse_coins() -> void:
	coins_label.pivot_offset = coins_label.size * 0.5
	Juice.punch_scale(coins_label, 1.18, 0.14)


func _on_coins_changed(coins: int) -> void:
	if _coin_tween != null and _coin_tween.is_valid():
		_coin_tween.kill()
	var from := _displayed_coins
	_coin_tween = create_tween()
	_coin_tween.tween_method(_set_coins_display, from, float(coins), 0.3)


func _set_coins_display(value: float) -> void:
	_displayed_coins = value
	coins_label.text = "● %d" % int(round(value))


func _on_lives_changed(lives: int) -> void:
	lives_label.text = "♥ %d" % lives
	lives_label.pivot_offset = lives_label.size * 0.5
	if _prev_lives >= 0 and lives < _prev_lives:
		Juice.punch_scale(lives_label)
	_prev_lives = lives


func _on_wave_started(number: int, total: int) -> void:
	set_wave(number, total)
	hide_countdown()


func _on_wave_cleared(_number: int) -> void:
	pass
