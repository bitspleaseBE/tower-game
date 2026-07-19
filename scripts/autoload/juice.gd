extends Node
## Dumb juice toolkit. Never connects to Events — call sites own their juice.

const FloaterScene: PackedScene = preload("res://scenes/ui/floater.tscn")
const CoinFlyerScene: PackedScene = preload("res://scenes/ui/coin_flyer.tscn")
const ConfettiScene: PackedScene = preload("res://scenes/fx/confetti_cpu.tscn")

var _registered: bool = false
var _fx_layer: Node2D
var _shake_target: Node2D
var _hud: Node
var _shake_rest: Vector2 = Vector2.ZERO
var _shake_strength: float = 0.0
var _shake_time_left: float = 0.0
var _shake_duration: float = 0.0

var _claims: Dictionary = {} ## CanvasItem -> {scale, rotation, position, modulate, tween}
var _floater_pool: ObjectPool
var _coin_pool: ObjectPool
var _confetti_pool: ObjectPool


func register_game(fx_layer: Node2D, shake_target: Node2D, hud: Node) -> void:
	_unregister()
	_fx_layer = fx_layer
	_shake_target = shake_target
	_hud = hud
	_shake_rest = shake_target.position
	_shake_strength = 0.0
	_shake_time_left = 0.0
	_claims.clear()

	_floater_pool = ObjectPool.new(
		FloaterScene, fx_layer, mini(8, PerfBudget.MAX_FLOATERS), PerfBudget.MAX_FLOATERS, ObjectPool.GrowPolicy.DROP
	)
	_coin_pool = ObjectPool.new(
		CoinFlyerScene, fx_layer, mini(8, PerfBudget.MAX_COIN_FLYERS), PerfBudget.MAX_COIN_FLYERS, ObjectPool.GrowPolicy.DROP
	)
	_confetti_pool = ObjectPool.new(
		ConfettiScene, fx_layer, mini(4, PerfBudget.MAX_CONFETTI_BURSTS), PerfBudget.MAX_CONFETTI_BURSTS, ObjectPool.GrowPolicy.DROP
	)

	if not fx_layer.tree_exiting.is_connected(_unregister):
		fx_layer.tree_exiting.connect(_unregister)
	_registered = true
	set_process(true)


func _unregister() -> void:
	if _shake_target != null and is_instance_valid(_shake_target):
		_shake_target.position = _shake_rest
	_registered = false
	_fx_layer = null
	_shake_target = null
	_hud = null
	_floater_pool = null
	_coin_pool = null
	_confetti_pool = null
	_claims.clear()
	_shake_strength = 0.0
	_shake_time_left = 0.0
	set_process(false)


func claim(item: CanvasItem) -> void:
	if item == null:
		return
	_kill_claim_tween(item)
	_claims[item] = {
		"scale": item.scale,
		"rotation": item.rotation,
		"position": item.position,
		"modulate": item.modulate,
		"tween": null,
	}


func set_claim_modulate(item: CanvasItem, color: Color) -> void:
	if item == null:
		return
	item.modulate = color
	if _claims.has(item):
		_claims[item]["modulate"] = color


func release(item: CanvasItem) -> void:
	if item == null or not _claims.has(item):
		return
	_kill_claim_tween(item)
	_restore_rest(item)
	_claims.erase(item)


func punch_scale(item: CanvasItem, amount := 1.35, duration := 0.18) -> void:
	if item == null:
		return
	var rest := _ensure_claim(item)
	_kill_claim_tween(item)
	item.scale = rest["scale"]
	var tween := item.create_tween()
	_set_claim_tween(item, tween)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(item, "scale", rest["scale"] * amount, duration * 0.35)
	tween.tween_property(item, "scale", rest["scale"], duration * 0.65)


func bounce_in(item: CanvasItem, duration := 0.25) -> void:
	if item == null:
		return
	var rest := _ensure_claim(item)
	_kill_claim_tween(item)
	item.scale = rest["scale"] * 0.5
	var tween := item.create_tween()
	_set_claim_tween(item, tween)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(item, "scale", rest["scale"], duration)


func squash(item: CanvasItem, squish := Vector2(1.2, 0.8), duration := 0.15) -> void:
	if item == null:
		return
	var rest := _ensure_claim(item)
	_kill_claim_tween(item)
	item.scale = rest["scale"]
	var tween := item.create_tween()
	_set_claim_tween(item, tween)
	tween.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(item, "scale", Vector2(rest["scale"].x * squish.x, rest["scale"].y * squish.y), duration * 0.4)
	tween.tween_property(item, "scale", rest["scale"], duration * 0.6)


func flash(
	item: CanvasItem,
	flash_color := Color(6, 6, 6),
	duration := 0.1,
	restore_to: Variant = null
) -> void:
	if item == null:
		return
	var rest := _ensure_claim(item)
	_kill_claim_tween(item)
	var end_color: Color = rest["modulate"]
	if restore_to is Color:
		end_color = restore_to as Color
		rest["modulate"] = end_color
	item.modulate = end_color
	var tween := item.create_tween()
	_set_claim_tween(item, tween)
	tween.tween_property(item, "modulate", flash_color, duration * 0.4)
	tween.tween_property(item, "modulate", end_color, duration * 0.6)


## Horizontal wiggle for invalid taps. Unregistered-safe; restores claimed rest or pre-tween x.
func wiggle(item: CanvasItem, amp_px := 6.0, duration := 0.2) -> void:
	if item == null:
		return
	var rest_x: float
	if _claims.has(item):
		rest_x = (_claims[item]["position"] as Vector2).x
		_kill_claim_tween(item)
	else:
		rest_x = item.position.x
	if item is Control:
		var control := item as Control
		control.pivot_offset = control.size * 0.5
	var tween := item.create_tween()
	if _claims.has(item):
		_set_claim_tween(item, tween)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var step := duration / 6.0
	tween.tween_property(item, "position:x", rest_x + amp_px, step)
	tween.tween_property(item, "position:x", rest_x - amp_px, step)
	tween.tween_property(item, "position:x", rest_x + amp_px * 0.6, step)
	tween.tween_property(item, "position:x", rest_x - amp_px * 0.6, step)
	tween.tween_property(item, "position:x", rest_x + amp_px * 0.3, step)
	tween.tween_property(item, "position:x", rest_x, step)


func splash_ring(world_pos: Vector2, max_radius := 90.0) -> void:
	if not _registered or _fx_layer == null:
		return
	var ring := Node2D.new()
	ring.z_index = 20
	_fx_layer.add_child(ring)
	ring.global_position = world_pos
	ring.set_meta("r", 8.0)
	ring.set_meta("a", 0.7)
	ring.draw.connect(func() -> void:
		var r: float = float(ring.get_meta("r"))
		var a: float = float(ring.get_meta("a"))
		ring.draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(1.0, 0.84, 0.42, a), 4.0, true)
	)
	ring.queue_redraw()
	var tween := ring.create_tween()
	tween.tween_method(func(v: float) -> void:
		ring.set_meta("r", lerpf(8.0, max_radius, v))
		ring.set_meta("a", lerpf(0.7, 0.0, v))
		ring.queue_redraw()
	, 0.0, 1.0, 0.28)
	tween.tween_callback(ring.queue_free)


func frost_pulse(world_pos: Vector2, max_radius: float) -> void:
	if not _registered or _fx_layer == null:
		return
	var ring := Node2D.new()
	ring.z_index = 20
	_fx_layer.add_child(ring)
	ring.global_position = world_pos
	ring.set_meta("r", 12.0)
	ring.set_meta("a", 0.65)
	ring.draw.connect(func() -> void:
		var r: float = float(ring.get_meta("r"))
		var a: float = float(ring.get_meta("a"))
		ring.draw_circle(Vector2.ZERO, r, Color(0.75, 0.89, 1.0, a * 0.25))
		ring.draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(0.55, 0.82, 0.94, a), 3.0, true)
	)
	ring.queue_redraw()
	var tween := ring.create_tween()
	tween.tween_method(func(v: float) -> void:
		ring.set_meta("r", lerpf(12.0, max_radius, v))
		ring.set_meta("a", lerpf(0.65, 0.0, v))
		ring.queue_redraw()
	, 0.0, 1.0, 0.35)
	tween.tween_callback(ring.queue_free)


func muzzle_flash(world_pos: Vector2) -> void:
	if not _registered or _fx_layer == null:
		return
	var flash := Sprite2D.new()
	flash.z_index = 20
	flash.texture = preload("res://assets/fx/particle_muzzle.png")
	flash.modulate = Color(1.0, 0.95, 0.7, 1.0)
	var flash_scale := 36.0 / float(flash.texture.get_width())
	flash.scale = Vector2(flash_scale, flash_scale)
	_fx_layer.add_child(flash)
	flash.global_position = world_pos
	var tween := flash.create_tween()
	tween.tween_property(flash, "scale", flash.scale * 1.6, 0.12)
	tween.parallel().tween_property(flash, "modulate:a", 0.0, 0.12)
	tween.tween_callback(flash.queue_free)


func upgrade_fx(tower: Node2D) -> void:
	if tower == null:
		return
	var skin_node: Node2D = tower.get_node_or_null("Skin") as Node2D
	if skin_node != null:
		punch_scale(skin_node, 1.25, 0.2)
	confetti(tower.global_position)
	_sparkle_burst(tower.global_position)
	var range_px := 180.0
	if tower.get("data") != null and tower.get("tier") != null:
		var td: TowerData = tower.data
		var t: int = tower.tier
		if td != null and t >= 0 and t < td.range_px.size():
			range_px = td.range_px[t]
	splash_ring(tower.global_position, range_px)


func sell_fx(world_pos: Vector2, pad_skin: CanvasItem = null) -> void:
	coin_burst(world_pos, 5)
	confetti(world_pos)
	_puff_burst(world_pos)
	if pad_skin != null:
		squash(pad_skin, Vector2(1.3, 0.6), 0.2)


func _sparkle_burst(world_pos: Vector2) -> void:
	if not _registered or _fx_layer == null:
		return
	var sparkle := Sprite2D.new()
	sparkle.z_index = 20
	sparkle.texture = preload("res://assets/fx/particle_sparkle.png")
	sparkle.modulate = Color(1.0, 0.95, 0.7, 0.9)
	var s := 28.0 / float(sparkle.texture.get_width())
	sparkle.scale = Vector2(s, s)
	_fx_layer.add_child(sparkle)
	sparkle.global_position = world_pos
	var tween := sparkle.create_tween()
	tween.tween_property(sparkle, "scale", sparkle.scale * 1.8, 0.22)
	tween.parallel().tween_property(sparkle, "modulate:a", 0.0, 0.22)
	tween.tween_callback(sparkle.queue_free)


func _puff_burst(world_pos: Vector2) -> void:
	if not _registered or _fx_layer == null:
		return
	var puff := Sprite2D.new()
	puff.z_index = 20
	puff.texture = preload("res://assets/fx/particle_puff.png")
	puff.modulate = Color(1.0, 1.0, 1.0, 0.7)
	var s := 40.0 / float(puff.texture.get_width())
	puff.scale = Vector2(s, s)
	_fx_layer.add_child(puff)
	puff.global_position = world_pos
	var tween := puff.create_tween()
	tween.tween_property(puff, "scale", puff.scale * 1.7, 0.28)
	tween.parallel().tween_property(puff, "modulate:a", 0.0, 0.28)
	tween.tween_callback(puff.queue_free)


func pop_in_out(item: CanvasItem, hold := 0.7) -> void:
	if item == null:
		return
	var rest := _ensure_claim(item)
	_kill_claim_tween(item)
	item.visible = true
	item.scale = rest["scale"] * 0.4
	if item is Control:
		var control := item as Control
		control.pivot_offset = control.size * 0.5
	var tween := item.create_tween()
	_set_claim_tween(item, tween)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(item, "scale", rest["scale"], 0.28)
	tween.tween_interval(hold)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(item, "scale", rest["scale"] * 0.4, 0.2)
	tween.tween_callback(func() -> void:
		item.visible = false
		item.scale = rest["scale"]
	)


func wobble_scale(t: float, strength := 0.07, freq := 9.0) -> Vector2:
	return Vector2(1.0 + strength * sin(t * freq), 1.0 + strength * sin(t * freq + PI))


func shake(strength_px := 4.0, duration := 0.2) -> void:
	if not _registered or _shake_target == null:
		push_warning("Juice.shake called while unregistered")
		return
	var clamped_strength := minf(strength_px, PerfBudget.MAX_SHAKE_PX)
	var clamped_duration := minf(duration, PerfBudget.MAX_SHAKE_DURATION)
	_shake_strength = maxf(_shake_strength, clamped_strength)
	_shake_duration = maxf(_shake_duration, clamped_duration)
	_shake_time_left = maxf(_shake_time_left, clamped_duration)


func squishify_button(button: Button) -> void:
	if button == null:
		return
	_center_button_pivot(button)
	if button.get_meta("juice_squish", false):
		return
	button.set_meta("juice_squish", true)
	if not button.resized.is_connected(_center_button_pivot.bind(button)):
		button.resized.connect(_center_button_pivot.bind(button))
	button.button_down.connect(_on_button_down.bind(button))
	button.button_up.connect(_on_button_up.bind(button))


func floater(text: String, world_pos: Vector2, color := Color.WHITE) -> void:
	if not _registered or _floater_pool == null:
		push_warning("Juice.floater called while unregistered")
		return
	var node: Node = _floater_pool.acquire()
	if node == null:
		node = _floater_pool.oldest_live()
		if node == null:
			return
		var stolen := node as Floater
		stolen.force_stop()
		_floater_pool.release(stolen)
		node = _floater_pool.acquire()
		if node == null:
			return
	var floater_node := node as Floater
	floater_node.activate(text, world_pos, color)
	floater_node.finished.connect(_on_floater_finished.bind(floater_node), CONNECT_ONE_SHOT)


func coin_burst(world_pos: Vector2, count := 3) -> void:
	if not _registered or _coin_pool == null:
		push_warning("Juice.coin_burst called while unregistered")
		return
	var anchor := Vector2.ZERO
	if _hud != null and _hud.has_method("coin_anchor"):
		anchor = _hud.coin_anchor()
	for i: int in count:
		var node: Node = _coin_pool.acquire()
		if node == null:
			break
		var flyer := node as CoinFlyer
		var side := 1.0 if (i % 2 == 0) else -1.0
		var control := world_pos + Vector2(side * randf_range(80.0, 150.0), randf_range(-60.0, -20.0))
		var duration := randf_range(0.45, 0.65)
		flyer.activate(world_pos, control, anchor, duration)
		flyer.finished.connect(_on_coin_finished.bind(flyer), CONNECT_ONE_SHOT)


func confetti(world_pos: Vector2) -> void:
	if not _registered or _confetti_pool == null:
		push_warning("Juice.confetti called while unregistered")
		return
	var node: Node = _confetti_pool.acquire()
	if node == null:
		return
	var burst := node as ConfettiBurst
	burst.activate(world_pos)
	burst.finished.connect(_on_confetti_finished.bind(burst), CONNECT_ONE_SHOT)


func floater_live_count() -> int:
	return 0 if _floater_pool == null else _floater_pool.live_count()


func coin_live_count() -> int:
	return 0 if _coin_pool == null else _coin_pool.live_count()


func confetti_live_count() -> int:
	return 0 if _confetti_pool == null else _confetti_pool.live_count()


func is_registered() -> bool:
	return _registered


func sync_shake_rest() -> void:
	if _registered and _shake_target != null and is_instance_valid(_shake_target):
		_shake_rest = _shake_target.position


func _process(delta: float) -> void:
	if not _registered or _shake_target == null:
		return
	if _shake_time_left <= 0.0:
		_shake_target.position = _shake_rest
		_shake_strength = 0.0
		return
	_shake_time_left = maxf(0.0, _shake_time_left - delta)
	var t := 0.0 if _shake_duration <= 0.0 else _shake_time_left / _shake_duration
	var amp := _shake_strength * t
	if _shake_time_left <= 0.0:
		_shake_target.position = _shake_rest
		_shake_strength = 0.0
	else:
		_shake_target.position = _shake_rest + Vector2(randf_range(-amp, amp), randf_range(-amp, amp))


func _ensure_claim(item: CanvasItem) -> Dictionary:
	if not _claims.has(item):
		claim(item)
	return _claims[item]


func _kill_claim_tween(item: CanvasItem) -> void:
	if not _claims.has(item):
		return
	var entry: Dictionary = _claims[item]
	var tween: Tween = entry.get("tween")
	if tween != null and tween.is_valid():
		tween.kill()
	entry["tween"] = null


func _set_claim_tween(item: CanvasItem, tween: Tween) -> void:
	if not _claims.has(item):
		return
	_claims[item]["tween"] = tween


func _restore_rest(item: CanvasItem) -> void:
	if not _claims.has(item) or not is_instance_valid(item):
		return
	var rest: Dictionary = _claims[item]
	item.scale = rest["scale"]
	item.rotation = rest["rotation"]
	item.position = rest["position"]
	item.modulate = rest["modulate"]


func _center_button_pivot(button: Button) -> void:
	button.pivot_offset = button.size * 0.5


func _on_button_down(button: Button) -> void:
	if button.disabled:
		return
	Sound.play_sfx(&"ui_tap")
	_center_button_pivot(button)
	var tween := button.create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2(0.92, 0.92), 0.06)


func _on_button_up(button: Button) -> void:
	_center_button_pivot(button)
	var tween := button.create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2.ONE, 0.12)


func _on_floater_finished(floater_node: Floater) -> void:
	if _floater_pool != null:
		_floater_pool.release(floater_node)


func _on_coin_finished(flyer: CoinFlyer) -> void:
	if _coin_pool != null:
		_coin_pool.release(flyer)
	if _hud != null and _hud.has_method("pulse_coins"):
		_hud.pulse_coins()


func _on_confetti_finished(burst: ConfettiBurst) -> void:
	if _confetti_pool != null:
		_confetti_pool.release(burst)
