extends Node2D
## Portrait board skeleton — layout + navigation only. Stage 2 owns gameplay.

# Canonical map-1 route. Stage 2 copies these into data/maps/map_01.tres.
# Typed PackedVector2Array literals (not PackedVector2Array([...]) ctor — not const in 4.7).
const PATH_POINTS: PackedVector2Array = [
	Vector2(-40, 280),
	Vector2(560, 280),
	Vector2(560, 540),
	Vector2(160, 540),
	Vector2(160, 820),
	Vector2(560, 820),
	Vector2(560, 1000),
	Vector2(760, 1000),
]

# 8 pads: ≥ 90 px from path centerline, ≥ 110 px apart. Stage 2 copies verbatim.
const PAD_POSITIONS: PackedVector2Array = [
	Vector2(180, 400),
	Vector2(420, 400),
	Vector2(650, 410),
	Vector2(360, 660),
	Vector2(620, 660),
	Vector2(70, 690),
	Vector2(300, 930),
	Vector2(440, 1020),
]
const DESIGN_SIZE := Vector2(720, 1280)
const PAD_FILL := Color(0.902, 0.851, 0.969, 1) # #E6D9F7
const PAD_BORDER := Color(0.749, 0.627, 0.91, 1) # #BFA0E8


func _ready() -> void:
	var curve := Curve2D.new()
	for point: Vector2 in PATH_POINTS:
		curve.add_point(point)
	$Board/Path.curve = curve

	$Board/Path/PathBorder.points = PATH_POINTS
	$Board/Path/PathLine.points = PATH_POINTS

	_spawn_pads()
	_recenter_board()
	get_viewport().size_changed.connect(_recenter_board)

	%MenuButton.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_back()


func _on_menu_button_pressed() -> void:
	_go_back()


func _go_back() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


## Centers the 720×1280 design rect inside whatever canvas aspect "expand"
## produced (extra height on 20:9 phones, extra width on tablets/desktop).
## Stage 2's rebuild must keep this pattern.
func _recenter_board() -> void:
	$Board.position = ((get_viewport_rect().size - DESIGN_SIZE) * 0.5).max(Vector2.ZERO)


func _spawn_pads() -> void:
	var pads: Node2D = $Board/Pads
	for i: int in PAD_POSITIONS.size():
		var pad := Node2D.new()
		pad.name = "Pad%d" % (i + 1)
		pad.position = PAD_POSITIONS[i]

		var skin := Node2D.new()
		skin.name = "Skin"
		pad.add_child(skin)

		var border := Polygon2D.new()
		border.name = "Border"
		border.color = PAD_BORDER
		border.polygon = _circle_polygon(36.0)
		skin.add_child(border)

		var fill := Polygon2D.new()
		fill.name = "Fill"
		fill.color = PAD_FILL
		fill.polygon = _circle_polygon(32.0)
		skin.add_child(fill)

		pads.add_child(pad)
		_start_pad_breathe(skin)


func _start_pad_breathe(skin: Node2D) -> void:
	var phase := randf() * 1.8
	var tween := create_tween()
	tween.tween_interval(phase)
	tween.tween_callback(func() -> void:
		var breathe := create_tween()
		breathe.set_loops()
		breathe.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		breathe.tween_property(skin, "scale", Vector2(1.04, 1.04), 0.9)
		breathe.tween_property(skin, "scale", Vector2.ONE, 0.9)
	)


func _circle_polygon(radius: float, segments: int = 24) -> PackedVector2Array:
	var points := PackedVector2Array()
	points.resize(segments)
	for i: int in segments:
		var angle := TAU * float(i) / float(segments)
		points[i] = Vector2(cos(angle), sin(angle)) * radius
	return points
