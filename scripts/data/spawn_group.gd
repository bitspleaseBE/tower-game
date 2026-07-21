class_name SpawnGroup
extends Resource

@export var enemy: EnemyData
@export var count: int
@export var spawn_interval: float
@export var start_delay: float = 0.0
## Index into MapData.lanes / resolved_lanes(). 0 for single-path maps.
@export var lane: int = 0
