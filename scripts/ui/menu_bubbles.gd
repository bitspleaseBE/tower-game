extends Control
## Rising ice-cream bubbles for the main menu — float up, pop on tap, burst on shake.

const MAX_BUBBLES := 14
const MAX_SHAKE_BURST := 22
const SPAWN_INTERVAL := 0.45
const SHAKE_JERK := 4.5
const SHAKE_COOLDOWN := 0.4
const SOFT_TEX: Texture2D = preload("res://assets/fx/particle_soft.png")

## One scoop per bubble — ice-cream parlor flavors.
const SCOOP_COLORS: Array[Color] = [
	Color(1.0, 0.62, 0.74, 1.0), ## strawberry
	Color(0.72, 0.92, 0.86, 1.0), ## mint chip
	Color(0.78, 0.68, 0.96, 1.0), ## ube / lavender
	Color(1.0, 0.94, 0.82, 1.0), ## vanilla
	Color(0.62, 0.84, 0.98, 1.0), ## blueberry soft-serve
	Color(1.0, 0.78, 0.58, 1.0), ## peach
	Color(0.92, 0.72, 0.62, 1.0), ## caramel
]

var _spawn_cd := 0.0
var _shake_cd := 0.0
var _prev_accel := Vector3.ZERO
var _accel_primed := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	await get_tree().process_frame
	for i: int in 5:
		_spawn_bubble(randf_range(0.15, 0.85))


func _process(delta: float) -> void:
	_shake_cd = maxf(0.0, _shake_cd - delta)
	_poll_shake()
	_spawn_cd -= delta
	if _spawn_cd > 0.0:
		return
	if get_child_count() >= MAX_BUBBLES:
		return
	_spawn_bubble(0.0)
	_spawn_cd = SPAWN_INTERVAL * randf_range(0.65, 1.35)


func _poll_shake() -> void:
	if _shake_cd > 0.0:
		return
	var accel := Input.get_accelerometer()
	# Desktop / no-sensor builds report zero — stay quiet.
	if accel.length_squared() < 0.0001:
		_accel_primed = false
		_prev_accel = Vector3.ZERO
		return
	if not _accel_primed:
		_prev_accel = accel
		_accel_primed = true
		return
	var jerk := (accel - _prev_accel).length()
	_prev_accel = accel
	if jerk >= SHAKE_JERK:
		_burst_from_shake()


func _burst_from_shake() -> void:
	_shake_cd = SHAKE_COOLDOWN
	Sound.play_sfx(&"ui_tap")
	var room := MAX_SHAKE_BURST - get_child_count()
	var count := mini(room, randi_range(4, 7))
	for i: int in count:
		_spawn_bubble(0.0)


func _spawn_bubble(rise_progress: float) -> void:
	var bubble := _MenuBubble.new()
	var radius := randf_range(40.0, 88.0)
	var color: Color = SCOOP_COLORS[randi() % SCOOP_COLORS.size()]
	add_child(bubble)
	bubble.setup(radius, color, SOFT_TEX)
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
	var _soft: Texture2D
	var _rise_speed := 40.0
	var _sway_amp := 18.0
	var _sway_phase := 0.0
	var _sway_speed := 1.5
	var _base_x := 0.0
	var _popping := false
	var _wobble := 0.0
	var _life := 5.0


	func setup(radius: float, color: Color, soft_tex: Texture2D) -> void:
		_radius = radius
		_color = color
		_soft = soft_tex
		_rise_speed = randf_range(28.0, 62.0)
		_sway_amp = randf_range(12.0, 34.0)
		_sway_phase = randf() * TAU
		_sway_speed = randf_range(1.1, 2.2)
		_wobble = randf() * TAU
		_life = randf_range(3.5, 8.5)
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
		_wobble += delta * 2.6
		position.y -= _rise_speed * delta
		position.x = _base_x + sin(_sway_phase) * _sway_amp
		var pulse := 1.0 + sin(_wobble) * 0.035
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
		# Soft contact shadow (ice-cream scoop sitting in light).
		_draw_soft(c + Vector2(r * 0.08, r * 0.22), r * 1.05, Color(0.35, 0.22, 0.35, 0.18))
		# Outer glow halo — same flavor, airy.
		_draw_soft(c, r * 1.28, Color(_color.r, _color.g, _color.b, 0.22))
		# Volume body: soft disc + solid core for scoop density.
		_draw_soft(c, r * 1.08, Color(_color.r, _color.g, _color.b, 0.55))
		draw_circle(c, r * 0.82, Color(_color.r, _color.g, _color.b, 0.92))
		# Same-hue shading — darker underside, lighter crown (one color family).
		var shade := _color.darkened(0.18)
		shade.a = 0.35
		_draw_soft(c + Vector2(r * 0.12, r * 0.28), r * 0.7, shade)
		var cream := _color.lightened(0.28)
		cream.a = 0.55
		_draw_soft(c + Vector2(-r * 0.22, -r * 0.28), r * 0.55, cream)
		# Glossy specular (soft-serve shine).
		draw_circle(c + Vector2(-r * 0.32, -r * 0.38), r * 0.18, Color(1.0, 1.0, 1.0, 0.78))
		_draw_soft(c + Vector2(-r * 0.18, -r * 0.42), r * 0.42, Color(1.0, 1.0, 1.0, 0.28))
		# Thin rim catch-light.
		draw_arc(c, r * 0.86, -2.2, -0.4, 24, Color(1.0, 1.0, 1.0, 0.45), 2.0, true)


	func _draw_soft(center: Vector2, diameter: float, tint: Color) -> void:
		if _soft == null:
			draw_circle(center, diameter * 0.5, tint)
			return
		draw_texture_rect(
			_soft,
			Rect2(center - Vector2(diameter, diameter) * 0.5, Vector2(diameter, diameter)),
			false,
			tint
		)


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
		tween.tween_property(self, "scale", Vector2(1.6, 1.6), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "modulate:a", 0.0, 0.16)
		tween.chain().tween_callback(func() -> void: popped.emit())
