extends Control
## Bouncy wave announcement banner. Never eats pad taps.

@onready var label: Label = %BannerLabel
@onready var subtitle: Label = get_node_or_null("%SubtitleLabel")

var _pending_subtitle: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if subtitle != null:
		subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		subtitle.text = ""
	visible = false
	Juice.claim(self)
	Events.wave_started.connect(_on_wave_started)
	Events.wave_cleared.connect(_on_wave_cleared)
	Events.run_won.connect(_on_run_end)
	Events.run_lost.connect(_on_run_end)


func announce(text: String) -> void:
	label.text = text
	if subtitle != null:
		subtitle.text = ""
	_show_banner()


func set_pending_subtitle(text: String) -> void:
	_pending_subtitle = text


func _on_wave_started(number: int, _total: int) -> void:
	var game := get_tree().get_first_node_in_group("game")
	var is_boss_wave := false
	if game != null and game.has_method("get_wave"):
		var wave: WaveData = game.get_wave(number)
		if wave != null:
			for group: SpawnGroup in wave.spawn_groups:
				if group.enemy != null and group.enemy.is_boss:
					is_boss_wave = true
					break
	label.text = "BOSS!" if is_boss_wave else "Wave %d" % number
	if subtitle != null:
		subtitle.text = _pending_subtitle
		_pending_subtitle = ""
	Sound.play_sfx(&"wave_start")
	_show_banner()


func _on_wave_cleared(_number: int) -> void:
	label.text = "Clear!"
	if subtitle != null:
		subtitle.text = ""
	_show_banner(0.35)


func _on_run_end(_map_id: StringName) -> void:
	visible = false


func _show_banner(hold := 0.7) -> void:
	pivot_offset = size * 0.5
	visible = true
	Juice.pop_in_out(self, hold)
