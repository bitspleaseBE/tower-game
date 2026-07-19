# Stage 1: Portrait Shell & Board Skeleton

**Status:** not started

Objective: after this stage, anyone opening https://bitspleasebe.github.io/tower-game/ on a phone sees a candy-bright PORTRAIT game instead of a dark landscape scaffold — a cream main menu with a bouncy title and two big thumb-reach buttons, a matching settings screen, and behind New Game a real game board: soft mint ground, a thick rounded candy path snaking top-left to right, 8 lilac build pads, a status strip up top (hearts/coins/wave placeholders) and a thumb-zone bar at the bottom. No gameplay yet — this stage locks the screen shape, the single candy theme, and the conventions (Skin swap points, directory layout, committed `*.uid`s) every later stage builds on.

## Prerequisites

No earlier stages (this is Stage 1) — the prerequisite is the intact scaffold. Verify each; if any check fails, stop and investigate before changing anything.

- [ ] Repo is on an up-to-date `main` with a clean tree: `git -C /home/user/tower-game status` and `git pull`.
- [ ] Scaffold files exist: `ls scenes/main_menu.tscn scenes/settings_menu.tscn scenes/game.tscn scripts/settings.gd scripts/main_menu.gd scripts/settings_menu.gd scripts/game.gd project.godot export_presets.cfg`.
- [ ] Viewport is still the landscape scaffold (i.e. this stage hasn't already run): `grep viewport_ project.godot` shows `1280` / `720`.
- [ ] `Settings` autoload registered: `grep 'Settings=' project.godot` → `Settings="*res://scripts/settings.gd"`.
- [ ] Web preset has threads disabled (must stay that way): `grep thread_support export_presets.cfg` → `variant/thread_support=false`.
- [ ] CI is green on `main`: `gh run list --branch main --limit 1`.
- [ ] Godot availability: `godot --version` prints 4.7.x. If not installed in this sandbox, all headless verification falls back to the PR CI build — plan for that, don't skip verification.
- [ ] Work on a branch: `git checkout -b stage-01-portrait-shell`.

## Tasks

### 1. Flip `project.godot` to portrait

- [ ] Edit `project.godot` `[display]`: `window/size/viewport_width=720`, `window/size/viewport_height=1280`. Keep `window/stretch/mode="canvas_items"` and `window/stretch/aspect="expand"` exactly as they are.
- [ ] Add `window/handheld/orientation=1` (portrait hint for the web export — browsers only honor it in fullscreen/PWA contexts; see Implementation notes).
- [ ] Add desktop dev-window overrides so the editor's run window fits a monitor: `window/size/window_width_override=405`, `window/size/window_height_override=720` (scales the OS window only; logical resolution stays 720×1280; ignored on web).
- [ ] `[rendering]`: add `environment/defaults/default_clear_color=Color(0.78, 0.914, 0.745, 1)` (ground mint `#C7E9BE`) — the clear color IS the ground, so whatever extra space aspect "expand" reveals is automatically pastel, never black.
- [ ] `[application]`: add `boot_splash/bg_color=Color(0.78, 0.914, 0.745, 1)` so the web loading screen matches instead of flashing dark.
- [ ] Do NOT touch: renderer lines (`gl_compatibility` twice), `export_presets.cfg` (threads stay disabled), `run/main_scene`, `config/version`.

### 2. Create `theme/candy_theme.tres` and register it project-wide

- [ ] Create the `theme/` directory and hand-author `theme/candy_theme.tres` (`[gd_resource type="Theme" format=3]` — see Implementation notes for serialization syntax). Palette (first-guess values — tune by eye, but keep every color in the theme or the palette table, never scattered ad hoc):

  | Role | Hex |
  |---|---|
  | Ground mint (clear color) | `#C7E9BE` |
  | Menu background cream | `#FFF6E9` |
  | Path fill sand / border | `#F6E0A8` / `#E3C077` |
  | Pad lilac fill / border | `#E6D9F7` / `#BFA0E8` |
  | Primary button pink normal / hover / pressed / bottom-lip | `#FF8FB1` / `#FFA1BE` / `#EF6E96` / `#D9557F` |
  | Panel white / shadow | `#FFFFFF` / `#4F3A5B` at 12% alpha |
  | Text plum / on-pink white | `#4F3A5B` / `#FFFFFF` |
  | Accents (later stages): sky / sunny / coral / hearts / coins | `#8DD0F0` / `#FFD66B` / `#FF9E7D` / `#FF6B81` / `#FFC94D` |

- [ ] Theme contents:
  - `default_font_size = 30` (no custom font files — default font until Stage 6 at the earliest).
  - **Button**: StyleBoxFlat for `normal`/`hover`/`pressed`/`disabled`/`focus`. Gumdrop look: `corner_radius_*` 24 on all four, `bg_color` pink, `border_width_bottom = 6` with the darker lip color (fake 3D), content margins ≈ L/R 32, T 18, B 22. **Pressed** state is the built-in squish: `border_width_bottom = 2`, content margins T 22 / B 18 (content visibly sinks 4 px), pressed bg. **Disabled**: `#E7DCEC` bg, 60%-alpha plum text. **Focus**: `draw_center = false`, 4 px sky-blue border, corner radius 28, `expand_margin_*` 3 — keyboard users get a visible ring. `Button/font_sizes/font_size = 34`, `Button/colors/font_color` white (+ `font_pressed_color`, `font_hover_color`, `font_disabled_color`).
  - **ButtonSecondary** theme type variation (`ButtonSecondary/base_type = &"Button"`): white bg, 3 px pink border all round + 6 px bottom lip, plum text — for non-primary actions (Settings, Back, later Sell).
  - **Label**: `font_color` plum.
  - **Panel** and **PanelContainer** `panel` style: white StyleBoxFlat, corner radius 20, soft shadow (`shadow_size = 8`, `shadow_offset = Vector2(0, 3)`, plum 12% alpha).
- [ ] Register it as THE project theme in `project.godot`: `[gui]` section, `theme/custom="res://theme/candy_theme.tres"` — every Control in every current and future scene inherits it; scenes must not set their own `theme`.

### 3. Relayout `scenes/main_menu.tscn` for one-thumb portrait

- [ ] Rebuild the tree (root stays `MainMenu` Control, full rect, same script):
  - `Background` ColorRect full rect, cream `#FFF6E9` (replaces the dark scaffold color). Optionally 2–3 decor `Panel`s with fully-rounded StyleBoxFlat (corner radius = half size = pastel circles) scattered as candy dots — cheap, static, no textures.
  - `Title` Label ("TOWER GAME", font size 72 via override, plum) anchored top-center, roughly y 180–300 — upper third.
  - `Buttons` VBoxContainer anchored **center-bottom** (anchor preset center-bottom, fixed width 520 → offsets −260/+260, `offset_bottom = -56` safe margin), `separation = 20`, containing `NewGameButton` ("New Game", primary) and `SettingsButton` ("Settings", `theme_type_variation = "ButtonSecondary"`), each `custom_minimum_size = Vector2(0, 88)` — the ~88 px tap target, in the bottom thumb arc, never full-screen-width on desktop.
  - `VersionLabel` bottom-left, small, plum 40% alpha.
- [ ] Keep `unique_name_in_owner` on `NewGameButton`, `SettingsButton`, `VersionLabel` and keep the `[connection]` blocks pointing at the SAME handler methods (`_on_new_game_button_pressed`, `_on_settings_button_pressed`) with updated `from=` node paths — `scripts/main_menu.gd` keeps working with only the juice additions below.
- [ ] Juice in `scripts/main_menu.gd` `_ready()` (inline `create_tween()`; the Juice autoload is Stage 3):
  - Title bounce-in: scale 0.6→1.0, `TRANS_BACK`/`EASE_OUT`, ~0.4 s, then an infinite gentle bob loop (position.y ±6, sine, ~2 s). Set `pivot_offset = size / 2.0` first (deferred/after layout — see notes).
  - Buttons staggered pop-in: each scales 0→1 `TRANS_BACK` with ~0.08 s stagger.
  - Keyboard intact: `%NewGameButton.grab_focus()` stays (call after the tweens are started, not awaited).

### 4. Relayout `scenes/settings_menu.tscn` to match

- [ ] Same shell: cream `Background`; `Title` ("Settings", 56) top-center; a `SettingsCard` PanelContainer (white rounded panel from the theme) anchored center-top area (width 600, y ≈ 340), containing a MarginContainer (24) > VBoxContainer with the two existing rows — each row `custom_minimum_size.y = 72` for fat touch targets:
  - `FullscreenRow`: Label "Fullscreen" + `FullscreenCheck` CheckButton (keep unique name).
  - `VolumeRow`: Label "Master volume" + `VolumeSlider` HSlider (keep unique name, `custom_minimum_size = Vector2(280, 48)`, `size_flags_vertical = 4`).
- [ ] `BackButton` ("Back", ButtonSecondary, 520×88) anchored center-bottom with the same 56 px bottom margin as the main menu.
- [ ] Re-point the three `[connection]` blocks (toggled / value_changed / pressed) to the new paths, same methods — `scripts/settings_menu.gd` needs zero changes; Esc (`ui_cancel`) back-navigation keeps working.

### 5. Rebuild `scenes/game.tscn` as the portrait board skeleton

- [ ] Replace the placeholder scene with this tree (root name/type unchanged — `Game`, Node2D):
  ```
  Game (Node2D, script res://scripts/game.gd)
  ├─ Board (Node2D)                    # all world-space content; recentered by game.gd
  │  ├─ Decor (Node2D)                 # SpawnMarker + BaseMarker, each: Node2D ► Skin (Node2D) ► Polygon2D primitives
  │  ├─ Path (Path2D)                  # curve assigned at runtime from PATH_POINTS
  │  │  ├─ PathBorder (Line2D)         # width 64, sand border #E3C077, round joints+caps
  │  │  └─ PathLine (Line2D)           # width 48, sand fill #F6E0A8, round joints+caps
  │  └─ Pads (Node2D)                  # 8 placeholder pads spawned at runtime
  └─ UI (CanvasLayer)
     └─ Root (Control, full rect, mouse_filter = MOUSE_FILTER_IGNORE)
        ├─ TopBar (PanelContainer, anchored top-wide, side margins 12, top margin 12)
        │  └─ MarginContainer ► HBoxContainer: LivesLabel · CoinsLabel · WaveLabel · MenuButton
        └─ BottomBar (PanelContainer, anchored bottom-wide, offset_top = -128)
           └─ HintLabel (centered, plum 50% alpha: "Turrets land here soon.")
  ```
  The dark placeholder Background/CenterContainer/BackButton content is deleted; the clear color is the ground.
- [ ] Rewrite `scripts/game.gd` (still `extends Node2D`, no gameplay — layout + navigation only):
  - `const PATH_POINTS := PackedVector2Array([Vector2(-40, 280), Vector2(560, 280), Vector2(560, 540), Vector2(160, 540), Vector2(160, 820), Vector2(560, 820), Vector2(560, 1000), Vector2(760, 1000)])` — enters off-screen left at the top, S-curves down, exits off-screen right. This exact route is what Stage 2 copies into `data/maps/map_01.tres`.
  - `const PAD_POSITIONS := PackedVector2Array([Vector2(180, 400), Vector2(420, 400), Vector2(650, 410), Vector2(360, 660), Vector2(620, 660), Vector2(70, 690), Vector2(300, 930), Vector2(440, 1020)])` — 8 pads, each ≥ 90 px from the path centerline and ≥ 110 px from each other (verified values; if you adjust, re-check both rules).
  - `_ready()`: build a `Curve2D` from `PATH_POINTS` into `$Board/Path.curve`; assign the same points to both Line2D nodes (`points = PATH_POINTS`); call `_spawn_pads()`; call `_recenter_board()` and connect `get_viewport().size_changed` to it.
  - `_spawn_pads()`: for each position create `Node2D` (name `Pad1`…`Pad8`) ► child `Skin` (Node2D) ► two Polygon2D discs (border r 36 lilac-border, fill r 32 lilac) via a small `_circle_polygon(radius: float, segments := 24) -> PackedVector2Array` helper. These are throwaway placeholders — Stage 2 replaces them with instances of `scenes/entities/build_pad.tscn`.
  - `_recenter_board()`: `$Board.position = ((get_viewport_rect().size - Vector2(720, 1280)) * 0.5).max(Vector2.ZERO)` — centers the 720×1280 design rect inside whatever canvas aspect "expand" produced (extra height on 20:9 phones, extra width on tablets/desktop). Document this line; Stage 2's rebuild must keep the pattern.
  - Navigation: `MenuButton` ("Menu", min height 56, top-right of TopBar) and `ui_cancel` in `_unhandled_input` both call `_go_back()` → `change_scene_to_file("res://scenes/main_menu.tscn")` (same as scaffold).
  - Optional juice: give each pad `Skin` an idle "breathe" loop (scale 1.0→1.04, sine, ~1.8 s, random phase offset) — tween targets the `Skin` node only.
- [ ] TopBar labels are STATIC placeholders styled like the future HUD: `LivesLabel` "♥ 20", `CoinsLabel` "● 100", `WaveLabel` "Wave 1/6" (HBox with expand size flags spacing them). If `♥`/`●` render as tofu boxes in the web build, fall back to "Lives 20" / "Coins 100" — real icons are Stage 6.
- [ ] No Area2D, no groups, no signals, no data resources anywhere in this scene — Stage 2 owns all of that.

### 6. Document the conventions in `README.md`

- [ ] Add a short `## Conventions` section (after "Project layout") covering, in a few bullets each:
  - **Portrait policy**: base 720×1280, stretch `canvas_items` + `expand`; UI uses anchors/containers only (never absolute offsets from edges that expand moves); world content lives in a `Board` Node2D recentered via the `_recenter_board()` pattern; extra revealed space is always ground-colored (clear color).
  - **Skin swap points**: every visual entity (tower, enemy, pad, projectile, decor) owns a child `Skin` (Node2D) holding its placeholder primitives; gameplay scripts never reference nodes inside `Skin`; all feel-tweens target the `Skin` node's transform; Stage 6 swaps art by replacing `Skin`'s children only.
  - **Directory layout**: the canonical tree (`scenes/entities/`, `scenes/ui/`, `scripts/` mirroring, `scripts/autoload/`, `scripts/data/`, `data/`, `theme/`, `assets/`), marking dirs that arrive in later stages; `snake_case` files, `PascalCase` `class_name`s and root nodes.
  - **Theme**: `theme/candy_theme.tres` is registered project-wide via `gui/theme/custom` — style through the theme (or its type variations), no ad-hoc per-node color overrides except placeholder `Skin` primitives; palette table lives in this stage's plan and the theme file.
  - **Commit `*.uid` files** (extend the existing Development-section note: they appear on first import and must always be committed).
- [ ] Update the "Project layout" tree in the same file: `theme/candy_theme.tres` added; `game.tscn` described as "portrait board skeleton (path, pads, HUD zones)" instead of "placeholder". Leave the rest of the README alone (the scaffold→game rewrite is Stage 8's).

### 7. Verify, commit, PR

- [ ] Run the Verification section below end-to-end.
- [ ] `git add -A`; confirm every generated `*.uid` is staged (`git status --short | grep uid`) — if Godot wasn't available locally, no `.uid` sidecars exist yet: say so explicitly in the PR description so the first Godot-equipped session commits them.
- [ ] Commit with a descriptive message (e.g. "Stage 1: portrait shell — 720x1280 flip, candy theme, one-thumb menus, board skeleton with path/pads/HUD zones"), push, open a PR to `main`, and confirm the CI web-export build is green before merge. After merge, play-check portrait rendering on a real phone via https://bitspleasebe.github.io/tower-game/.

## Implementation notes

- **Where "expand" puts extra space**: with `canvas_items` + `expand`, the root canvas keeps (0,0) at the window's top-left and grows in one dimension — extra height on taller-than-9:16 phones (e.g. 20:9 → canvas 720×1600), extra width on wider screens (tablet portrait, desktop). Anchored Controls follow the REAL edges automatically (TopBar/BottomBar/buttons stay pinned — thumb reach is safe); fixed-coordinate Node2D content does not, hence `_recenter_board()`. Never hardcode 1280 as "the bottom" in UI.
- **Orientation hint is only a hint**: browsers ignore `handheld/orientation` outside fullscreen/PWA. A desktop or landscape-phone browser will happily show a wide window — the design answer is: expand adds width, the board recenters, menus stay center-anchored. Verify it looks intentional (centered, no black), don't fight it. `html/canvas_resize_policy=2` in the export preset already makes the canvas track the window.
- **Safe margins are static**: web can't read notch/home-bar insets reliably, so bake generous margins instead — 56 px bottom clearance under the menu buttons, 12 px top margin on TopBar (browser chrome usually covers the notch area in-browser). Do not add a safe-area API dependency.
- **Hand-authoring `.tscn`/`.tres`** (no editor in the sandbox): existing scaffold files are the syntax reference (`format=3`, `[ext_resource type="Script" path="..."]` without `uid` is fine — import fixes UIDs up; commit whatever it rewrites). `load_steps` must be 1 + ext_resource + sub_resource count (wrong values print warnings). Theme property serialization is `<Type>/<data_type>/<name>`, e.g.:
  ```
  [gd_resource type="Theme" load_steps=6 format=3]

  [sub_resource type="StyleBoxFlat" id="btn_normal"]
  bg_color = Color(1, 0.561, 0.694, 1)
  border_width_bottom = 6
  border_color = Color(0.851, 0.333, 0.498, 1)
  corner_radius_top_left = 24
  ... (all four corners, content margins)

  [resource]
  default_font_size = 30
  Button/styles/normal = SubResource("btn_normal")
  Button/font_sizes/font_size = 34
  Button/colors/font_color = Color(1, 1, 1, 1)
  ButtonSecondary/base_type = &"Button"
  ```
  Colors in `.tres` are float RGBA — convert hex as value/255.
- **Curve2D at runtime, not serialized**: building `$Board/Path.curve` from `PATH_POINTS` in `_ready()` avoids hand-writing Curve2D's `_data` triplet format and exactly matches Stage 2, which builds the curve from `MapData.path_points`. The Path2D/Line2D node TYPES still live in the `.tscn` (Stage 2's prerequisite grep checks for them).
- **Line2D candy look**: `joint_mode = 2` (round), `begin_cap_mode = 2`, `end_cap_mode = 2` (round) on BOTH lines, border line wider underneath — sharp 90° path corners come out smooth. `round_precision = 12` is plenty.
- **Control scale pivots at top-left** by default — before any scale tween on a Label/Button set `pivot_offset = size / 2.0`, and do it after layout has run (`await get_tree().process_frame`, or `call_deferred`), because `size` is 0 at `_enter_tree`.
- **Tweens (Godot 4.7)**: `create_tween()` per node; loop idle motions with `set_loops()`; chain `set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)`. Tweens die with their creating node — irrelevant here (menu/board nodes live as long as the scene), but keep the habit.
- **No particles, no pooling, no Events bus, no data resources this stage** — Stage 3 measures the particle decision; adding a GPUParticles2D "just for the menu" would prejudge it. Feel comes from theme styling and transform tweens only.
- **GL Compatibility / no-threads**: nothing in this stage may touch renderer settings or `export_presets.cfg`. StyleBoxFlat shadows/rounded corners and Line2D are all cheap on WebGL2 — no perf risk at this scope.
- **Mouse filters**: `UI/Root` is `MOUSE_FILTER_IGNORE` from day one so Stage 2's board tap-handling never fights the HUD; interactive Buttons keep their default STOP.
- **Keyboard/desktop parity**: focus is grabbed on the first button of each scene (already in the scaffold scripts), VBox containers give sane arrow-key neighbors for free, and the theme's focus ring makes it visible. Esc (`ui_cancel`) keeps working in settings and game scenes.

## Juice checklist

This stage's juice is UI-feel (board character arrives with Stages 2–3):

- [ ] Gumdrop button press on EVERY button via the theme's pressed StyleBoxFlat (bottom lip shrinks 6→2 px, content sinks 4 px) — zero code, applies to all future buttons automatically.
- [ ] Main-menu title bounce-in (`TRANS_BACK` overshoot) then a gentle endless bob.
- [ ] Menu buttons staggered pop-in (scale 0→1, ~0.08 s apart).
- [ ] Visible sky-blue focus ring (feel + keyboard accessibility in one).
- [ ] Build pads idle "breathe" pulse with randomized phase (tween on `Skin` only) — the board reads alive even before gameplay.
- [ ] Boot splash and clear color match the palette — no dark flash anywhere from load to board.

## Acceptance criteria

- [ ] `grep -A8 '\[display\]' project.godot` shows `viewport_width=720`, `viewport_height=1280`, stretch `canvas_items` + `expand`, `window/handheld/orientation=1`; renderer lines still `gl_compatibility`; `git diff export_presets.cfg` is empty.
- [ ] `grep 'theme/custom' project.godot` points at `res://theme/candy_theme.tres`, and no scene sets its own root `theme`.
- [ ] In a phone-portrait viewport, the main menu shows title in the upper third and two ≥ 88 px-tall buttons whose centers sit in the bottom ~25% of the screen; Settings screen matches; no default-grey Godot UI is visible anywhere (every button/panel is rounded pastel).
- [ ] Settings still work after the relayout: fullscreen toggle and volume slider apply and persist across a reload (`user://settings.cfg` behavior unchanged); Esc and Back both return to the menu.
- [ ] New Game shows the board skeleton: mint ground covers EVERY pixel (no black/dark bars) on iPhone SE, Pixel 7, and iPad Mini portrait presets; the path is a thick sand line with rounded corners entering off the left edge near the top and exiting off the right edge lower down; 8 lilac pads, none overlapping the path or each other; TopBar shows the three placeholder labels + Menu button pinned to the real top; BottomBar pinned to the real bottom.
- [ ] On Pixel 7 (20:9) the board sits vertically centered between the bars; on iPad Mini the extra width splits evenly left/right (`_recenter_board()` working both ways).
- [ ] Menu button and Esc leave the game scene; keyboard-only traversal (Tab/arrows + Enter) can operate every screen on desktop with a visible focus ring.
- [ ] `README.md` has the `## Conventions` section (portrait policy, Skin pattern, directory layout, theme rule, `*.uid` rule) and the updated layout tree.
- [ ] The PR's CI web-export build is green; generated `*.uid` files are committed (or their absence is explained in the PR per task 7).

## Verification

1. Local headless, if `godot` is available (otherwise skip to step 3 — CI is the authoritative gate):
   ```sh
   godot --headless --import                                      # zero script/parse errors
   godot --headless --export-release "Web" build/web/index.html
   python3 -m http.server 8080 -d build/web
   ```
2. In Chrome at http://localhost:8080, DevTools → device toolbar, touch emulation ON. Walk every Acceptance criterion on: **iPhone SE** (375×667 ≈ exactly 9:16 baseline), **Pixel 7** (412×915, 20:9 tall extreme), **iPad Mini** (768×1024, short/wide extreme). Then a normal desktop window: resize it tall, wide, and tiny — content stays centered, no black bars, nothing unreachable. Rotate one emulated phone to landscape: ugly-but-centered is acceptable (landscape optimization is a blueprint non-goal), broken/clipped is not.
3. Push the branch, open the PR; the `deploy.yml` PR build must go green (this is the standard remote verification when Godot isn't local).
4. "Smooth" here means: menus and board hold a steady 60 fps in Chrome device emulation with 4× CPU throttling (they're static scenes — anything less means a runaway tween or per-frame allocation; fix it), and the console shows zero errors/warnings-per-frame.
5. After merge, open https://bitspleasebe.github.io/tower-game/ on a real phone: portrait fills the screen, buttons sit under the thumb, board renders, Menu navigates back. File anything odd as notes in the PR thread.

## Out of scope

- Any gameplay: enemies, towers, projectiles, waves, economy, lives, countdown; the data schema (`scripts/data/`, `data/*.tres`); `Events` autoload; live HUD values; `BuildMenu` / pad tap interaction; `scenes/entities/*` — **Stage 2** (its plan already assumes this stage's exact node names and consts).
- Juice autoload, particles/confetti, pooling, screen shake, wave banner, stress harness, `scripts/perf_budget.gd` — **Stage 3**.
- Remaining tower types/enemy archetypes, full wave lists, debug accelerators — **Stage 4**.
- Maps 2–3, `scenes/map_select.tscn`, endless mode, `SaveGame` autoload — **Stage 5**.
- Kenney sprites, real icons (including replacing `icon.svg`), theme nine-patches, fonts — **Stage 6**. All audio — **Stage 7**. Version bump / README rewrite / final polish — **Stage 8**.
- Do not modify `export_presets.cfg`, the renderer, `deploy.yml`, or anything in `inspiration/`.

## Handoff

After this stage, later stages may rely on:

- **Display contract (final, never revisited)**: 720×1280 portrait, `canvas_items` + `expand`, `handheld/orientation=1`, GL Compatibility, no-threads web export; ground = `default_clear_color` mint; boot splash matches.
- **`theme/candy_theme.tres`** applied project-wide via `gui/theme/custom`, with a `ButtonSecondary` type variation and the palette table in this plan — every future Control is styled by default; new UI adds theme types/variations rather than per-node overrides.
- **`scenes/game.tscn` skeleton with canonical names**: `Game` (Node2D) ► `Board` ► `Decor` / `Path` (Path2D, with `PathBorder` + `PathLine` Line2D children) / `Pads`, and `UI` (CanvasLayer) ► `Root` (mouse-ignore) ► `TopBar` / `BottomBar` zones. Stage 2 rebuilds internals but keeps these names, the `_recenter_board()` pattern, and the bar zones (BottomBar is where the BuildMenu sheet lives).
- **Route and pad layout to copy verbatim into `data/maps/map_01.tres`**: `PATH_POINTS` = (-40, 280), (560, 280), (560, 540), (160, 540), (160, 820), (560, 820), (560, 1000), (760, 1000); `PAD_POSITIONS` = (180, 400), (420, 400), (650, 410), (360, 660), (620, 660), (70, 690), (300, 930), (440, 1020) — thumb-tested, ≥ 90 px off-path, ≥ 110 px apart. From Stage 2 on, the `.tres` is the single source of truth and the consts are deleted.
- **Conventions documented in README** and demonstrated in code: `Skin` swap-point pattern (pads and decor already follow it), directory layout, theme rule, committed `*.uid` files.
- **One-thumb ergonomics proven**: 88 px bottom-anchored buttons, static safe margins, `MOUSE_FILTER_IGNORE` on non-interactive UI roots, keyboard/desktop parity — the template every later screen (BuildMenu, ResultOverlay, MapSelect) follows.
