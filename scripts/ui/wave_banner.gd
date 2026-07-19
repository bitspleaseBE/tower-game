extends Control
## Bouncy wave announcement banner. Never eats pad taps.

@onready var label: Label = %BannerLabel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	Juice.claim(self)
	Events.wave_started.connect(_on_wave_started)
	Events.wave_cleared.connect(_on_wave_cleared)
	Events.run_won.connect(_on_run_end)
	Events.run_lost.connect(_on_run_end)


func _on_wave_started(number: int, _total: int) -> void:
	label.text = "Wave %d" % number
	_show_banner()


func _on_wave_cleared(_number: int) -> void:
	label.text = "Clear!"
	_show_banner(0.35)


func _on_run_end(_map_id: StringName) -> void:
	visible = false


func _show_banner(hold := 0.7) -> void:
	pivot_offset = size * 0.5
	visible = true
	Juice.pop_in_out(self, hold)
