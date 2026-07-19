extends Node
## Autoload ("Settings") that owns persistent user settings.
## Loads them from user:// at startup and applies them to the engine.
## Master bus volume is applied by Sound (mute-at-zero); this emits volume_changed.

signal volume_changed(volume: float)

const SETTINGS_PATH := "user://settings.cfg"

var fullscreen := false
var master_volume := 1.0


func _ready() -> void:
	_load()
	volume_changed.emit(master_volume)
	# Browsers only allow entering fullscreen from a user gesture, so on web
	# fullscreen is applied when toggled in the settings menu, not at startup.
	if not OS.has_feature("web"):
		_apply_fullscreen()


func set_fullscreen(enabled: bool) -> void:
	fullscreen = enabled
	_apply_fullscreen()
	_save()


func set_master_volume(volume: float) -> void:
	master_volume = clampf(volume, 0.0, 1.0)
	volume_changed.emit(master_volume)
	_save()


func _apply_fullscreen() -> void:
	var mode := DisplayServer.WINDOW_MODE_WINDOWED
	if fullscreen:
		mode = DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(mode)


func _load() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	fullscreen = config.get_value("display", "fullscreen", fullscreen)
	master_volume = config.get_value("audio", "master_volume", master_volume)


func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("audio", "master_volume", master_volume)
	config.save(SETTINGS_PATH)
