extends Control
## Once-ever coach tip card. PROCESS_MODE_ALWAYS while the tree is paused.

signal dismissed

const DEMO_WEAPONS := {
	&"popper": preload("res://assets/tower/weapon_popper.png"),
	&"lobber": preload("res://assets/tower/weapon_lobber.png"),
	&"chiller": preload("res://assets/tower/weapon_chiller.png"),
	&"longshot": preload("res://assets/tower/weapon_longshot.png"),
}
const DEMO_WEAPONS_T3 := {
	&"popper": preload("res://assets/tower/weapon_popper_t3.png"),
	&"lobber": preload("res://assets/tower/weapon_lobber_t3.png"),
	&"chiller": preload("res://assets/tower/weapon_chiller_t3.png"),
	&"longshot": preload("res://assets/tower/weapon_longshot_t3.png"),
}
const DEMO_PROJECTILES := {
	&"popper": preload("res://assets/tower/projectile_shot.png"),
	&"lobber": preload("res://assets/tower/projectile_balloon.png"),
	&"chiller": preload("res://assets/fx/particle_water_drop.png"),
	&"longshot": preload("res://assets/tower/projectile_laser.png"),
}
const DEMO_BURST_TEXTURE: Texture2D = preload("res://assets/tower/projectile_balloon.png")
const DEMO_MINION: Texture2D = preload("res://assets/enemies/critter_swarm.png")
const DEMO_SLUSH_TINT := Color(0.62, 0.85, 1.0, 1.0)
const DEMO_STUN_TINT := Color(0.749, 0.89, 1.0, 1.0) ## Matches Enemy.SLOW_TINT.
const DEMO_FLASH := Color(1.7, 1.7, 1.5, 1.0)

@onready var backdrop: ColorRect = %Backdrop
@onready var panel: PanelContainer = %TipPanel
@onready var art: TextureRect = %TipArt
@onready var demo_box: Control = %TipDemo
@onready var title_label: Label = %TitleLabel
@onready var body_label: Label = %BodyLabel
@onready var got_it_button: Button = %GotItButton

var _tip_key: String = ""
var _open: bool = false
var _demo_tower: Sprite2D
var _demo_minion: Sprite2D
var _demo_projectile: Sprite2D
var _demo_burst: Sprite2D
var _demo_tower_scale := Vector2.ONE
var _demo_minion_scale := Vector2.ONE
var _demo_burst_scale := Vector2.ONE
var _demo_tween: Tween
var _demo_fx: Array[Tween] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if demo_box != null:
		demo_box.process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	got_it_button.pressed.connect(_on_got_it)
	Juice.squishify_button(got_it_button)


func is_open() -> bool:
	return _open


func show_tip(
	title: String, body: String, tip_key: String, texture: Texture2D = null, demo: Dictionary = {}
) -> void:
	_tip_key = tip_key
	title_label.text = title
	body_label.text = body
	_stop_demo()
	if not demo.is_empty():
		art.visible = false
		demo_box.visible = true
	elif texture != null:
		art.texture = texture
		art.visible = true
		demo_box.visible = false
	else:
		art.visible = false
		demo_box.visible = false
	_open = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	Sound.set_music_ducked(true)
	get_tree().paused = true
	panel.scale = Vector2(0.6, 0.6)
	await get_tree().process_frame
	panel.pivot_offset = panel.size * 0.5
	if _open and not demo.is_empty():
		_start_demo(demo)
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.28)
	got_it_button.grab_focus()


func close() -> void:
	if not _open:
		return
	_open = false
	_stop_demo()
	get_tree().paused = false
	Sound.set_music_ducked(false)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_got_it() -> void:
	if not _tip_key.is_empty():
		SaveGame.mark_tip_seen(_tip_key)
	close()
	dismissed.emit()


func _ensure_demo_nodes() -> void:
	if _demo_tower != null:
		return
	_demo_tower = Sprite2D.new()
	_demo_tower.name = "DemoTower"
	_demo_tower.process_mode = Node.PROCESS_MODE_ALWAYS
	demo_box.add_child(_demo_tower)
	_demo_minion = Sprite2D.new()
	_demo_minion.name = "DemoMinion"
	_demo_minion.process_mode = Node.PROCESS_MODE_ALWAYS
	demo_box.add_child(_demo_minion)
	_demo_burst = Sprite2D.new()
	_demo_burst.name = "DemoBurst"
	_demo_burst.process_mode = Node.PROCESS_MODE_ALWAYS
	_demo_burst.visible = false
	demo_box.add_child(_demo_burst)
	_demo_projectile = Sprite2D.new()
	_demo_projectile.name = "DemoProjectile"
	_demo_projectile.process_mode = Node.PROCESS_MODE_ALWAYS
	_demo_projectile.visible = false
	demo_box.add_child(_demo_projectile)


func _start_demo(demo: Dictionary) -> void:
	_ensure_demo_nodes()
	var tower_id: StringName = demo.get("tower", &"popper")
	var flavor: StringName = demo.get("flavor", &"")
	# VBox lays TipDemo out after it becomes visible; fall back if a frame was missed.
	var w := demo_box.size.x
	if w < 8.0:
		w = maxf(demo_box.get_parent().size.x if demo_box.get_parent() is Control else 0.0, 480.0)
	var mid := demo_box.size.y * 0.5 if demo_box.size.y > 8.0 else 85.0

	var weapons: Dictionary = DEMO_WEAPONS_T3 if flavor != &"" else DEMO_WEAPONS
	var weapon_tex: Texture2D = weapons.get(tower_id, DEMO_WEAPONS[&"popper"]) as Texture2D
	_demo_tower.texture = weapon_tex
	var tower_fit := 96.0 / float(maxi(weapon_tex.get_width(), weapon_tex.get_height()))
	_demo_tower_scale = Vector2(tower_fit, tower_fit)
	_demo_tower.scale = _demo_tower_scale
	# Weapon sprites face up at rotation 0 — turn to face the minion on the right.
	_demo_tower.rotation = PI * 0.5
	_demo_tower.position = Vector2(72.0, mid)

	_demo_minion.texture = DEMO_MINION
	var minion_fit := 72.0 / float(maxi(DEMO_MINION.get_width(), DEMO_MINION.get_height()))
	_demo_minion_scale = Vector2(minion_fit, minion_fit)
	_demo_minion.scale = _demo_minion_scale
	_demo_minion.position = Vector2(w - 80.0, mid)
	_demo_minion.modulate = Color.WHITE

	var proj_tex: Texture2D = DEMO_PROJECTILES.get(tower_id, DEMO_PROJECTILES[&"popper"]) as Texture2D
	_demo_projectile.texture = proj_tex
	var proj_fit := 26.0 / float(maxi(proj_tex.get_width(), proj_tex.get_height()))
	_demo_projectile.scale = Vector2(proj_fit, proj_fit)
	_demo_projectile.rotation = PI * 0.5
	_demo_projectile.self_modulate = DEMO_SLUSH_TINT if tower_id == &"chiller" else Color.WHITE
	_demo_projectile.visible = false

	var burst_fit := 90.0 / float(maxi(DEMO_BURST_TEXTURE.get_width(), DEMO_BURST_TEXTURE.get_height()))
	_demo_burst.texture = DEMO_BURST_TEXTURE
	_demo_burst_scale = Vector2(burst_fit, burst_fit)
	_demo_burst.visible = false

	var muzzle := _demo_tower.position + Vector2(46.0, 0.0)
	var hit := _demo_minion.position - Vector2(30.0, 0.0)
	_demo_tween = create_tween()
	_demo_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_demo_tween.set_loops()
	_demo_tween.tween_callback(_demo_fire.bind(muzzle))
	_demo_tween.tween_property(_demo_projectile, "position", hit, 0.45)
	_demo_tween.tween_callback(_demo_hit.bind(flavor))
	if flavor == &"pierce":
		# Shot keeps flying past the minion and off the card.
		_demo_tween.tween_property(_demo_projectile, "position", Vector2(w + 40.0, mid), 0.3)
		_demo_tween.parallel().tween_property(_demo_projectile, "modulate:a", 0.0, 0.3)
	else:
		_demo_tween.tween_callback(func() -> void: _demo_projectile.visible = false)
	_demo_tween.tween_interval(0.85)


func _stop_demo() -> void:
	if _demo_tween != null and _demo_tween.is_valid():
		_demo_tween.kill()
	_demo_tween = null
	for fx: Tween in _demo_fx:
		if fx != null and fx.is_valid():
			fx.kill()
	_demo_fx.clear()
	if _demo_projectile != null:
		_demo_projectile.visible = false
	if _demo_burst != null:
		_demo_burst.visible = false
	if _demo_minion != null:
		_demo_minion.modulate = Color.WHITE
		_demo_minion.scale = _demo_minion_scale
	if _demo_tower != null:
		_demo_tower.scale = _demo_tower_scale


func _demo_fx_tween() -> Tween:
	# Prune finished tweens so the list stays small while the demo loops.
	for i: int in range(_demo_fx.size() - 1, -1, -1):
		var t: Tween = _demo_fx[i]
		if t == null or not t.is_valid():
			_demo_fx.remove_at(i)
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_demo_fx.append(tween)
	return tween


func _demo_fire(muzzle: Vector2) -> void:
	_demo_minion.modulate = Color.WHITE
	_demo_minion.scale = _demo_minion_scale
	_demo_projectile.position = muzzle
	_demo_projectile.modulate = Color.WHITE
	_demo_projectile.visible = true
	var recoil := _demo_fx_tween()
	recoil.tween_property(_demo_tower, "scale", _demo_tower_scale * Vector2(0.85, 1.1), 0.06)
	recoil.tween_property(_demo_tower, "scale", _demo_tower_scale, 0.12)


func _demo_hit(flavor: StringName) -> void:
	var pop := _demo_fx_tween()
	pop.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(_demo_minion, "scale", _demo_minion_scale * Vector2(1.3, 0.7), 0.08)
	pop.tween_property(_demo_minion, "scale", _demo_minion_scale, 0.16)
	match flavor:
		&"burst":
			_demo_burst.position = _demo_minion.position
			_demo_burst.modulate = Color(1.0, 0.85, 0.4, 0.9)
			_demo_burst.scale = _demo_burst_scale * 0.25
			_demo_burst.visible = true
			var burst := _demo_fx_tween()
			burst.tween_property(_demo_burst, "scale", _demo_burst_scale * 1.5, 0.28)
			burst.parallel().tween_property(_demo_burst, "modulate:a", 0.0, 0.28)
			burst.tween_callback(func() -> void: _demo_burst.visible = false)
		&"stun":
			var stun := _demo_fx_tween()
			stun.tween_property(_demo_minion, "modulate", DEMO_STUN_TINT, 0.08)
			stun.tween_interval(0.5)
			stun.tween_property(_demo_minion, "modulate", Color.WHITE, 0.15)
		&"slush":
			var slush := _demo_fx_tween()
			slush.tween_property(_demo_minion, "modulate", DEMO_FLASH, 0.06)
			slush.tween_property(_demo_minion, "modulate", DEMO_SLUSH_TINT, 0.1)
			slush.tween_interval(0.35)
			slush.tween_property(_demo_minion, "modulate", Color.WHITE, 0.15)
		_:
			var flash := _demo_fx_tween()
			flash.tween_property(_demo_minion, "modulate", DEMO_FLASH, 0.06)
			flash.tween_property(_demo_minion, "modulate", Color.WHITE, 0.12)
