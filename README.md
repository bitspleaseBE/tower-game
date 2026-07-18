# Tower Game

[![Deploy to GitHub Pages](https://github.com/bitspleaseBE/tower-game/actions/workflows/deploy.yml/badge.svg)](https://github.com/bitspleaseBE/tower-game/actions/workflows/deploy.yml)

A [Godot 4](https://godotengine.org/) game. Currently a scaffold: a main menu
(New Game / Settings), a settings screen with persistent options, and a
placeholder game scene. Game design lives in [blueprint.md](blueprint.md).

**Play the latest build:** <https://bitspleasebe.github.io/tower-game/>

## Project layout

```
project.godot            Project configuration (main scene, autoloads, renderer)
export_presets.cfg       "Web" export preset used by CI (threads disabled, see below)
scenes/
  main_menu.tscn         Entry scene: New Game / Settings
  settings_menu.tscn     Fullscreen + master volume, persisted to user://settings.cfg
  game.tscn              Placeholder — the actual game goes here
scripts/
  settings.gd            "Settings" autoload: loads/saves/applies user settings
  main_menu.gd, settings_menu.gd, game.gd
.github/workflows/
  deploy.yml             Exports the web build and deploys it to GitHub Pages
```

## Development

1. Install [Godot](https://godotengine.org/download) **4.7.1** (keep in sync
   with `GODOT_VERSION` in `.github/workflows/deploy.yml`).
2. Open the project in the editor (import `project.godot`) and press F5, or run
   `godot --path .` from the repo root.

The first time the editor opens the project it generates `.godot/` (ignored by
git) and `*.uid` files next to scripts/scenes — **commit the `.uid` files**,
they keep resource references stable when files move.

## Asset workflow

Fill in `blueprint.md` §9 + §13, then in a Claude Code session run
`/find-assets` — it stages free asset-pack proposals under
[`inspiration/`](inspiration/README.md) with per-pack `SOURCE.md` provenance
notes (Godot ignores that folder via `.gdignore`). After the team picks a
winner, `/select-asset` promotes the chosen files into `assets/` and keeps
`assets/ATTRIBUTION.md` crediting exactly the files the game ships.

## Web deployment

Every push to `main` runs [`deploy.yml`](.github/workflows/deploy.yml), which:

1. Downloads headless Godot + export templates (cached between runs).
2. Exports the `Web` preset to `build/web/`.
3. Publishes it to GitHub Pages via `actions/deploy-pages`.

PRs against `main` run the build without deploying, so broken exports are
caught before merge. You can also deploy any branch manually from the
Actions tab ("Deploy to GitHub Pages" → "Run workflow").

### One-time repository setup

Two settings need a repo admin once; until both are done, deploy runs fail
(PR builds are unaffected):

1. **Enable Pages:** Settings → Pages → Build and deployment → Source:
   **"GitHub Actions"**. The default workflow token is not allowed to enable
   Pages itself; until this is set, runs fail at the "Configure GitHub Pages"
   step with a hint.
2. **Allow `main` to deploy:** Settings → Environments → `github-pages` →
   Deployment branches and tags → add `main`. GitHub creates this environment
   restricted to whatever branch was the default when Pages was first enabled
   (here: the original scaffold branch), so deploys from `main` are rejected
   by environment protection rules — the `deploy` job fails within seconds,
   with no logs — until `main` is on the allowed list.

After both, every deploy is fully automatic.

Notes:

- The web export has **thread support disabled** because GitHub Pages does not
  send the COOP/COEP headers required for `SharedArrayBuffer`. Keep it that way
  unless the hosting changes.
- The project uses the **Compatibility** renderer (WebGL 2), which is what the
  web platform supports.
- To upgrade Godot: install the new editor, bump `GODOT_VERSION` in
  `deploy.yml`, open + resave the project with the new editor, and commit.

### Local web build

```sh
godot --headless --import
godot --headless --export-release "Web" build/web/index.html
python3 -m http.server 8080 -d build/web   # http://localhost:8080
```

(Plain `http.server` works because the export doesn't need cross-origin
isolation — see the threads note above.)
