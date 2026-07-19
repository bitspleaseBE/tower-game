# Stage 6: Candy Coat — Kenney Art via /select-asset

**Status:** not started

Objective: after this stage, the live Pages build stops looking like tinted geometry and starts looking like the blueprint's candy screenshot — critters are cute round Kenney characters wobbling down a real grass-and-path board, the four tower types are distinct flat-vector turrets that visibly grow through their tiers, hearts and coins in the HUD are real icons, confetti bursts use real particle sprites, the buttons wear chunky Kenney nine-patch skins, and the browser tab shows a real game icon — with **zero gameplay or juice regressions**: same waves, same numbers, same squash/wobble/pop feel, same PerfBudget-verified frame rate. Because the packs need manual team download, every category degrades gracefully: whatever isn't in `inspiration/` yet keeps its release-shaped primitives and is logged as a follow-up — the stage merges shippable regardless. The session ends by staging CC0 audio proposals under `inspiration/audio/` so the team can download them before Stage 7.

## Prerequisites

Stages 1–5 (`portrait-shell` … `campaign-endless`) must be merged and deployed. Verify each; if any check fails, stop and fix the earlier stage first.

- [ ] CI green on `main` (`gh run list --branch main --limit 1`) and https://bitspleasebe.github.io/tower-game/ plays the full game: MapSelect → 3 maps, endless unlock, saves survive a reload.
- [ ] Stage 5 outputs exist: `ls scenes/map_select.tscn scripts/autoload/save_game.gd data/maps/map_01.tres data/maps/map_02.tres data/maps/map_03.tres`.
- [ ] Juice/budget/harness exist: `grep 'Juice=' project.godot`; `ls scripts/autoload/juice.gd scripts/perf_budget.gd`; find the stress gate (`grep -rn 'stress' scripts/ | head`) and note its activation (`?stress=1` / F9) and the FPS floor recorded in `scripts/perf_budget.gd`'s header.
- [ ] Skin swap points exist everywhere: `grep -l 'Skin' scenes/entities/*.tscn` lists tower/enemy/projectile/build_pad; `ls scenes/ui/coin_flyer.tscn scenes/fx/` (identify the ONE shipped confetti scene — Stage 3 deleted the loser). READ the skin-construction code before touching it: `grep -n 'Skin\|skin' scripts/entities/tower.gd scripts/entities/enemy.gd scripts/entities/projectile.gd scripts/entities/build_pad.gd` and the BuildMenu icon-slot code in `scripts/ui/build_menu.gd`. Do not assume function names from the plans — read what actually shipped.
- [ ] Theme is project-wide: `grep 'theme/custom' project.godot` → `res://theme/candy_theme.tres`.
- [ ] Skills present: `ls .claude/skills/select-asset/SKILL.md .claude/skills/find-assets/SKILL.md` — this stage invokes both.
- [ ] The 7 staged proposals are intact: `find inspiration -name SOURCE.md | wc -l` → 7 (background/, enemies/×2, tower/, ui/×2, fx/).
- [ ] `assets/` does not exist yet (`ls assets 2>/dev/null` fails) — this stage creates it via `/select-asset` only.
- [ ] Godot availability: `godot --version` prints 4.7.x; if absent, headless verification falls back to the PR CI build (and `.import`/`.uid` sidecars for new assets get committed by the first Godot-equipped session — say so in the PR).
- [ ] Work on a branch: `git checkout -b stage-06-kenney-art`.

## Tasks

Ordered so the download inventory and the perspective decision gate everything, and each art category is an independent promote→swap→check unit that can be skipped (with a logged follow-up) if its files never arrived. Category priority follows blueprint §13: board → enemies → towers → UI → FX. Tasks 1–2, 9–12 are unconditional; tasks 3–8 each self-skip if their category has no files.

### 1. Inventory the downloads (the stage's precondition)

- [ ] For each of the 7 proposal folders, check for real pack files beyond `SOURCE.md`: `find inspiration -type f ! -name 'SOURCE.md' ! -name '.gdignore' | sort`. Build a category status table (background / enemies / tower / ui / fx → DOWNLOADED or MISSING) — it goes verbatim into the PR description.
- [ ] For any MISSING category, make ONE bounded rescue attempt (≤ 15 min total across all categories, then stop): try the mirror URLs documented in each `SOURCE.md` (the OpenGameArt mirrors are curl-friendly; kenney.nl and itch.io usually are not from this sandbox). If a fetch succeeds, unzip into the proposal folder, delete junk (`__MACOSX`, `.DS_Store`), and update its `SOURCE.md` `Status:` line to `Downloaded: 2026-07-18 (agent, via mirror)`. If it fails, move on — the fallback rule covers it.
- [ ] Anything still MISSING after the attempt: its swap task below is skipped, its primitives ship as-is, its proposal folder **stays** in `inspiration/` (still pending download), and it is listed under "Follow-ups" in the PR description. Do not silently skip.
- [ ] Eyeball what arrived: use the Read tool on a handful of PNGs per downloaded pack (Read renders images) to confirm the contents match `SOURCE.md` and judge style fit before promoting anything.

### 2. Resolve the perspective conflict (decision, then prune)

- [ ] Decision (made now, in this plan, per blueprint §3 "angled top-down"): **`kenney-tower-defense-top-down` is the anchor family; `kenney-tower-defense-kit` (isometric renders) is OUT.** One perspective family only — isometric tower sprites on a top-down board would make the board incoherent, exactly the documented risk.
- [ ] Delete `inspiration/tower/kenney-tower-defense-kit/` now (git history keeps it). Record the decision + one-line rationale in the PR description. Towers, board tiles, and projectiles all come from the top-down pack.
- [ ] Only exception: if the top-down pack is MISSING and could not be rescued, towers/board keep their primitives (fallback rule) — do **not** promote the isometric kit as a substitute, even if it was downloaded.
- [ ] Round critters (enemies category) and flat UI/FX/icons are perspective-neutral; mixing those Kenney packs with the top-down board is fine and expected (all flat-vector, same author, per §9).

### 3. Board — ground, path, pads (from `background/kenney-tower-defense-top-down`)

Skip if MISSING. Invoke the `select-asset` skill for this and every promotion (it moves files and maintains `assets/ATTRIBUTION.md`; this plan is the team go-ahead it asks for). Promote the **minimal set of individual PNGs** — never whole tilesheets or vector sources — with role-based snake_case names.

- [ ] Promote to `assets/background/`: one grass tile (`grass_tile.png`), one straight road/path tile (`path_straight.png`), and one pad-ish base tile (`pad.png`) if the pack has one that reads as a build pad. 64 px tiles expected.
- [ ] Ground: locate the existing overdrawing ground node inside `Board` in `scenes/game.tscn` (Stage 2 note: a ColorRect spanning roughly −200…1480 in y). Replace it with a `Sprite2D`: `texture = grass_tile`, `texture_repeat = TEXTURE_REPEAT_ENABLED`, `region_enabled = true`, `region_rect = Rect2(0, 0, 1120, 1680)`, `centered = true`, `position = Vector2(360, 640)` — covers the 720×1280 design rect plus ≥ 200 px overdraw for aspect-expand on every side. Retune `[rendering] environment/defaults/default_clear_color` in `project.godot` to the grass tile's dominant color so any sliver beyond the overdraw still blends (keep `boot_splash/bg_color` in sync).
- [ ] Path: try texturing the existing `PathLine` Line2D — `texture = path_straight`, `texture_mode = Line2D.LINE_TEXTURE_TILE`, width matched to the tile's road width; eyeball the 90° corners on all three maps (round joints smear textures). If corners read badly, **keep the flat candy Line2D** and instead retune its fill/border colors to sit on the grass (sand-on-grass like the pack's own roads). Either way the path stays a Line2D driven by `MapData.path_points` — no per-map tile baking, no TileMap; document the choice in the PR.
- [ ] Pads: in `build_pad.gd`'s skin construction, replace the primitive discs under `Skin` with a `Sprite2D` (`pad.png`), scaled to the current pad footprint (~72 px). Pad tap-pulse and idle breathe target `Skin` and survive untouched.
- [ ] Check on all 3 maps (MapSelect makes this fast): ground tiles everywhere including expand-revealed space, path legible, pads visible on grass, decor (spawn/base markers) not floating oddly — retint their primitives if the new ground clashes.

### 4. Enemies — five critters (from `enemies/…`)

Skip if both enemy proposals are MISSING (the top-down pack's round units are the third option below).

- [ ] Pick ONE family, in this preference order, judged by Reading the sprites at game size (diameters 2×`radius_px`: swarm 28 px → boss 92 px on a 720-wide canvas): (a) `kenney-shape-characters` — blueprint-literal round blobs, compose body + face as two Sprite2Ds under `Skin`; (b) `kenney-animal-pack-redux` — **round + outline** variants only, one Sprite2D per archetype; (c) the top-down pack's round enemy units. Criteria: 5 distinct silhouettes/colors, bright bodies (status tints must read — see notes), thick outlines per §9.
- [ ] Promote exactly 5 body sprites (+ faces if shape-characters) to `assets/enemies/` as `critter_normal.png`, `critter_fast.png`, `critter_swarm.png`, `critter_armored.png`, `critter_boss.png` — choose bodies whose stock colors roughly track the existing archetype color-coding (players learned it in Stages 2–4).
- [ ] In `enemy.gd`'s skin construction (keyed off `EnemyData.id`), replace primitive blobs with the sprite(s): texture from a `const TEXTURES := {...}` preload dictionary, sprite **scaled on the Sprite2D child** to `2.0 * data.radius_px / texture.get_size().x` — `Skin` itself stays at rest scale 1.0 (see notes). Boss keeps its primitive candy-crown polygon as an extra `Skin` child on top of the sprite.
- [ ] Verify sprite-era behavior: jelly-wobble, hit flash (overbright modulate on textures), kill punch, slow tint icy and recovering, HpBar (beside `Skin`) still above the boss and undistorted, pool reuse shows the right sprite per archetype after recycling (`reset_for()` path re-keys the skin).

### 5. Towers + projectiles — 4 types × 3 tiers (from the top-down pack)

Skip if MISSING (same pack as task 3).

- [ ] Map the pack's modular base + weapon sprites onto the four identities. Read the weapon sprites and pick per type: **Popper** stubby rapid gun, **Lobber** fat mortar/cannon tube, **Chiller** the most crystal/emitter-looking part tinted icy via `self_modulate` (~`#8DD0F0`), **Longshot** the longest single barrel. Tiers: if the pack has weapon mark-variants use them per tier; otherwise keep one weapon sprite + the existing per-tier `Skin` scale step and add small primitive tier-pip stripes as `Skin` children. Prefer weapon parts that read fine at a fixed facing — **do not add barrel-rotation toward targets** (it fights the Juice rest-state claim on `Skin`; log as optional Stage 8 polish if it itches).
- [ ] Promote to `assets/tower/` with role names: `base_<shape>.png`, `weapon_popper.png` / `…_t2.png` (only files actually referenced), plus 2 projectile sprites (`projectile_shot.png`, `projectile_shell.png`).
- [ ] In `tower.gd`'s skin construction (keyed off `TowerData.id` + tier): compose `Base` + `Weapon` Sprite2Ds under `Skin`, sized to the current primitive footprint so `RangeArea`, pad spacing, and read-at-a-glance sizes are unchanged. Four silhouettes must still be tellable apart in the iPhone SE viewport — if two weapons read alike, differentiate with `self_modulate` toward each type's established candy color.
- [ ] `projectile.gd`: swap the primitive under `Skin` for the sprite per mode (HOMING small shot, LOB shell — the fake-height arc already lives on `Skin.position.y` and survives). Longshot's stretched-tracer read keeps working since stretch targets `Skin`.
- [ ] BuildMenu: replace the 26 px color-swatch `Icon` slot (Stage 4's named swap point in `build_menu.gd`/`.tscn`) with a `TextureRect` showing each type's weapon or composed tier-1 look, `expand_mode`/`stretch_mode` set to fit ~40 px, `mouse_filter = MOUSE_FILTER_IGNORE`. Greyed-affordability modulate keeps working on the textures.
- [ ] Verify: build/upgrade/sell each type; recoil squash, bounce-in, upgrade sparkle + ring, sell deflate all fire on the sprites; range rings unchanged (they sit beside `Skin`).

### 6. UI icons + HUD + MapSelect cards (from `ui/kenney-game-icons` and/or top-down pack)

Skip icon/HUD swaps if the icons pack is MISSING; MapSelect still gets a task-6b pass either way (primitives stay if no art).

- [ ] Promote to `assets/ui/`: `icon_heart.png`, `icon_coin.png` (single-color pack sprites; tint at use sites — hearts `#FF6B81`, coins `#FFC94D` per the Stage 1 palette). Optional extras if clearly better than primitives: `icon_star.png` (beaten badge), `icon_lock.png` (locked card affordance).
- [ ] HUD (`scenes/ui/hud.tscn` + `hud.gd`): replace the "♥"/"●" text glyphs with a 32-ish px `TextureRect` icon beside each Label (HBox per stat); `hud.gd` format strings become plain numbers. Heart-thump / coin-pulse juice retargets the small HBox or Label exactly as before (re-check `pivot_offset` centering). `coin_anchor()` must still return the coin stat's position — coin flyers land on it.
- [ ] Coin flyer: swap `scenes/ui/coin_flyer.tscn`'s golden disc under `Skin` for `icon_coin.png` tinted gold, ~20 px.
- [ ] Cost glyphs elsewhere ("50●" in BuildMenu / sell labels): keeping the text glyph is acceptable; if the font swap in task 7 drops the glyph, switch those strings to `"50c"`-free form — number + small coin TextureRect. Log whichever you did.
- [ ] **MapSelect card art (Stage 5 named swap points — required this stage):**
  - `MapCard` Badge `Skin`: replace the gold-star Polygon2D with `icon_star.png` (or keep the primitive if icons MISSING — log follow-up). Idle pulse still targets `Skin`.
  - `MapPreview` (`scripts/ui/map_preview.gd`): keep the data-driven `_draw()` polyline + pad dots as the default (they ARE the three route shapes). Optional upgrade only if a clear thumbnail sprite exists per map in a downloaded pack — then swap via a TextureRect sibling and hide the draw; never invent baked art that drifts from `MapData.path_points`. Document the choice in the PR.
  - Locked-card dim + `Juice.wiggle` behavior must still read on the reskinned cards; Settings + MapSelect theme A/B in task 7.

### 7. Theme nine-patches + optional font (from `ui/kenney-ui-pack`)

Skip if MISSING. This category has an explicit keep-if-worse rule: the Stage 1 StyleBoxFlat gumdrops are already release-shaped.

- [ ] Promote the minimal button/panel sprites to `assets/ui/` (`button_9slice.png`, `button_pressed_9slice.png`, `panel_9slice.png` — pick a rounded chunky set; prefer light sprites and tint with `StyleBoxTexture.modulate_color` to the candy palette).
- [ ] Rebuild `theme/candy_theme.tres` Button `normal/hover/pressed/disabled` and Panel/PanelContainer styles as `StyleBoxTexture` with `texture_margin_*` nine-slice margins; preserve the pressed content-sink (content margins shift ~4 px), disabled greying, and the existing StyleBoxFlat focus ring (mixing box types is fine). Keep the `ButtonSecondary` variation distinct.
- [ ] A/B eyeball at 88 px button height on the main menu, Settings, MapSelect, BuildMenu sheet, and ResultOverlay: if the nine-patches read worse than the gumdrops, revert the theme (keep the promoted files out of `assets/` — reconcile ATTRIBUTION per the skill) and log the decision. Do not ship a downgrade for the sake of using the pack.
- [ ] Optional (only if it clearly improves): set the pack's rounded TTF as the theme's `default_font`. Check payload (+~50–100 KB is fine), verify every screen's text (glyph coverage is basic Latin — another reason task 6 moved ♥/● to icons), and confirm web-export rendering.

### 8. FX sprites (from `fx/kenney-particle-pack`)

Skip if MISSING.

- [ ] Promote to `assets/fx/`: one small star or dot sprite (`particle_confetti.png`) and one soft puff (`particle_puff.png`) — mostly-white sprites that tint freely.
- [ ] Swap the confetti scene's `GradientTexture2D` (Stage 3's named swap point in the ONE shipped confetti scene under `scenes/fx/`) for `particle_confetti.png`; keep `amount`, lifetime, and the candy `color_initial_ramp` exactly as budgeted; set `scale_amount_min/max` so bursts match the old visual size. Same texture swap for the sparkle/puff emitters Stage 4 added (upgrade sparkle, sell puff, Lobber detonation puff) — find them via the Juice pool construction, change textures only, never counts.
- [ ] Verify a kill-storm: confetti reads as candy pieces, no visible size/perf change, pools still cap per `PerfBudget`.

### 9. Real game icon (unconditional — no download needed)

- [ ] Replace the scaffold crosshair `icon.svg` with a hand-authored 128×128 flat candy icon (original art, no attribution entry needed): mint rounded-square background (`#C7E9BE`, rx 20), a sand path swoosh, and a chunky pink turret (rounded base + stubby barrel + white eye highlight) in the Stage 1 palette. Keep the filename `icon.svg` — `project.godot` `config/icon` and the web export favicon (`html/export_icon=true`) pick it up unchanged.
- [ ] Verify the favicon in a local web build's browser tab and that the 128 px raster reads at 16–32 px.

### 10. Juice retune pass + debug overlay additions

- [ ] Walk the Stage 3/4 juice checklists on the reskinned build and retune ONLY feel parameters (amplitudes/durations/tints in `juice.gd` call sites — never counts, caps, or balance): wobble strength so faces jiggle without smearing (~0.06–0.08), kill-punch and tower-recoil amplitudes against the new silhouettes, flash still reading on textured sprites, slow-tint strength against the chosen critter colors, coin-flyer size/arc with the real coin.
- [ ] Add two lines to the stress overlay (`scripts/debug/stress_test.gd`, debug-only): texture memory `Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)` in MB, and `RENDER_TOTAL_DRAW_CALLS_IN_FRAME` — the scope's "watch texture memory and draw calls" becomes a number on screen.
- [ ] Payload guard: record `du -sh build/web` (or the CI artifact size) before and after the swaps; the promoted PNG set should add well under ~1.5 MB. If it doesn't, promote fewer/smaller files — individual sprites only, no sheets.

### 11. Stage the audio proposals (end of session — unconditional)

- [ ] Invoke the `find-assets` skill with args `audio` and the needs list from blueprint §13 + the Stage 7 hook matrix in [`stage-07-audio.md`](stage-07-audio.md) (same list, authoritative there): kill pops, build place / upgrade / sell, per-tower-type shots, hit, coin tink, leak/heart loss, countdown tick, wave-start, win/lose stings, unlock/new-best, UI button taps, and ONE cheerful upbeat music loop. **CC0 only** (§13 — commercial release, obligation-free). Kenney audio packs (Digital Audio, Interface Sounds, Music Jingles…) are the expected first stops.
- [ ] Result: 2–4 proposals under `inspiration/audio/<pack-slug>/` each with a complete `SOURCE.md`; manual-download `Status:` lines are fine (that's the point — the team downloads before Stage 7). Do NOT promote any audio into `assets/` and do NOT wire any sound — Stage 7 owns all of that (including the ui-pack's bundled click sounds: leave them unpromoted).

### 12. Prune, reconcile attribution, verify, commit, PR

- [ ] Prune `inspiration/` per its README, now that categories are decided: delete each promoted proposal folder and each rejected sibling (e.g. the losing enemies pack); the isometric kit went in task 2. KEEP folders for categories that stayed MISSING (still awaiting download) and the new `audio/` proposals. This plan's scope is the documented go-ahead the skill asks for.
- [ ] Reconcile `assets/ATTRIBUTION.md` against `ls -R assets/`: every shipped file listed, nothing else (the select-asset contract). CC0 entries included.
- [ ] Run the Verification section end-to-end.
- [ ] `git add -A`; confirm every new `*.uid` **and `*.import`** sidecar for `assets/` files is staged (`git status --short | grep -E 'uid|import'`; if Godot wasn't available locally, note their absence in the PR). Commit with a descriptive message (e.g. "Stage 6: candy coat — Kenney top-down art at Skin swap points, real icons/theme/game-icon, audio proposals staged"), push, open a PR to `main` whose description contains the category status table, the perspective decision, payload delta, stress numbers, and the follow-ups list — then confirm the CI web-export build is green before merge. After merge, play-check the live Pages build on a phone.

## Implementation notes

- **The swap contract is the whole stage**: art changes happen ONLY inside `Skin` children, texture properties of named swap points (confetti texture, BuildMenu icon slot, coin flyer), the ground node, `hud.tscn` stat rows, `theme/candy_theme.tres`, and `icon.svg`. Gameplay scripts' logic, every `data/**/*.tres`, `Events`, spawner, economy, and `PerfBudget` numbers are untouchable. Audit before PR: `git diff main --stat -- data/ scripts/data/` must be empty.
- **Size on the Sprite2D child, juice on `Skin`**: Kenney sprites have arbitrary pixel sizes; fit them by scaling the Sprite2D inside `Skin` (`scale = target_px / texture.get_size().x`). `Skin` itself must stay at its established rest transform — Stage 3's `Juice.claim()` records `Skin`'s rest, enemy wobble multiplies it, and Stage 4's tier growth scales it; putting fit-scale on `Skin` would silently shrink every squash amplitude and break claim/rest math on pool reuse.
- **Keep skin construction keyed off data ids**: the existing functions key off `TowerData.id`+tier / `EnemyData.id`. Replace their primitive bodies with sprite composition (preload dictionaries at the top of the script); delete the replaced primitive code rather than keeping dual paths — but only per category actually promoted. A category that stays primitive keeps its old code verbatim.
- **Tinting textured sprites**: `modulate` multiplies — white/bright sprites tint like the old primitives, dark ones go muddy. The slow-status icy tint, hit-flash overbright (`Color(6,6,6)` still clamps textured pixels to white), affordability greying, and Chiller's identity tint all rely on this: pick bright bodies. Flash must still restore to the enemy's current base tint (Stage 4's `_update_tint()` owner), not hardcoded white — verify, don't reimplement.
- **Not pixel art**: keep the default linear texture filter (crisp rounded vectors scale cleanly); never set NEAREST. No AnimatedSprite2D / AnimationPlayer anywhere — these packs have no walk frames and the blueprint's locomotion IS the wobble tween; death is the punch+confetti. Adding frame animation would be new scope and new perf cost.
- **Draw order inside entities**: siblings render in tree order — keep `RangeRing`, `HpBar`, tier pips, and the boss crown ordered exactly as they are relative to `Skin` (ring/bar beside and after `Skin` = drawn on top). The `.tscn` diffs should show textures swapped, not nodes reordered.
- **Ground overdraw + clear color**: aspect `expand` reveals extra height on 20:9 phones and extra width on tablets; the 1120×1680 region covers both extremes (±200 px around the design rect), and the retuned `default_clear_color` backstops anything wilder. Never anchor the ground to the viewport — it lives in `Board`, which `_recenter_board()` moves.
- **Line2D texturing**: `LINE_TEXTURE_TILE` maps texture height to line width and tiles along length; joints stretch it at sharp corners — that's why task 3 keeps the flat-color fallback legitimate. Do not bake per-map tile paths; three maps × arbitrary `path_points` make TileMap stamping a Stage-sized project of its own, and the thick rounded Line2D already matches §9.
- **Import hygiene**: PNGs import with project defaults (lossless, mipmaps off for 2D) — do not touch `export_presets.cfg` (threads stay off, `vram_texture_compression/for_mobile` stays false) or renderer settings. Commit the generated `.import` + `.uid` sidecars for everything under `assets/`. `inspiration/` stays `.gdignore`d — nothing there imports or ships, which is why un-downloaded folders can safely remain.
- **`/select-asset` discipline**: one skill invocation per promotion, minimal file sets, role-based snake_case names decoupled from pack numbering (`towerDefense_tile249.png` → `weapon_popper.png`), never re-encode during promotion (cropping/compositing afterward is normal game work, but at these sizes you shouldn't need any). `ATTRIBUTION.md` lists exactly what ships — it is the file the team pastes into an itch.io page later.
- **Web/perf reality check**: a few dozen 64–128 px PNGs are trivial VRAM and draw-call-wise (SpriteS replace Polygon2Ds ~1:1), but the overlay numbers from task 10 make that a measurement, not a hope. The PerfBudget FPS floor and particle caps are Stage 3 law — if real textures somehow dent the floor, shrink sprite counts/sizes, never raise budget numbers.
- **One-thumb layout is frozen**: icons and nine-patches must not change any tap-target geometry — 88 px buttons, pad hit areas, sheet layout all stay. If a nine-patch changes a button's visual size, fix margins in the theme, not the scenes.

## Juice checklist

This stage's juice work is making the existing juice land on real art (regression-checked one by one), plus small new sparkle:

- [ ] Jelly-wobble, hit flash, kill punch + confetti + coin arc + floater — all firing on the new critter sprites, retuned amplitudes.
- [ ] Tower recoil squash, build bounce-in, upgrade sparkle + ring, sell deflate + coin shower — all firing on the new turret sprites.
- [ ] Confetti bursts are visibly candy pieces (real star/dot sprites, same candy color ramp, same counts).
- [ ] Coin flyers are real spinning-gold coins landing on a real coin icon that pulses; hearts icon thumps on life loss.
- [ ] Buttons keep their press-squish and gumdrop/nine-patch pressed sink; BuildMenu options pop in with real tower thumbnails.
- [ ] Boss still stomps in crowned, HP bar crisp above the sprite, entrance shake intact.
- [ ] Slowed critters visibly frost-tint on the new art and recover.
- [ ] Browser tab has a candy game icon instead of the scaffold crosshair.

## Acceptance criteria

- [ ] Every DOWNLOADED category (per task 1's table) ships real Kenney art at its swap points; every MISSING category demonstrably still ships its Stage-5 primitives and appears in the PR's follow-ups list. Nothing was silently skipped.
- [ ] One perspective family on the board: no isometric renders anywhere; `inspiration/tower/kenney-tower-defense-kit/` is gone; the decision is in the PR description.
- [ ] Zero gameplay diffs: `git diff main -- data/ scripts/data/` is empty; a full map 1 campaign run plays identically (same waves/costs/lives outcomes) before and after the reskin; upgrade/sell math, endless mode, and saves are untouched.
- [ ] Zero juice regressions: every item in the Juice checklist verified on the deployed build; all tweens still target `Skin`/swap-point nodes only (spot-check the diff: entity scripts changed only in skin construction). MapSelect cards show Badge/Preview swap results (or logged MISSING follow-ups); locked-card wiggle still works.
- [ ] Pool hygiene survives the reskin: kill and recycle 20+ critters across archetypes — every reused enemy shows the correct sprite, tint, and HpBar state for its new identity.
- [ ] `assets/` exists with role-named files under `background|enemies|tower|ui|fx` (only promoted categories), each with committed `.import`/`.uid` sidecars (or the PR notes Godot was unavailable); `assets/ATTRIBUTION.md` lists exactly the shipped files, one section per source pack, CC0 stated.
- [ ] `inspiration/` contains only: still-MISSING categories' proposals and the new `audio/` proposals (2–4 packs, each with complete `SOURCE.md`, CC0, download/mirror URLs).
- [ ] `icon.svg` is the new candy icon; the web build's favicon shows it.
- [ ] Stress harness (`?stress=1`) on the deployed branch holds the `PerfBudget` header's FPS floor with real textures; the overlay's new texture-memory and draw-call lines show sane numbers (texture mem a few MB, draw calls same order of magnitude as before); web payload grew ≤ ~1.5 MB (delta reported in the PR).
- [ ] The PR CI web-export build is green; the merged Pages build is play-checked on a phone.

## Verification

1. Local headless (skip to step 5 if `godot` is unavailable — CI is the authoritative gate):
   ```sh
   godot --headless --import          # zero errors; generates .import/.uid for assets/ — commit them
   godot --headless --export-release "Web" build/web/index.html
   du -sh build/web                   # payload delta vs the pre-stage build
   python3 -m http.server 8080 -d build/web
   ```
2. Chrome http://localhost:8080, DevTools device toolbar, touch on, iPhone SE then Pixel 7 portrait: full map 1 run on the new art — walk the Juice checklist item by item; build/upgrade/sell all four towers; check maps 2 and 3 boards (ground/path/pads coherent on their layouts); MapSelect, ResultOverlay, settings all wear the (possibly nine-patched) theme with no layout shifts; favicon check.
3. Regression sweep: Retry mid-run, win a map, enter endless, reload the tab (saves persist), return to menu — no console errors, no missing-texture warnings, no pink placeholders.
4. Stress: `?stress=1` (F9 locally), ≥ 60 s at the Stage 3/4 worst-case presets; FPS floor per `perf_budget.gd` holds; read the new texture-mem/draw-call lines. Also one pass with Chrome 4× CPU throttle — "smooth" here means: the stress floor from the PerfBudget header still holds on real textures, and normal play never visibly hitches on sprite-swap moments (pool prewarm covers first-use).
5. Branch deploy (required — same as Stages 3/5): `gh workflow run deploy.yml --ref stage-06-kenney-art`, `gh run watch`, then on a mid-range Android phone in Chrome re-run `?stress=1` and a short MapSelect → map 1 juice walk on the deployed artifact. Record FPS, texture-mem, and draw-call numbers in the PR. No phone → keep emulation numbers and mark Stage 8 re-verify debt.
6. Push the branch; PR build must go green.
7. After merge: re-deploy `main` if the branch overwrite is still live; phone play-check of the live build — the game should read "candy screenshot" at arm's length; grab a screenshot for the PR thread.

## Out of scope

- Downloading or wiring ANY audio into the game, Music/SFX buses, `Sound` autoload, settings sliders, autoplay-gesture handling — **Stage 7** ([stage-07-audio.md](stage-07-audio.md); this stage only stages `inspiration/audio/` proposals; even the ui-pack's bundled sounds stay unpromoted).
- Balance or data edits of any kind, new waves/maps/towers/enemies — **Stage 8** ([stage-08-release.md](stage-08-release.md)) owns further balance; this stage owns none.
- Final juice escalation (idle tower wobbles, HUD count-up escalations, low-lives heart pulse, menu transitions), copy pass, version bump, README rewrite from "scaffold", pruning follow-up categories that never got downloads — **Stage 8**.
- Barrel rotation toward targets, walk/death animation frames, TileMap-baked paths, PWA icons/splash — not in v1.0 unless Stage 8 explicitly picks them up (default: out; see Stage 8 task 5).
- Revisiting Stage 3 decisions: particle backend, pool architecture, `PerfBudget` caps (re-verify only — a genuine cap problem is a PR discussion, never a silent edit).
- Never touched, any stage: `export_presets.cfg` (threads stay disabled), renderer settings, `deploy.yml`, the 720×1280 portrait contract, local-only saves.

## Handoff

After this stage, later stages may rely on:

- **The shipped look is final-family**: CC0 Kenney flat-vector art (top-down perspective on the board) at every promoted swap point, primitives only where the PR's follow-ups table says so — Stage 7/8 sessions read that table to know what art debt remains.
- **`assets/` + `assets/ATTRIBUTION.md`** as the single truthful manifest of shipped third-party files, maintained exclusively via `/select-asset`; `.import`/`.uid` sidecars committed.
- **The swap contract held**: gameplay scripts, `data/**`, Events, pools, and `PerfBudget` are bit-identical in behavior; all juice still targets `Skin` transforms — Stage 7 hooks SFX onto the same moments without touching art, Stage 8 rebalances `.tres` without touching visuals.
- **Stress harness extended** with texture-memory and draw-call readouts, and a post-art measurement on record (PR description) proving the PerfBudget floor holds with real textures — Stage 8's performance pass starts from those numbers.
- **`inspiration/audio/` proposals staged with provenance**, download-ready for the team — Stage 7's precondition, mirroring how this stage consumed the art proposals (including the same fallback rule if some never arrive).
- **Theme + icons finalized enough for copy/UI polish**: `theme/candy_theme.tres` (nine-patched or consciously kept gumdrop — decision logged), real heart/coin icons with `hud.coin_anchor()` intact, real `icon.svg`.
