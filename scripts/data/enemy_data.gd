class_name EnemyData
extends Resource

@export var id: StringName
@export var display_name: String = ""
@export var hp: float
@export var speed: float ## px/s along path
@export var bounty: int
@export var lives_cost: int
@export var armor: float = 0.0
@export var radius_px: float = 26.0 ## hurtbox radius AND Skin size reference
@export var is_boss: bool = false
