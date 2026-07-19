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

	if map.path_points.size() < 2:
		push_error("%s: need ≥2 path points" % label)
		ok = false
	for p: Vector2 in map.path_points:
		if p.x < PATH_X_MIN or p.x > PATH_X_MAX or p.y < PATH_Y_MIN or p.y > PATH_Y_MAX:
			push_error("%s: path point %s out of bounds" % [label, p])
			ok = false

	if map.pad_positions.is_empty():
		push_error("%s: no pads" % label)
		ok = false
	for i: int in map.pad_positions.size():
		var pad: Vector2 = map.pad_positions[i]
		if pad.x < PAD_X_MIN or pad.x > PAD_X_MAX or pad.y < PAD_Y_MIN or pad.y > PAD_Y_MAX:
			push_error("%s: pad %d %s out of bounds" % [label, i, pad])
			ok = false
		var dist_path := _min_dist_to_path(pad, map.path_points)
		if dist_path < PAD_PATH_MIN:
			push_error("%s: pad %d dist to path %.1f < %s" % [label, i, dist_path, PAD_PATH_MIN])
			ok = false
		for j: int in range(i + 1, map.pad_positions.size()):
			var other: Vector2 = map.pad_positions[j]
			var d := pad.distance_to(other)
			if d < PAD_PAD_MIN:
				push_error("%s: pads %d–%d dist %.1f < %s" % [label, i, j, d, PAD_PAD_MIN])
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

	if ok:
		print("PASS %s (waves=%d pads=%d)" % [label, wave_count, map.pad_positions.size()])
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
