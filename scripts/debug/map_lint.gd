extends SceneTree
## Layout / wave sanity for every data/maps/*.tres.
## Usage: godot --headless --path . --script scripts/debug/map_lint.gd

const PAD_PATH_MIN := 90.0
const PAD_PAD_MIN := 110.0
const PAD_X_MIN := 60.0
const PAD_X_MAX := 660.0
const PAD_Y_MIN := 190.0
const PAD_Y_MAX := 1040.0
const PATH_X_MIN := -80.0
const PATH_X_MAX := 800.0
const PATH_Y_MIN := 160.0
const PATH_Y_MAX := 1060.0
const WAVES_MIN := 10
const WAVES_MAX := 15


func _initialize() -> void:
	var failed := false
	var dir := DirAccess.open("res://data/maps")
	if dir == null:
		push_error("Cannot open res://data/maps")
		quit(1)
		return
	dir.list_dir_begin()
	var names: Array[String] = []
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".tres"):
			names.append(fname)
		fname = dir.get_next()
	dir.list_dir_end()
	names.sort()
	if names.is_empty():
		push_error("No map .tres files found")
		quit(1)
		return
	for name: String in names:
		var path := "res://data/maps/%s" % name
		if not _lint_map(path):
			failed = true
	if failed:
		print("map_lint FAILED")
		quit(1)
	else:
		print("map_lint PASS (%d maps)" % names.size())
		quit(0)


func _lint_map(path: String) -> bool:
	var map: MapData = load(path) as MapData
	if map == null:
		push_error("%s: failed to load as MapData" % path)
		print("FAIL %s" % path)
		return false
	var ok := true
	var label := String(map.id) if map.id != &"" else path
	var y_pad_max := PAD_Y_MAX + map.expansion_pan
	var y_path_max := PATH_Y_MAX + map.expansion_pan

	var lanes: Array[LaneData] = map.resolved_lanes()
	if lanes.is_empty():
		push_error("%s: need ≥1 lane / path points" % label)
		ok = false
	for li: int in lanes.size():
		var lane: LaneData = lanes[li]
		if lane == null or lane.points.size() < 2:
			push_error("%s: lane %d needs ≥2 points" % [label, li])
			ok = false
			continue
		if lane.phase1_point_count > 0 and lane.phase1_point_count < 2:
			push_error("%s: lane %d phase1_point_count %d < 2" % [label, li, lane.phase1_point_count])
			ok = false
		if lane.phase1_point_count > lane.points.size():
			push_error("%s: lane %d phase1_point_count exceeds points" % [label, li])
			ok = false
		for p: Vector2 in lane.points:
			if p.x < PATH_X_MIN or p.x > PATH_X_MAX or p.y < PATH_Y_MIN or p.y > y_path_max:
				push_error("%s: lane %d point %s out of bounds" % [label, li, p])
				ok = false

	# Legacy path_points still checked when present (preview / fallback).
	for p: Vector2 in map.path_points:
		if p.x < PATH_X_MIN or p.x > PATH_X_MAX or p.y < PATH_Y_MIN or p.y > y_path_max:
			push_error("%s: path point %s out of bounds" % [label, p])
			ok = false

	if map.pad_positions.is_empty():
		push_error("%s: no pads" % label)
		ok = false
	if not map.pad_unlock_waves.is_empty() and map.pad_unlock_waves.size() != map.pad_positions.size():
		push_error(
			"%s: pad_unlock_waves size %d != pads %d"
			% [label, map.pad_unlock_waves.size(), map.pad_positions.size()]
		)
		ok = false

	var lane_point_lists: Array[PackedVector2Array] = []
	for lane: LaneData in lanes:
		if lane != null and lane.points.size() >= 2:
			lane_point_lists.append(lane.points)
	if lane_point_lists.is_empty() and map.path_points.size() >= 2:
		lane_point_lists.append(map.path_points)

	for i: int in map.pad_positions.size():
		var pad: Vector2 = map.pad_positions[i]
		if pad.x < PAD_X_MIN or pad.x > PAD_X_MAX or pad.y < PAD_Y_MIN or pad.y > y_pad_max:
			push_error("%s: pad %d %s out of bounds" % [label, i, pad])
			ok = false
		var unlock := map.pad_unlock_wave(i)
		if unlock < 1 or unlock > maxi(1, map.waves.size()):
			push_error("%s: pad %d unlock_wave %d invalid" % [label, i, unlock])
			ok = false
		var dist_path := INF
		for pts: PackedVector2Array in lane_point_lists:
			dist_path = minf(dist_path, _min_dist_to_path(pad, pts))
		if dist_path < PAD_PATH_MIN:
			push_error("%s: pad %d dist to path %.1f < %s" % [label, i, dist_path, PAD_PATH_MIN])
			ok = false
		for j: int in range(i + 1, map.pad_positions.size()):
			var other: Vector2 = map.pad_positions[j]
			var d := pad.distance_to(other)
			if d < PAD_PAD_MIN:
				push_error("%s: pads %d–%d dist %.1f < %s" % [label, i, j, d, PAD_PAD_MIN])
				ok = false

	if map.expansion_wave < 0 or map.expansion_wave > map.waves.size():
		push_error("%s: expansion_wave %d invalid" % [label, map.expansion_wave])
		ok = false
	if map.expansion_wave > 0 and map.expansion_pan <= 0.0:
		push_error("%s: expansion_wave set but expansion_pan is 0" % label)
		ok = false

	var wave_count := map.waves.size()
	if wave_count < WAVES_MIN or wave_count > WAVES_MAX:
		push_error("%s: wave count %d not in %d–%d" % [label, wave_count, WAVES_MIN, WAVES_MAX])
		ok = false
	for wi: int in map.waves.size():
		var wave: WaveData = map.waves[wi]
		if wave == null or wave.spawn_groups.is_empty():
			push_error("%s: wave %d empty" % [label, wi + 1])
			ok = false
			continue
		for gi: int in wave.spawn_groups.size():
			var g: SpawnGroup = wave.spawn_groups[gi]
			if g == null or g.enemy == null:
				push_error("%s: wave %d group %d null enemy" % [label, wi + 1, gi])
				ok = false
			elif g.count <= 0:
				push_error("%s: wave %d group %d count %d" % [label, wi + 1, gi, g.count])
				ok = false
			elif g.lane < 0 or g.lane >= lanes.size():
				push_error("%s: wave %d group %d lane %d out of range" % [label, wi + 1, gi, g.lane])
				ok = false

	for li: int in lanes.size():
		var lane: LaneData = lanes[li]
		if lane == null:
			continue
		if lane.unlock_wave < 1 or lane.unlock_wave > maxi(1, wave_count):
			push_error("%s: lane %d unlock_wave %d invalid" % [label, li, lane.unlock_wave])
			ok = false

	if ok:
		print("PASS %s (waves=%d pads=%d lanes=%d)" % [label, wave_count, map.pad_positions.size(), lanes.size()])
	else:
		print("FAIL %s" % label)
	return ok


func _min_dist_to_path(point: Vector2, path: PackedVector2Array) -> float:
	var best := INF
	for i: int in range(path.size() - 1):
		best = minf(best, _dist_point_to_segment(point, path[i], path[i + 1]))
	return best


func _dist_point_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len_sq := ab.length_squared()
	if len_sq <= 0.0001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
	return p.distance_to(a + ab * t)
