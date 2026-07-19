extends Node
## Persistent campaign progress + transient run handoff for MapSelect → Game.

const SAVE_PATH := "user://save.cfg"
const CAMPAIGN: Array[StringName] = [&"map_01", &"map_02", &"map_03"]

## Never persisted to disk — MapSelect / Next map! set these; Game reads at _ready.
## Survive reload_current_scene() so Retry relaunches the same setup.
var run_map: MapData = null
var run_endless := false
## MapSelect reads + clears for the unlock ceremony.
var just_unlocked: StringName = &""

var _config := ConfigFile.new()


func _ready() -> void:
	_load()
	Events.run_won.connect(_on_run_won)


func is_beaten(id: StringName) -> bool:
	return bool(_config.get_value(String(id), "beaten", false))


func best_endless_wave(id: StringName) -> int:
	return int(_config.get_value(String(id), "best_endless_wave", 0))


func is_unlocked(id: StringName) -> bool:
	if id == CAMPAIGN[0]:
		return true
	var idx := CAMPAIGN.find(id)
	if idx <= 0:
		return false
	return is_beaten(CAMPAIGN[idx - 1])


func mark_beaten(id: StringName) -> void:
	var was_beaten := is_beaten(id)
	_config.set_value(String(id), "beaten", true)
	_save()
	if was_beaten:
		return
	var idx := CAMPAIGN.find(id)
	if idx < 0 or idx >= CAMPAIGN.size() - 1:
		return
	var next_id: StringName = CAMPAIGN[idx + 1]
	# Flipped false→true: previous was unbeaten, so next was locked.
	just_unlocked = next_id


func record_endless_wave(id: StringName, wave: int) -> bool:
	var best := best_endless_wave(id)
	if wave <= best:
		return false
	_config.set_value(String(id), "best_endless_wave", wave)
	_save()
	Events.endless_best.emit(id, wave)
	return true


func _on_run_won(map_id: StringName) -> void:
	mark_beaten(map_id)


func _load() -> void:
	_config = ConfigFile.new()
	if _config.load(SAVE_PATH) != OK:
		return


func _save() -> void:
	# Ensure every known map section has both keys for a clean save.cfg shape.
	for id: StringName in CAMPAIGN:
		var section := String(id)
		_config.set_value(section, "beaten", bool(_config.get_value(section, "beaten", false)))
		_config.set_value(
			section, "best_endless_wave", int(_config.get_value(section, "best_endless_wave", 0))
		)
	var err := _config.save(SAVE_PATH)
	if err != OK:
		push_warning("SaveGame: failed to save %s (err %s)" % [SAVE_PATH, err])
