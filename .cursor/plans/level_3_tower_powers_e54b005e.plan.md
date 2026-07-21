---
name: Level 3 tower powers
overview: Give every tower a special power at level 3 (tier index 2), announce each power with a first-time tip card, upgrade the "new tower" tip cards with an animated shooting demo, and recolor the upgrade button when the next upgrade unlocks the power.
todos:
  - id: pierce
    content: "Candy Cane tier 2: add PIERCE projectile mode and fire it from tower.gd"
    status: completed
  - id: explode
    content: "Lollipop tier 2: splash-on-impact via splash_radius_px on homing projectile"
    status: completed
  - id: slush-damage
    content: "Slushie tier 2: pass damage through stream droplets (last droplet deals it)"
    status: completed
  - id: stun
    content: "Ballooner tier 2: splash stuns enemies briefly via apply_slow"
    status: completed
  - id: tier3-tips
    content: One-time tier-3 explainer tip per tower via Events.tower_upgraded + SaveGame
    status: completed
  - id: tip-demo
    content: "Animated tip-card demo: tower shoots right at swarm minion; wire into new-tower and tier-3 tips"
    status: completed
  - id: button-color
    content: ButtonPower theme variation on upgrade button when next upgrade reaches level 3
    status: completed
isProject: false
---

# Level 3 Tower Super Powers

Level 3 = `tier == 2` (arrays in `TowerData` are indexed 0/1/2). All four towers get a power, announced via the existing tip-card system, with an animated demo and a distinct upgrade-button color.

## 1. The four level-3 powers

### Candy Cane (`longshot`) — Piercing shot
- At tier 2, `_fire` in [scripts/entities/tower.gd](scripts/entities/tower.gd) fires a new pierce projectile instead of `_fire_homing(..., true)`: a straight-line laser aimed at the target that keeps flying after impact.
- Add a `PIERCE` behavior to [scripts/entities/projectile.gd](scripts/entities/projectile.gd): travels in a fixed direction, damages each enemy once (track hit enemies in a dictionary), deactivates after ~1.3× tower range.

### Lollipop (`popper`) — Explodes on impact
- Add `splash_radius_px = [0, 0, 55]` to [data/towers/popper.tres](data/towers/popper.tres).
- Extend `Projectile.launch(...)` with an optional `splash_radius` param; in `_resolve_homing_hit`, when radius > 0, also damage all enemies within the radius around the hit point (reuse the loop from `_detonate_splash`) and play the splash pop juice.

### Slushie (`chiller`) — Slush also damages
- Change `damage` to `[0, 0, 1]` in [data/towers/chiller.tres](data/towers/chiller.tres).
- Pass `data.damage[tier]` through `_fire_water_stream` → `launch_stream` and apply it in `_resolve_stream_impact` via `enemy.take_damage()`. Each of the 4 droplets per pulse deals it, so tune low (0.25 per droplet or 1 on the last droplet only — I'll do damage on the last droplet only to keep it predictable).

### Ballooner (`lobber`) — Splash stuns
- In `_detonate_splash`, when a new `stun_duration` param > 0, also call `enemy.apply_slow(0.05, stun_duration)` on every enemy hit — reuses the existing slow system (near-zero factor = frozen briefly). Tower passes ~0.6s at tier 2, 0 otherwise.
- Add `stun_duration: Array[float] = [0, 0, 0.6]` to [scripts/data/tower_data.gd](scripts/data/tower_data.gd) + [data/towers/lobber.tres](data/towers/lobber.tres).

## 2. First-time level-3 explainer tips
- In [scripts/ui/coach_controller.gd](scripts/ui/coach_controller.gd), connect to `Events.tower_upgraded`; when `tower.tier == 2` and `not SaveGame.has_seen_tip("tier3_" + id)`, enqueue a tip card (existing queue handles pause + `mark_tip_seen` on "Got it").
- Copy per tower, e.g.:
  - Lollipop: "Super Lollipop! — Now pops in a sugary blast, hitting nearby critters too."
  - Ballooner: "Super Ballooner! — Splashes now stun critters in place for a moment."
  - Slushie: "Super Slushie! — Slush now hurts! Slowed critters take damage too."
  - Candy Cane: "Super Candy Cane! — Shots pierce through, hitting every critter in a line."

## 3. Animated demo in tip cards
- Add a `TipDemo` control to [scenes/ui/tip_card.tscn](scenes/ui/tip_card.tscn) next to/instead of the static `%TipArt`: tower weapon sprite on the left facing right, the swarm minion sprite (lowest rank, `assets` skin used by `enemy.gd` for `swarm`) on the right, and a looping tween that flies a small projectile sprite from tower to minion with a squash "pop" on the minion. Everything uses `process_mode = ALWAYS` since the tip card pauses the tree.
- `show_tip` gets an optional demo config (tower id); the coach passes it for the two "New: …" tower tips (`tower_chiller`, `tower_longshot`) and for the new tier-3 tips (where the demo can reflect the power: e.g. pierce shows the shot continuing past the minion, lollipop shows a burst ring). Static art path stays for non-tower tips.

## 4. Upgrade button color for the level-3 upgrade
- Add a `ButtonPower` theme type variation in [theme/candy_theme.tres](theme/candy_theme.tres) (e.g. golden/purple candy style, clearly distinct from the pink default).
- In `_refresh_manage_buttons` in [scripts/ui/build_menu.gd](scripts/ui/build_menu.gd): when `tower.tier == 1` (next upgrade hits level 3), set `primary_button.theme_type_variation = &"ButtonPower"` and text like "Upgrade — %d ★"; reset the variation to default otherwise.

## Verification
- Run the game, upgrade each tower to level 3 on a wave and confirm each power, the one-time tip, and the button color; delete `tip_tier3_*` keys from `user://save.cfg` between checks as needed.
