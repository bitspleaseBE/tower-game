extends Control
## Screen-edge arrows pointing at off-screen spawn entries during countdown.

const MARGIN := 48.0
const ARROW_SIZE := 28.0
const COLOR := Color(1.0, 0.42, 0.62, 0.95)

var _game: Node = null
var _lane_indices: Array = []
var _active := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	Events.wave_started.connect(_on_wave_started)
	Events.run_won.connect(_on_run_end)
	Events.run_lost.connect(_on_run_end)


func show_lanes(game: Node, lane_indices: Array) -> void:
	_game = game
	_lane_indices = lane_indices.duplicate()
	_active = true
	visible = true
	queue_redraw()


func clear() -> void:
	_active = false
	_lane_indices.clear()
	visible = false
	queue_redraw()


func _on_wave_started(_number: int, _total: int) -> void:
	clear()


func _on_run_end(_map_id: StringName) -> void:
	clear()


func _process(_delta: float) -> void:
	if _active:
		queue_redraw()


func _draw() -> void:
	if not _active or _game == null or not _game.has_method("get_lane_entry"):
		return
	var vp := get_viewport_rect().size
	for lane: Variant in _lane_indices:
		var entry: Vector2 = _game.get_lane_entry(int(lane))
		if entry == Vector2.ZERO:
			continue
		# Board-local → global (screen) via board transform.
		var board: Node2D = _game.get("board") as Node2D
		if board == null:
			continue
		var screen: Vector2 = board.to_global(entry)
		var on_screen := (
			screen.x >= MARGIN
			and screen.x <= vp.x - MARGIN
			and screen.y >= MARGIN
			and screen.y <= vp.y - MARGIN
		)
		if on_screen:
			continue
		var clamped := Vector2(
			clampf(screen.x, MARGIN, vp.x - MARGIN),
			clampf(screen.y, MARGIN, vp.y - MARGIN)
		)
		_draw_arrow(clamped, screen - clamped)


func _draw_arrow(tip: Vector2, toward: Vector2) -> void:
	var dir := toward.normalized() if toward.length_squared() > 0.01 else Vector2.UP
	# Point toward the off-screen entry (from edge inward-ish toward the spawn).
	if toward.length_squared() < 0.01:
		dir = (tip - get_viewport_rect().size * 0.5).normalized()
	else:
		dir = toward.normalized()
	var base := tip - dir * ARROW_SIZE
	var left := base + dir.rotated(2.4) * (ARROW_SIZE * 0.55)
	var right := base + dir.rotated(-2.4) * (ARROW_SIZE * 0.55)
	draw_colored_polygon(PackedVector2Array([tip, left, right]), COLOR)
	# Bang label above the arrow.
	var font := ThemeDB.fallback_font
	if font != null:
		draw_string(
			font,
			tip + Vector2(-6, -ARROW_SIZE - 4),
			"!",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			28,
			COLOR
		)
