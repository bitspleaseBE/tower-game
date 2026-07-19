extends Control
## Rising candy bubbles for the main menu — float up, pop at random or on tap.

const MAX_BUBBLES := 12
const SPAWN_INTERVAL := 0.45
const GUM_COLORS: Array[Color] = [
	Color(0.55, 0.82, 0.98, 0.92),
	Color(1.0, 0.56, 0.72, 0.92),
	Color(0.78, 0.58, 0.95, 0.92),
	Color(1.0, 0.98, 1.0, 0.88),
	Color(1.0, 0.84, 0.55, 0.9),
]

var _spawn_cd := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	# Seed a few mid-rise so the screen isn't empty on first paint.
	await get_tree().process_frame
	for i: int in 5:
		_spawn_bubble(randf_range(0.15, 0.85))


func _process(delta: float) -> void:
	_spawn_cd -= delta
	if _spawn_cd > 0.0:
		return
	if get_child_count() >= MAX_BUBBLES:
		return
	_spawn_bubble(0.0)
	_spawn_cd = SPAWN_INTERVAL * randf_range(0.65, 1.35)


func _spawn_bubble(rise_progress: float) -> void:
	var bubble := _MenuBubble.new()
	var radius := randf_range(36.0, 78.0)
	var color: Color = GUM_COLORS[randi() % GUM_COLORS.size()]
	add_child(bubble)
	bubble.setup(radius, color)
	var view := get_viewport_rect().size
	if view.x < 1.0 or view.y < 1.0:
		view = Vector2(720, 1280)
	var x := randf_range(radius, maxf(radius + 1.0, view.x - radius))
	var y := lerpf(view.y + radius, -radius * 2.0, rise_progress)
	bubble.position = Vector2(x - radius, y - radius)
	bubble.sync_base_x()
	bubble.popped.connect(_on_bubble_popped.bind(bubble), CONNECT_ONE_SHOT)


func _on_bubble_popped(bubble: Control) -> void:
	if is_instance_valid(bubble):
		bubble.queue_free()


class _MenuBubble extends Control:
	signal popped

	var _radius := 48.0
	var _color := Color.WHITE
	var _swirl_a := Color.WHITE
	var _swirl_b := Color.WHITE
	var _rise_speed := 40.0
	var _sway_amp := 18.0
	var _sway_phase := 0.0
	var _sway_speed := 1.5
	var _base_x := 0.0
	var _popping := false
	var _wobble := 0.0
	var _life := 5.0


	func setup(radius: float, color: Color) -> void:
		_radius = radius
		_color = color
		var swirl_pool: Array[Color] = [
			Color(0.55, 0.82, 0.98, 0.92),
			Color(1.0, 0.56, 0.72, 0.92),
			Color(0.78, 0.58, 0.95, 0.92),
			Color(1.0, 0.98, 1.0, 0.88),
			Color(1.0, 0.84, 0.55, 0.9),
		]
		_swirl_a = swirl_pool[randi() % swirl_pool.size()]
		_swirl_b = swirl_pool[randi() % swirl_pool.size()]
		_rise_speed = randf_range(28.0, 62.0)
		_sway_amp = randf_range(12.0, 34.0)
		_sway_phase = randf() * TAU
		_sway_speed = randf_range(1.1, 2.2)
		_wobble = randf() * TAU
		_life = randf_range(3.0, 8.0)
		custom_minimum_size = Vector2(radius * 2.0, radius * 2.0)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_STOP
		pivot_offset = size * 0.5
		gui_input.connect(_on_gui_input)


	func sync_base_x() -> void:
		_base_x = position.x


	func _ready() -> void:
		_base_x = position.x


	func _enter_tree() -> void:
		_base_x = position.x


	## Circular hit so rect corners don't steal taps from buttons behind.
	func _has_point(point: Vector2) -> bool:
		return point.distance_to(size * 0.5) <= _radius


	func _on_gui_input(event: InputEvent) -> void:
		if _popping:
			return
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				pop(true)
				accept_event()
		elif event is InputEventScreenTouch:
			var st := event as InputEventScreenTouch
			if st.pressed:
				pop(true)
				accept_event()


	func _process(delta: float) -> void:
		if _popping:
			return
		_life -= delta
		_sway_phase += delta * _sway_speed
		_wobble += delta * 3.2
		position.y -= _rise_speed * delta
		position.x = _base_x + sin(_sway_phase) * _sway_amp
		var pulse := 1.0 + sin(_wobble) * 0.04
		scale = Vector2(pulse, pulse)
		queue_redraw()
		if _life <= 0.0:
			pop(false)
			return
		if position.y + size.y < -24.0:
			pop(false)


	func _draw() -> void:
		var c := size * 0.5
		var r := _radius
		draw_circle(c, r, _color)
		draw_circle(c + Vector2(-r * 0.28, -r * 0.18), r * 0.5, Color(_swirl_a.r, _swirl_a.g, _swirl_a.b, 0.7))
		draw_circle(c + Vector2(r * 0.3, r * 0.22), r * 0.38, Color(_swirl_b.r, _swirl_b.g, _swirl_b.b, 0.65))
		draw_arc(c, r * 0.92, 0.0, TAU, 40, Color(1.0, 1.0, 1.0, 0.35), 2.5, true)
		draw_circle(c + Vector2(-r * 0.35, -r * 0.4), r * 0.16, Color(1.0, 1.0, 1.0, 0.8))


	func pop(from_tap: bool) -> void:
		if _popping:
			return
		_popping = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		if from_tap:
			Sound.play_sfx(&"kill_pop")
		else:
			Sound.play_sfx(&"ui_tap")
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(self, "scale", Vector2(1.55, 1.55), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "modulate:a", 0.0, 0.16)
		tween.chain().tween_callback(func() -> void: popped.emit())
