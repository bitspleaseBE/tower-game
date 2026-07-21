extends Node
## Wave state machine: COUNTDOWN → SPAWNING → (countdown while leftovers alive | WON).
## Kingdom Rush style: one Next-wave button carries the timer and early-call bonus.

signal countdown_tick(seconds_left: int)
## Next-wave button is offered during every countdown (including the opening one).
signal early_call_available(seconds_left: int, bonus: int)
signal early_call_hidden

## Inter-wave / opening breather. Button + timer arm for the full duration.
const COUNTDOWN_SECONDS := 25

enum State { IDLE, COUNTDOWN, SPAWNING, CLEARING, DONE }

var map_data: MapData
var _game: Node
var _state: State = State.IDLE
var _wave_index: int = 0 ## 0-based; wave number = index + 1
var _alive_enemies: int = 0
var _run_over: bool = false
var _lost: bool = false ## permanent halt; resume_endless may clear a won halt only
var _groups_remaining: int = 0
var _countdown_remaining: int = 0
var _skip_countdown: bool = false
var _early_call_armed: bool = false
var _early_call_claimed: bool = false
var _wave_has_next: bool = false


func setup(game: Node, data: MapData) -> void:
	_game = game
	map_data = data
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.enemy_leaked.connect(_on_enemy_leaked)
	Events.run_lost.connect(_on_run_lost)
	Events.run_won.connect(_on_run_won)


func start() -> void:
	if map_data == null or map_data.waves.is_empty():
		return
	_wave_index = 0
	_run_over = false
	_lost = false
	_begin_countdown()


func stop() -> void:
	_run_over = true
	_state = State.DONE
	_skip_countdown = true
	_disarm_early_call()


func resume_endless() -> void:
	## Clear a won halt and continue past the scripted list. Lost runs stay halted.
	if _lost:
		return
	_run_over = false
	_wave_index = map_data.waves.size() ## next wave number = scripted + 1
	_begin_countdown()


func is_countdown() -> bool:
	return _state == State.COUNTDOWN


func countdown_remaining() -> int:
	return _countdown_remaining


func early_call_bonus_now() -> int:
	if not _early_call_armed or _early_call_claimed or _run_over:
		return 0
	var max_bonus := 18
	if map_data != null:
		max_bonus = maxi(0, map_data.early_wave_bonus_max)
	if max_bonus <= 0:
		return 0
	if _state == State.COUNTDOWN and _countdown_remaining > 0:
		return maxi(
			1,
			int(round(float(max_bonus) * float(_countdown_remaining) / float(COUNTDOWN_SECONDS)))
		)
	return 0


## Player pressed Next wave. Returns bonus coins (0 if not available).
func request_early_call() -> int:
	var bonus := early_call_bonus_now()
	if bonus <= 0:
		return 0
	_early_call_claimed = true
	_skip_countdown = true
	early_call_hidden.emit()
	return bonus


func _disarm_early_call() -> void:
	_early_call_armed = false
	_early_call_claimed = false
	early_call_hidden.emit()


func _emit_early_call() -> void:
	if not _early_call_armed or _early_call_claimed or _run_over:
		return
	early_call_available.emit(_countdown_remaining, early_call_bonus_now())


func _begin_countdown() -> void:
	if _run_over:
		return
	_state = State.COUNTDOWN
	_preview_upcoming_lanes()
	if _skip_countdown:
		_disarm_early_call()
		_skip_countdown = false
		countdown_tick.emit(0)
		_countdown_remaining = 0
		if _run_over:
			return
		await _spawn_wave()
		return

	# One control owns the timer: arm the Next-wave button for the full countdown.
	_countdown_remaining = COUNTDOWN_SECONDS
	_early_call_armed = true
	_early_call_claimed = false
	while _countdown_remaining > 0:
		if _run_over:
			_disarm_early_call()
			return
		if _skip_countdown:
			break
		countdown_tick.emit(_countdown_remaining)
		_emit_early_call()
		await get_tree().create_timer(1.0).timeout
		if _run_over:
			_disarm_early_call()
			return
		if _skip_countdown:
			break
		_countdown_remaining -= 1
	_disarm_early_call()
	countdown_tick.emit(0)
	_countdown_remaining = 0
	_skip_countdown = false
	if _run_over:
		return
	await _spawn_wave()


func _preview_upcoming_lanes() -> void:
	if _game == null or map_data == null:
		return
	var wave_number := _wave_index + 1
	var wave: WaveData = _game.get_wave(wave_number)
	if wave == null:
		return
	var indices: Array = []
	var labels: Array = []
	var seen: Dictionary = {}
	for group: SpawnGroup in wave.spawn_groups:
		if group == null or seen.has(group.lane):
			continue
		seen[group.lane] = true
		indices.append(group.lane)
		var lab := ""
		if _game.has_method("get_lane_label"):
			lab = String(_game.get_lane_label(group.lane))
		labels.append(lab)
	Events.wave_lanes_previewed.emit(indices, labels)


func _spawn_wave() -> void:
	if _run_over:
		return
	_state = State.SPAWNING
	_disarm_early_call()
	var wave_number := _wave_index + 1
	var total_scripted := map_data.waves.size()
	var endless: bool = bool(_game.get("endless"))
	_wave_has_next = endless or wave_number < total_scripted
	Events.wave_started.emit(wave_number, total_scripted)

	var wave: WaveData = _game.get_wave(wave_number)
	_groups_remaining = wave.spawn_groups.size()
	for group: SpawnGroup in wave.spawn_groups:
		_spawn_group(group) # fire-and-forget parallel coroutines

	while _groups_remaining > 0:
		if _run_over:
			return
		await get_tree().create_timer(0.05).timeout
		if _run_over:
			return

	# Last group dispatched. Campaign last wave: wait for the board to clear, then win.
	# Otherwise: start the next-wave countdown immediately — leftovers may still be alive.
	if not _wave_has_next:
		_state = State.CLEARING
		while _alive_enemies > 0:
			if _run_over:
				return
			await get_tree().create_timer(0.1).timeout
			if _run_over:
				return
		Events.wave_cleared.emit(wave_number)
		Events.wave_all_clear.emit(wave_number)
		if _run_over:
			return
		_disarm_early_call()
		_state = State.DONE
		if _game.lives > 0:
			Events.run_won.emit(map_data.id)
		return

	Events.wave_cleared.emit(wave_number)
	# Expansion maps must finish the board clear + pan before the next countdown.
	if map_data.expansion_wave > 0 and wave_number == map_data.expansion_wave:
		while _alive_enemies > 0:
			if _run_over:
				return
			await get_tree().create_timer(0.1).timeout
			if _run_over:
				return
		Events.wave_all_clear.emit(wave_number)
		if _game.has_method("run_expansion_if_needed"):
			await _game.run_expansion_if_needed()
	else:
		_emit_all_clear_when_empty(wave_number)
	_wave_index += 1
	_begin_countdown()


func _emit_all_clear_when_empty(wave_number: int) -> void:
	while _alive_enemies > 0:
		if _run_over:
			return
		await get_tree().create_timer(0.1).timeout
		if _run_over:
			return
	Events.wave_all_clear.emit(wave_number)


func _spawn_group(group: SpawnGroup) -> void:
	if group.start_delay > 0.0:
		await get_tree().create_timer(group.start_delay).timeout
		if _run_over:
			_groups_remaining = maxi(0, _groups_remaining - 1)
			return
	for i: int in group.count:
		if _run_over:
			_groups_remaining = maxi(0, _groups_remaining - 1)
			return
		var spawned: Variant = _game._spawn_enemy(group.enemy, group.lane)
		if spawned != null:
			_alive_enemies += 1
		if i < group.count - 1:
			await get_tree().create_timer(group.spawn_interval).timeout
			if _run_over:
				_groups_remaining = maxi(0, _groups_remaining - 1)
				return
	_groups_remaining = maxi(0, _groups_remaining - 1)


func _on_enemy_killed(_enemy: Node, _bounty: int) -> void:
	_alive_enemies = maxi(0, _alive_enemies - 1)


func _on_enemy_leaked(_enemy: Node) -> void:
	_alive_enemies = maxi(0, _alive_enemies - 1)


func _on_run_lost(_map_id: StringName) -> void:
	_lost = true
	_run_over = true
	_state = State.DONE
	_disarm_early_call()


func _on_run_won(_map_id: StringName) -> void:
	_run_over = true
	_state = State.DONE
	_disarm_early_call()
