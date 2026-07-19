extends Node
## Canonical gameplay signal bus. Register after Settings in project.godot.

signal coins_changed(coins: int)
signal lives_changed(lives: int)
signal wave_started(number: int, total: int)
signal wave_cleared(number: int)
signal enemy_killed(enemy: Node, bounty: int)
signal enemy_leaked(enemy: Node)
signal tower_built(tower: Node, pad: Node)
signal tower_upgraded(tower: Node)
signal tower_sold(pad: Node, refund: int)
signal run_won(map_id: StringName)
signal run_lost(map_id: StringName)

signal endless_best(map_id: StringName, wave: int)
