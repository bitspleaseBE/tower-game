extends Node
## Autoload ("Sound") — CC0 SFX/music pool, Settings volume, web first-gesture unlock.
##
## Web browsers block AudioContext until a user gesture. Until unlock_audio(),
## play_* are silent no-ops (one warning max). After unlock, Master volume and
## the Music/SFX buses drive all playback. ResultOverlay stings use
## PROCESS_MODE_ALWAYS players so they remain audible while the tree is paused.

const MUSIC_DUCK_DB := -8.0
const MUTE_FLOOR := 0.0001

## Hook-matrix ids → stream paths. Missing files are omitted at load (play no-ops).
const STREAM_PATHS := {
	&"ui_tap": "res://assets/audio/ui_tap.ogg",
	&"build_place": "res://assets/audio/build_place.ogg",
	&"upgrade": "res://assets/audio/upgrade.ogg",
	&"sell": "res://assets/audio/sell.ogg",
	&"shot_popper": "res://assets/audio/shot_popper.ogg",
	&"shot_lobber": "res://assets/audio/shot_lobber.ogg",
	&"shot_chiller": "res://assets/audio/shot_chiller.ogg",
	&"shot_longshot": "res://assets/audio/shot_longshot.ogg",
	&"hit": "res://assets/audio/hit.ogg",
	&"kill_pop": "res://assets/audio/kill_pop.ogg",
	&"coin": "res://assets/audio/coin.ogg",
	&"leak": "res://assets/audio/leak.ogg",
	&"countdown_tick": "res://assets/audio/countdown_tick.ogg",
	&"wave_start": "res://assets/audio/wave_start.ogg",
	&"win": "res://assets/audio/win.ogg",
	&"lose": "res://assets/audio/lose.ogg",
	&"unlock": "res://assets/audio/unlock.ogg",
	&"new_best": "res://assets/audio/new_best.ogg",
	&"music_game": "res://assets/audio/music_game.ogg",
}

## Celebration / pause-safe ids — play on ALWAYS players so ResultOverlay hears them.
const STING_IDS := {
	&"win": true,
	&"lose": true,
	&"new_best": true,
	&"unlock": true,
}

var _streams: Dictionary = {} ## StringName -> AudioStream
var _sfx_players: Array[AudioStreamPlayer] = []
var _sting_players: Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer
var _unlocked := false
var _warned_locked := false
var _music_base_db := 0.0
var _music_ducked := false
var _pending_music_id: StringName = &""
var _steal_cursor := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_streams()
	_build_players()
	set_enabled_from_settings()
	if Settings.has_signal("volume_changed"):
		Settings.volume_changed.connect(_on_volume_changed)
	# Desktop may unlock immediately; web stays locked until first gesture.
	if not OS.has_feature("web"):
		_unlocked = true
	set_process_input(true)


func _input(event: InputEvent) -> void:
	if _unlocked:
		return
	var gesture := false
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		gesture = true
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		gesture = true
	elif event is InputEventKey and (event as InputEventKey).pressed:
		gesture = true
	if gesture:
		unlock_audio()


func unlock_audio() -> void:
	if _unlocked:
		return
	_unlocked = true
	# Touching a player after a gesture resumes the browser AudioContext.
	if _music_player != null:
		_music_player.volume_db = -80.0
		_music_player.play()
		_music_player.stop()
		_music_player.volume_db = _music_duck_db()
	if _pending_music_id != &"":
		var id := _pending_music_id
		_pending_music_id = &""
		play_music(id)


func is_unlocked() -> bool:
	return _unlocked


func play_sfx(id: StringName, pitch_scale := 1.0, volume_db := 0.0) -> void:
	if not _unlocked:
		_warn_locked_once()
		return
	if not _streams.has(id):
		return
	var stream: AudioStream = _streams[id]
	var pool: Array[AudioStreamPlayer] = _sting_players if STING_IDS.has(id) else _sfx_players
	var player := _acquire_player(pool)
	if player == null:
		return
	player.stream = stream
	player.pitch_scale = pitch_scale
	player.volume_db = volume_db
	player.play()


func play_music(id: StringName = &"music_game") -> void:
	if not _streams.has(id):
		return
	if not _unlocked:
		_pending_music_id = id
		_warn_locked_once()
		return
	var stream: AudioStream = _streams[id]
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	var need_restart := _music_player.stream != stream or not _music_player.playing
	_music_player.stream = stream
	_music_player.volume_db = _music_duck_db()
	if need_restart:
		_music_player.play()


func stop_music() -> void:
	_pending_music_id = &""
	if _music_player == null:
		return
	if _music_player.playing:
		_music_player.stop()
	# Drop stream so Ogg playback packets don't leak on headless SceneTree quit.
	_music_player.stream = null


func set_music_ducked(ducked: bool) -> void:
	_music_ducked = ducked
	if _music_player != null:
		_music_player.volume_db = _music_duck_db()


func stop_sfx() -> void:
	for player: AudioStreamPlayer in _sfx_players:
		if player.playing:
			player.stop()
		player.stream = null
	for player: AudioStreamPlayer in _sting_players:
		if player.playing:
			player.stop()
		player.stream = null


func release_for_exit() -> void:
	## Headless smoke / process shutdown: drop player streams + cached Ogg refs so
	## SceneTree quit doesn't report ObjectDB audio leaks.
	## Prefer: stop_* → await process_frame → release_for_exit (lets playbacks drop).
	stop_sfx()
	stop_music()
	_streams.clear()
	_sfx_players.clear()
	_sting_players.clear()
	_music_player = null
	for child in get_children():
		remove_child(child)
		child.free()


func set_enabled_from_settings() -> void:
	var bus := AudioServer.get_bus_index("Master")
	if bus < 0:
		return
	var vol: float = Settings.master_volume
	if vol <= MUTE_FLOOR:
		AudioServer.set_bus_mute(bus, true)
		AudioServer.set_bus_volume_db(bus, -80.0)
	else:
		AudioServer.set_bus_mute(bus, false)
		AudioServer.set_bus_volume_db(bus, linear_to_db(vol))


func _on_volume_changed(_volume: float) -> void:
	set_enabled_from_settings()


func _music_duck_db() -> float:
	return _music_base_db + (MUSIC_DUCK_DB if _music_ducked else 0.0)


func _warn_locked_once() -> void:
	if _warned_locked:
		return
	_warned_locked = true
	push_warning("Sound: audio locked until first user gesture (browser autoplay policy).")


func _load_streams() -> void:
	for id: StringName in STREAM_PATHS:
		var path: String = STREAM_PATHS[id]
		if not ResourceLoader.exists(path):
			continue
		# IGNORE keeps Ogg packet graphs out of the global ResourceLoader cache so
		# headless --script smokes can drop them via release_for_exit() without
		# false ObjectDB "still in use" noise at quit.
		var stream := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as AudioStream
		if stream == null:
			continue
		if id == &"music_game" and stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = true
		_streams[id] = stream


func _build_players() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.bus = "Music"
	_music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_music_player)

	for i: int in PerfBudget.MAX_SFX_VOICES:
		var p := AudioStreamPlayer.new()
		p.name = "Sfx%d" % i
		p.bus = "SFX"
		add_child(p)
		_sfx_players.append(p)

	# A few ALWAYS voices for win/lose/new-best under get_tree().paused.
	for i: int in 3:
		var p := AudioStreamPlayer.new()
		p.name = "Sting%d" % i
		p.bus = "SFX"
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_sting_players.append(p)


func _acquire_player(pool: Array[AudioStreamPlayer]) -> AudioStreamPlayer:
	for player: AudioStreamPlayer in pool:
		if not player.playing:
			return player
	# DROP / steal oldest — never stall, never instantiate per shot.
	if pool.is_empty():
		return null
	_steal_cursor = (_steal_cursor + 1) % pool.size()
	var stolen: AudioStreamPlayer = pool[_steal_cursor]
	stolen.stop()
	return stolen
