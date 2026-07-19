extends PanelContainer
## One campaign map card: locked / unlocked / beaten.

signal play_pressed(endless: bool)

@onready var preview: Control = %Preview
@onready var name_label: Label = %NameLabel
@onready var badge: Control = %Badge
@onready var badge_skin: Node2D = %Skin
@onready var lock_icon: TextureRect = %LockIcon
@onready var status_label: Label = %StatusLabel
@onready var play_button: Button = %PlayButton
@onready var endless_button: Button = %EndlessButton
@onready var buttons: HBoxContainer = %Buttons

var _unlocked: bool = false
var _map: MapData = null


func _ready() -> void:
	play_button.pressed.connect(func() -> void: play_pressed.emit(false))
	endless_button.pressed.connect(func() -> void: play_pressed.emit(true))
	Juice.squishify_button(play_button)
	Juice.squishify_button(endless_button)
	gui_input.connect(_on_gui_input)
	_start_badge_pulse()


func setup(map: MapData, unlocked: bool, beaten: bool, best: int, prev_name: String) -> void:
	_map = map
	_unlocked = unlocked
	name_label.text = map.display_name if map != null else "?"
	if preview.has_method("setup_from_map"):
		preview.setup_from_map(map)

	badge.visible = beaten
	if lock_icon != null:
		lock_icon.visible = not unlocked
	if not unlocked:
		modulate = Color(1, 1, 1, 0.55)
		buttons.visible = false
		status_label.text = "Beat %s first!" % prev_name
	elif beaten:
		modulate = Color.WHITE
		buttons.visible = true
		play_button.visible = true
		play_button.text = "Replay"
		endless_button.visible = true
		endless_button.text = "Endless!"
		if best > 0:
			status_label.text = "Best: wave %d" % best
		else:
			status_label.text = "Endless awaits!"
	else:
		modulate = Color.WHITE
		buttons.visible = true
		play_button.visible = true
		play_button.text = "Play!"
		endless_button.visible = false
		status_label.text = "A fresh path!"


func _on_gui_input(event: InputEvent) -> void:
	if _unlocked:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			Juice.wiggle(self)
			accept_event()


func _start_badge_pulse() -> void:
	if badge_skin == null:
		return
	badge_skin.scale = Vector2.ONE
	var tween := create_tween()
	tween.set_loops()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(badge_skin, "scale", Vector2(1.08, 1.08), 0.85 + randf() * 0.3)
	tween.tween_property(badge_skin, "scale", Vector2.ONE, 0.85 + randf() * 0.3)
