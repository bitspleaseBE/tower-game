extends Control
## Once-ever coach tip card. PROCESS_MODE_ALWAYS while the tree is paused.

signal dismissed

@onready var backdrop: ColorRect = %Backdrop
@onready var panel: PanelContainer = %TipPanel
@onready var art: TextureRect = %TipArt
@onready var title_label: Label = %TitleLabel
@onready var body_label: Label = %BodyLabel
@onready var got_it_button: Button = %GotItButton

var _tip_key: String = ""
var _open: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	got_it_button.pressed.connect(_on_got_it)
	Juice.squishify_button(got_it_button)


func is_open() -> bool:
	return _open


func show_tip(title: String, body: String, tip_key: String, texture: Texture2D = null) -> void:
	_tip_key = tip_key
	title_label.text = title
	body_label.text = body
	if texture != null:
		art.texture = texture
		art.visible = true
	else:
		art.visible = false
	_open = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	Sound.set_music_ducked(true)
	get_tree().paused = true
	panel.scale = Vector2(0.6, 0.6)
	await get_tree().process_frame
	panel.pivot_offset = panel.size * 0.5
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.28)
	got_it_button.grab_focus()


func close() -> void:
	if not _open:
		return
	_open = false
	get_tree().paused = false
	Sound.set_music_ducked(false)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_got_it() -> void:
	if not _tip_key.is_empty():
		SaveGame.mark_tip_seen(_tip_key)
	close()
	dismissed.emit()
