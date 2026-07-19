extends Control
## Mini path/pad preview drawn from MapData. Stage 6 swap point for thumbnail sprites.

const PATH_COLOR := Color(1.0, 0.86, 0.9, 1) ## frosting path
const PAD_COLOR := Color(0.82, 0.72, 0.94, 1) ## marshmallow lilac
const SCALE := 0.16
const PATH_WIDTH := 6.0
const PAD_RADIUS := 5.0

var _points: PackedVector2Array = PackedVector2Array()
var _pads: PackedVector2Array = PackedVector2Array()


func setup_from_map(map: MapData) -> void:
	_points = PackedVector2Array()
	_pads = PackedVector2Array()
	if map == null:
		queue_redraw()
		return
	for p: Vector2 in map.path_points:
		_points.append(p * SCALE)
	for p: Vector2 in map.pad_positions:
		_pads.append(p * SCALE)
	queue_redraw()


func _draw() -> void:
	if _points.size() >= 2:
		draw_polyline(_points, PATH_COLOR, PATH_WIDTH, true)
	for pad: Vector2 in _pads:
		draw_circle(pad, PAD_RADIUS, PAD_COLOR)
