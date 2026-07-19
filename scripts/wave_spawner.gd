extends Node
## Wave state machine: COUNTDOWN → SPAWNING → CLEARING → (next COUNTDOWN | WON).

signal countdown_tick(seconds_left: int)

const COUNTDOWN_SECONDS := 7.0

enum State { IDLE, COUNTDOWN, SPAWNING, CLEARING, DONE }

var map_data: MapData
var _game: Node
var _state: State = State.IDLE
var _wave_index: int = 0 ## 0-based index into map_data.waves
var _alive_enemies: int = 0
var _run_over: bool = false
var _groups_remaining: int = 0


func setup(game: Node, data: MapData) -> void:
	_game = game
	map_data = data
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.enemy_leaked.connect(_on_enemy_leaked)
	Events.run_lost.connect(_on_run_over)
	Events.run_won.connect(_on_run_over)


func start() -> void:
	if map_data == null or map_data.waves.is_empty():
		return
	_wave_index = 0
	_run_over = false
	_begin_countdown()


func stop() -> void:
	_run_over = true
	_state = State.DONE


func _begin_countdown() -> void:
	if _run_over:
		return
	_state = State.COUNTDOWN
	var remaining := int(COUNTDOWN_SECONDS)
	while remaining > 0:
		if _run_over:
			return
		countdown_tick.emit(remaining)
		await get_tree().create_timer(1.0).timeout
		if _run_over:
			return
		remaining -= 1
	countdown_tick.emit(0)
	if _run_over:
		return
	await _spawn_wave()


func _spawn_wave() -> void:
	if _run_over:
		return
	_state = State.SPAWNING
	var wave_number := _wave_index + 1
	var total := map_data.waves.size()
	Events.wave_started.emit(wave_number, total)

	var wave: WaveData = map_data.waves[_wave_index]
	_groups_remaining = wave.spawn_groups.size()
	for group: SpawnGroup in wave.spawn_groups:
		_spawn_group(group) # fire-and-forget parallel coroutines

	while _groups_remaining > 0:
		if _run_over:
			return
		await get_tree().create_timer(0.05).timeout
		if _run_over:
			return

	_state = State.CLEARING
	while _alive_enemies > 0:
		if _run_over:
			return
		await get_tree().create_timer(0.1).timeout
		if _run_over:
			return

	Events.wave_cleared.emit(wave_number)
	if _run_over:
		return

	if _wave_index >= map_data.waves.size() - 1:
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
		_game._spawn_enemy(group.enemy)
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


func _on_run_over(_map_id: StringName) -> void:
	_run_over = true
	_state = State.DONE
