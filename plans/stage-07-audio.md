# Stage 7: Audio — SFX, Music & Web Autoplay

**Status:** done

Objective: after this stage, the live Pages build *sounds* like the blueprint's juice pitch — every kill pops, every build/upgrade/sell and tower shot has a punchy arcade sting, coins tink, leaks thump hearts, waves announce, win/lose and unlock/new-best celebrate, UI buttons click, and one cheerful music loop beds the run — all CC0, all routed through a `Sound` autoload that respects the existing Settings master-volume slider, web autoplay restrictions (first user gesture), pause, scene changes, and `PerfBudget.MAX_SFX_VOICES`. Missing downloaded packs degrade gracefully (silent hooks logged as Stage 8 follow-ups); the stage still merges with whatever audio arrived.

## Prerequisites

Stages 1–6 must be merged and deployed. Verify each; if any check fails, stop and fix the earlier stage first.

- [ ] CI green on `main` and the live build plays the full candy-coated game: `gh run list --branch main --limit 1`, then MapSelect → a map on https://bitspleasebe.github.io/tower-game/.
- [ ] Stage 6 art follow-ups table exists in the Stage 6 PR (or equivalent notes) — know which categories stayed primitive.
- [ ] Audio proposals staged: `ls inspiration/audio/*/SOURCE.md` shows ≥ 1 proposal (Stage 6 task 11). Inventory real files: `find inspiration/audio -type f ! -name 'SOURCE.md' ! -name '.gdignore' | sort`.
- [ ] Skills present: `ls .claude/skills/select-asset/SKILL.md .claude/skills/find-assets/SKILL.md`.
- [ ] Settings master volume already persists: `grep -n 'master_volume\|volume' scripts/settings.gd scripts/settings_menu.gd` — this stage wires the bus, does not redesign the slider.
- [ ] Juice + Events live (SFX hooks attach at call sites / signal owners, never invent a parallel bus): `grep 'Events=\|Juice=' project.godot`.
- [ ] `scripts/perf_budget.gd` exists with the Stage 3 header; note the comment reserving `MAX_SFX_VOICES`.
- [ ] Godot availability: `godot --version` prints 4.7.x; if absent, headless verification falls back to PR CI + branch deploy.
- [ ] Work on a branch: `git checkout -b stage-07-audio`.

## Hook matrix (authoritative)

This is the Stage 7 hook list Stage 6's find-assets pass targets. Implement every row that has a promoted sample; rows without samples stay silent and go to Stage 8 follow-ups.

| Moment | Owner / call site | Suggested id | Notes |
|--------|-------------------|--------------|-------|
| UI button down | `Juice.squishify_button` or each menu `_ready` | `ui_tap` | One shared click; don't per-button variants |
| Build placed | BuildMenu confirm path | `build_place` | |
| Tower upgraded | manage Upgrade path | `upgrade` | |
| Tower sold | manage Sell path | `sell` | |
| Popper fire | `tower.gd` SINGLE | `shot_popper` | Per-type shots |
| Lobber fire | `tower.gd` SPLASH | `shot_lobber` | |
| Chiller pulse | `tower.gd` SLOW | `shot_chiller` | |
| Longshot fire | `tower.gd` SNIPER | `shot_longshot` | |
| Projectile / pulse hit | enemy `take_damage` (non-lethal) | `hit` | Soft; may share across types |
| Enemy killed | death branch after juice | `kill_pop` | |
| Coin earned | kill bounty path (not flyer arrival) | `coin` | Credit-instant; don't wait for arc |
| Enemy leaked / life lost | `game.gd` leak handler | `leak` | |
| Countdown tick | spawner / HUD countdown | `countdown_tick` | Optional soft tick; skip if noisy |
| Wave started | WaveBanner / `wave_started` owner | `wave_start` | |
| Run won | ResultOverlay show (campaign) | `win` | |
| Run lost | ResultOverlay show | `lose` | Endless defeat may reuse `lose` or a softer variant |
| Map unlocked | MapSelect ceremony | `unlock` | |
| New endless best | ResultOverlay NEW BEST / mid-run `endless_best` | `new_best` | Fanfare; don't stack with `lose` |
| Gameplay music loop | `Sound` after first gesture + game enter | `music_game` | One loop; menu may reuse quieter |

## Tasks

### 1. Inventory downloads + promote CC0 samples

- [ ] Build an audio status table (pack → DOWNLOADED / MISSING) for the PR description.
- [ ] One bounded rescue attempt (≤ 15 min total) via `SOURCE.md` mirrors, same discipline as Stage 6 task 1.
- [ ] Invoke `/select-asset` per promoted set into `assets/audio/` with role-based snake_case names matching the hook matrix ids (`kill_pop.ogg`, `shot_popper.ogg`, `music_game.ogg`, …). Prefer Ogg Vorbis for web size; WAV only if tiny UI clicks. Never promote whole packs.
- [ ] Reconcile `assets/ATTRIBUTION.md` for every shipped audio file (CC0 stated).
- [ ] Anything still MISSING: leave the hook as a no-op, list under Stage 8 follow-ups — do not block the stage.

### 2. Buses + `PerfBudget.MAX_SFX_VOICES`

- [ ] Ensure default Godot buses (or create) `Master`, `Music`, `SFX`. Music and SFX both child of Master. No dynamic bus creation at runtime after `_ready`.
- [ ] Add to `scripts/perf_budget.gd`: `MAX_SFX_VOICES := 8` (provisional — tune if stress + audio janks; document in header). Voice limiting is SFX-only; music is one dedicated player.
- [ ] Header comment notes device/browser if audio stress was measured; otherwise `PROVISIONAL` with Stage 8 re-verify.

### 3. `Sound` autoload — `scripts/autoload/sound.gd`

- [ ] Plain `extends Node`, registered in `project.godot` **after** `Juice`: `Sound="*res://scripts/autoload/sound.gd"`.
- [ ] Preload a dictionary of `AudioStream` by `StringName` id from the hook matrix (only ids that have files). Missing ids → omit key (play becomes no-op).
- [ ] Players: one `AudioStreamPlayer` for music (`bus = "Music"`, `stream` looping); a small pool of SFX `AudioStreamPlayer`s (size `PerfBudget.MAX_SFX_VOICES`, `bus = "SFX"`). Acquire free player or steal oldest (DROP policy for cosmetics like overlapping `ui_tap`; never stall).
- [ ] API (stable for Stage 8):
  - `play_sfx(id: StringName, pitch_scale := 1.0, volume_db := 0.0)` — no-op if locked (pre-gesture), missing, or muted.
  - `play_music(id: StringName = &"music_game")` / `stop_music()` / `set_music_ducked(ducked: bool)` (e.g. −8 dB under ResultOverlay).
  - `set_enabled_from_settings()` — reads Settings master volume into Master bus (`linear_to_db`), and a mute-at-zero convention.
  - `unlock_audio()` — called on first qualifying user gesture; sets internal `_unlocked`; until then all play calls no-op (no console spam — one `push_warning` max).
- [ ] Scene lifecycle: stop/release SFX on tree exit of game scene; music may continue across MapSelect ↔ Game if desired, but **must** stop or restart cleanly on full menu return without overlap. Never leave orphan players after `reload_current_scene()`.
- [ ] Pause: SFX players use default pause behavior with the tree; ResultOverlay win/lose stings use `PROCESS_MODE_ALWAYS` players (or play before pause) so they are audible under `get_tree().paused = true` — document the chosen approach.

### 4. Wire Settings master volume

- [ ] On `Sound._ready` and whenever the settings slider changes, apply `Settings` master volume to the Master bus. Prefer connecting a small signal from Settings (add `volume_changed` if absent) over polling.
- [ ] Volume 0 = silent (mute Master or −80 dB); slider still persists to `user://settings.cfg` exactly as today.
- [ ] Settings screen itself can play `ui_tap` only **after** unlock (the slider drag is a gesture — first interaction unlocks).

### 5. Web autoplay / first-gesture unlock

- [ ] On web (`OS.has_feature("web")`), audio starts locked. Unlock on the first `InputEventMouseButton` pressed or button `pressed` at the MainMenu / MapSelect layer — implement once in `Sound` via `_input` or a one-shot connection on the main scene root, not per button.
- [ ] Desktop editor/export may unlock immediately or on first input — either is fine; web is the contract.
- [ ] After unlock, start/resume music when entering Game (and optionally quiet loop on MainMenu/MapSelect — if one loop only, reuse at lower volume via `set_music_ducked` or a volume param).
- [ ] Document in README Conventions (or Stage 8 README rewrite intake): "Audio starts after the first tap (browser autoplay policy)."

### 6. Wire every hook in the matrix

- [ ] Attach `Sound.play_sfx(...)` at the owner call sites listed above — prefer the same moments Stage 3/4 juice already fires (keeps feel coherent). Do **not** make `Juice` listen to Events for audio; call sites own their SFX (same design as Juice).
- [ ] Music: `Game._ready` (after unlock or deferred until unlock) starts `music_game`; ResultOverlay may duck; Menu return stops or returns to menu bed.
- [ ] Rapid-fire cap: Popper shots and `ui_tap` must not explode voice count — stealing oldest is fine; never `instantiate` players per shot.
- [ ] After wiring, `grep -rn 'AudioStreamPlayer\|play(' scripts/` should show Sound owning nearly all playback (local ResultOverlay always-process players are the documented exception).

### 7. Verify, commit, PR

- [ ] Run the Verification section end-to-end.
- [ ] `git add -A`; stage `*.uid` / `*.import` for `assets/audio/`.
- [ ] Commit (e.g. "Stage 7: Sound autoload — CC0 SFX/music, buses, web first-gesture unlock, Settings volume"), push, open PR with audio status table + missing-hook follow-ups, confirm CI green, merge, phone-check live Pages **with sound on**.

## Implementation notes

- **Autoplay is non-negotiable on Pages:** browsers block audio until a user gesture. Silent failure before unlock is correct; never fight with muted autoplay hacks.
- **Master volume already exists:** Stage 1 Settings UI ships the slider. Wire the bus only — do not add a second volume store.
- **CC0 only:** same commercial-release policy as art ([blueprint.md](../blueprint.md) §13). Attribution via `/select-asset`.
- **No balance/juice redesign:** do not retune `.tres` or PerfBudget particle caps here. Audio voice cap is the only new budget constant.
- **Pause + stings:** if a sting must play on the paused ResultOverlay, use a player with `PROCESS_MODE_ALWAYS` owned by the overlay or by Sound with explicit process mode — test Retry/Menu still unpause and don't leave music doubled.
- **`Engine.time_scale`:** debug ×2/×4 pitches gameplay; default AudioStreamPlayer does **not** follow time_scale — leave it (arcade SFX at normal pitch under FF is acceptable). Do not couple audio to time_scale in v1.0.
- **Untouchables:** renderer, `export_presets.cfg` threads, particle backend, gameplay numbers, portrait contract.

## Juice / feel checklist (audio)

- [ ] First tap unlocks audio without a permission dialog beyond browser norms.
- [ ] Kill / build / upgrade / sell / shots / hit / coin / leak each have a distinct-enough sound when samples exist.
- [ ] Wave start and win/lose/unlock/new-best read as celebration or sting, not a wall of noise.
- [ ] Music loops without a gap hitch; ducks or stops cleanly under overlays; no double music after Retry.
- [ ] Master volume 0 → silence; mid → audible; persists across reload.
- [ ] Voice stealing under Popper + confetti storm never hitches the frame (stress with audio on).

## Acceptance criteria

- [ ] `Sound` autoload registered after Juice; buses Master/Music/SFX in use; `PerfBudget.MAX_SFX_VOICES` referenced at the pool size.
- [ ] Every DOWNLOADED hook id plays at its moment; every MISSING id is silent and listed in PR Stage 8 follow-ups — nothing silently forgotten.
- [ ] On the deployed web build, before any tap: no audio. After first tap: SFX and music can play. Refresh resets to locked until the next gesture.
- [ ] Settings master volume affects Master bus live; value persists in `user://settings.cfg` across reload.
- [ ] ResultOverlay win/lose (and new-best) stings are audible even while the tree is paused; Retry/Menu leave no stuck music or paused tree.
- [ ] Stress (`?stress=1`) with audio unlocked holds the Stage 3/6 FPS floor; SFX voices stay ≤ `MAX_SFX_VOICES`.
- [ ] `assets/ATTRIBUTION.md` lists every shipped audio file; CI web-export green; `*.import`/`*.uid` committed (or absence explained).

## Verification

1. Local headless (skip to step 3 if no Godot — CI is the gate):
   ```sh
   godot --headless --import
   godot --headless --export-release "Web" build/web/index.html
   python3 -m http.server 8080 -d build/web
   ```
2. Chrome localhost: fresh load → confirm silence → tap Play → confirm unlock + music/SFX through a short combat burst; drag volume to 0 and back; open Settings mid-flow; win once and hear sting under pause; Retry; return to MapSelect; trigger unlock ceremony if possible (accelerators OK).
3. Branch deploy: `gh workflow run deploy.yml --ref stage-07-audio`, `gh run watch`, then on a **real phone** with sound on: first-gesture unlock, one map fight, volume persistence across reload, stress 30 s with audio. Record device/browser in the PR.
4. PR CI green; after merge, re-check live Pages once with headphones.

## Out of scope

- Final balance, copy, README rewrite, version bump, first-run tutorial text, remaining idle juice — **Stage 8**.
- New gameplay, maps, towers, enemies; dynamic music layers; per-map themes; voice acting.
- Replacing MISSING samples with generative placeholders — leave silent + follow-up.
- PWA / install prompts; enabling threads; renderer changes.

## Handoff

After this stage, Stage 8 may rely on:

- **`Sound` autoload** with `play_sfx` / `play_music` / `stop_music` / `set_music_ducked` / `unlock_audio` / settings sync — hook matrix implemented for every available sample.
- **Buses + `MAX_SFX_VOICES`** in `PerfBudget`, attribution complete for shipped audio.
- **Web first-gesture contract** proven on deployed Pages.
- **Stage 8 follow-ups list** of any silent hooks / missing packs / provisional voice cap.
