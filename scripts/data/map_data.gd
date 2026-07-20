class_name MapData
extends Resource

@export var id: StringName
@export var display_name: String
@export var path_points: PackedVector2Array
@export var pad_positions: PackedVector2Array
@export var starting_coins: int
@export var starting_lives: int
@export var waves: Array[WaveData]
@export var endless_hp_growth: float = 1.15
@export var endless_count_growth: float = 1.1
@export var endless_speed_growth: float = 1.03
## Max coins for calling the next wave at the first moment the button appears.
@export var early_wave_bonus_max: int = 12
