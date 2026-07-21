extends Control
## Mini path/pad preview drawn from MapData. Stage 6 swap point for thumbnail sprites.

const PATH_COLOR := Color(1.0, 0.86, 0.9, 1) ## frosting path
const PAD_COLOR := Color(0.82, 0.72, 0.94, 1) ## marshmallow lilac
const PAD_LOCKED_COLOR := Color(0.82, 0.72, 0.94, 0.4)
const PATH_WIDTH := 6.0
const PAD_RADIUS := 5.0
const MARGIN := 8.0

var _lanes: Array[PackedVector2Array] = []
var _pads: PackedVector2Array = PackedVector2Array()
var _pad_locked: Array[bool] = []
var _fit_scale: float = 0.16
var _fit_offset: Vector2 = Vector2.ZERO


func setup_from_map(map: MapData) -> void:
	_lanes.clear()
	_pads = PackedVector2Array()
	_pad_locked.clear()
	if map == null:
		queue_redraw()
		return
	var lanes := map.resolved_lanes()
	var bounds := Rect2()
	var has_bounds := false
	for lane: LaneData in lanes:
		if lane == null or lane.points.size() < 2:
			continue
		var pts := PackedVector2Array()
		for p: Vector2 in lane.points:
			pts.append(p)
			if not has_bounds:
				bounds = Rect2(p, Vector2.ZERO)
				has_bounds = true
			else:
				bounds = bounds.expand(p)
		_lanes.append(pts)
	for i: int in map.pad_positions.size():
		var p: Vector2 = map.pad_positions[i]
		_pads.append(p)
		_pad_locked.append(map.pad_unlock_wave(i) > 1)
		if not has_bounds:
			bounds = Rect2(p, Vector2.ZERO)
			has_bounds = true
		else:
			bounds = bounds.expand(p)
	_compute_fit(bounds)
	queue_redraw()


func _compute_fit(bounds: Rect2) -> void:
	var avail := size
	if avail.x < 8.0 or avail.y < 8.0:
		avail = Vector2(120, 160)
	if bounds.size.x < 1.0 or bounds.size.y < 1.0:
		_fit_scale = 0.16
		_fit_offset = Vector2(MARGIN, MARGIN)
		return
	var sx := (avail.x - MARGIN * 2.0) / bounds.size.x
	var sy := (avail.y - MARGIN * 2.0) / bounds.size.y
	_fit_scale = minf(sx, sy)
	var drawn := bounds.size * _fit_scale
	_fit_offset = Vector2(
		MARGIN + (avail.x - MARGIN * 2.0 - drawn.x) * 0.5 - bounds.position.x * _fit_scale,
		MARGIN + (avail.y - MARGIN * 2.0 - drawn.y) * 0.5 - bounds.position.y * _fit_scale
	)


func _map_to_local(p: Vector2) -> Vector2:
	return p * _fit_scale + _fit_offset


func _draw() -> void:
	if size.x >= 8.0 and size.y >= 8.0 and not _lanes.is_empty():
		# Recompute if we now know our real size (first draw after setup).
		var bounds := Rect2()
		var has := false
		for pts: PackedVector2Array in _lanes:
			for p: Vector2 in pts:
				if not has:
					bounds = Rect2(p, Vector2.ZERO)
					has = true
				else:
					bounds = bounds.expand(p)
		for p: Vector2 in _pads:
			if not has:
				bounds = Rect2(p, Vector2.ZERO)
				has = true
			else:
				bounds = bounds.expand(p)
		_compute_fit(bounds)
	for pts: PackedVector2Array in _lanes:
		if pts.size() < 2:
			continue
		var local := PackedVector2Array()
		for p: Vector2 in pts:
			local.append(_map_to_local(p))
		draw_polyline(local, PATH_COLOR, PATH_WIDTH, true)
	for i: int in _pads.size():
		var col := PAD_LOCKED_COLOR if i < _pad_locked.size() and _pad_locked[i] else PAD_COLOR
		draw_circle(_map_to_local(_pads[i]), PAD_RADIUS, col)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
