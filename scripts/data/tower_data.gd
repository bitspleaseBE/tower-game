class_name TowerData
extends Resource

enum Behavior { SINGLE, SPLASH, SLOW, SNIPER }

@export var id: StringName
@export var display_name: String
@export var cost: Array[int] ## size 3: build, tier-2, tier-3
@export var damage: Array[float]
@export var range_px: Array[float]
@export var fire_interval: Array[float]
@export var behavior: Behavior = Behavior.SINGLE
@export var sell_refund_ratio: float = 0.7
@export var projectile_speed: float = 360.0
@export var splash_radius_px: Array[float] = [] ## size 3 when used; SPLASH lob + SINGLE popper burst
@export var slow_factor: Array[float] = [] ## speed multiplier while slowed; SLOW only
@export var slow_duration: Array[float] = [] ## seconds; SLOW only
@export var stun_duration: Array[float] = [] ## seconds of near-freeze on splash hit; SPLASH only
