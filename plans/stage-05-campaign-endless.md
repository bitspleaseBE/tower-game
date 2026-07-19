# Stage 5: Campaign, Endless Mode & Local Saves

**Status:** done

Objective: after this stage, the game has its whole final shape — tapping Play on the main menu opens a MapSelect screen with three portrait map cards (Meadow Munch, Sugar Switchback, Loop-de-Loop), each showing locked/unlocked/beaten state and its endless best wave; beating a map unlocks the next with a little confetti ceremony; every beaten map can be played in endless mode, where after the scripted waves the game generates ever-scaling waves until the player falls, the HUD showing "Wave 17 · Best 23" and defeat celebrating a "NEW BEST!"; the win overlay offers Next map! / Go endless! / Menu; and all of it — beaten flags and best waves — provably survives a browser reload of the deployed web build via `user://save.cfg`. Blueprint §11 bullets 1–3 become functionally complete in placeholder art.

## Prerequisites

Stage 4 ("Full Roster & Map 1 Campaign", slug `tower-roster`) must be merged and deployed, on top of Stages 1–3. Verify each; if any check fails, stop and fix the earlier stage first.

- [ ] Full enemy roster exists: `ls data/enemies/` shows normal, fast, swarm, armored, and boss `.tres` files (note the exact ids/filenames — the wave tables below use `normal/fast/swarm/armored/boss`; substitute the real ids if Stage 4 named them differently).
- [ ] Four towers exist: `ls data/towers/*.tres` shows 4 files; the BuildMenu offers all four in-game.
- [ ] Map 1 is full-length: open `data/maps/map_01.tres` and confirm 12–15 waves.
- [ ] `MapData` schema has the endless params: `grep -n 'endless_' scripts/data/map_data.gd` shows `endless_hp_growth`, `endless_count_growth`, `endless_speed_growth`.
- [ ] Map injection seam exists: `grep -n 'map_data' scripts/game.gd` — Stage 2 left `var map_data: MapData` defaulting to a `preload` of map_01 with a comment that Stage 5 injects it. Read `scripts/game.gd` and `scripts/wave_spawner.gd` fully; this stage rewires both.
- [ ] Events bus declares `endless_best(map_id, wave)` and `run_won(map_id)`: `grep -n 'endless_best\|run_won' scripts/autoload/events.gd`.
- [ ] Juice + budget live: `grep 'Juice=' project.godot`, `ls scripts/perf_budget.gd`, and `grep -n 'func ' scripts/autoload/juice.gd` (note the exact helper names — punch/bounce/`wiggle` — this stage reuses them; also note which functions require `register_game` vs work unregistered). Stage 4 owns `Juice.wiggle` — if the grep misses it, add the helper before MapSelect work (do not invent a parallel tween).
- [ ] One confetti scene survived Stage 3's measurement: `ls scenes/fx/` (this stage instances the winner directly for two celebrations).
- [ ] Stage 4 debug accelerators exist (2x/4x fast-forward, free-build): `grep -rn 'time_scale' scripts/` — you need them for the tuning pass.
- [ ] CI green on `main` (`gh run list --branch main --limit 1`) and https://bitspleasebe.github.io/tower-game/ plays map 1's full campaign on a phone.
- [ ] Godot availability: `godot --version` prints 4.7.x; if absent, all headless verification falls back to the PR CI build + `workflow_dispatch` branch deploys.
- [ ] Work on a branch: `git checkout -b stage-05-campaign-endless`.

## Tasks

Ordered so persistence and data exist before the flow that displays them. The schedule flex point is task 9 (tuning depth): wave *authoring* must ship complete, but ramp polish may lean on Stage 8 — say so in the PR if you lean.

### 1. `SaveGame` autoload — `scripts/autoload/save_game.gd`

- [x] Plain `extends Node`, mirroring `scripts/settings.gd`'s ConfigFile pattern exactly (`const SAVE_PATH := "user://save.cfg"`, `_load()` in `_ready()`, `_save()` writing the whole file; `push_warning` if `config.save()` returns non-OK). One section per map id: `[map_01] beaten=bool best_endless_wave=int` (absent → `false`/`0`).
- [x] Campaign order is the single source of truth here: `const CAMPAIGN: Array[StringName] = [&"map_01", &"map_02", &"map_03"]`. MapSelect derives `.tres` paths as `"res://data/maps/%s.tres" % id`.
- [x] API: `is_beaten(id) -> bool`, `best_endless_wave(id) -> int`, `is_unlocked(id) -> bool` (map_01 always; else previous CAMPAIGN entry beaten), `mark_beaten(id)` (saves immediately; if this flips the next map's `is_unlocked` false→true, set `just_unlocked` to that next id), `record_endless_wave(id, wave) -> bool` (true + save immediately + `Events.endless_best.emit(id, wave)` when `wave` beats the stored best; else false, no write).
- [x] Transient state, clearly commented **never persisted to disk**: `var run_map: MapData = null`, `var run_endless := false` (the run request `Game` reads at `_ready`; survives `reload_current_scene()` so Retry relaunches the same setup), and `var just_unlocked: StringName = &""` (MapSelect reads + clears for the unlock ceremony).
- [x] In `_ready()`, connect `Events.run_won` → `mark_beaten(map_id)`. Persistence is SaveGame's job; `game.gd` never writes files.
- [x] Register in `project.godot` `[autoload]` **between `Events` and `Juice`**: `SaveGame="*res://scripts/autoload/save_game.gd"` (it connects to Events at ready, so Events must precede it).
- [x] Remove the now-stale `@warning_ignore("unused_signal")` on `endless_best` in `events.gd`.

### 2. Maps 2 & 3 as data — `data/maps/map_02.tres`, `data/maps/map_03.tres`

Author per Stage 2's hand-authoring notes (typed arrays as `Array[ExtResource("...")]([SubResource(...)])`; or generate once via a throwaway `godot --headless --script` + `ResourceSaver.save()` and delete the script). All numbers below are first guesses — tune ONLY by editing `.tres`.

- [x] **map_02 — "Sugar Switchback"** (serpentine, enters top-RIGHT — mirrors map 1): `starting_coins 110`, `starting_lives 15`.
  - `path_points`: `(760, 220), (160, 220), (160, 460), (600, 460), (600, 700), (160, 700), (160, 940), (760, 940)` — four horizontal lanes, tight 240 px spacing.
  - `pad_positions` (7 pads — fewer than map 1, choices hurt): `(300, 340), (520, 340), (300, 580), (480, 580), (300, 820), (480, 820), (360, 1040)`.
- [x] **map_03 — "Loop-de-Loop"** (self-crossing route; the path crosses itself at (560, 480) — a double-coverage hotspot; Line2D just overdraws, enemies walk through): `starting_coins 130`, `starting_lives 10`.
  - `path_points`: `(-40, 240), (560, 240), (560, 900), (160, 900), (160, 480), (680, 480), (680, 1040), (760, 1040)`.
  - `pad_positions` (8 pads): `(70, 360), (250, 360), (430, 360), (660, 360), (300, 690), (450, 690), (300, 1020), (470, 1020)`.
  - Both coordinate sets are verified against the layout rules (pads ≥ 90 px from every path segment centerline, ≥ 110 px apart, on the 720-wide screen, board band y ≈ 160–1040) — after authoring, run `map_lint.gd` (created later in this same task) and fix any FAIL before continuing.
- [x] Wave lists (notation: `count×id @spawn_interval`, `(+Ns)` = group `start_delay`). Calibrate against merged map 1: map 2 wave 4 should feel like map 1 wave 7. Counts may shift ±30% in task 9.
  - **map_02, 13 waves:** W1 `8×normal @1.0` · W2 `10×normal @0.9 + 4×fast (+4s) @0.8` · W3 `12×swarm @0.4` · W4 `8×fast @0.7 + 6×normal @0.9` · W5 `6×armored @1.2` · W6 `14×swarm @0.35 + 6×fast (+3s) @0.7` · W7 `1×boss + 8×normal (+2s) @0.8` · W8 `8×armored @1.0 + 10×swarm (+4s) @0.4` · W9 `12×fast @0.55` · W10 `10×armored @0.9 + 8×fast (+5s) @0.6` · W11 `20×swarm @0.3 + 6×armored (+4s) @1.0` · W12 `14×fast @0.5 + 10×armored (+3s) @0.8` · W13 `2×boss @6.0 + 12×swarm (+3s) @0.4 + 8×fast (+8s) @0.6`.
  - **map_03, 14 waves:** W1 `10×normal @0.9` · W2 `8×fast @0.7 + 8×swarm (+3s) @0.4` · W3 `8×armored @1.0` · W4 `16×swarm @0.3 + 6×fast (+4s) @0.6` · W5 `1×boss + 10×swarm (+2s) @0.4` · W6 `10×fast @0.5 + 8×armored (+3s) @0.9` · W7 `24×swarm @0.25` · W8 `12×armored @0.8` · W9 `14×fast @0.45 + 12×swarm (+3s) @0.3` · W10 `1×boss + 8×armored (+2s) @0.9` · W11 `18×fast @0.4 + 10×armored (+4s) @0.7` · W12 `30×swarm @0.22 + 6×armored (+5s) @0.9` · W13 `14×armored @0.6 + 14×fast (+3s) @0.4` · W14 `2×boss @8.0 + 16×swarm (+2s) @0.3 + 10×fast (+10s) @0.5 + 8×armored (+6s) @0.8`.
- [x] Set explicit endless growth params in all THREE map `.tres` files (map_01 edit is in-scope for these three fields only): map_01 `1.14 / 1.06 / 1.015`, map_02 `1.16 / 1.07 / 1.02`, map_03 `1.18 / 1.08 / 1.02` (hp / count / speed).
- [x] `scripts/debug/map_lint.gd` — `extends SceneTree`, run as `godot --headless --script scripts/debug/map_lint.gd` (after `--import`). For every `data/maps/*.tres`: assert pad-to-path-segment distance ≥ 90, pad-to-pad ≥ 110, pads inside x 60–660 / y 190–1040, path inside x −80–800 / y 160–1060, 12–15 waves, every SpawnGroup has a non-null enemy and count > 0. Print PASS/FAIL per map, `quit(1)` on any failure. Keep it — Stage 8 reuses it while rebalancing.

### 3. Endless wave generator — `scripts/endless_waves.gd`

- [x] `class_name EndlessWaves extends RefCounted`, one pure static entry point — deterministic (no RNG), so every endless run of a map is the same fair gauntlet:
  ```gdscript
  static func generate(map: MapData, wave_number: int) -> WaveData
  ```
  With `scripted = map.waves.size()` and `k = wave_number - scripted` (k ≥ 1): template = the last `TEMPLATE_TAIL := 5` scripted waves cycled in order (`map.waves[scripted - TAIL + ((k - 1) % TAIL)]`) — the finale boss wave recurs naturally every 5th endless wave. Multipliers: `hp_mult = pow(map.endless_hp_growth, k)`, `count_mult = pow(map.endless_count_growth, k)`, `speed_mult = minf(pow(map.endless_speed_growth, k), SPEED_MULT_CAP)`.
- [x] Build the returned WaveData from **fresh** `WaveData.new()`/`SpawnGroup.new()` plus `template_group.enemy.duplicate()` with `hp *= hp_mult`, `speed *= speed_mult` — NEVER mutate the loaded template resources (see Implementation notes). `bounty`, `lives_cost`, `armor`, `is_boss`, `id` stay untouched (Skin variants and boss behaviors keep keying off them).
- [x] Counts: `ceili(count * count_mult)`; if the wave's total spawn count exceeds `wave_cap()` (`PerfBudget.MAX_ENEMIES / 2` — pool headroom for inter-wave carryover), scale all group counts down proportionally (`maxi(1, ...)`). `spawn_interval = maxf(template interval, INTERVAL_FLOOR := 0.25)`.
- [x] Sanctioned constants here (fairness/perf guards, NOT balance — balance is the `.tres` growth params): `TEMPLATE_TAIL = 5`, `SPEED_MULT_CAP = 1.5`, `INTERVAL_FLOOR = 0.25`, `wave_cap()`. Comment each as such.

### 4. Run modes — `scripts/game.gd` + `scripts/wave_spawner.gd`

- [x] `game.gd` gains `var endless := false` and reads the run request in `_ready()`: if `SaveGame.run_map` is set, `map_data = SaveGame.run_map; endless = SaveGame.run_endless`; else keep the Stage 2 map_01 preload fallback with `endless = false` (editor F5 on game.tscn still works). Snapshot `var best_at_run_start := SaveGame.best_endless_wave(map_data.id)`.
- [x] `game.gd` exposes `get_wave(n: int) -> WaveData`: `map_data.waves[n - 1]` while `n <= map_data.waves.size()`, else `EndlessWaves.generate(map_data, n)`. The spawner stops touching `map_data.waves` directly and requests every wave through this.
- [x] `wave_spawner.gd` loop change: after CLEARING wave `n` — campaign mode AND `n == total_scripted` → WON (emit `run_won`, exactly as today); otherwise re-arm COUNTDOWN for wave `n + 1` forever. Keep emitting `Events.wave_started.emit(n, total_scripted)` unchanged (consumers key off mode, not a changed payload). Audit every `run_over`-style guard from Stage 2: a won run must be *resumable* (next bullet), a lost run must not.
- [x] `game.gd.enter_endless()` (called by the win overlay's Go endless! button): set `endless = true`, tell the HUD to flip to endless display, call `spawner.resume_endless()` — which clears the won/halt flag and re-enters COUNTDOWN at wave `total_scripted + 1`. Lives, coins, and towers carry over untouched; that continuity is the whole point.
- [x] Best-wave recording is EAGER (a mid-run browser close still keeps your wave): `game.gd` connects `Events.wave_started` → if `endless`, `SaveGame.record_endless_wave(map_data.id, number)`. Recording starts from whenever the run is endless: a from-scratch endless run records wave 1 up; a converted post-win run records from `total_scripted + 1`. The defeat overlay only *celebrates*; it never writes.
- [x] Endless defeat is the existing 0-lives path (`Events.run_lost.emit(map_data.id)`) — no new signal. Navigation retargets: the top-bar Menu button and `ui_cancel` in game now go to `res://scenes/map_select.tscn` (canonical flow: ResultOverlay/Game → MapSelect).

### 5. HUD — current vs best wave

- [x] `hud.gd` gains `setup_run(total_waves: int, endless: bool, best: int)` called from `Game._ready()` (and again from `enter_endless()`). Campaign renders the wave label as today (`"Wave 3/13"`); endless renders `"Wave 14 · Best 23"` (best 0 → just `"Wave 14"`). Store `best` locally.
- [x] Connect `Events.endless_best` → update the stored best, re-render, and `Juice.punch_scale` the wave label (pivot centered) — the mid-run "new best" tick. The big celebration stays on the defeat overlay.

### 6. ResultOverlay grows — `scenes/ui/result_overlay.tscn` + `scripts/ui/result_overlay.gd`

- [x] `Game._ready()` hands the overlay its context: `result_overlay.setup(game)` (it reads `game.map_data`, `game.endless`, `game.best_at_run_start` at show time; it already tracks the current wave from `wave_started`). Three variants, all short and bouncy (blueprint §8), all buttons ≥ 88 px, bottom-anchored, squishified:
  - **Campaign win** (`run_won`): title "Path defended!". Buttons: `Next map!` (only when `SaveGame.CAMPAIGN` has a successor — hidden after map_03, where the title becomes "All paths defended!"), `Go endless!`, `Menu`.
  - **Campaign lose** (`run_lost`, not endless): title "The critters got through!" — Retry / Menu, as today.
  - **Endless defeat** (`run_lost`, endless): title `"Wave %d wants a word."` (the blueprint's own line), below it `"Best: wave %d"` from SaveGame; when the best beat `best_at_run_start`, add a big "NEW BEST!" label punch-scaled in, and fire the celebration confetti. Buttons: Retry / Menu.
  - Button wiring (every one unpauses FIRST — Stage 2's rule): `Next map!` → `SaveGame.run_map = load(next map path); SaveGame.run_endless = false; change_scene_to_file("res://scenes/game.tscn")` (changing to the currently-running scene file is fine). `Go endless!` → unpause, hide overlay, `game.enter_endless()` — no scene change. `Retry` → `reload_current_scene()` (run_map/run_endless persist, so an endless retry restarts endless). `Menu` → `res://scenes/map_select.tscn`.
- [x] Celebration confetti: the overlay embeds two instances of the surviving `scenes/fx/confetti_*.tscn` (positioned upper-left/upper-right of the panel), `process_mode = PROCESS_MODE_ALWAYS` — the tree is paused under the overlay and `Juice.confetti()` pool bursts would freeze; these local one-shots `restart()` on new-best reveal instead. Do not route them through Juice's pools.

### 7. MapSelect flow — `scenes/map_select.tscn`, `scenes/ui/map_card.tscn`

- [x] `scenes/ui/map_card.tscn` (root `MapCard`, PanelContainer, `custom_minimum_size ≈ (640, 270)`, script `scripts/ui/map_card.gd`):
  ```
  MapCard (PanelContainer)
  └─ Margin (MarginContainer, 20) ► HBox (HBoxContainer, sep 16)
     ├─ Preview (Control, 130×230 min, script scripts/ui/map_preview.gd)   # _draw(): map shape mini-render
     └─ Info (VBoxContainer, expand)
        ├─ NameLabel (display_name, font 34)  ·  Badge (Control 44×44 ► Skin (Node2D) ► gold star Polygon2D; beaten only)
        ├─ StatusLabel
        └─ Buttons (HBoxContainer): PlayButton · EndlessButton
  ```
  `setup(map: MapData, unlocked: bool, beaten: bool, best: int, prev_name: String)` drives three states: **locked** — `modulate` dimmed to ~0.55, buttons hidden, StatusLabel "Beat %s first!" (prev_name), any tap on the card calls `Juice.wiggle(card)` (Stage 4 API — horizontal rejection wiggle, returns to claimed rest); **unlocked** — PlayButton "Play!", StatusLabel "A fresh path!"; **beaten** — Badge shown, PlayButton "Replay", EndlessButton "Endless!", StatusLabel "Best: wave %d" (best 0 → "Endless awaits!"). Buttons ≥ 88 px tall. Card emits `play_pressed(endless: bool)`.
- [x] `scripts/ui/map_preview.gd`: store `PackedVector2Array` points + pad positions scaled by ~0.16 into the 130×230 box; `_draw()` with `draw_polyline(points, path sand color, 6.0, true)` + `draw_circle` per pad (lilac, r 5) — the three route shapes ARE the card art, straight from data. This Control is a named Stage 6 swap point (thumbnail sprites replace the draw).
- [x] `scenes/map_select.tscn` (root `MapSelect`, Control full rect, script `scripts/map_select.gd`): cream `Background` ColorRect; `Title` Label "Pick a path!" top-center; `Cards` VBoxContainer (center-anchored, width 640, separation 24) with three MapCard instances; `BackButton` (ButtonSecondary, 520×88, bottom-center, 56 px margin) → main menu, `ui_cancel` ditto; `UnlockFx` (Node2D) holding one instance of the surviving confetti scene for the unlock ceremony. Keyboard: `grab_focus()` the first visible enabled button (desktop parity).
- [x] `map_select.gd._ready()`: for each id in `SaveGame.CAMPAIGN`, `load("res://data/maps/%s.tres" % id)` and `setup` its card from SaveGame state. `play_pressed(endless)` → `SaveGame.run_map = map; SaveGame.run_endless = endless; change_scene_to_file("res://scenes/game.tscn")`.
- [x] Flow rewiring: `main_menu` New Game button now reads "Play" and opens `map_select.tscn` (same handler method, retargeted path + text). Confirm the full canonical loop: MainMenu → MapSelect → Game → ResultOverlay → MapSelect.

### 8. Unlock & selection juice

- [x] Cards staggered bounce-in on MapSelect load (scale 0→1, `TRANS_BACK`, ~0.08 s apart — the Stage 1 menu pattern; set `pivot_offset = size / 2.0` after layout).
- [x] Unlock ceremony: if `SaveGame.just_unlocked` matches a card, clear it, then ~0.5 s after load: punch-scale that card, position `UnlockFx` over it and `restart()` the confetti, pop a small "Unlocked!" label above the card (local tween — Juice's pooled floaters are game-scene-only). One burst, within `PerfBudget` amounts.
- [x] Badge star idle: gentle scale pulse loop on its `Skin` (~1.0→1.08, sine, randomized phase) — beaten cards read alive.
- [x] Press feedback: `Juice.squishify_button` on every new button (cards, back, overlay); locked-card wiggle per task 7; WaveBanner gains `announce(text)` and `enter_endless()` calls `announce("Endless!")` once.

### 9. Campaign beatability + endless validation pass (the flex task)

- [ ] With the Stage 4 accelerators (2x/4x, free-build for probing only), play campaign start-to-finish in order: map 1 → 2 → 3, each beatable by an attentive first-timer in a 5–10 minute honest-speed run, ramp strictly rising (map 2 opens harder than map 1's midgame). Fix blockers by editing wave/`.tres` numbers only; log non-blocking ramp roughness for Stage 8 in the PR.
- [ ] Endless validation per map: one 10+ wave endless run each (accelerated). Confirm: waves visibly stiffen (hp/count/speed), a maxed board eventually falls (hp growth must outpace fixed DPS — expect defeat within ~8–15 generated waves), spawn counts clamp at `wave_cap()` without pool warnings, boss waves recur ~every 5th, and the run never trivializes or brick-walls at k=1. Adjust the three growth params per map if needed.
- [ ] Verify `?stress=1` still works end-to-end now that game.tscn is reached via MapSelect (harness activation is inside the Game scene and must be unaffected).

### 10. Verify, commit, PR

- [ ] Run the Verification section end-to-end (including BOTH reload persistence tests).
- [ ] `git add -A`; confirm every new `*.uid` is staged (`git status --short | grep uid` — new: save_game, endless_waves, map_lint, map_select, map_card, map_preview scenes/scripts). Commit with a descriptive message (e.g. "Stage 5: 3-map campaign + MapSelect, endless mode with scaling waves, SaveGame persistence to user://save.cfg"), push, open a PR to `main` whose description records the persistence-test evidence and any tuning debts left for Stage 8, confirm the CI web-export build is green, merge, then re-verify persistence on the live Pages build (below).

## Implementation notes

- **Never mutate loaded `.tres` resources**: a loaded `EnemyData` is shared by every spawner/reference in the session — scaling `hp` on it directly would corrupt the campaign for the rest of the run (until a full reload). Endless scaling must operate on `duplicate()`d EnemyData and fresh WaveData/SpawnGroup objects each generated wave (a handful of tiny allocations per ~30 s wave — no pooling concern). Same rule if the tuning pass tempts you to tweak numbers at runtime: edit files, not live resources.
- **Web `user://` persistence timing**: on the web export `user://` is an IndexedDB-backed virtual FS; Godot flushes writes asynchronously shortly after file close. Two rules follow: save at the *moment of change* (`mark_beaten` at `run_won`, `record_endless_wave` at wave start), never batch to "on quit" — `NOTIFICATION_WM_CLOSE_REQUEST` is unreliable on web and a closing tab loses unflushed writes; and by the time a human sees the win overlay and reaches for reload, the flush (< ~1 s) is long done. The reload tests in Verification are the proof, not an assumption.
- **ConfigFile hygiene**: mirror `settings.gd` — defaults via `config.get_value(section, key, fallback)` so a missing/corrupt `save.cfg` yields a fresh profile, never a crash. `config.load()` failing is NORMAL on first run.
- **Pause interplay (restating Stage 2's trap, two new ways to hit it)**: the overlay pauses the tree. Every overlay button unpauses BEFORE `change_scene_to_file`/`reload_current_scene`; `Go endless!` unpauses before `enter_endless()` or the countdown never ticks. Pooled `Juice.confetti()` bursts freeze under pause — that is why the new-best celebration uses overlay-local `PROCESS_MODE_ALWAYS` confetti instances instead.
- **Resuming a "won" spawner**: Stage 2 guards every `await` resume with a run-over flag. `resume_endless()` must clear the won-flavored halt and re-enter the COUNTDOWN state at `total_scripted + 1`; the lost-flavored halt stays permanent. Read the actual flag structure in `wave_spawner.gd` before touching it, and re-test that a *lose* still halts every pending `await`.
- **Signal payload stability**: keep `wave_started(number, total)` emitting the scripted total in endless too — HUD/banner render by mode, no consumer needs a schema change, and Stage 3's banner keeps working untouched.
- **Juice outside the Game scene**: transform helpers (`punch_scale`, `bounce_in`, `squishify_button`, wiggle) are node-local and must work unregistered (Stage 3 designed them so — verify; fix in place if any accidentally requires registration). Pool-backed FX (`confetti`, `floater`, `coin_burst`, `shake`) no-op outside a registered Game scene — hence local confetti instances in MapSelect and ResultOverlay, and a plain tweened Label (not `Juice.floater`) for "Unlocked!".
- **Control scale juice pivots**: cards and overlay labels need `pivot_offset = size / 2.0` set after layout (`await get_tree().process_frame` or `call_deferred`) — Stage 1's note, still true.
- **Transient handoff lifetime**: `SaveGame.run_map`/`run_endless` are set by MapSelect and the Next map! button, read by `Game._ready()`, and deliberately NOT cleared on read — that's what makes Retry (scene reload) relaunch the identical setup. They live only in memory; grep `_save()` to confirm they never touch the ConfigFile.
- **Self-crossing path (map 3)**: purely visual/positional — `PathFollow2D` walks the curve linearly, `Line2D` overdraws at the crossing, no collision implications (enemies have no inter-collision). Towers near (560, 480) legitimately hit two passes; that's the map's identity, not a bug.
- **Hand-authoring volume**: two maps × 13–14 waves × 2–4 groups ≈ 90 sub_resources. The throwaway-generator route (build resources in a `--script` run, `ResourceSaver.save()`, delete the script) is strongly recommended over hand-typing; either way `godot --headless --import` must report zero parse/load errors before gameplay work continues, and `map_lint` must PASS.
- **No new balance in code**: growth params, wave compositions, coins/lives all live in `.tres`. Sanctioned new constants: `EndlessWaves`' four guards (task 3), UI copy strings, tween durations. `wave_cap()` derives from `PerfBudget.MAX_ENEMIES` — never a raw number.
- **Untouchables**: renderer, `export_presets.cfg` (threads stay off), `deploy.yml`, `inspiration/`, Stage 3's particle decision, map 1's wave list (beyond the three endless params and blocker-level fixes).

## Juice checklist

- [x] MapSelect cards staggered bounce-in; every new button press-squishes.
- [x] Locked-card tap wiggles (rejection you can feel); beaten badge star idles with a gentle pulse.
- [x] Map-unlock ceremony on the freshly unlocked card: punch + confetti burst + "Unlocked!" pop — once, then consumed.
- [x] "Endless!" banner announcement when a won run rolls into endless.
- [x] HUD wave label punches on every new-best tick mid-run.
- [x] Endless defeat: "NEW BEST!" label punch + overlay confetti celebration (pause-proof).
- [x] All within `PerfBudget` caps — MapSelect and overlays use single local one-shot emitters, never unbounded effects.

## Acceptance criteria

- [ ] Fresh profile (cleared site data): Play opens MapSelect showing map 1 unlocked ("A fresh path!"), maps 2–3 locked and dimmed with "Beat … first!"; tapping a locked card wiggles it and starts nothing.
- [ ] Beating map 1 shows the win overlay with Next map! / Go endless! / Menu; returning to MapSelect shows map 1 beaten (badge) and map 2 unlocked with the one-time ceremony; beating map 2 unlocks map 3; map 3's win shows "All paths defended!" with no Next map!.
- [ ] Next map! launches the next map's campaign directly; Menu (overlay and in-game top bar) returns to MapSelect; Retry after a campaign loss restarts the same map; each map's path/pad layout is visibly distinct and matches its card preview.
- [ ] Go endless! continues the just-won run seamlessly — same towers, coins, and remaining lives — with the countdown re-arming for wave `scripted + 1` and the HUD flipping to "Wave N · Best M"; Endless! on a beaten card starts an endless run from wave 1.
- [ ] Endless waves keep coming after the scripted list and get measurably harder per the map's growth params; enemy speed never exceeds 1.5× base; per-wave spawn totals clamp at `PerfBudget.MAX_ENEMIES / 2` with no pool warnings; a boss wave recurs roughly every 5th generated wave; a maxed board is eventually overwhelmed on every map.
- [ ] Endless defeat overlay reads "Wave N wants a word." with "Best: wave M"; when the run set a new best it celebrates NEW BEST! with confetti that visibly animates while the tree is paused; Retry restarts endless on the same map.
- [ ] Best recording is eager: dying is not required — reaching wave N then reloading the page still shows Best ≥ N on the card.
- [ ] `user://save.cfg` holds exactly one section per map with `beaten` and `best_endless_wave`; SaveGame writes at every change; `run_map`/`run_endless`/`just_unlocked` never appear in the file.
- [ ] Persistence survives reload on the DEPLOYED build (Verification steps 4–5) — beaten flags, unlocks, and bests all intact.
- [ ] `map_lint` passes for all three maps; `godot --headless --import` is error-free; no balance numbers appear in the stage's script diff (audit `save_game.gd`, `endless_waves.gd`, `game.gd`, `wave_spawner.gd`, `map_select.gd`, `map_card.gd`).
- [ ] All new UI copy is short and bouncy per blueprint §8 (no sentence over ~6 words on cards/overlays); every new scene/script has its `*.uid` committed; the PR build is green.

## Verification

1. Local headless (skip to step 3 if `godot` is unavailable — CI + branch deploy are the authoritative gates):
   ```sh
   godot --headless --import                                   # zero errors, all .tres parse
   godot --headless --script scripts/debug/map_lint.gd         # PASS ×3
   godot --headless --export-release "Web" build/web/index.html
   python3 -m http.server 8080 -d build/web
   ```
2. Chrome DevTools device toolbar (Pixel 7 portrait, touch on): walk the full flow — fresh profile (Application → Clear site data), Play → MapSelect states correct → beat map 1 (accelerators allowed) → win overlay → Go endless! continuity → die → NEW BEST celebration → Menu → ceremony + unlocked map 2. Then map 2 and map 3 campaign wins (accelerated), one from-scratch endless run.
3. **Local reload persistence test**: after beating map 1 and setting an endless best, reload the tab (F5) — MapSelect must show beaten/unlocked/best exactly as before. This is the same IndexedDB path the deploy uses; catch failures here first.
4. Branch deploy for the deployed-build proof: `gh workflow run deploy.yml --ref stage-05-campaign-endless`, `gh run watch`, then on a phone (or desktop Chrome) open the Pages URL: beat map 1, note the states, **reload the page**, confirm beaten + unlock + best survived; play 3+ endless waves, reload, confirm the eager best survived. Record the evidence in the PR description.
5. Push, open the PR; the `deploy.yml` PR build must be green. After merge, `main` redeploys — repeat the reload check once on the live URL and play map 2 or 3 one-thumbed on a real phone.
6. "Smooth" here means: MapSelect and overlays hold 60 fps in 4×-throttled emulation (they're near-static — anything less is a runaway tween); deep endless (scripted + 10) at clamped spawn caps stays at or above Stage 3's measured floor (≥ 50 fps) with zero console errors; scene transitions (menu ↔ select ↔ game) show no hitch or dark flash.

## Out of scope

- Kenney art for cards/badges/previews, theme nine-patches, real icons — **Stage 6** (Badge `Skin`, `MapPreview._draw`, and the confetti texture are the named swap points).
- All SFX/music (unlock sting, new-best fanfare, button taps) — **Stage 7** ([stage-07-audio.md](stage-07-audio.md)).
- Final balance sweep, endless-curve polish, low-lives hearts pulse, map-select transition polish, first-run hint, copy audit, README rewrite, version bump, mid-run reload QA — **Stage 8** ([stage-08-release.md](stage-08-release.md); hand it the tuning-debt list from task 9; every cut/debt must appear in the PR description under a `## Stage 8 follow-ups` heading so Stage 8 can ingest it).
- Re-authoring map 1's waves or any tower/enemy stats (Stage 4 owns those; Stage 8 tunes) — this stage touches map_01.tres for the three endless params only.
- New towers, enemies, behaviors, or a fourth map; difficulty selects; meta progression, accounts, cloud saves (blueprint non-goals — local `save.cfg` only).
- Any change to renderer, threads, export preset, particle backend, or `PerfBudget` caps.

## Handoff

After this stage, later stages may rely on:

- **The complete game shape**: MainMenu → MapSelect → Game(MapData) → ResultOverlay → MapSelect, all blueprint §11 bullets 1–3 functional in placeholder art — Stage 6 reskins, Stage 7 sonifies, Stage 8 polishes; nobody adds mechanics.
- **`SaveGame` autoload** (registered between Events and Juice): `CAMPAIGN` order const, `is_beaten` / `is_unlocked` / `best_endless_wave` / `mark_beaten` / `record_endless_wave` (emits `Events.endless_best`), save-on-change to `user://save.cfg` (`[map_id] beaten best_endless_wave`), plus the transient `run_map` / `run_endless` / `just_unlocked` contract (never persisted; Retry-safe).
- **Run modes in `game.gd`**: `endless` flag, `get_wave(n)` seam (scripted then generated), `enter_endless()` continuation, eager best recording — and `EndlessWaves.generate()` as the deterministic, PerfBudget-clamped generator.
- **Three tuned-enough maps as data**: `data/maps/map_0{1,2,3}.tres` with distinct verified layouts (S-curve / switchback / self-crossing), 12–15 waves each, explicit per-map endless growth params; `scripts/debug/map_lint.gd` guards any future layout edit (Stage 8: run it after every balance pass **and** wire it into `.github/workflows/deploy.yml` per [VERIFICATION.md](VERIFICATION.md)).
- **UI surfaces to reskin, not rewire**: `MapSelect` + `MapCard` (three states, `play_pressed(endless)`, Badge/Preview swap points), grown `ResultOverlay` (three variants, pause-proof local celebration confetti), HUD endless display, `WaveBanner.announce(text)`.
- **Proven web persistence**: the save path is verified across reload on the deployed Pages build — Stage 8's "refresh mid-run save integrity" QA builds on this baseline.
