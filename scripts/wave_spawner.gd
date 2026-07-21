extends Node
## Wave state machine: COUNTDOWN → SPAWNING → CLEARING → (next COUNTDOWN | WON).

signal countdown_tick(seconds_left: int)
## Bonus updates while the Next wave button is offered (CLEARING + countdown).
signal early_call_available(seconds_left: int, bonus: int)
signal early_call_hidden

## Inter-wave breather. Next-wave button arms when the last spawn group finishes.
const COUNTDOWN_SECONDS := 5

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
	var max_bonus := 12
	if map_data != null:
		max_bonus = maxi(0, map_data.early_wave_bonus_max)
	if max_bonus <= 0:
		return 0
	# Full bonus while finishing the current wave; scales down during the breather.
	if _state == State.CLEARING:
		return max_bonus
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


func _arm_early_call() -> void:
	if not _wave_has_next or _run_over:
		return
	_early_call_armed = true
	_early_call_claimed = false
	early_call_available.emit(0, early_call_bonus_now())


func _begin_countdown() -> void:
	if _run_over:
		return
	_state = State.COUNTDOWN
	# First wave (and resume) has no prior spawn — button stays hidden.
	# After a wave, keep the button if it was armed and not yet claimed.
	if _skip_countdown:
		_disarm_early_call()
		_skip_countdown = false
		countdown_tick.emit(0)
		_countdown_remaining = 0
		if _run_over:
			return
		await _spawn_wave()
		return

	_countdown_remaining = COUNTDOWN_SECONDS
	while _countdown_remaining > 0:
		if _run_over:
			_disarm_early_call()
			return
		if _skip_countdown:
			break
		countdown_tick.emit(_countdown_remaining)
		if _early_call_armed and not _early_call_claimed:
			early_call_available.emit(_countdown_remaining, early_call_bonus_now())
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

	# Last group dispatched — offer Next wave if another wave can follow.
	_state = State.CLEARING
	_arm_early_call()

	while _alive_enemies > 0:
		if _run_over:
			return
		await get_tree().create_timer(0.1).timeout
		if _run_over:
			return

	Events.wave_cleared.emit(wave_number)
	if _run_over:
		return

	# Campaign: clearing the last scripted wave wins. Endless: keep going forever.
	if not endless and wave_number >= total_scripted:
		_disarm_early_call()
		_state = State.DONE
		if _game.lives > 0:
			Events.run_won.emit(map_data.id)
		return

	_wave_index += 1
	_begin_countdown()


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
		var spawned: Variant = _game._spawn_enemy(group.enemy)
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
