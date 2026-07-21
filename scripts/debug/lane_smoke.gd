extends SceneTree
func _initialize() -> void:
	var failed := false
	var sg: Node = root.get_node("SaveGame")
	for id in ["map_04", "map_05"]:
		var map: MapData = load("res://data/maps/%s.tres" % id) as MapData
		if map == null:
			push_error("load fail %s" % id)
			failed = true
			continue
		var lanes := map.resolved_lanes()
		print("OK %s lanes=%d expansion=%d pan=%.0f" % [id, lanes.size(), map.expansion_wave, map.expansion_pan])
		sg.set("run_map", map)
		sg.set("run_endless", false)
		var packed := load("res://scenes/game.tscn") as PackedScene
		var game = packed.instantiate()
		game.set_meta("smoke_silent", true)
		root.add_child(game)
		await process_frame
		await process_frame
		var count: int = int(game.call("lane_count"))
		print("OK %s runtime lanes=%d" % [id, count])
		if id == "map_04" and count != 2:
			push_error("map_04 expected 2")
			failed = true
		if id == "map_05" and count != 3:
			push_error("map_05 expected 3")
			failed = true
		if id == "map_05":
			await game.call("run_expansion_if_needed")
			var pan = game.get("_board_pan")
			print("OK map_05 after expand pan=%s expanded=%s" % [pan, game.get("_expanded")])
			if not bool(game.get("_expanded")):
				push_error("map_05 did not expand")
				failed = true
		game.queue_free()
		await process_frame
	if failed:
		print("lane_smoke FAILED")
		quit(1)
	print("lane_smoke PASSED")
	quit(0)
