# Verification plan (v1.0)

Per-stage `## Verification` sections remain the day-to-day gates while building. This document is the **consolidated** plan: what CI must prove, what humans must prove on a deployed build, and the evidence required to call blueprint §11 done.

Related: [README.md](README.md) (roadmap) · [stage-08-release.md](stage-08-release.md) (sign-off owner) · [../.github/workflows/deploy.yml](../.github/workflows/deploy.yml).

## Layers

| Layer | When | Proves |
|-------|------|--------|
| A. Headless / CI | Every PR + `main` | Import, map lint, deterministic rules, web export artifacts |
| B. Local browser | Each stage + release | One-thumb UX, flows, juice, no console errors |
| C. Branch / Pages deploy | Stages 3–8 as each plan requires | Real hosting path (IndexedDB saves, autoplay, phone GPU) |
| D. Device | Stages 3, 4, 6, 7, 8 | Mid-range Android Chrome FPS + touch + audio |
| E. Evidence pack | Stage 8 only | Traceable sign-off for blueprint §11 |

CI never claims B–D. Humans never skip A when Godot/CI is available.

## A — Automated checks (CI)

### Already in deploy.yml (scaffold)

1. `godot --headless --import`
2. `godot --headless --export-release "Web" build/web/index.html`
3. Artifact presence: `index.html`, `index.wasm`, `index.pck`

### Add in Stage 8 (and keep forever)

Run after import (fail job on non-zero exit):

| Script | Asserts |
|--------|---------|
| `scripts/debug/map_lint.gd` | All `data/maps/*.tres`: pad↔path ≥ 90 px, pad↔pad ≥ 110 px, bounds, 12–15 waves, non-null spawn groups |
| `scripts/debug/schema_smoke.gd` | All tower/enemy/map resources load; roster counts; wave-band |
| `scripts/debug/economy_rules.gd` | Sell refund + armor floor samples; endless generate deterministic + non-mutating |
| `scripts/debug/save_defaults.gd` | Missing/corrupt save → defaults; transient run fields not persisted |

Local equivalents:

```sh
godot --headless --import
godot --headless --script scripts/debug/map_lint.gd
godot --headless --script scripts/debug/schema_smoke.gd
godot --headless --script scripts/debug/economy_rules.gd
godot --headless --script scripts/debug/save_defaults.gd
godot --headless --export-release "Web" build/web/index.html
```

Until Stage 5 ships `map_lint.gd`, stages 1–4 keep the current export-only CI gate. Stage 5's plan already runs `map_lint` manually; Stage 8 wires it into CI.

## B — Per-stage manual (summary)

| Stage | Must manually prove |
|-------|---------------------|
| 1 | Portrait menus + board skeleton on SE / Pixel 7 / iPad Mini; no black bars; focus ring |
| 2 | Full win + deliberate loss; BuildMenu tap-away; no double-fire; Menu/Esc mid-run |
| 3 | Juice checklist; `?stress=1` both particle backends → decide; pool node count flat |
| 4 | Four towers × tiers; boss finale; roster stress; counter-play spot checks |
| 5 | Fresh profile → unlock chain; Go endless continuity; **reload persistence** local + deployed |
| 6 | Art swap / MISSING fallbacks; MapSelect badge/preview; payload + texture mem; stress floor |
| 7 | First-gesture unlock; volume persist; stings under pause; stress with audio |
| 8 | Full release journey + evidence pack |

Device presets (default): **iPhone SE** (9:16), **Pixel 7** (20:9), desktop resize; touch emulation ON. Landscape: ugly-but-centered OK.

## C — Deployed-build gates (required, not optional)

| Gate | First required | Command / URL |
|------|----------------|---------------|
| Branch Pages deploy | Stage 3 (perf), then 4, 5, 6, 7, 8 | `gh workflow run deploy.yml --ref <branch>` |
| Save reload on Pages | Stage 5 | Beat map → F5 → beaten/unlock/best intact |
| Audio unlock on Pages | Stage 7 | Silent until first tap; then SFX/music |
| Stress on Pages | Stages 3, 4, 6, 8 | `?stress=1` on phone Chrome |
| RC + post-merge live | Stage 8 | Repeat journey on branch then `main` |

After a branch deploy, remember Pages shows that branch until `main` redeploys — Stage 3/4/6/8 plans already call this out.

## D — Performance definition of "smooth"

| Context | Bar |
|---------|-----|
| Normal map play (throttled emulation) | No visible hitch; console clean |
| Stress at `PerfBudget` caps (measurement device) | Target ~60 fps, **floor 50**; no frame > 50 ms after warm-up (Stage 3) |
| Post-art / post-audio | Same floor unless caps consciously lowered and header updated |
| Menus / MapSelect | Steady 60 in 4× throttle (near-static) |

`PerfBudget` header is the document of record (`MEASURED` vs `PROVISIONAL`). Stage 8 forbids releasing on silent PROVISIONAL.

## Blueprint → test matrix

| Blueprint §11 requirement | Automated | Manual scenario | Device / browser | Evidence | Owner stage |
|---------------------------|-----------|-----------------|------------------|----------|-------------|
| 3 maps, 12–15 waves, beatable & balanced | `map_lint` + `schema_smoke` | Beat maps 1→2→3 at 1× in 5–10 min each; endless falls fairly | Phone Chrome + desktop sanity | Notes + optional clips; lint green in CI | 5 author / **8 sign-off** |
| 4 towers × 3 tiers; place/upgrade/sell; one-thumb | `schema_smoke` (4 towers) | Build each type, tier-3 one, sell each; sheet thumb reach on SE | Phone | Checklist in Stage 4/8 PR | 4 / **8** |
| Auto-wave, lives, win/lose, endless + local best | `save_defaults` + `economy_rules` (endless gen) | Fresh profile → unlock → endless → reload best | **Deployed** Pages + phone | Persistence screenshot/notes | 5 / **8** |
| Juice + full SFX + music | — | Juice checklist + audio hook matrix; unlock after first tap | Phone with sound | Stage 7 PR table + Stage 8 confirm | 3–4, **7**, **8** |
| Live on Pages, smooth mid-range phone | Export artifacts in CI | `?stress=1` ≥ 60 s at caps; normal run feels smooth | Mid-range Android Chrome | FPS / worst-frame in `perf_budget.gd` header + PR | 3 measure / **8 close** |

## v1.0 release journey (Stage 8)

Run on branch RC deploy, then once on live `main` after merge:

1. **Fresh profile** — browser clear site data.
2. **Settings** — set volume mid; confirm persistence after later reload.
3. **Audio unlock** — confirm silence before first tap; tap Play; music/SFX alive.
4. **MapSelect** — map 1 unlocked; 2–3 locked; locked wiggle.
5. **Campaign map 1** — one-thumb win (accelerators off for at least one honest map across the sign-off; others may use ×2).
6. **Win overlay** — Next map / Go endless / Menu; ceremony unlocks map 2.
7. **Maps 2 and 3** — win both; map 3 "All paths defended!"
8. **Endless** — from card or Go endless; 3+ waves; die; NEW BEST if applicable.
9. **Reload persistence** — F5; beaten flags + bests intact.
10. **Mid-run reload note** — start a run, reload, document behavior (see Stage 8 task 9).
11. **Retry / Menu / MapSelect** — no freeze (`paused` false), no double music, `time_scale == 1`.
12. **Stress** — `?stress=1` full-roster ≥ 60 s; record FPS / worst-frame / texture mem / voices.
13. **Desktop sanity** — tall/wide resize; keyboard focus still works on menus.

## Evidence pack (Stage 8 PR + release notes)

- [ ] CI run URL (green) including map_lint + regression scripts
- [ ] Deployed Pages URL tested
- [ ] Device model + Chrome version + OS
- [ ] `PerfBudget` status `MEASURED` with numbers (or lowered caps + rationale)
- [ ] Persistence result (pass/fail notes)
- [ ] Audio first-gesture + volume persist (pass/fail notes)
- [ ] Known limitations list (matches README)
- [ ] Blueprint §11 checklist all `[x]` in the Stage 8 PR description

## Cut-line policy

A stage may ship a documented cut only if:

1. The stage plan allows that cut, and
2. The PR has `## Stage 8 follow-ups` with concrete bullets, and
3. Stage 8 intake closes each bullet (fix or known limitation).

No silent cuts.
