extends Control
## Win / lose / endless-defeat overlay. PROCESS_MODE_ALWAYS while tree is paused.

const ConfettiScene: PackedScene = preload("res://scenes/fx/confetti_cpu.tscn")

@onready var backdrop: ColorRect = %Backdrop
@onready var panel: PanelContainer = %ResultPanel
@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var new_best_label: Label = %NewBestLabel
@onready var next_map_button: Button = %NextMapButton
@onready var go_endless_button: Button = %GoEndlessButton
@onready var retry_button: Button = %RetryButton
@onready var menu_button: Button = %MenuButton
@onready var confetti_left: Node2D = %ConfettiLeft
@onready var confetti_right: Node2D = %ConfettiRight

var _game: Node = null
var _current_wave: int = 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	subtitle_label.visible = false
	new_best_label.visible = false
	next_map_button.visible = false
	go_endless_button.visible = false
	_ensure_confetti()
	next_map_button.pressed.connect(_on_next_map)
	go_endless_button.pressed.connect(_on_go_endless)
	retry_button.pressed.connect(_on_retry)
	menu_button.pressed.connect(_on_menu)
	Juice.squishify_button(next_map_button)
	Juice.squishify_button(go_endless_button)
	Juice.squishify_button(retry_button)
	Juice.squishify_button(menu_button)
	Events.run_won.connect(_on_run_won)
	Events.run_lost.connect(_on_run_lost)
	Events.wave_started.connect(_on_wave_started)


func setup(game: Node) -> void:
	_game = game


func _ensure_confetti() -> void:
	if confetti_left.get_child_count() == 0:
		var left: Node = ConfettiScene.instantiate()
		left.process_mode = Node.PROCESS_MODE_ALWAYS
		confetti_left.add_child(left)
	if confetti_right.get_child_count() == 0:
		var right: Node = ConfettiScene.instantiate()
		right.process_mode = Node.PROCESS_MODE_ALWAYS
		confetti_right.add_child(right)


func _on_wave_started(number: int, _total: int) -> void:
	_current_wave = number


func _on_run_won(map_id: StringName) -> void:
	var has_next := _campaign_successor(map_id) != &""
	if has_next:
		title_label.text = "Path defended!"
	else:
		title_label.text = "All paths defended!"
	subtitle_label.visible = false
	new_best_label.visible = false
	next_map_button.visible = has_next
	go_endless_button.visible = true
	retry_button.visible = false
	menu_button.visible = true
	Sound.play_sfx(&"win")
	_show_panel()


func _on_run_lost(map_id: StringName) -> void:
	var is_endless := _game != null and bool(_game.get("endless"))
	next_map_button.visible = false
	go_endless_button.visible = false
	retry_button.visible = true
	menu_button.visible = true
	if is_endless:
		title_label.text = "Wave %d wants a word." % _current_wave
		var best: int = SaveGame.best_endless_wave(map_id)
		subtitle_label.text = "Best: wave %d" % best
		subtitle_label.visible = true
		var start_best: int = int(_game.get("best_at_run_start")) if _game != null else 0
		var is_new := best > start_best
		new_best_label.visible = is_new
		# Fanfare; don't stack new_best with lose.
		if is_new:
			Sound.play_sfx(&"new_best")
			_celebrate_new_best()
		else:
			Sound.play_sfx(&"lose")
	else:
		title_label.text = "The critters got through!"
		subtitle_label.visible = false
		new_best_label.visible = false
		Sound.play_sfx(&"lose")
	_show_panel()


func _celebrate_new_best() -> void:
	new_best_label.visible = true
	await get_tree().process_frame
	new_best_label.pivot_offset = new_best_label.size * 0.5
	new_best_label.scale = Vector2(0.5, 0.5)
	Juice.punch_scale(new_best_label, 1.35, 0.28)
	_restart_confetti(confetti_left)
	_restart_confetti(confetti_right)


func _restart_confetti(host: Node2D) -> void:
	if host.get_child_count() == 0:
		return
	var burst: Node = host.get_child(0)
	if burst.has_method("activate"):
		burst.call("activate", host.global_position)
	elif burst.get_node_or_null("Particles") != null:
		var particles: CPUParticles2D = burst.get_node("Particles")
		particles.restart()


func _show_panel() -> void:
	Engine.time_scale = 1.0
	Sound.set_music_ducked(true)
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	get_tree().paused = true
	panel.scale = Vector2(0.6, 0.6)
	panel.pivot_offset = panel.size * 0.5
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.35)
	_focus_first_button()


func _focus_first_button() -> void:
	for btn: Button in [next_map_button, go_endless_button, retry_button, menu_button]:
		if btn.visible and not btn.disabled:
			btn.grab_focus()
			return


func _campaign_successor(map_id: StringName) -> StringName:
	var idx := SaveGame.CAMPAIGN.find(map_id)
	if idx < 0 or idx >= SaveGame.CAMPAIGN.size() - 1:
		return &""
	return SaveGame.CAMPAIGN[idx + 1]


func _on_next_map() -> void:
	get_tree().paused = false
	Sound.set_music_ducked(false)
	if _game == null or _game.get("map_data") == null:
		return
	var next_id := _campaign_successor((_game.map_data as MapData).id)
	if next_id == &"":
		return
	SaveGame.run_map = load("res://data/maps/%s.tres" % String(next_id)) as MapData
	SaveGame.run_endless = false
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _on_go_endless() -> void:
	get_tree().paused = false
	Sound.set_music_ducked(false)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _game != null and _game.has_method("enter_endless"):
		_game.enter_endless()


func _on_retry() -> void:
	get_tree().paused = false
	Sound.set_music_ducked(false)
	get_tree().reload_current_scene()


func _on_menu() -> void:
	get_tree().paused = false
	Sound.set_music_ducked(false)
	get_tree().change_scene_to_file("res://scenes/map_select.tscn")
