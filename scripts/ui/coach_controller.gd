extends Node
## Queues once-ever tip cards and fires recurring leak toasts.

const HOW_TO_PLAY_ART: Texture2D = preload("res://assets/ui/tip_how_to_play.png")
const BUILD_ART: Texture2D = preload("res://assets/background/pad.png")
const TOWER_ART := {
	&"chiller": preload("res://assets/tower/weapon_chiller.png"),
	&"longshot": preload("res://assets/tower/weapon_longshot.png"),
}
const ENEMY_ART := {
	&"fast": preload("res://assets/enemies/critter_fast.png"),
	&"swarm": preload("res://assets/enemies/critter_swarm.png"),
	&"armored": preload("res://assets/enemies/critter_armored.png"),
	&"boss": preload("res://assets/enemies/critter_boss.png"),
}
const ENEMY_TIP_BODY := {
	&"fast": "Speedy! Watch the path.",
	&"swarm": "Lots of little ones!",
	&"armored": "Tough shell — hit harder.",
	&"boss": "Big boss incoming!",
}
## Level-3 (tier index 2) power explainers, shown once per tower.
const TIER3_TIPS := {
	&"popper": {
		"title": "Super Lollipop!",
		"body": "Now pops in a sugary blast, hitting nearby critters too.",
		"flavor": &"burst",
	},
	&"lobber": {
		"title": "Super Ballooner!",
		"body": "Splashes now stun critters in place for a moment.",
		"flavor": &"stun",
	},
	&"chiller": {
		"title": "Super Slushie!",
		"body": "Slush now hurts! Slowed critters take damage too.",
		"flavor": &"slush",
	},
	&"longshot": {
		"title": "Super Candy Cane!",
		"body": "Shots pierce through, hitting every critter in a line.",
		"flavor": &"pierce",
	},
}
const LEAK_COOLDOWN_SEC := 1.5

@onready var tip_card: Control = %TipCard
@onready var toast_balloon: Control = %ToastBalloon

var _game: Node
var _queue: Array[Dictionary] = []
var _showing_tip: bool = false
var _enabled: bool = false
var _seen_enemies_run: Dictionary = {}
var _last_leak_toast_msec: int = -99999


func setup(game: Node) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_game = game
	if game.get_meta("smoke_silent", false):
		_enabled = false
		return
	_enabled = true
	_seen_enemies_run.clear()
	if not tip_card.dismissed.is_connected(_on_tip_dismissed):
		tip_card.dismissed.connect(_on_tip_dismissed)
	if game.get("build_menu") != null and game.build_menu.has_signal("build_opened"):
		if not game.build_menu.build_opened.is_connected(_on_build_opened):
			game.build_menu.build_opened.connect(_on_build_opened)
	if not Events.wave_started.is_connected(_on_wave_started):
		Events.wave_started.connect(_on_wave_started)
	if not Events.enemy_leaked.is_connected(_on_enemy_leaked):
		Events.enemy_leaked.connect(_on_enemy_leaked)
	if not Events.tower_upgraded.is_connected(_on_tower_upgraded):
		Events.tower_upgraded.connect(_on_tower_upgraded)
	_queue_run_start_tips()


func _queue_run_start_tips() -> void:
	if not SaveGame.has_seen_tip("how_to_play"):
		_enqueue({
			"key": "how_to_play",
			"title": "Let's pop!",
			"body": "Stop critters before they reach the end.",
			"art": HOW_TO_PLAY_ART,
		})
	# Right after "Let's pop!" — don't wait for the player to open Build.
	if not SaveGame.has_seen_tip("how_to_build"):
		_enqueue({
			"key": "how_to_build",
			"title": "Build a tower",
			"body": "Tap a soft pad, then pick a tower.",
			"art": BUILD_ART,
		})
	var map_id: StringName = &"map_01"
	if _game != null and _game.get("map_data") != null:
		map_id = (_game.map_data as MapData).id
	if map_id == &"map_02" and not SaveGame.has_seen_tip("tower_chiller"):
		_enqueue({
			"key": "tower_chiller",
			"title": "New: Slushie!",
			"body": "Slows critters so others can pop them.",
			"art": TOWER_ART[&"chiller"],
			"demo": {"tower": &"chiller"},
		})
	elif map_id == &"map_03" and not SaveGame.has_seen_tip("tower_longshot"):
		_enqueue({
			"key": "tower_longshot",
			"title": "New: Candy Cane!",
			"body": "Hits hard from far away.",
			"art": TOWER_ART[&"longshot"],
			"demo": {"tower": &"longshot"},
		})
	_try_show_next()


func _enqueue(tip: Dictionary) -> void:
	_queue.append(tip)


func _try_show_next() -> void:
	if not _enabled or _showing_tip or _queue.is_empty():
		return
	if tip_card == null or not tip_card.has_method("show_tip"):
		return
	_showing_tip = true
	var tip: Dictionary = _queue.pop_front()
	tip_card.show_tip(
		String(tip.get("title", "")),
		String(tip.get("body", "")),
		String(tip.get("key", "")),
		tip.get("art") as Texture2D,
		tip.get("demo", {}) as Dictionary
	)


func _on_tip_dismissed() -> void:
	_showing_tip = false
	_try_show_next()


func _on_build_opened(_pad: BuildPad) -> void:
	if not _enabled:
		return
	if SaveGame.has_seen_tip("how_to_build"):
		return
	_enqueue({
		"key": "how_to_build",
		"title": "Build a tower",
		"body": "Tap a soft pad, then pick a tower.",
		"art": BUILD_ART,
	})
	_try_show_next()


func _on_wave_started(number: int, _total: int) -> void:
	if not _enabled or _game == null or not _game.has_method("get_wave"):
		return
	var wave: WaveData = _game.get_wave(number)
	if wave == null:
		return
	for group: SpawnGroup in wave.spawn_groups:
		if group.enemy == null:
			continue
		var enemy_id: StringName = group.enemy.id
		if enemy_id == &"normal":
			continue
		if _seen_enemies_run.has(enemy_id):
			continue
		_seen_enemies_run[enemy_id] = true
		var tip_key := "enemy_%s" % String(enemy_id)
		if SaveGame.has_seen_tip(tip_key):
			continue
		var display := group.enemy.display_name
		if display.is_empty():
			display = String(enemy_id).capitalize()
		var body: String = String(ENEMY_TIP_BODY.get(enemy_id, "A new critter!"))
		_enqueue({
			"key": tip_key,
			"title": "New: %s!" % display,
			"body": body,
			"art": ENEMY_ART.get(enemy_id),
		})
	_try_show_next()


func _on_tower_upgraded(tower: Node) -> void:
	if not _enabled:
		return
	if tower == null or tower.get("tier") == null or tower.get("data") == null:
		return
	if int(tower.tier) != 2:
		return
	var tower_id: StringName = (tower.data as TowerData).id
	if not TIER3_TIPS.has(tower_id):
		return
	var tip_key := "tier3_%s" % String(tower_id)
	if SaveGame.has_seen_tip(tip_key):
		return
	var info: Dictionary = TIER3_TIPS[tower_id]
	_enqueue({
		"key": tip_key,
		"title": String(info["title"]),
		"body": String(info["body"]),
		"demo": {"tower": tower_id, "flavor": info["flavor"]},
	})
	_try_show_next()


func _on_enemy_leaked(_enemy: Node) -> void:
	if not _enabled or toast_balloon == null:
		return
	var now := Time.get_ticks_msec()
	if now - _last_leak_toast_msec < int(LEAK_COOLDOWN_SEC * 1000.0):
		return
	_last_leak_toast_msec = now
	toast_balloon.show_toast("One got away!")
