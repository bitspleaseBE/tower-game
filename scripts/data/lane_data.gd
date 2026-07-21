class_name LaneData
extends Resource
## One enemy path on a map. Multiple lanes share a stem when their later points match.

@export var points: PackedVector2Array
## If > 0, phase 1 uses only the first N points (ending at the phase-1 base).
## After expansion, the full `points` array is used.
@export var phase1_point_count: int = 0
## Wave number when this lane becomes active (1 = from the start).
@export var unlock_wave: int = 1
## Candy label for spawn warnings, e.g. "Strawberry Ridge".
@export var label: String = ""
