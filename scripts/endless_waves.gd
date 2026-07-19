class_name EndlessWaves
extends RefCounted
## Deterministic endless wave generator. No RNG — same map + wave → same gauntlet.

## Fairness/perf guards (NOT balance — growth lives on MapData .tres).
const TEMPLATE_TAIL := 5
const SPEED_MULT_CAP := 1.5
const INTERVAL_FLOOR := 0.25


static func wave_cap() -> int:
	return PerfBudget.MAX_ENEMIES / 2


static func generate(map: MapData, wave_number: int) -> WaveData:
	var scripted := map.waves.size()
	var k := wave_number - scripted
	assert(k >= 1)
	var tail := mini(TEMPLATE_TAIL, scripted)
	var template: WaveData = map.waves[scripted - tail + ((k - 1) % tail)]
	var hp_mult := pow(map.endless_hp_growth, float(k))
	var count_mult := pow(map.endless_count_growth, float(k))
	var speed_mult := minf(pow(map.endless_speed_growth, float(k)), SPEED_MULT_CAP)

	var out := WaveData.new()
	var groups: Array[SpawnGroup] = []
	var total_count := 0
	for tg: SpawnGroup in template.spawn_groups:
		var g := SpawnGroup.new()
		var enemy: EnemyData = tg.enemy.duplicate() as EnemyData
		enemy.hp *= hp_mult
		enemy.speed *= speed_mult
		g.enemy = enemy
		g.count = maxi(1, int(ceili(float(tg.count) * count_mult)))
		g.spawn_interval = maxf(tg.spawn_interval, INTERVAL_FLOOR)
		g.start_delay = tg.start_delay
		groups.append(g)
		total_count += g.count

	var cap := wave_cap()
	if total_count > cap and total_count > 0:
		var scale := float(cap) / float(total_count)
		for g: SpawnGroup in groups:
			g.count = maxi(1, int(floor(float(g.count) * scale)))

	out.spawn_groups = groups
	return out
