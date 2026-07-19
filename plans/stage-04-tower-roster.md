# Stage 4: Full Roster & Map 1 Campaign

**Status:** not started

Objective: after this stage, the live Pages build carries the complete combat vocabulary of blueprint v1.0. Tapping a pad opens a four-option candy grid — Popper (rapid), Lobber (splash), Chiller (slow), Longshot (sniper) — each with 3 linear tiers, distinct primitive silhouettes, and a per-type range ring; unaffordable options sit greyed and wiggle when tapped. Waves now mix all four critter archetypes — fast, swarm, armored (flat damage reduction), and a boss with an HP bar that caps the final wave with an entrance shake — and map 1 has grown from 6 to its full 14 handcrafted waves: beatable by an attentive first-timer in a 5–10 minute run where both tower choice and tier-3 upgrades visibly matter. Every new number is data in `.tres` files; every new interaction ships already juiced within `PerfBudget`; hidden 2×/4× fast-forward and free-build accelerators make this and all later tuning humane.

## Prerequisites

Stages 1–3 (`portrait-shell`, `core-loop`, `juice-engine`) must be merged and deployed. Verify each; if any check fails, stop and fix the earlier stage first.

- [ ] CI green on `main` and the live build plays map 1's 6 waves: `gh run list --branch main --limit 1`, then a quick run at https://bitspleasebe.github.io/tower-game/.
- [ ] Data schema complete: `grep -n 'enum Behavior' scripts/data/tower_data.gd` shows `SINGLE, SPLASH, SLOW, SNIPER`; `grep -n 'armor\|is_boss' scripts/data/enemy_data.gd` finds both fields.
- [ ] Stage 2 instances exist: `ls data/towers/popper.tres data/enemies/normal.tres data/enemies/fast.tres data/maps/map_01.tres`.
- [ ] Events bus registered: `grep 'Events=' project.godot`.
- [ ] **Upgrade/sell manage mode shipped** (Stage 2's documented cut line): `grep -n 'open_manage' scripts/ui/build_menu.gd`. If Stage 2 took the cut, Task 0 below is mandatory before anything else.
- [ ] Stage 3 outputs exist: `grep 'Juice=' project.godot`; `ls scripts/autoload/juice.gd scripts/perf_budget.gd scenes/ui/wave_banner.tscn`; `grep -n 'class_name PerfBudget' scripts/perf_budget.gd`.
- [ ] Locate and READ (do not assume APIs): `scripts/autoload/juice.gd` (helper names, pool acquire/release paths), `scripts/perf_budget.gd` (the caps this stage must respect), the pooling implementation (`grep -rin 'pool' scripts/ | head -30`), and the stress-harness/debug gate (`grep -rin 'debug\|stress' scripts/ | head -30` — Stage 3 shipped a hidden toggle, e.g. URL query param or hidden input). This stage extends those mechanisms; it never invents parallel ones.
- [ ] Godot availability: `godot --version` prints 4.7.x. If not installed in this sandbox, all headless verification falls back to the PR CI build — plan for that, don't skip verification.
- [ ] Work on a branch: `git checkout -b stage-04-tower-roster`.

## Tasks

Ordered so accelerators exist before the wave-authoring grind, and the risk cut-line is real: Tasks 0–8 are mandatory; if the session runs long, Task 9 may ship at the 12-wave minimum (not 14) and per-behavior impact FX may degrade to the shared kill-pop + a per-type tint — log any such cut in the PR description as a Stage 8 follow-up.

### 0. (Conditional) Finish upgrade/sell if Stage 2 cut it

- [ ] Only if the prerequisite grep found no manage mode: implement Stage 2's Task 11 manage mode exactly as its plan specifies (range ring, "Upgrade — N●" with MAX at tier 3, "Sell +N●" at `floor(0.7 × total spent)`) before touching anything below. This stage's BuildMenu work builds directly on it.

### 1. Schema extensions & mechanics constants (small, first)

- [ ] `scripts/data/tower_data.gd` — add behavior-parameter exports with safe defaults so `popper.tres` loads unchanged: `splash_radius_px: Array[float] = []` (size 3 when used; SPLASH only), `slow_factor: Array[float] = []` (speed multiplier while slowed, lower = stronger; SLOW only), `slow_duration: Array[float] = []` (seconds; SLOW only).
- [ ] `scripts/data/enemy_data.gd` — add `radius_px: float = 26.0` (hurtbox radius AND Skin size reference — archetype sizes are data, not code).
- [ ] `scripts/entities/enemy.gd` — replace Stage 2's armor floor `maxf(1.0, amount - data.armor)` with `maxf(ARMOR_MIN_DAMAGE_RATIO * amount, amount - data.armor)` where `const ARMOR_MIN_DAMAGE_RATIO := 0.25`. Rationale (document in a comment): a flat min of 1 made armor irrelevant to 1-damage rapid shots; a proportional floor makes armored critters genuinely punish spam towers while big single hits shrug armor off — the counter-play matrix of this stage depends on it. This ratio and the ones below are sanctioned mechanic constants, NOT balance data.

### 2. Enemy archetypes — data, status effects, boss support

- [ ] New `.tres` under `data/enemies/` (starter numbers — tune only by editing these files):
  | id | hp | speed | bounty | lives_cost | armor | radius_px | is_boss |
  |---|---|---|---|---|---|---|---|
  | `swarm` | 1 | 95 | 2 | 1 | 0 | 14 | false |
  | `armored` | 12 | 55 | 12 | 2 | 2 | 30 | false |
  | `boss` | 220 | 40 | 100 | 10 | 3 | 46 | true |
- [ ] `scripts/entities/enemy.gd` — slow-status pipeline: fields `_slow_factor := 1.0`, `_slow_time_left := 0.0`; movement becomes `progress += data.speed * _slow_factor * delta`; `apply_slow(factor: float, duration: float)` keeps the STRONGEST slow (`_slow_factor = minf(_slow_factor, factor)`) and refreshes `_slow_time_left = maxf(_slow_time_left, duration)` — never stack multiplicatively. Timer decays in `_process`; on expiry reset factor to 1.0.
- [ ] Single tint owner: `_update_tint()` sets `Skin.modulate` from status (normal = white, slowed = icy `#BFE3FF`-ish). Stage 3's hit flash must END on the enemy's current base tint, not hardcoded white — adapt `juice.gd`'s flash helper to restore to a passed/queried base color (see Implementation notes).
- [ ] Per-instance hurtbox sizing: in `setup()`, assign a fresh `CircleShape2D.new()` with `radius = data.radius_px` (the `.tscn`'s shape resource is shared across instances — same pitfall as Stage 2's tower range shapes).
- [ ] Skins keyed off `data.id` (primitives only, all inside `Skin`): `swarm` tiny pale-pink dot with single eye; `armored` octagonal body, grape `#9B8ACB`-ish with a darker thick rim reading as a candy shell; `boss` big deep-magenta blob wearing a 3-spike candy crown polygon. Reuse the Stage 2/3 blob construction helpers; sizes derive from `data.radius_px`.
- [ ] Boss HP bar: `HpBar` node (Node2D) added to `enemy.tscn` BESIDE `Skin` (never inside — it must survive the Stage 6 art swap and ignore squash tweens): a dark back ColorRect ~64×8 and a fill ColorRect the enemy script resizes to `hp/max_hp` on each `take_damage`; positioned at `y = -(data.radius_px + 22)`; `visible = data.is_boss` only.
- [ ] Pool-reset audit (the named risk of this stage): extend Stage 3's enemy acquire/reset path so a reused enemy ALWAYS restores: `hp`, `_slow_factor`/`_slow_time_left`, tint via `_update_tint()`, Skin scale/rotation (kill-punch leftovers), `progress = 0`, Hurtbox `monitorable`, HpBar visibility+fill, and the fresh hurtbox radius. Write the reset as one `reset_for(data: EnemyData)` function so Stage 5+ can't miss a field.

### 3. Projectile modes — homing, lob, and the splash resolve

- [ ] `scripts/entities/projectile.gd` — add `enum Mode { HOMING, LOB }`, keep ONE pooled scene:
  - `HOMING` (existing path, now also used by Longshot): unchanged, plus an overshoot guard — if `speed * delta >= distance_to_target` this frame, snap to the target and resolve the hit (at Longshot's ~1500 px/s a 60 Hz step is ~25 px, borderline against small hurtboxes; never rely on Area2D overlap alone at that speed).
  - `LOB` (Lobber): `launch_lob(dest: Vector2, damage: float, speed: float, splash_radius: float)`. Root travels start→dest linearly over `flight_time = clampf(distance / speed, 0.25, 0.6)`; the fake height is `Skin.position.y = -sin(t * PI) * 56.0` (arc lives on Skin only). CollisionShape2D is DISABLED in LOB mode (`set_deferred("disabled", true)`) — a mortar must not clip enemies en route; damage resolves only at detonation.
  - Splash resolve at arrival: iterate `get_tree().get_nodes_in_group("enemies")`, skip pool-inactive ones (use Stage 3's live-flag/group convention — read the pool code; never damage a parked pooled node), and `take_damage(damage)` every enemy with `global_position.distance_squared_to(dest) <= splash_radius * splash_radius`. Group iteration beats a physics query here: it is immune to the one-physics-frame staleness of overlap state and to pooled-node ghosts.
- [ ] Pool-reset audit for projectiles: mode, `Skin.position/scale/modulate`, collision disabled state, any trail/tween — one `reset()` function, called on acquire.

### 4. Tower behaviors — dispatch off `TowerData.behavior`

- [ ] `scripts/entities/tower.gd` — firing switches on behavior; targeting stays canonical first-in-range (highest `progress` among overlapping live enemies) for ALL types:
  - `SINGLE` and `SNIPER`: existing homing fire (SNIPER differs only in data — long `range_px`, big `damage`, slow `fire_interval`, `projectile_speed ≈ 1500` — plus its own FX/skin keyed off the enum).
  - `SPLASH`: on cooldown, lob at the current target's `global_position` (no lead — flight ≤ 0.6 s and the splash radius forgives drift), passing `splash_radius_px[tier]`.
  - `SLOW`: no projectile. On cooldown, if any enemy overlaps `RangeArea`: apply `apply_slow(slow_factor[tier], slow_duration[tier])` to EVERY overlapping live enemy, fire the frost-pulse FX (Task 7), and apply `damage[tier]` only if > 0 (starter data keeps it 0 — pure support identity).
- [ ] Per-type/tier Skins (primitives inside `Skin`, keyed off `TowerData.id` + tier exactly like Stage 2): **Popper** round base + short stubby barrel, pink/coral; **Lobber** squat wide dome + fat up-angled tube, sunny `#FFD66B`; **Chiller** hexagonal crystal with 3 small orbit dots, sky `#8DD0F0`; **Longshot** narrow tall base + one long thin barrel, lilac `#BFA0E8`. Tier N adds a contrasting stripe band per tier and ~+8% Skin scale — four silhouettes must be tellable apart at a glance in the iPhone SE viewport.
- [ ] `RangeRing` already reads `range_px[tier]` — confirm it renders correctly at Longshot radii (ring may exceed the screen; that's fine) and after upgrades of each type.

### 5. Tower data — three new `.tres` + Popper's final identity

- [ ] Retune `data/towers/popper.tres` into the committed rapid identity: damage `[1, 2, 3]`, fire_interval `[0.55, 0.45, 0.35]`, range `[180, 195, 210]`, cost stays `[50, 60, 90]`.
- [ ] New files under `data/towers/` (starter numbers; arrays are per-tier 1→3):
  | file | id / name | behavior | cost | damage | range_px | fire_interval | extras |
  |---|---|---|---|---|---|---|---|
  | `lobber.tres` | `lobber` "Lobber" | SPLASH | [70, 90, 130] | [2, 3.5, 5] | [170, 185, 200] | [1.5, 1.4, 1.2] | splash_radius_px [70, 85, 100] |
  | `chiller.tres` | `chiller` "Chiller" | SLOW | [60, 80, 110] | [0, 0, 0] | [150, 170, 190] | [1.0, 1.0, 1.0] | slow_factor [0.65, 0.55, 0.45], slow_duration [1.2, 1.5, 1.8] |
  | `longshot.tres` | `longshot` "Longshot" | SNIPER | [90, 120, 170] | [7, 12, 20] | [300, 340, 380] | [2.2, 2.0, 1.8] | projectile_speed 1500 |
- [ ] The intended counter matrix (verify it emerges in Task 9, tune data if not): armored punishes Popper (0.25 floor) and shrugs at nothing vs Longshot/Lobber; swarm clumps die to Lobber splash but drown slow-firing Longshot; fast leaks past sparse boards unless Chiller drags them back through the kill zone; boss is an HP wall that demands tier-3 damage plus Chiller uptime.

### 6. BuildMenu — four options, one thumb

- [ ] Validate the layout in DevTools (iPhone SE 375-wide preset) BEFORE wiring logic — this is the stage's flagged UX risk. Primary layout: the bottom sheet gains an `Options` HBoxContainer of 4 equal-width buttons (`size_flags_horizontal = EXPAND_FILL`, `custom_minimum_size = Vector2(0, 112)`, sheet side margins 12, separation 8 → ~168 px wide each at 720). Each button: two-line text `"Popper\n50●"` (Button renders `\n`; if alignment fights, fall back to a VBox of two `MOUSE_FILTER_IGNORE` Labels inside the button) plus an `Icon` slot — a 26 px fully-rounded Panel swatch in the tower's base color, the named Stage 6 swap point. If any name wraps or targets feel cramped, switch to a 2×2 GridContainer (~330×96 cells) and note the choice in the PR.
- [ ] Build the four options in code from an exported `towers: Array[TowerData]` preloading the four `.tres` — no tower names or costs typed into the scene.
- [ ] Select-then-confirm flow (new for 4 differently-priced, differently-ranged options; upgrade/sell manage mode stays EXACTLY as Stage 2 shipped it): first tap on an option selects it — button highlights (toggle_mode + ButtonGroup so the theme's pressed style is the highlight), the pad shows a `RangePreview` ring at that type's `range_px[0]`, and a small `HintLabel` in the sheet says "Tap again to build"; second tap on the SAME option buys (spend → instantiate → `Events.tower_built` → close, as Stage 2); tapping a different option switches the selection; tap-away closes sheet, clears selection and preview. `RangePreview` is one reusable `_draw()` Node2D under `Board` in `game.tscn` (translucent fill + outline, same look as `RangeRing`).
- [ ] Affordability: unaffordable options are greyed via `modulate` alpha ~0.55 (NOT `disabled = true` — disabled Buttons emit no signals, and greyed options must still respond: selecting for preview is allowed, CONFIRMING is blocked with the invalid-tap wiggle from Task 7). Re-evaluate greying on every `Events.coins_changed` — and give an option that just became affordable a tiny 1.0→1.06→1.0 pop.

### 7. Juice for every new beat (through `Juice`, within `PerfBudget`)

All effects go through `scripts/autoload/juice.gd` helpers and its pools — extend the autoload with any missing helper rather than inlining tweens; everything targets `Skin` transforms or dedicated FX nodes; every particle burst respects the Stage 3 caps (gracefully skipped when the pool is dry, never queued).

- [ ] Upgrade: sparkle burst (pooled particles, small count) + tower Skin scale punch + one-shot ring flash at the new range.
- [ ] Sell: 4–5 pooled coin fliers arcing to the HUD coin label (reuse Stage 3's coin-fly) + a soft dust puff + pad Skin deflate-squash.
- [ ] Per-behavior fire/impact FX: **Popper** existing recoil + small impact pop; **Lobber** Skin recoil-thump on fire, arcing projectile (Task 3), detonation = expanding ring (tween-scaled primitive, no particle cost) + a modest confetti puff; **Chiller** frost pulse = expanding icy ring from the tower + brief icy tint on affected enemies (the `_update_tint()` pipeline); **Longshot** muzzle flash + near-instant tracer read (stretched Skin on the fast projectile) + a single heavy impact pop with a stronger scale punch on the victim.
- [ ] Boss entrance: when a `is_boss` enemy spawns — screen micro-shake (Stage 3's shake, stronger preset but inside its cap), boss Skin stomp-in (scale 1.4→1.0 TRANS_BACK), HP bar slides in. If `wave_banner`'s API accepts custom text, the boss wave banner reads "BOSS!" — one-line change at most, skip if the API resists.
- [ ] Invalid-tap wiggle: confirming an unaffordable option wiggles that button horizontally (x ±6, ~3 oscillations, 0.2 s, tween on the button, pivot centered) and pulses the HUD coin label.
- [ ] BuildMenu options pop in staggered (~0.05 s apart) when the sheet opens, reusing Stage 3's button-squish/pop helpers.

### 8. Debug accelerators + roster stress (before wave tuning)

Extend Stage 3's existing debug gate and overlay — same activation mechanism (query param / hidden input), nothing visible or reachable in a normal run.

- [ ] Fast-forward: a debug-overlay button cycling `×1 → ×2 → ×4` (and desktop key, e.g. `F`) setting `Engine.time_scale`. It scales tweens, `SceneTreeTimer`s, and physics coherently — the whole game speeds up, which is the point. MUST reset to 1.0 in `game.gd._exit_tree()` AND when `ResultOverlay` shows: `Engine.time_scale` is global and survives scene changes; a leaked 4× would haunt the main menu.
- [ ] Free-build: overlay toggle (+ key `G`) setting `game.free_build: bool`; `spend()` returns `true` without deducting when set; BuildMenu treats everything affordable while it's on. Sell/earn still work normally.
- [ ] Extend the stress harness with a "full roster" preset: free-builds all four towers at tier 3 across the pads, then spawns a continuous mixed stream (swarm-heavy + armored + fast + 1 boss) — worst case now includes splash detonations, frost pulses, boss HP bar, and confetti simultaneously. Verify the Stage 3 FPS overlay holds the measured floor and no `PerfBudget` cap is exceeded (Juice should be skipping, not dying).
- [ ] Optional, only if trivial after the above: a debug "skip wave" button that force-clears the current wave (despawn live enemies without bounty, jump to countdown). Skip it without guilt if the spawner state machine resists — free-build + ×4 already makes a full run ~2 minutes.

### 9. Map 1 full campaign — waves 7–14 + first real balance pass

- [ ] Extend `data/maps/map_01.tres` to **14 waves** (inside the 12–15 band; 12 is the documented cut-line minimum). Keep waves 1–4 as shipped; waves 5+ below are starter values (groups listed as count × id @ spawn_interval, `d` = start_delay; approximate bounty total per wave in parentheses — the teaching arc is: fast rush → swarm → armor → combinations → boss):
  | # | groups | (coins) |
  |---|---|---|
  | 5 | 12× fast @0.7 | (72) |
  | 6 | 20× swarm @0.4 + 6× normal @1.0 d2 | (70) |
  | 7 | 24× swarm @0.35 + 8× fast @0.7 d3 | (96) |
  | 8 | 4× armored @2.5 + 8× normal @0.8 d2 | (88) |
  | 9 | 30× swarm @0.3 + 6× fast @0.6 d4 | (96) |
  | 10 | 6× armored @2.0 + 16× swarm @0.35 d3 | (104) |
  | 11 | 10× fast @0.5 + 10× fast @0.5 d6 | (120) |
  | 12 | 8× armored @1.6 + 20× swarm @0.3 d2 | (136) |
  | 13 | 10× armored @1.4 + 10× fast @0.5 d5 | (180) |
  | 14 | 1× boss + 24× swarm @0.4 d3 + 8× fast @0.6 d8 | (196) |
- [ ] Balance method (timeboxed — target "beatable and interesting", NOT final balance, which is Stage 8's): total run economy ≈ 100 start + ~1550 bounty; one-of-each maxed board costs 1120, so full tier-3s arrive only late and choices bite early — keep that shape. Play at ×2/×4: (a) a sensible mixed board built without foreknowledge wins with 5+ lives spare; (b) a deliberate popper-only board starts leaking hard at wave 8 (armor) and a longshot-only board at 9 (swarm) — type choice matters; (c) at least one tier-3 upgrade is clearly worth its cost by wave 10; (d) a real-time 1× run lands in 5–10 minutes. Tune ONLY `.tres` numbers; three full tuning passes maximum, then stop and log residual wonk in the PR for Stage 8.
- [ ] Confirm the HUD wave counter, `wave_started(number, total)` and the win-after-last-wave logic all follow `waves.size()` automatically (they must — no hardcoded 6 anywhere; grep for it).

### 10. Verify, commit, PR

- [ ] Run the Verification section below end-to-end.
- [ ] `git add -A`; confirm every new/changed `*.uid` is staged (`git status --short | grep uid`).
- [ ] Commit with a descriptive message (e.g. "Stage 4: full roster — 4 tower behaviors x 3 tiers, swarm/armored/boss archetypes, 14-wave map 1, debug accelerators"), push, open a PR to `main` noting any taken cut lines, and confirm the CI web-export build is green before merge. After merge, play-check the live Pages build on a phone.

## Implementation notes

- **`Engine.time_scale` is process-global**: it survives `change_scene_to_file()` and `reload_current_scene()`. Reset it in `game.gd._exit_tree()` and when the ResultOverlay appears. Note `get_tree().paused` and `time_scale` are independent — the pause overlay works the same at ×4. Default `SceneTreeTimer`s honor time_scale (`ignore_time_scale` defaults false), so countdowns and spawn intervals accelerate for free.
- **Pooled-node hygiene is THE risk here**: status timers (`_slow_time_left`), tint, Skin scale left by kill punches, HP-bar fill, disabled collision shapes, projectile mode — any of these leaking through a pool reuse produces baffling bugs (a "pre-slowed" swarm critter, an invisible mortar shell). Funnel every reset through one `reset_for(...)`/`reset()` function per pooled scene and extend Stage 3's acquire path to call it. When iterating group `"enemies"` (splash resolve), always skip pool-parked nodes using Stage 3's live-flag convention.
- **Hit flash vs slow tint**: if Stage 3's flash helper tweens `Skin.modulate` white→hardcoded `Color.WHITE`, a slowed enemy flickers out of its icy tint. Change the helper to restore to an end color (parameter or a `get_base_tint()` on the owner). One owner for base tint: `enemy._update_tint()`.
- **Shared shape resources (again)**: `CircleShape2D` in `enemy.tscn` is shared across all instances; per-archetype radii require `CircleShape2D.new()` in `setup()` (or `resource_local_to_scene = true`). Same lesson as Stage 2's tower range shapes.
- **Splash via group iteration, not physics query**: `PhysicsDirectSpaceState2D.intersect_shape` reflects last physics tick and returns pooled ghosts unless collision is meticulously toggled; a distance check over live group members is exact, allocation-free at our scale (≤ ~40 alive × ~1 detonation/s), and obviously correct. Use `distance_squared_to`.
- **Fast projectiles tunnel**: 1500 px/s ≈ 25 px per 60 Hz physics frame — comparable to hurtbox radii. The HOMING overshoot guard (snap-hit when this frame's step reaches the target) is mandatory, not optional.
- **LOB collision off**: detonation-only damage; leave the Area2D monitoring machinery untouched but keep the shape disabled while in LOB mode, and re-enable on pool reset for HOMING reuse (use `set_deferred` — flipping shapes mid-physics-callback errors).
- **Greyed ≠ disabled**: `disabled = true` Buttons swallow taps silently — the invalid-tap wiggle and select-to-preview both need live signals. Grey via modulate; gate the confirm in code.
- **Multiline Button text**: `"Name\n50●"` renders fine in Godot 4; set `alignment` center. If the two-line look fights the theme's content margins, use inner Labels with `mouse_filter = MOUSE_FILTER_IGNORE` so taps still reach the Button.
- **One-thumb discipline unchanged**: pad taps stay centrally hit-tested in `game.gd._unhandled_input` (emulated-mouse-only path from Stage 2 — do not add `InputEventScreenTouch` handling anywhere, including the new debug overlay buttons, which are ordinary Buttons and fine). Test tap-away with a selection active: one tap must clear preview + close sheet, not require two.
- **Chiller pulse cadence**: pulse every `fire_interval` (1.0 s) applying a ≥1.2 s slow gives seamless perma-slow inside the ring while letting escapees recover — intended. Do not implement a per-frame aura; the pulse reuses the standard cooldown machinery and reads as a "shot" for juice/SFX hooks.
- **Boss HP bar is not UI-layer**: it's a world-space Node2D following the enemy, ColorRect-based (cheap, no `_draw()` script needed), beside `Skin` so squash/wobble never distorts it and Stage 6's art swap ignores it. Resize the fill only inside `take_damage` — never per-frame.
- **FX budget accounting**: expanding rings (splash detonation, frost pulse, upgrade ring) are single tween-scaled primitives — they cost nothing from the particle budget; confetti/sparkle/coin-shower draw from Stage 3's pools which enforce `PerfBudget`. Never instantiate a particles node ad hoc; Stage 3's CPU/GPU particle decision is final — reuse whatever it shipped.
- **Zero balance in code**: new sanctioned constants are ONLY `ARMOR_MIN_DAMAGE_RATIO` (0.25), the LOB arc height (56 px) and flight-time clamp (0.25–0.6 s), tween durations/scales, and debug key bindings. Every hp/damage/cost/speed/radius/slow number lives in `.tres`. If you type one into a `.gd`, stop and move it.
- **Hand-authoring the new `.tres`**: same drill as Stage 2 (typed arrays as `Array[float]([...])`, sub_resources for waves/groups, omit `uid` attrs and commit what import rewrites). With 14 waves `map_01.tres` gets long — keep sub_resource ids mnemonic (`wave7_swarm`, `w14_boss`) and verify with `godot --headless --import` BEFORE playtesting; a typo'd resource fails at load, not at edit.

## Juice checklist

Every new mechanic this stage ships lands already juiced (through `Juice`, inside `PerfBudget`):

- [ ] Upgrade sparkle burst + tower scale punch + range-ring flash.
- [ ] Sell coin shower arcing to the HUD + pad deflate puff.
- [ ] Lobber: recoil thump, arcing shell (fake-height Skin arc), detonation ring + confetti puff.
- [ ] Chiller: expanding frost ring each pulse; slowed critters visibly icy-tinted until recovery.
- [ ] Longshot: muzzle flash + tracer read + heavy single-impact punch on the victim.
- [ ] Boss entrance: screen shake + stomp-in scale + HP bar slide-in (banner "BOSS!" if the Stage 3 API allows).
- [ ] Invalid-tap wiggle on unaffordable build options + HUD coin-label pulse.
- [ ] BuildMenu options staggered pop-in; newly-affordable option gives a small "now you can" pop.
- [ ] Distinct per-type tower silhouettes/colors and per-archetype critter bodies — readability is feel too.

## Acceptance criteria

- [ ] Tapping an empty pad shows four options with live costs; options grey/un-grey as coins change; first tap previews (highlight + correct per-type range ring at the pad), second tap on the same option buys; tapping a greyed option's confirm wiggles it and buys nothing; tap-away clears selection and closes. All strictly one-thumb in a phone viewport.
- [ ] All four tower types build, upgrade to tier 3, and sell at `floor(0.7 × total spent)`; each type/tier has a visibly distinct silhouette; range rings match `range_px[tier]` per type.
- [ ] Popper fires rapidly at single targets; Lobber shells arc and damage every enemy inside the splash radius on detonation (visibly killing swarm clumps); Chiller pulses slow all critters in range — they tint icy, move slower, recover after the duration; Longshot hits across most of the board for big single hits.
- [ ] Armor works per the 0.25-floor formula: a popper-only board demonstrably struggles against `armored` while Longshot three-shots them; all four `.tres` archetypes appear across the campaign with correct speeds/sizes/bounties; leaks cost 1/1/1/2/10 lives by archetype.
- [ ] Wave 14 ends with the boss: entrance shake fires, the HP bar tracks damage and empties at death, and a boss leak costs 10 lives.
- [ ] Map 1 runs 14 waves; the HUD counter shows `n/14` throughout; winning wave 14 with lives > 0 shows the win overlay; a 1× run lands in 5–10 minutes and an attentive first-timer mixed board wins.
- [ ] Debug gate: fast-forward cycles ×1/×2/×4 and free-build toggles, both ONLY in debug mode with nothing visible in a normal run; `Engine.time_scale` is 1.0 again after Retry, Menu, and win/lose.
- [ ] Roster stress preset holds Stage 3's measured FPS floor with all four tier-3 types firing into a mixed boss+swarm stream, and no `PerfBudget` cap is exceeded (effects skip gracefully).
- [ ] Diff audit: no hp/damage/cost/speed/radius/slow numbers in `.gd` files beyond the sanctioned constants; all tuning happened in `data/**/*.tres`.
- [ ] Every new/changed scene and script has its `*.uid` committed.

## Verification

1. Local headless (skip to step 4 if `godot` is unavailable — CI is the authoritative gate):
   ```sh
   godot --headless --import          # zero script errors, zero .tres parse errors (14-wave map included)
   godot --headless --export-release "Web" build/web/index.html
   python3 -m http.server 8080 -d build/web
   ```
2. Chrome http://localhost:8080, DevTools device toolbar, touch emulation ON, iPhone SE then Pixel 7 portrait. Playthroughs: (a) full 1× winning run with at least one of each tower type and one tier-3, timing it (5–10 min); (b) accelerated ×4 free-build run exercising every acceptance criterion — sell each type once, wiggle an unaffordable option, watch the boss bar, count leak costs against lives; (c) deliberate popper-only run to confirm wave 8 punishes it.
3. Stress check: enable the debug gate, run the full-roster preset ≥ 60 s with the FPS overlay visible; confirm the Stage 3 floor holds and effect counts cap out gracefully. Also sanity-play with Chrome's 4× CPU throttle: no sustained drops below the Stage 3 floor, no per-frame console errors — that is what "smooth" means for this stage.
4. Push the branch, open the PR; the `deploy.yml` PR web-export build must go green.
5. After merge, on a real phone at https://bitspleasebe.github.io/tower-game/: one full one-thumb campaign run; confirm the four-option sheet is comfortably tappable with a right thumb and the boss finale feels like a finale.

## Out of scope

- Maps 2–3, `scenes/map_select.tscn`, unlock progression, endless mode, `SaveGame` autoload / `user://save.cfg`, ResultOverlay's Next Map/Endless buttons — **Stage 5**.
- Kenney sprites, icons, theme nine-patches, any `assets/` or `inspiration/` changes — **Stage 6**. All SFX/music — **Stage 7**.
- Final balance polish, difficulty-curve tuning beyond "beatable and interesting", performance tightening, copy pass, low-lives heart pulses and remaining idle juice — **Stage 8**.
- Revisiting Stage 3 decisions: particle strategy, pool architecture, `PerfBudget` numbers (this stage may propose a cap change in the PR if measurements demand it, never silently edit).
- Do not modify `export_presets.cfg`, renderer settings, `deploy.yml`, or the 720×1280 display contract.

## Handoff

After this stage, later stages may rely on:

- **The complete v1.0 combat roster as pure data**: `data/towers/{popper,lobber,chiller,longshot}.tres` (4 behaviors × 3 tiers) and `data/enemies/{normal,fast,swarm,armored,boss}.tres` — Stage 5 authors maps 2–3 and Stage 8 rebalances by editing/referencing `.tres` only; no new behavior code needed for v1.0.
- **Behavior engine**: `tower.gd` dispatch over the full `Behavior` enum; `projectile.gd` HOMING/LOB modes with pooled resets; enemy status pipeline (`apply_slow`, `_update_tint`, per-instance sized hurtboxes, `reset_for()` pool contract); armor formula with `ARMOR_MIN_DAMAGE_RATIO = 0.25`; boss support (`is_boss` → HP bar + entrance FX).
- **Four-option BuildMenu pattern**: data-driven option grid, select-then-confirm one-thumb flow, `RangePreview` node, greyed-but-interactive affordability — MapSelect (Stage 5) and any future option grids copy this pattern.
- **`data/maps/map_01.tres` complete at 14 waves** — the authoring template (teaching arc, group mixing, per-wave coin totals) for Stage 5's maps 2–3.
- **Debug accelerators behind Stage 3's gate**: ×1/×2/×4 fast-forward (time_scale, self-resetting on run end), free-build toggle, full-roster stress preset — the tuning workflow Stages 5 and 8 are built on.
- **Juice coverage**: every roster interaction (build/upgrade/sell, all four fire/impact styles, boss entrance, invalid tap) already wired through `Juice` within `PerfBudget` — Stage 6 only reskins `Skin` nodes; Stage 7 hooks SFX onto the same events/moments.
