# Stage 2: Data-Driven Core Loop on Map 1

**Status:** not started

Objective: after this stage, a stranger on a phone can open the live Pages build, tap New Game, and play map 1's short run start-to-finish with one thumb — a 7 s countdown ticks on the HUD, waves of critters march the path, tapping a pad opens a bottom-sheet BuildMenu to build the one tower type (3 upgrade tiers, 70% sell refund), towers auto-shoot visible projectiles, kills pop for coins with floating "+N" text, leaks cost lives, and the run ends in a win overlay after wave 6 or a lose overlay at 0 lives, both offering Retry / Menu. Every balance number lives in `.tres` resources under `data/` from day one; gameplay scripts contain zero hardcoded stats.

## Prerequisites

Stage 1 ("Portrait Shell & Board Skeleton", slug `portrait-shell`) must be merged and deployed. Verify each before starting; if any check fails, stop and fix Stage 1 first.

- [ ] Portrait viewport: `grep -A8 '\[display\]' project.godot` shows `viewport_width=720`, `viewport_height=1280`, stretch `canvas_items`/`expand`, and `window/handheld/orientation=1`.
- [ ] Candy theme exists: `ls theme/candy_theme.tres`.
- [ ] Board skeleton exists: `grep -E 'Path2D|Line2D' scenes/game.tscn` finds the hand-placed route, and the scene has top status strip + bottom thumb-zone HUD zones (open the file and read the node tree before rebuilding it).
- [ ] `Settings` autoload registered: `grep 'Settings=' project.godot`.
- [ ] CI is green on `main` and https://bitspleasebe.github.io/tower-game/ renders portrait (`gh run list --branch main --limit 1`).
- [ ] Godot availability: `godot --version` prints 4.7.x. If Godot is not installed in this sandbox, all headless verification falls back to the PR CI build — plan for that, don't skip verification.
- [ ] Work on a branch: `git checkout -b stage-02-core-loop`.

## Tasks

Ordered so the risk cut-line is real: tasks 1–10 make a playable build-only game; task 11's manage mode (upgrade/sell) is the documented cut if the session runs long — ship build-only and log upgrade/sell as a Stage 4 follow-up in the PR description.

### 1. Data schema (`scripts/data/`) — do this FIRST

- [ ] `scripts/data/tower_data.gd` — `class_name TowerData extends Resource`. Exports: `id: StringName`, `display_name: String`, `cost: Array[int]` (size 3: build cost, tier-2 upgrade cost, tier-3 upgrade cost), `damage: Array[float]`, `range_px: Array[float]`, `fire_interval: Array[float]` (all size 3, indexed by tier 0–2), `behavior: Behavior` (`enum Behavior { SINGLE, SPLASH, SLOW, SNIPER }`), `sell_refund_ratio: float = 0.7`, `projectile_speed: float = 520.0`. Only `SINGLE` is implemented this stage, but the enum ships complete so Stage 4 adds no schema churn.
- [ ] `scripts/data/enemy_data.gd` — `class_name EnemyData extends Resource`. Exports: `id: StringName`, `hp: float`, `speed: float` (px/s along path), `bounty: int`, `lives_cost: int`, `armor: float = 0.0` (flat damage reduction), `is_boss: bool = false`.
- [ ] `scripts/data/spawn_group.gd` — `class_name SpawnGroup extends Resource`. Exports: `enemy: EnemyData`, `count: int`, `spawn_interval: float`, `start_delay: float = 0.0`.
- [ ] `scripts/data/wave_data.gd` — `class_name WaveData extends Resource`. Export: `spawn_groups: Array[SpawnGroup]`.
- [ ] `scripts/data/map_data.gd` — `class_name MapData extends Resource`. Exports: `id: StringName` (`"map_01"`), `display_name: String`, `path_points: PackedVector2Array`, `pad_positions: PackedVector2Array`, `starting_coins: int`, `starting_lives: int`, `waves: Array[WaveData]`, `endless_hp_growth: float = 1.15`, `endless_count_growth: float = 1.1`, `endless_speed_growth: float = 1.03`. Endless params are unused until Stage 5 but belong to the schema now.
- [ ] Sanity-review the schema against Stage 4 (all four `Behavior` values expressible? armor/boss fields present?) and Stage 5 (endless growth params present?) before writing any gameplay code — getting this wrong ripples through every later stage.

### 2. Data instances (`data/`)

Starter numbers below are deliberate first guesses — tune freely, but ONLY by editing `.tres` files.

- [ ] `data/enemies/normal.tres` — id `normal`, hp 3, speed 70, bounty 5, lives_cost 1, armor 0.
- [ ] `data/enemies/fast.tres` — id `fast`, hp 2, speed 120, bounty 6, lives_cost 1, armor 0.
- [ ] `data/towers/popper.tres` — id `popper`, display_name "Popper", behavior SINGLE, cost [50, 60, 90], damage [1, 2, 4], range_px [180, 200, 230], fire_interval [0.8, 0.7, 0.55], sell_refund_ratio 0.7. (This becomes Stage 4's rapid single-target identity.)
- [ ] `data/maps/map_01.tres` — id `map_01`, display_name "Meadow Munch", starting_coins 100, starting_lives 20. `path_points`: a portrait S-route through the board band (y ≈ 160–1040; HUD strips own the rest), entering off-screen left and exiting off-screen right, e.g. `(-40, 280), (560, 280), (560, 540), (160, 540), (160, 820), (560, 820), (560, 1000), (760, 1000)`. If Stage 1's hand-placed route differs meaningfully, copy Stage 1's points into the `.tres` — from this stage on the resource is the single source of truth. `pad_positions`: 8 pads in the S-pockets, each ≥ 90 px from the path centerline and ≥ 110 px from each other, all fully on the 720-wide screen. A set that satisfies those constraints for the path above: `(240, 410), (450, 410), (650, 400), (280, 680), (470, 680), (260, 940), (450, 940), (650, 910)` — re-check the constraints if you adjust either list; thumb-test in devtools. 6 waves:
  1. 6× normal, interval 1.2
  2. 10× normal, interval 1.0
  3. 8× normal interval 1.0 + 4× fast (start_delay 4.0, interval 0.9)
  4. 12× normal interval 0.8 + 6× fast (start_delay 3.0, interval 0.8)
  5. 12× fast, interval 0.7
  6. 16× normal interval 0.7 + 8× fast (start_delay 2.0, interval 0.7)
- [ ] Load-check the `.tres` files (see Implementation notes for hand-authoring syntax; verify with the headless import in task 13 before building gameplay on top).

### 3. Events autoload

- [ ] `scripts/autoload/events.gd` — plain `extends Node` declaring the full canonical signal set: `coins_changed(coins)`, `lives_changed(lives)`, `wave_started(number, total)`, `wave_cleared(number)`, `enemy_killed(enemy, bounty)`, `enemy_leaked(enemy)`, `tower_built(tower, pad)`, `tower_upgraded(tower)`, `tower_sold(pad, refund)`, `run_won(map_id)`, `run_lost(map_id)`, `endless_best(map_id, wave)`. Signals not yet fired (`endless_best`) get `@warning_ignore("unused_signal")` so headless import stays warning-clean.
- [ ] Register in `project.godot` under `[autoload]`: `Events="*res://scripts/autoload/events.gd"` (after `Settings`).

### 4. Enemy scene

- [ ] `scenes/entities/enemy.tscn` + `scripts/entities/enemy.gd`:
  ```
  Enemy (PathFollow2D, script enemy.gd, group "enemies", loop=false, rotates=false)
  ├─ Skin (Node2D)            # primitive blob: 2 Polygon2D circles + eye dots, candy color
  └─ Hurtbox (Area2D, layer=1, mask=0)
     └─ CollisionShape2D (CircleShape2D r≈26)
  ```
- [ ] `setup(data: EnemyData)` stores the resource and current `hp`; `fast` gets a visibly different Skin tint/size keyed off `data.id` (swap point for Stage 6 sprites).
- [ ] `_process`: `progress += data.speed * delta`; when `progress_ratio >= 1.0` → `Events.enemy_leaked.emit(self)` and `queue_free()`.
- [ ] `take_damage(amount)`: `hp -= maxf(1.0, amount - data.armor)`; at hp ≤ 0 → disable Hurtbox (`set_deferred("monitorable", false)`), stop moving, emit `Events.enemy_killed.emit(self, data.bounty)`, play the kill scale-punch (task 12), `queue_free()` when the tween finishes.
- [ ] Route all creation/destruction through `game.gd`'s `_spawn_enemy()` helper and `queue_free()` — Stage 3 swaps these for pools; keep the seams obvious.

### 5. Projectile scene

- [ ] `scenes/entities/projectile.tscn` + `scripts/entities/projectile.gd`:
  ```
  Projectile (Area2D, script projectile.gd, layer=0, mask=1)
  ├─ Skin (Node2D)            # small bright Polygon2D circle
  └─ CollisionShape2D (CircleShape2D r≈8)
  ```
- [ ] `launch(target: Enemy, damage: float, speed: float)`; `_physics_process` homes toward the target's global position; if `not is_instance_valid(target)` keep last heading and self-free after a 1.5 s lifetime.
- [ ] On `area_entered`: resolve the owner Enemy (the Hurtbox's parent), call `take_damage(damage)`, `queue_free()`.

### 6. Tower scene

- [ ] `scenes/entities/tower.tscn` + `scripts/entities/tower.gd`:
  ```
  Tower (Node2D, script tower.gd, group "towers")
  ├─ Skin (Node2D)            # rounded Polygon2D base + barrel; tier shown by size/stripe count
  ├─ RangeRing (Node2D)       # _draw(): translucent filled circle + outline at current range_px; hidden by default; NOT inside Skin
  └─ RangeArea (Area2D, layer=0, mask=1, monitoring=true)
     └─ CollisionShape2D (CircleShape2D — fresh instance per tower, see notes)
  ```
- [ ] `setup(data: TowerData)` sets tier 0, range radius from `data.range_px[0]`, tracks `total_spent` (starts at `cost[0]`). `upgrade()` bumps tier (max 2), adds `cost[tier]` to `total_spent`, updates range shape + RangeRing + Skin. `sell_refund() -> int` returns `floori(total_spent * data.sell_refund_ratio)`.
- [ ] Targeting + firing in `_physics_process`: cooldown accumulator against `data.fire_interval[tier]`; target = first-in-range = the overlapping enemy with the highest `progress` (iterate `RangeArea.get_overlapping_areas()`, resolve each area's parent Enemy). Fire → instantiate projectile at barrel tip, `launch(target, data.damage[tier], data.projectile_speed)`, plus a tiny Skin recoil tween.

### 7. BuildPad scene

- [ ] `scenes/entities/build_pad.tscn` + `scripts/entities/build_pad.gd`:
  ```
  BuildPad (Node2D, script build_pad.gd, group "build_pads")
  └─ Skin (Node2D)            # rounded pastel Polygon2D disc ~72 px wide
  ```
  State: `var tower: Tower = null`. No Area2D and no physics picking — pad taps are resolved centrally by `game.gd` hit-testing (see task 9 and Implementation notes); this keeps touch/mouse unified and tap targets generous (56 px radius) regardless of visual size.
- [ ] Replace Stage 1's placeholder pad nodes in `game.tscn`: `game.gd` instantiates `build_pad.tscn` at every `MapData.pad_positions` entry at load.

### 8. HUD

- [ ] `scenes/ui/hud.tscn` + `scripts/ui/hud.gd`, instanced inside `game.tscn`'s CanvasLayer, restyling Stage 1's static strips:
  - Top strip (anchored top, safe margin): `LivesLabel` ("♥ 20"), `CoinsLabel` ("● 100"), `WaveLabel` ("Wave 2/6").
  - `CountdownLabel` (center-top of board): "Next wave in 7…" ticking per second; hidden while a wave runs.
  - Root Control and all non-interactive containers set `mouse_filter = MOUSE_FILTER_IGNORE` so board taps pass through.
- [ ] Wire to the Events bus: `coins_changed`, `lives_changed`, `wave_started`, `wave_cleared`. Countdown display is driven by a local signal from the spawner (`countdown_tick(seconds_left)`) relayed by `game.gd` — countdown is scene-local, not on the canonical bus.
- [ ] Initial state: children `_ready` before their parent, so the HUD's signal connections exist before `Game._ready` emits the starting `coins_changed`/`lives_changed`; the wave label needs a direct `hud.set_wave(1, total)`-style call from `game.gd` at load (no `wave_started` has fired yet).
- [ ] Coin tick: on `coins_changed`, tween the displayed number toward the new value with `tween_method` over ~0.3 s plus a small scale pulse on the label.

### 9. Game orchestration (`scripts/game.gd` rewrite, `scenes/game.tscn` rebuild)

- [ ] Rebuild `scenes/game.tscn` (retiring the placeholder for good):
  ```
  Game (Node2D, script game.gd)
  ├─ Board (Node2D)               # Stage 1 pastel ground decor kept/adapted
  │  ├─ Path (Path2D)             # curve built at runtime from MapData.path_points
  │  │  └─ PathLine (Line2D)      # thick rounded candy path, points from the same data
  │  └─ Pads (Node2D)             # BuildPad instances
  ├─ Spawner (Node, script wave_spawner.gd)
  └─ UI (CanvasLayer)
     ├─ Hud (instance)
     ├─ BuildMenu (instance)
     └─ ResultOverlay (instance)
  ```
- [ ] `game.gd`: `var map_data: MapData` defaulting to `preload("res://data/maps/map_01.tres")` with a comment that Stage 5's MapSelect will inject it. `_ready()` builds a `Curve2D` from `path_points` into `Path`, sets `PathLine.points`, spawns pads, sets `coins = map_data.starting_coins` / `lives = map_data.starting_lives` and emits `coins_changed` / `lives_changed`.
- [ ] Economy lives here: `spend(amount) -> bool` (cost-gate), `earn(amount)`; connect `Events.enemy_killed` → earn bounty; `Events.enemy_leaked` → `lives = maxi(0, lives - enemy.data.lives_cost)`, emit `lives_changed`, and at `lives == 0` → stop spawner, emit `Events.run_lost.emit(map_data.id)` exactly once (guard flag).
- [ ] One-thumb input: `game.gd._unhandled_input` handles ONLY `InputEventMouseButton`, left button, `pressed` — with the default `emulate_mouse_from_touch=true`, real touches arrive here too as emulated mouse events; do NOT also handle `InputEventScreenTouch` or one physical tap fires the handler twice (open-then-close bug). Convert to world via `get_global_mouse_position()`, find the nearest pad in group `build_pads` within 56 px: found → open BuildMenu for that pad (build or manage mode by `pad.tower`); none → dismiss BuildMenu and hide any RangeRing. UI buttons consume their events before `_unhandled_input`, so tap-away "just works".

### 10. Wave engine

- [ ] `scripts/wave_spawner.gd` on the `Spawner` node. Const `COUNTDOWN_SECONDS := 7.0` (canonical pacing constant, not balance). State machine: `COUNTDOWN → SPAWNING → CLEARING → (next COUNTDOWN | WON)`.
  - COUNTDOWN: emits local `countdown_tick(seconds_left)` each second; auto-starts the wave at 0 — no "start now" button this stage.
  - SPAWNING: emits `Events.wave_started.emit(number, map_data.waves.size())`; for each SpawnGroup, `await` its `start_delay`, then spawn `count` enemies every `spawn_interval` via `game.gd._spawn_enemy(enemy_data)` (instances `enemy.tscn` as a child of `Path`, calls `setup`).
  - CLEARING: wave done when all groups finished AND live enemy count is 0 (track a counter: +1 on spawn, −1 on `enemy_killed`/`enemy_leaked`). Emit `Events.wave_cleared.emit(number)`; after the last wave with lives > 0 → `Events.run_won.emit(map_data.id)`.
  - Halt cleanly on run_lost/run_won (guard every `await` resume with a `run_over` flag).

### 11. BuildMenu — build, then upgrade/sell (THE CUT LINE)

- [ ] `scenes/ui/build_menu.tscn` + `scripts/ui/build_menu.gd`: bottom sheet Control anchored to the bottom edge over the Stage 1 thumb-zone bar, candy_theme panel, slides up with a short `TRANS_BACK` tween. `open_build(pad)`, `open_manage(pad)`, `close()`.
- [ ] Build mode: one big button "Popper — 50●" (text from `TowerData`, ≥ 88 px tall). Disabled (greyed via theme) when `coins < data.cost[0]`; re-evaluate on `Events.coins_changed`. Press → `game.spend(cost)`, instantiate `tower.tscn` on the pad (`pad.tower = tower`), `Events.tower_built.emit(tower, pad)`, close sheet. Building/upgrading/selling is allowed at any time, including mid-wave.
- [ ] Manage mode (cut if long — ship build-only and log the follow-up): shows the selected tower's `RangeRing`; "Upgrade — 60●" (next tier cost, disabled when unaffordable, label "MAX" at tier 3) → `spend`, `tower.upgrade()`, `Events.tower_upgraded.emit(tower)`, refresh sheet; "Sell +N●" (N = `tower.sell_refund()`) → `earn(refund)`, free tower, `pad.tower = null`, `Events.tower_sold.emit(pad, refund)`, close. Tap-away (task 9) closes and hides the ring.

### 12. ResultOverlay + minimal feel floor

- [ ] `scenes/ui/result_overlay.tscn` + `scripts/ui/result_overlay.gd`: full-rect Control (hidden; `mouse_filter = STOP` when shown), dimmed backdrop, candy panel bouncing in. Win text "Path defended!" / lose text "The critters got through!" (short + bouncy per blueprint §8). Buttons Retry (`get_tree().reload_current_scene()`) and Menu (`change_scene_to_file("res://scenes/main_menu.tscn")`), both ≥ 88 px, bottom-anchored. Shows on `Events.run_won` / `run_lost`; pauses gameplay via `get_tree().paused = true` with the overlay `process_mode = PROCESS_MODE_ALWAYS`; both buttons MUST set `get_tree().paused = false` before changing scene (see notes).
- [ ] Feel floor (inline `create_tween()` calls, all targeting `Skin` transforms only; Stage 3 centralizes into the Juice autoload):
  - Kill scale-punch: Skin scales to ~1.5 and fades over 0.15 s before free.
  - Floating "+N": `game.gd` helper spawns a Label at the death position, floats up 40 px and fades over 0.6 s, self-frees.
  - Tower build bounce-in: Skin scale 0.5 → 1.0, `TRANS_BACK` `EASE_OUT`, ~0.25 s.
  - Pad tap pulse: Skin scale 1.0 → 1.15 → 1.0, ~0.12 s.
  - HUD coin tick (task 8).

### 13. Verify, commit, PR

- [ ] Run the Verification section below end-to-end.
- [ ] `git add -A` (confirm every new `*.uid` is staged: `git status --short | grep uid`), commit with a descriptive message (e.g. "Stage 2: data-driven core loop on map 1 — schema, Events bus, tower/enemy/wave engine, one-thumb BuildMenu, win/lose"), push the branch, open a PR to `main`, and confirm the CI web-export build is green before merge. After merge, play-check the live Pages build on a phone.

## Implementation notes

- **Hand-authoring `.tres` with typed arrays** (no editor in the sandbox): custom Resources serialize as `[gd_resource type="Resource" script_class="MapData" load_steps=N format=3]` with `script = ExtResource(...)` in the `[resource]` block; nested resources are `[sub_resource type="Resource" id="..."]` blocks; typed arrays serialize as `waves = Array[ExtResource("2_wd")]([SubResource("wave1"), ...])` where the ExtResource is the *script* (`wave_data.gd`). Every `.gd`/`.tres` referenced needs an `[ext_resource]` line — omit `uid` attributes and let the import fix them up, then commit what Godot rewrites. If hand-authoring fights back, generate the files once with a throwaway `godot --headless --script` run that builds the resources in code and `ResourceSaver.save()`s them, then delete the throwaway script. Either way, verify with `godot --headless --import` and check for "Parse Error" / "load failed" lines before writing gameplay code against the data.
- **Shared shape resources**: a `CircleShape2D` saved in `tower.tscn` is shared by ALL tower instances — upgrading one tower's range would change every tower's. Create a fresh `CircleShape2D.new()` in `tower.gd._ready()` (or set `resource_local_to_scene = true` on the shape).
- **Area2D timing**: overlap state updates on physics ticks — do targeting/firing in `_physics_process`, never `_process`. Newly spawned enemies take one physics frame to register in RangeArea; that's fine. Layers: Enemy Hurtbox layer 1 / mask 0; RangeArea and Projectile layer 0 / mask 1. No physics bodies anywhere.
- **Input routing**: Godot order is `_input` → Control `gui_input` → `_unhandled_input` → physics picking. Physics picking runs *after* `_unhandled_input`, so Area2D-pickable pads combined with tap-away-in-unhandled-input would close-then-reopen the sheet. That is why pads have no Area2D and `game.gd._unhandled_input` does a nearest-pad distance test instead — one code path for touch and mouse, generous tap radius, no ordering bugs. Keep `input_devices/pointing/emulate_mouse_from_touch` at its default (`true`) and handle only mouse events (task 9) — handling touch AND mouse double-fires on real phones.
- **Controls eating taps**: any full-rect Control (HUD root, containers) must be `MOUSE_FILTER_IGNORE` or pads become untappable. Only Buttons, the BuildMenu panel, and the shown ResultOverlay use `STOP`. Test both a pad tap and a tap-away with the sheet open.
- **Pause + overlays**: with `get_tree().paused = true`, the ResultOverlay needs `process_mode = PROCESS_MODE_ALWAYS` (children inherit). `paused` PERSISTS across `reload_current_scene()` and `change_scene_to_file()` — Retry/Menu must unpause first or the next scene loads frozen. Tweens created by paused nodes don't run; create the overlay's bounce-in tween from the overlay itself (it processes always).
- **Tweens (Godot 4.7)**: `create_tween()` is bound to the creating node — a freed enemy kills its tween, so free the enemy *from* the tween (`tween.tween_callback(queue_free)` last), never `queue_free()` first. Chain with `set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)`.
- **`await` in the spawner**: use `await get_tree().create_timer(x).timeout`; guard every resume point with `if run_over: return` — a lose can happen mid-await. Scene-tree timers keep running while awaiting; that's the intended behavior here.
- **No particles yet**: GPUParticles2D vs CPUParticles2D is Stage 3's measured decision — this stage uses only tweens and Labels for feel. Do not add any Particles2D node.
- **Web/no-threads/GL Compatibility**: nothing here needs threads; keep it that way. `queue_free`/`instantiate` churn is acceptable at Stage 2 enemy counts (≤ ~25 alive); pooling is Stage 3's job — just keep spawn/despawn funneled through the named helpers so the swap is local.
- **Expand aspect**: taller-than-16:9 phones reveal extra ground vertically; keep all gameplay (path, pads, HUD anchors) inside the 720×1280 design rect and let `Board`'s pastel ground overdraw generously (e.g. a ColorRect from −200 to 1480 in y).
- **Skin discipline**: gameplay scripts never reach inside `Skin`; all feel tweens hit the `Skin` node's transform. `RangeRing` sits *beside* Skin (it survives the Stage 6 art swap untouched). Skin variants key off `TowerData.id`+tier and `EnemyData.id`.
- **Zero balance in code**: if you type a damage/cost/hp/speed number into a `.gd` file, stop and move it into the schema. The only sanctioned constants: `COUNTDOWN_SECONDS` (canonical 7 s pacing), the 56 px tap radius, projectile lifetime, tween durations/scales.

## Juice checklist

Stage 2 ships the minimal feel floor (the full toolkit is Stage 3):

- [ ] Enemy kill scale-punch + fade — every pop reads as a pop.
- [ ] Floating "+N" coin text at each kill position.
- [ ] HUD coin count ticks up/down smoothly with a label pulse.
- [ ] Tower bounce-in on build (`TRANS_BACK` overshoot).
- [ ] Pad pulse on tap; BuildMenu sheet slides/overshoots in.
- [ ] Tower Skin recoil nudge on each shot.
- [ ] ResultOverlay panel bounces in on win/lose.

## Acceptance criteria

- [ ] From New Game, map 1 loads showing path, 8 pads, HUD (♥ 20, ● 100, Wave 1/6) and a ticking 7 s countdown; the wave auto-starts with no input.
- [ ] Tapping an empty pad opens the BuildMenu bottom sheet; the build button is disabled when coins < cost; buying deducts coins, places a tower with bounce-in, and closes the sheet.
- [ ] Tap-away anywhere (including during a wave) dismisses the sheet; tapping a different pad switches the sheet to that pad. One tap produces exactly one open/close action with mouse and with touch emulation.
- [ ] Tapping a built tower opens manage mode with a visible range ring; upgrade raises tier (visibly bigger Skin, larger ring) and costs `cost[tier]`; tier 3 shows "MAX"; sell refunds exactly `floor(0.7 × total spent)` and empties the pad. (Waived only if the documented cut-line was taken — then the PR must say so.)
- [ ] Towers auto-target the enemy furthest along the path within range and fire visible projectiles; damage respects `damage[tier]` and `fire_interval[tier]` from `popper.tres`.
- [ ] Normal and fast critters are visually distinct and move at their `.tres` speeds; kills grant bounty (coins + floater), leaks decrement lives by `lives_cost`.
- [ ] Waves 1–6 spawn per `map_01.tres`; between waves the countdown re-arms automatically; the HUD wave counter is correct throughout.
- [ ] Clearing wave 6 with lives > 0 shows the win overlay; hitting 0 lives at any point immediately shows the lose overlay and stops spawning. Retry restarts a fresh unpaused run (coins/lives/waves reset); Menu returns to the main menu.
- [ ] Building, upgrading, and selling all work mid-wave.
- [ ] Manual audit of the diff for `scripts/entities/`, `scripts/wave_spawner.gd`, `scripts/game.gd`, `scripts/ui/` confirms no hp/damage/cost/speed/bounty/range numbers in code — only the sanctioned constants listed in the notes; everything else reads from the `.tres` resources.
- [ ] Every new scene/script has its `*.uid` committed; `scenes/game.tscn` placeholder content is gone.

## Verification

1. Local headless (skip to step 3 if `godot` is unavailable — CI is the authoritative gate):
   ```sh
   godot --headless --import          # zero script errors, zero .tres parse errors
   godot --headless --export-release "Web" build/web/index.html
   python3 -m http.server 8080 -d build/web
   ```
2. In Chrome, open http://localhost:8080, DevTools → device toolbar → iPhone SE and Pixel 7 portrait presets, touch emulation ON. Play one full winning run (build 3–4 towers, upgrade one to tier 3, sell one) and one deliberate loss (build nothing). Confirm every Acceptance criterion by hand, especially tap-away, no double-fire on tap, and the sheet reachable by a right thumb.
3. Push the branch, open the PR; the `deploy.yml` PR build must go green (this is the standard remote verification).
4. "Smooth" here means: no visible hitching with ~25 enemies + 8 towers firing in Chrome's device emulation with 4× CPU throttling, and no per-frame errors in the console. (Hard perf budgets arrive in Stage 3 — this is a sanity bar, not the measured proof.)
5. After merge, load https://bitspleasebe.github.io/tower-game/ on a real phone and play map 1 start-to-finish one-thumbed.

## Out of scope

- Juice autoload, particles/confetti, pooling, screen shake, wave banner (`scenes/ui/wave_banner.tscn`), stress harness, `scripts/perf_budget.gd` — **Stage 3**.
- The other three tower types/behaviors (SPLASH/SLOW/SNIPER logic), swarm/armored/boss archetypes, waves 7–15 of map 1, multi-tower BuildMenu grid, debug fast-forward/free-build — **Stage 4**.
- Maps 2–3, `scenes/map_select.tscn`, endless mode, `SaveGame` autoload/persistence, Next Map/Endless buttons on ResultOverlay — **Stage 5**.
- Kenney art, icon, theme nine-patches — **Stage 6**. All SFX/music — **Stage 7**. Balance polish beyond "a careful first-timer can win map 1's 6 waves" — **Stage 8**.

## Handoff

After this stage, later stages may rely on:

- The complete data schema in `scripts/data/` (TowerData/EnemyData/WaveData/SpawnGroup/MapData with behavior enum, armor, is_boss, endless params) and instances `data/towers/popper.tres`, `data/enemies/{normal,fast}.tres`, `data/maps/map_01.tres` (6 waves) — Stage 4 adds towers/enemies/waves as pure data.
- `Events` autoload live with the full canonical signal set; HUD/economy/lives already wired through it.
- Working scenes with `Skin` swap points and committed `.uid`s: `scenes/entities/{tower,enemy,projectile,build_pad}.tscn`, `scenes/ui/{hud,build_menu,result_overlay}.tscn`, rebuilt `scenes/game.tscn` (root `Game`) with `game.gd` orchestration, `wave_spawner.gd` state machine, and `map_data` injectable for Stage 5.
- Spawn/despawn funneled through named helpers (`_spawn_enemy`, projectile instantiation in `tower.gd`) ready for Stage 3 pooling; all feel tweens target `Skin` transforms only, ready to migrate into the Juice autoload.
- The one-thumb interaction contract proven end-to-end: centralized pad hit-testing in `game.gd._unhandled_input` (emulated-mouse-only event path), bottom-sheet BuildMenu with cost-gating, 70% refund selling, mid-wave build/upgrade/sell.
