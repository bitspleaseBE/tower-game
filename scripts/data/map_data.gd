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
## Multiplier applied to enemy bounty payouts on this map (1.0 = full).
@export var bounty_scale: float = 1.0
## Max coins for calling the next wave at the first moment the button appears.
@export var early_wave_bonus_max: int = 18
## Candy river band center (board space). Zero hides the river.
## Prefer full-board width with a thin Y so the creek reads continuous; pads stay off the water.
@export var river_position: Vector2 = Vector2.ZERO
@export var river_scale: Vector2 = Vector2(0.95, 0.4)
## Bridge center — transparent wafer deck over the river; path draws on top.
@export var bridge_position: Vector2 = Vector2.ZERO
@export var bridge_scale: Vector2 = Vector2(0.58, 0.58)
@export var bridge_rotation: float = 0.0
## Decorative desserts / ornaments for this map (kinds: cupcake, sundae,
## donut, macaron, softserve, cookie). Keep sparse — a couple per map.
@export var ornaments: Array[MapOrnament] = []
## Multi-lane maps. Empty → legacy single lane from `path_points`.
@export var lanes: Array[LaneData] = []
## Wave after which the board expands (0 = no expansion). Fires when that wave is fully clear.
@export var expansion_wave: int = 0
## Board Y offset applied after expansion (positive = pan down / content moves up).
@export var expansion_pan: float = 0.0
## Parallel to `pad_positions`. Empty → all pads available from wave 1.
## Value is the first wave number the pad may appear (1 = start).
@export var pad_unlock_waves: PackedInt32Array = PackedInt32Array()


## Resolved lane list: authored `lanes`, or a synthetic lane from `path_points`.
func resolved_lanes() -> Array[LaneData]:
	if not lanes.is_empty():
		return lanes
	var legacy := LaneData.new()
	legacy.points = path_points
	legacy.unlock_wave = 1
	legacy.label = ""
	return [legacy] as Array[LaneData]


func pad_unlock_wave(index: int) -> int:
	if index < 0 or index >= pad_unlock_waves.size():
		return 1
	return maxi(1, pad_unlock_waves[index])
