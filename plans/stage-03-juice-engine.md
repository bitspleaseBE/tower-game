# Stage 3: Juice Engine & Web Performance Proof

**Status:** not started

Objective: after this stage, the same map 1 run from Stage 2 *feels* like the blueprint's pitch — critters jelly-wobble as they march, hits flash, kills burst into confetti while coins arc into the HUD counter, towers squash and recoil with every shot, hearts thump and the screen micro-shakes on a leak, waves announce themselves with a bouncy banner, and every button squishes under the thumb — and the scariest technical unknown is retired: a hidden stress harness proves that worst-case effect load (80+ pooled enemies, max towers firing, continuous confetti) holds ~60 fps (floor 50) on a mid-range Android phone in Chrome via the real Pages deploy, with the measured hard caps written into `scripts/perf_budget.gd` and the GPU-vs-CPU particle decision made final for every later stage.

## Prerequisites

Stage 2 ("Data-Driven Core Loop on Map 1", slug `core-loop`) must be merged and deployed. Verify each; if any check fails, stop and fix Stage 2 first.

- [ ] `Events` autoload live: `grep 'Events=' project.godot` and `ls scripts/autoload/events.gd`.
- [ ] Entity scenes with `Skin` nodes exist: `ls scenes/entities/{tower,enemy,projectile,build_pad}.tscn scenes/ui/{hud,build_menu,result_overlay}.tscn`.
- [ ] Spawn/despawn seams exist as promised by Stage 2's handoff: `grep -n '_spawn_enemy' scripts/game.gd` (all enemy creation funnels through it) and `grep -n 'instantiate' scripts/entities/tower.gd` (projectile creation is local to `tower.gd`). Read both files fully — this stage rewires those exact seams.
- [ ] Data resources load: `ls data/maps/map_01.tres data/towers/popper.tres data/enemies/*.tres`.
- [ ] Stage 2's inline feel tweens exist to migrate (kill punch, floater helper, build bounce-in, pad pulse, coin tick): `grep -rn 'create_tween' scripts/ | grep -v addons`. List every hit — task 6 replaces each with a Juice call.
- [ ] If Stage 2 took its documented cut line (no upgrade/sell), note it: the stress harness (task 9) upgrades towers via `tower.upgrade()` directly, which exists regardless.
- [ ] CI green on `main` (`gh run list --branch main --limit 1`) and https://bitspleasebe.github.io/tower-game/ plays map 1 on a phone.
- [ ] Godot availability: `godot --version` prints 4.7.x; if absent, plan on the CI PR build + manual `workflow_dispatch` branch deploys for everything remote.
- [ ] Work on a branch: `git checkout -b stage-03-juice-engine`.

## Tasks

Ordered so the pools and budget exist before the effects that consume them, and the harness exists before the measurements that finalize the budget. Nothing here changes gameplay rules: juice is cosmetic, coins/lives/damage timing stay exactly as Stage 2 shipped them.

### 1. Generic object pool — `scripts/object_pool.gd`

- [ ] `class_name ObjectPool extends RefCounted`. Constructor `_init(scene: PackedScene, parent: Node, prewarm: int, cap: int, grow_policy: GrowPolicy)` with `enum GrowPolicy { GROW_WARN, DROP }`. Instantiates `prewarm` nodes up front (children of `parent`, deactivated).
- [ ] `acquire() -> Node`: pop a free node, else if under `cap` instantiate; else `GROW_WARN` → instantiate anyway + `push_warning` (gameplay must never silently lose an enemy/projectile), `DROP` → return `null` (cosmetics are droppable).
- [ ] `release(node)`: `node.visible = false`, `node.process_mode = Node.PROCESS_MODE_DISABLED`, push to the free list. The pool never calls `queue_free()`; nodes die with their parent when the scene is freed (Retry via `reload_current_scene()` stays safe).
- [ ] `live_count()` / `free_count()` for the stress overlay. Pooled scenes own their reset logic via an `activate(...)` method (scene-specific args) that the *caller* invokes after `acquire()` — the pool stays generic.

### 2. `scripts/perf_budget.gd` — provisional now, measured later

- [ ] `class_name PerfBudget` — constants only, no logic. Starting (PROVISIONAL) values, all tuned by task 10: `MAX_ENEMIES := 96` (pool prewarm 32), `MAX_PROJECTILES := 64` (prewarm 24), `MAX_CONFETTI_BURSTS := 10`, `PARTICLES_PER_BURST := 16`, `MAX_FLOATERS := 20`, `MAX_COIN_FLYERS := 24`, `MAX_SHAKE_PX := 5.0`, `MAX_SHAKE_DURATION := 0.25`.
- [ ] Header comment block is the budget's documentation of record: device + browser measured on, date, fps results at the caps, the particle-backend decision and one paragraph of why, and a `PROVISIONAL`/`MEASURED` status line. Add a comment `# Stage 7 adds MAX_SFX_VOICES here.`
- [ ] Every FX/pool cap in the codebase must reference these constants — grep-auditable, no magic numbers at call sites.

### 3. Juice autoload core — `scripts/autoload/juice.gd`

- [ ] Plain `extends Node`, registered in `project.godot` after `Events`: `Juice="*res://scripts/autoload/juice.gd"`. Design decision (do not deviate): **Juice is a dumb toolkit — it never connects to the Events bus.** Call sites own their juice (hud thumps its own hearts, `game.gd` shakes on leak, enemies pop themselves). This keeps pool-reuse ordering sane and Juice reusable.
- [ ] Scene lifecycle: `register_game(fx_layer: Node2D, shake_target: Node2D, hud: Node)` called from `Game._ready()`. Juice builds its FX pools (task 5) under `fx_layer`, captures `shake_target`'s rest position, connects `fx_layer.tree_exiting` to an internal `_unregister()` that drops all pool/claim references — Retry and Menu never leave dangling refs. All FX functions no-op with a `push_warning` when unregistered (main menu can still use button squish, which needs no registration).
- [ ] Rest-state contract: `claim(item: CanvasItem)` records the item's current scale/rotation/position/modulate as its rest state; every transient effect returns to the claimed rest, and starting a new effect on an item kills that item's previous Juice tween first (one Juice tween per item — prevents scale drift from stacked punches). `release(item)` kills the tween, restores rest, forgets the claim. Entities `claim` their `Skin` in `activate()`/`_ready()`; `Tower.upgrade()` re-claims after resizing its Skin.
- [ ] Transient helpers (each: kill prior tween → `item.create_tween()` → end on claimed rest):
  - `punch_scale(item, amount := 1.35, duration := 0.18)` — up fast, back with `TRANS_BACK`/`EASE_OUT`.
  - `bounce_in(item, duration := 0.25)` — scale `0.5 → rest`, `TRANS_BACK`.
  - `squash(item, squish := Vector2(1.2, 0.8), duration := 0.15)` — tower recoil; overshoot back to rest with `TRANS_ELASTIC`.
  - `flash(item, flash_color := Color(6, 6, 6), duration := 0.1)` — tween `modulate` rest → overbright → rest (see notes for the clamp trick).
  - `pop_in_out(item, hold := 0.7)` — for the wave banner.
- [ ] Continuous helpers:
  - `wobble_scale(t: float, strength := 0.07, freq := 9.0) -> Vector2` — pure function returning `Vector2(1 + strength*sin(t*freq), 1 + strength*sin(t*freq + PI))` (antiphase x/y = jelly). Enemies multiply their claimed rest scale by it per frame.
  - `shake(strength_px := 4.0, duration := 0.2)` — clamped by `PerfBudget.MAX_SHAKE_PX`/`MAX_SHAKE_DURATION`; concurrent shakes take `max(current, new)`, never add. Juice `_process` applies a decaying random offset to `shake_target.position` around the captured rest and restores rest exactly at the end (no drift).
  - `squishify_button(button: Button)` — connects `button_down`/`button_up` to scale tweens (0.92 down, overshoot back up); sets `pivot_offset = size / 2.0` and keeps it centered via `resized`.

### 4. Gameplay pooling — enemies and projectiles (in `game.gd` / `tower.gd`)

- [ ] `game.gd` owns two `ObjectPool`s built in `_ready()`: enemies (`enemy.tscn`, parent = the `Path` node — PathFollow2D must stay a Path2D child; `GROW_WARN`, cap `PerfBudget.MAX_ENEMIES`) and projectiles (`projectile.tscn`, parent = new `Projectiles` Node2D under `Board`; `GROW_WARN`, cap `MAX_PROJECTILES`). `_spawn_enemy(data)` becomes acquire + `enemy.activate(data)`. Towers get projectiles via a `game.gd` helper (e.g. `game.acquire_projectile()`) instead of `instantiate()` — pass Game down or resolve via group; keep it one obvious seam.
- [ ] `enemy.gd` rework: add `var active := false` and `var generation := 0`. `activate(data)`: `generation += 1`, reset `hp`, `progress = 0` *before* re-enabling, `visible = true`, `process_mode = PROCESS_MODE_INHERIT`, `Hurtbox.set_deferred("monitorable", true)`, re-apply Skin variant for `data.id`, `Juice.claim(skin)`, `active = true`, `wobbling = true`. Replace both `queue_free()` paths with `deactivate()` → `active = false`, `set_deferred("monitorable", false)`, then release to the pool (death waits for the kill-pop tween via `tween_callback`; leaks release immediately). Signal connections are made **once** at first instantiate, never re-connected on `activate` (double-fire bug).
- [ ] Pooled-target validity: `is_instance_valid()` is no longer sufficient — a pooled enemy stays valid forever and may be re-activated as a different critter. `projectile.gd` stores `target` + `target_generation` at launch and self-releases (keep last heading, 1.5 s lifetime) when `not target.active or target.generation != target_generation`. `tower.gd` targeting skips non-`active` enemies (deferred `monitorable=false` leaves one stale physics frame).
- [ ] Hot-path allocation pass: towers re-acquire targets on fire and on a 0.1 s tick instead of every physics frame (keep current target while valid + active + in range); no `instantiate`/`queue_free` during waves (pools only); no per-frame string building outside the debug overlay's 0.25 s tick. Floating text and FX allocations move into task 5's pools.

### 5. FX pools in Juice — floaters, coin flyers, confetti (both backends)

- [ ] `game.tscn` gains `FxLayer (Node2D)` ordered after `Board` (world FX draw above the board, below the UI CanvasLayer) and **outside** `Board` so screen shake doesn't jitter FX or coin flights. Shake target = `Board`; register both in `Game._ready()` via `Juice.register_game($FxLayer, $Board, hud)`.
- [ ] Floaters: `scenes/ui/floater.tscn` (root `Floater`, a Label with theme outline, `mouse_filter = IGNORE`) + tiny script with `activate(text, world_pos, color)`. Pool cap `MAX_FLOATERS`, policy: when full, recycle the *oldest* live floater (steal, don't drop). API `Juice.floater(text, world_pos, color := Color.WHITE)` — floats up ~40 px, fades ~0.6 s, self-releases via tween callback. Migrate Stage 2's `game.gd` floater helper to this.
- [ ] Coin flyers: `scenes/ui/coin_flyer.tscn` (root `CoinFlyer`, Node2D with a small golden Polygon2D circle under a `Skin` child — swap point for a Stage 6 coin sprite). `Juice.coin_burst(world_pos, count := 3)` acquires up to `MAX_COIN_FLYERS` (policy `DROP` — coins are already credited, flight is pure cosmetics), each flying a quadratic bezier (`tween_method`, random control point ~80–150 px sideways) to `hud.coin_anchor()` over 0.45–0.65 s, then releasing and telling the hud to pulse its coin label (`hud.pulse_coins()`). **Coins credit instantly on kill exactly as in Stage 2** — never gate economy on animation arrival.
- [ ] Confetti kill-pop, the A/B vehicle: two visually identical one-shot scenes, `scenes/fx/confetti_cpu.tscn` (CPUParticles2D) and `scenes/fx/confetti_gpu.tscn` (GPUParticles2D + ParticleProcessMaterial): `one_shot = true`, `explosiveness = 1.0`, `amount = PerfBudget.PARTICLES_PER_BURST`, lifetime ~0.6 s, radial initial velocity + gravity, slight spin, `color_initial_ramp` = discrete candy-palette Gradient, texture = a small built-in `GradientTexture2D` (no asset files; this node is the Stage 6 swap point for `inspiration/fx/kenney-particle-pack` sprites). `Juice.confetti(world_pos)` acquires from a pool (cap `MAX_CONFETTI_BURSTS`, policy `DROP`), sets position, `restart()`; returns to pool on the particles' `finished` signal.
- [ ] Particle backend switch (temporary, deleted in task 10): `Juice.particle_backend: String = "cpu"` chosen before pools prewarm — settable only by the stress harness (URL param / debug button). The confetti pool rebuilds when it changes. Default and expected winner is **cpu** per the architecture; GPU must *prove* itself.

### 6. Wire juice into every Stage 2 interaction

Migrate every inline `create_tween()` feel-call found in Prerequisites into Juice calls (one implementation each), then wire the new effects. The full hook map — implement all of it:

| Moment (owner) | Juice calls |
|---|---|
| Enemy walking (`enemy._process`) | `skin.scale = rest * Juice.wobble_scale(walk_time)` while `wobbling` (see notes: wobble owns Skin.scale while alive) |
| Enemy hit (`take_damage`) | `Juice.flash(skin)` |
| Enemy killed (`take_damage` → death branch) | `wobbling = false`, `Juice.punch_scale(skin)`, `Juice.confetti(global_position)`, `Juice.coin_burst(global_position)`, `Juice.floater("+%d" % bounty, ...)` |
| Enemy leaked (`game.gd`'s `enemy_leaked` handler) | `Juice.shake(4.0, 0.2)`; hud thumps hearts (below) |
| Lives drop (`hud.gd`'s `lives_changed` handler) | `Juice.punch_scale(lives_label)` (pivot centered) |
| Coins change (`hud.gd`) | keep Stage 2's number tick; `pulse_coins()` also called on each coin-flyer arrival |
| Tower fires (`tower.gd`) | `Juice.squash(skin)` recoil (replaces Stage 2's nudge) |
| Tower built (BuildMenu placement path) | `Juice.bounce_in(skin)` |
| Pad tapped (`game.gd` tap handler) | `Juice.punch_scale(pad_skin, 1.15, 0.12)` |
| Wave starts (`WaveBanner`, task 7) | `Juice.pop_in_out(banner)` |
| Any button pressed (task 8) | `Juice.squishify_button(...)` at scene `_ready` |
| Win/lose (ResultOverlay) | keep Stage 2's bounce-in (runs while paused; leave its tween local — see notes) |

- [ ] After migration, `grep -rn 'create_tween' scripts/` should hit only `juice.gd`, `result_overlay.gd` (pause-safe local tween), and `hud.gd`'s coin number tick — anything else needs a reason in the PR description.

### 7. Wave banner — `scenes/ui/wave_banner.tscn`

- [ ] Root `WaveBanner` (Control, full-width, upper-third of the board, `mouse_filter = IGNORE` on every node — it must never eat a pad tap), big candy-theme label, instanced into `game.tscn`'s `UI` CanvasLayer. Script connects itself to `Events.wave_started` → sets text `"Wave %d"` (short and bouncy, blueprint §8; final copy pass is Stage 8's), scales/slides in with `TRANS_BACK`, holds ~0.7 s, pops out. Also connects `Events.wave_cleared` → quick "Clear!" variant, and hides instantly on `run_won`/`run_lost`.

### 8. Button press-squish everywhere

- [ ] In `main_menu.gd`, `settings_menu.gd`, `build_menu.gd`, `result_overlay.gd`: at `_ready`, call `Juice.squishify_button(b)` for each Button (walk direct children or an exported list — keep it dumb). Verify pivot centering on the wide bottom-anchored Stage 1 buttons and that disabled (unaffordable) BuildMenu buttons don't squish.

### 9. Stress-test harness (debug-only, hidden)

- [ ] `scenes/debug/stress_overlay.tscn` + `scripts/debug/stress_test.gd` on a `StressTest` Node inside `game.tscn` (idle by default, overlay hidden). Activation: on web, `?stress=1` read once at `_ready` via `JavaScriptBridge` (guard `OS.has_feature("web")`); on desktop, F9 toggles. Optional params `?particles=gpu|cpu` and `?enemies=N` (default 80). Normal players can never trip this.
- [ ] When activated: disable the `Spawner` state machine; set lives to 999999 and suppress win/lose; fill every pad with a tier-3 popper (direct `tower.tscn` instantiate + `setup` + `upgrade()` twice — bypasses economy; this is harness plumbing, NOT Stage 4's player-facing free-build toggle); top up live enemies to the target count continuously through the enemy pool (leaks recycle, so load is sustained); force extra confetti + floaters + coin bursts on a 0.15 s timer at random path points and a `Juice.shake` every 2 s. Worst case = enemy target 80+, all towers firing, continuous confetti.
- [ ] Overlay (top-left, `mouse_filter = IGNORE` except its buttons): FPS (`Engine.get_frames_per_second()`), average + worst frame ms over a rolling 60 frames (accumulate `delta` in `_process`), enemies alive, live confetti bursts x particles-per-burst, floaters/flyers live, pool live/free counts, node count (`Performance.get_monitor(Performance.OBJECT_NODE_COUNT)` — flat node count over minutes proves pooling works). Text rebuilt only every 0.25 s.
- [ ] Thumb-sized (>= 60 px) debug buttons on the overlay, usable on the phone: `[Particles: CPU/GPU]` toggle (rebuilds the confetti pool via task 5's switch) and `[Enemies: 40/80/120]` cycle.

### 10. Measure, decide, finalize the budget

- [ ] Local first: export the web build, serve it, and sanity-run the harness in Chrome device emulation (Pixel-class preset, CPU 4x throttle) with both particle backends. Fix anything obviously broken before burning a device run.
- [ ] Deploy the branch to Pages: `gh workflow run deploy.yml --ref stage-03-juice-engine`, wait for green (`gh run watch`), then open `https://bitspleasebe.github.io/tower-game/?stress=1` (and `...&particles=gpu`) **on a mid-range Android phone in Chrome** — ask the user/team to run it and report overlay numbers if no device is at hand. Record for each backend: steady-state FPS, worst frame ms, at enemy targets 40/80/120.
- [ ] Decide the particle backend from the numbers (tie or close → CPU, the architecture's default; GPU wins only if clearly better *and* free of first-emit hitching). The decision is FINAL for all later stages. Delete the losing confetti scene and the `particle_backend` switch; hardcode the winner in Juice; keep the stress harness's other toggles.
- [ ] Tune `PerfBudget` constants to what the device sustained at ~60 fps (floor 50): if 80 enemies + 10 bursts held 58 fps, those caps stand; if not, lower caps (smaller `PARTICLES_PER_BURST` first, then `MAX_CONFETTI_BURSTS`) until it holds, and record the honest ceiling. Update the header block: device, browser version, date, numbers, decision rationale, status `MEASURED` — or `PROVISIONAL (Chrome 4x-throttle emulation only — re-verify Stage 8)` if no physical device was available.
- [ ] After measuring, `main`'s Pages deploy is stale (the branch overwrote it) — merging this PR re-deploys `main`; if merge is delayed, re-run the workflow on `main`.

### 11. Verify, commit, PR

- [ ] Run the Verification section end-to-end.
- [ ] `git add -A` (confirm every new `*.uid` is staged: `git status --short | grep uid` — new scenes: floater, coin_flyer, confetti winner, wave_banner, stress_overlay; new scripts: object_pool, perf_budget, juice, stress_test), commit with a descriptive message (e.g. "Stage 3: Juice autoload + pooling, confetti/coin-arc/shake/banner, stress harness, measured PerfBudget"), push, open a PR to `main` whose description includes the measurement table and particle decision, confirm the CI web-export build is green, merge, and play-check the live Pages build (plus one `?stress=1` run) on a phone.

## Implementation notes

- **Overbright flash trick**: 2D canvas output clamps each channel at 1.0, so tweening `modulate` to `Color(6,6,6)` saturates any candy color to near-white without shaders or touching nodes inside `Skin` — e.g. pink `(1.0, 0.6, 0.7) * 6` clamps to white. Pure-zero channels stay 0, which is fine for this palette. Flash must tween back to the *claimed rest modulate*, not `Color.WHITE`, or archetype tints (if Stage 2 tinted via Skin.modulate) get wiped.
- **Wobble vs tween ownership of `Skin.scale`**: the per-frame wobble write would fight any scale tween. Rule: while `wobbling` is true, enemy `_process` owns `Skin.scale`; death sets `wobbling = false` *before* `Juice.punch_scale`. Hit flash uses `modulate` only, so it composes with wobble. Wobble is plain math in `_process` — do NOT implement it as 80 looping tweens.
- **One Juice tween per item + rest state**: transient effects always start by killing the item's previous Juice tween and always end on the claimed rest transform — this kills the classic stacked-punch scale-drift bug and makes pool reuse deterministic (`Juice.release(skin)` in `deactivate()` restores rest instantly). Tweens are created with `item.create_tween()` (dies with the node) *and* tracked in Juice's claim dictionary (killed on claim/release) — belt and suspenders.
- **Pools never free**: pooled nodes are scene children, freed only when the scene is freed. `reload_current_scene()` (Retry) frees everything → `FxLayer.tree_exiting` clears Juice's references → `register_game` rebuilds pools on the fresh `Game._ready()`. Never hold a pooled ref across frames outside the pool/owner (Events handlers read `enemy.global_position`/bounty synchronously, never store the enemy).
- **Pooled validity**: `is_instance_valid()` lies for pooled nodes. `active` flag + `generation` int is the contract (task 4). Audit every place Stage 2 checked `is_instance_valid` on an enemy.
- **PathFollow2D reset order**: set `progress = 0` while the node is still invisible/disabled, then enable — otherwise the enemy renders one frame at the exit before teleporting to the start. `loop = false` keeps `progress_ratio` clamped at 1.0, so the leak check stays `>= 1.0`.
- **Area2D deferred flags**: `monitorable` changes apply next physics frame; a just-deactivated enemy is overlappable for one more frame — the `active` check in tower targeting and projectile impact covers it. Re-enable on activate with `set_deferred` too.
- **Control scaling pivots top-left by default**: any label/button scale tween needs `pivot_offset = size / 2.0`, refreshed on `resized` (Stage 1's buttons are wide). `squishify_button` owns this.
- **Pause interplay**: `Juice` (autoload) and its tweens inherit pause like everything else — fine, the board is frozen anyway. ResultOverlay keeps its own locally created bounce-in tween because it runs with `PROCESS_MODE_ALWAYS` under `paused = true` (Stage 2 note); don't route it through claim/rest bookkeeping.
- **Shake without a camera**: there is no Camera2D; shake offsets `Board.position` around a captured rest and must restore it exactly (tween/decay to rest, no cumulative drift). Cap 5 px / 0.25 s and never rotate — blueprint priority is Bloons-grade readability (risk: juice overreach). FxLayer and the UI CanvasLayer sit outside `Board`, so floaters, coin arcs and HUD stay stable. Stage 2's ground already overdraws the viewport, so 5 px reveals no edges.
- **Coordinate spaces line up**: no camera + default CanvasLayer transform means world coords == screen coords, so `hud.coin_anchor()` (Control global position) can be used directly as a Node2D target in `FxLayer`. If anyone ever adds a Camera2D, this breaks — leave a comment saying so at `coin_anchor()`.
- **Particles on WebGL2/Compatibility, no threads**: CPUParticles2D cost main-thread ms per particle per frame — exactly what the harness measures; that cost is the honest ceiling for confetti size. GPUParticles2D work under the Compatibility renderer (4.3+) via transform feedback, but on mobile WebGL2 they can jank, and the first emission compiles a shader (visible hitch) — if GPU is even a candidate after measuring, prewarm by emitting each variant once invisibly during `register_game`. `one_shot` particles emit their `finished` signal on completion — that's the pool-return hook (works for both node types). Use `local_coords = false` so a returned-to-pool emitter doesn't drag its dead particles along.
- **`GradientTexture2D` as particle texture**: built-in generated texture (soft radial dot or plain square), serializes into the `.tscn`, needs no asset files, and is the named swap point for Stage 6's `inspiration/fx/kenney-particle-pack` sprites; `color_initial_ramp` with a discrete-interpolation Gradient gives multi-color candy confetti from one emitter.
- **Query params via JavaScriptBridge**: `JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('stress')", true)` — web feature only, call once at `_ready`, never per frame (synchronous JS calls stall the main thread). Desktop fallback is the F9 toggle.
- **Zero balance in code, still**: this stage adds *feel* constants (tween durations, scales, shake px) — those are sanctioned and live as defaults in `juice.gd`/`PerfBudget`, not in `.tres`. It must not touch any damage/cost/hp number.
- **Readability guard**: tune conservative — flash <= 0.1 s, shake <= 5 px, wobble strength ~0.07. If the stress view looks like soup, lower amplitudes before lowering counts; the game must stay readable mid-storm (blueprint §9, Bloons reference).

## Juice checklist

This stage IS the juice stage — everything below ships now, wired into real gameplay:

- [ ] Jelly-wobble on every walking critter (antiphase x/y sine on Skin).
- [ ] Hit flash (overbright modulate) on every projectile impact.
- [ ] Kill = scale punch + confetti burst + 2–3 coins arcing into the HUD counter + "+N" floater, all pooled.
- [ ] HUD coin label pulses on each coin arrival; hearts label thumps on every life lost.
- [ ] Subtle screen micro-shake on leaks (<= 5 px, board only, exact rest restore).
- [ ] Tower squash-and-stretch recoil on every shot; bounce-in overshoot on build.
- [ ] Pad pulse on tap (migrated into Juice).
- [ ] Bouncy wave banner on wave start + quick "Clear!" on wave end.
- [ ] Every button in every menu press-squishes (centered pivot).
- [ ] All of it within PerfBudget caps — effects visibly *drop* (never hitch) past the caps in stress mode.

## Acceptance criteria

- [ ] Side-by-side with the Stage 2 deploy, the map 1 slice is unmistakably juicier: wobble, flashes, confetti, coin arcs, shake, banner — with identical gameplay numbers (same waves, coins, lives outcomes).
- [ ] Coins are credited at the kill instant (HUD number ticks immediately); the coin flight is cosmetic only.
- [ ] A full map 1 run followed by Retry and a second full run produces zero console errors and no orphaned FX; `OBJECT_NODE_COUNT` in the stress overlay stays flat over minutes of stress (pooling works, nothing leaks).
- [ ] During waves, no `instantiate()`/`queue_free()` executes in gameplay hot paths (code audit of `game.gd`, `tower.gd`, `enemy.gd`, `projectile.gd`, `juice.gd`) — pools only; towers retarget on the 0.1 s cadence.
- [ ] A recycled enemy (killed, re-activated) is never hit by a projectile launched at its previous life (generation check verifiable in code review; no misdirected homing observed in stress).
- [ ] Normal load (`index.html` with no params) shows no overlay and no way for a player to stumble into stress mode; `?stress=1` on the deployed build shows the overlay, sustains the enemy target, and its thumb-sized toggles work on a phone.
- [ ] `scripts/perf_budget.gd` exists; header records device/browser/date/results + the particle decision and why; status says `MEASURED` (or `PROVISIONAL` with the emulation caveat and a Stage 8 re-verify note). All FX caps at call sites reference `PerfBudget.*` (grep shows no duplicate magic caps).
- [ ] Exactly one confetti scene remains in the repo (the measured winner); the loser and the backend switch are deleted.
- [ ] Stress at the recorded caps holds ~60 fps with a 50 fps floor on the measurement device (or the budget was consciously lowered until it does, and the header says so).
- [ ] At FX caps, extra effects degrade gracefully (confetti/flyers drop, floaters recycle oldest) — no hitches, no warnings spam in normal play.
- [ ] Every new scene/script has its `*.uid` committed; the PR build is green.

## Verification

1. Local headless (skip to step 4 if `godot` is unavailable — CI + branch deploy are the authoritative gates):
   ```sh
   godot --headless --import          # zero script errors
   godot --headless --export-release "Web" build/web/index.html
   python3 -m http.server 8080 -d build/web
   ```
2. Chrome, DevTools device toolbar (Pixel 7 portrait, touch on): play a full map 1 win. Confirm every Juice-checklist item by eye, tap-away/pad taps still behave (juice must not break Stage 2 input), Retry then re-play one wave (pool rebuild), and `?stress=1` + F9 both bring up the harness locally.
3. Emulation stress pass: CPU throttle 4x, run stress at 40/80/120 enemies on both backends; note numbers (these are the fallback measurements).
4. Branch deploy for the real measurement: `gh workflow run deploy.yml --ref stage-03-juice-engine`, `gh run watch`, then on a mid-range Android phone in Chrome open the Pages URL with `?stress=1` (both backends via the overlay toggle). Record FPS/worst-frame at each enemy target. No phone available → keep step 3's numbers and mark the budget `PROVISIONAL`.
5. Finalize `perf_budget.gd` numbers + decision header; delete the losing backend; re-run steps 1–2 once to confirm nothing broke.
6. Push, open the PR (measurement table + decision rationale in the description); `deploy.yml` PR build must be green.
7. "Smooth" here means, concretely: stress mode at the shipped `PerfBudget` caps sustains >= 50 fps (target ~60) on the measurement device with no frame > 50 ms after the first two seconds; normal map 1 play never dips below 55 fps in 4x-throttled emulation.
8. After merge: confirm the `main` deploy went green (it also refreshes Pages after the branch deploy), then play the live build on a phone — one normal run for feel, one `?stress=1` run to confirm caps on the shipped artifact.

## Out of scope

- Upgrade sparkle + scale punch, sell coin-shower + deflate puff, per-behavior projectile/impact FX, boss entrance shake, invalid-tap wiggle, and extending the stress harness to the full roster — **Stage 4**.
- Player-facing debug accelerators (2x/4x fast-forward, free-build toggle) — **Stage 4** (the harness's internal free tier-3 fill is not that feature).
- Maps 2–3, endless mode, `SaveGame`, MapSelect — **Stage 5**.
- Kenney sprites for particles/coins/entities (swap at `Skin`/`GradientTexture2D` points), theme nine-patches — **Stage 6**.
- All SFX/music, `MAX_SFX_VOICES` in PerfBudget — **Stage 7**.
- Idle wobbles on towers, HUD count-up escalations, hearts pulse at low lives, menu/title bounce-in, low-end re-verification of a `PROVISIONAL` budget, further balance work — **Stage 8**.
- Any gameplay/balance change, new tower/enemy content, thread enablement, renderer change — never in this stage.

## Handoff

After this stage, later stages may rely on:

- `Juice` autoload (registered after `Events`) with the stable API: `register_game(fx_layer, shake_target, hud)`, `claim/release(item)`, `punch_scale`, `bounce_in`, `squash`, `flash`, `pop_in_out`, `wobble_scale`, `shake`, `floater`, `coin_burst`, `confetti`, `squishify_button` — all budget-enforcing, all safe to call every frame at caps (graceful drop). Juice never listens to Events; call sites own their juice.
- The claim/rest-state contract: entities claim their `Skin` on activate, `release` on pool return; one Juice tween per item; wobble owns `Skin.scale` while walking. Stage 4's new towers/enemies get full juice by following the same calls.
- `scripts/object_pool.gd` (`ObjectPool`, GROW_WARN/DROP policies) and live pools: enemies + projectiles in `game.gd`, floaters/coin flyers/confetti in Juice under `Game/FxLayer`; the `active` + `generation` validity contract for anything pooled.
- `scripts/perf_budget.gd` (`PerfBudget`) with measured (or explicitly PROVISIONAL) caps that every later stage must respect, and the **final** particle-backend decision recorded in its header — one confetti scene, no runtime switch.
- `scenes/ui/wave_banner.tscn` (`WaveBanner`) self-wired to `wave_started`/`wave_cleared`; `scenes/ui/floater.tscn`, `scenes/ui/coin_flyer.tscn`, `scenes/fx/confetti_*.tscn` (winner) as Stage 6 swap points; `hud.coin_anchor()` + `hud.pulse_coins()`.
- The stress harness (`?stress=1` / F9, `scripts/debug/stress_test.gd` + overlay) with FPS/frame-time/pool metrics and enemy-count cycling, ready for Stage 4 to extend to the full roster, plus the `gh workflow run deploy.yml --ref <branch>` measurement workflow.
