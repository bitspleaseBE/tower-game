# Stage 8: Release Polish & v1.0 Sign-off

**Status:** not started

Objective: after this stage, blueprint §11 is honestly true — three maps are beatable and balanced, the full roster and endless/saves feel fair, juice and audio are complete, the README describes the game (not the scaffold), the version is bumped, every documented cut-line debt from Stages 2–7 is either fixed or explicitly accepted as a known limitation, and a recorded evidence pack proves the live Pages build on a mid-range Android phone. This stage adds no new mechanics; it closes the product.

## Prerequisites

Stages 1–7 must be merged and deployed. Verify each; if any check fails, stop and fix the earlier stage first.

- [ ] Live build is the full game with audio: https://bitspleasebe.github.io/tower-game/ — Play → MapSelect → map → SFX/music after first tap.
- [ ] CI green on `main`: `gh run list --branch main --limit 1`.
- [ ] Collect debt: open merged PRs for stages 2–7 and copy every `## Stage 8 follow-ups` section into a working checklist (also skim plan Out of scope deferrals). If a stage left no heading, skim its PR description for "follow-up" / "cut" / `PROVISIONAL`.
- [ ] Tools exist: `ls scripts/debug/map_lint.gd scripts/perf_budget.gd`; stress gate (`?stress=1`); Stage 4 accelerators (×2/×4, free-build).
- [ ] `assets/ATTRIBUTION.md` exists and matches `ls -R assets/`.
- [ ] Godot 4.7.x available or plan on CI + branch deploy for verification.
- [ ] Work on a branch: `git checkout -b stage-08-release`.

## Tasks

### 1. Debt intake (first — do not skip)

- [ ] Create a temporary working list (PR description draft is fine) with every open follow-up, tagged `must-fix` / `accept-as-known-limitation` / `out-of-v1`.
- [ ] Must-fix examples: Stage 2 manage mode if somehow still missing; broken persistence; PerfBudget still PROVISIONAL with no device numbers; silent audio hooks the team expected; map_lint FAILs; cut wave counts below blueprint's 12–15 band.
- [ ] Acceptable known limitations must be written into README "Known limitations" (short, honest) — never silent.

### 2. Final balance pass (`.tres` only)

- [ ] Run `godot --headless --script scripts/debug/map_lint.gd` — PASS ×3 before and after edits.
- [ ] Campaign: attentive first-timer can beat maps 1→2→3 in 5–10 minutes each at 1× with a mixed board; ramp rises (map 2 opens harder than map 1 midgame). Tune only `data/**/*.tres`.
- [ ] Counter-play still matters: popper-only struggles on armor waves; longshot-only struggles on swarm — spot-check map 1 and at least one later map.
- [ ] Endless: per map, a maxed board falls within a fair window (~8–20 generated waves); growth doesn't brick at k=1 or trivialize forever; boss recurrence ~every 5th still true; spawn caps hold.
- [ ] Cap tuning passes (timebox): three campaign passes + one endless pass per map, then stop. Residual wonk → known limitations if non-blocking.

### 3. Onboarding & copy

- [ ] First-run hint for "no TD literacy" ([blueprint.md](../blueprint.md) §6): one short, bouncy affordance — e.g. MapSelect subtitle or a single dismissible tip on the first game ("Tap a pad to build!") that never appears again once `SaveGame` has any progress (or a `hint_seen` flag in `save.cfg`). No multi-page tutorial.
- [ ] Copy audit: every on-screen string ≤ ~6 words where blueprint §8 applies (cards, overlays, banners). Replace leftover scaffold phrasing ("New Game" should already be "Play").
- [ ] Wave banner / result lines stay playful; keep the blueprint example energy ("Wave 12 wants a word.").

### 4. Remaining juice (only listed debts)

- [ ] Ship only what earlier stages deferred and Stage 8 intake marked must-fix — candidates from plans: idle tower Skin wobble, low-lives heart pulse, HUD count-up escalation, menu/title polish, MapSelect transition polish. All through `Juice`, inside `PerfBudget`.
- [ ] Do not reopen particle backend, pool architecture, or raise caps silently.

### 5. Art & audio debt decisions

- [ ] For each Stage 6 MISSING art category and Stage 7 silent hook: either (a) team downloaded + promote now via `/select-asset`, or (b) accept primitives/silence as v1.0 known limitation in README. No implicit "we'll get to it."
- [ ] Optional PWA icons/splash: **default decision = out of v1.0** (record in README known limitations) unless a must-fix intake item explicitly takes it on. Portrait orientation remains a browser hint, not a PWA guarantee.

### 6. README rewrite + version bump

- [ ] Rewrite root [`README.md`](../README.md) from scaffold docs to game docs: pitch (from blueprint), how to play (one thumb), Play link, controls, settings/audio-after-first-tap note, attribution pointer (`assets/ATTRIBUTION.md`), local Godot 4.7.1 + web build commands, link to [`blueprint.md`](../blueprint.md) + [`plans/README.md`](README.md).
- [ ] Keep deploy/Pages setup notes (still needed for contributors) but secondary to "what is this game."
- [ ] Bump `config/version` in `project.godot` (and any on-screen version label) to the v1.0 release value agreed by the team (e.g. `1.0.0`).
- [ ] Confirm Conventions section from Stage 1 still accurate (or fold into the rewrite without losing Skin / portrait / uid rules).

### 7. CI verification hooks

- [ ] Extend [`.github/workflows/deploy.yml`](../.github/workflows/deploy.yml) **after** import and **before** export (or after export if scripts need packed assets — prefer after import):
  - `godot --headless --script scripts/debug/map_lint.gd` (fail the job on non-zero).
  - Run any headless regression scripts that exist under `scripts/debug/` / `scripts/test/` introduced by this stage (task 8) — each must `quit(0)`/`quit(1)` cleanly.
- [ ] Do not put browser/audio/FPS checks in CI — those stay manual per [VERIFICATION.md](VERIFICATION.md).

### 8. Headless regression scripts (add what is still missing)

Add small `--script` SceneTree utilities (mirroring `map_lint.gd`) that fail CI on regressions. Implement only stable, deterministic checks:

- [ ] `scripts/debug/schema_smoke.gd` — load all `data/towers/*.tres`, `data/enemies/*.tres`, `data/maps/*.tres`; assert required exports present; map wave counts in 12–15; four towers / five enemies.
- [ ] `scripts/debug/economy_rules.gd` — pure asserts: sell refund `floor(total_spent * 0.7)` sample; armor floor formula `maxf(0.25 * amount, amount - armor)` samples; endless `EndlessWaves.generate` deterministic for fixed (map, wave) and does not mutate packed resources (compare template hp before/after).
- [ ] `scripts/debug/save_defaults.gd` — instantiate SaveGame logic or ConfigFile round-trip: missing file → defaults; corrupt section → safe fallback; `run_map` never written to disk (grep or API contract test).
- [ ] Optional if cheap: scene pack smoke (`load` main_menu/map_select/game `.tscn`).

Wire each into deploy.yml (task 7). Document commands in [VERIFICATION.md](VERIFICATION.md).

### 9. Final performance & persistence gates

- [ ] If `PerfBudget` header is still `PROVISIONAL`, run Stage 3-style device measurement on the release candidate branch (`?stress=1`, full-roster preset) and update the header to `MEASURED` (or accept a lowered cap).
- [ ] Mid-run reload integrity: start a campaign run, play ≥ 1 wave, reload the tab mid-run — document expected behavior (in-memory run request may reset; **beaten/best flags** from prior completed runs must persist). After a completed map + endless best, reload must keep SaveGame state (Stage 5 baseline — reconfirm on RC).
- [ ] Audio: first-gesture unlock + volume persistence on the RC deploy (Stage 7 baseline — reconfirm).

### 10. v1.0 sign-off journey + evidence pack

- [ ] Execute the full journey in [VERIFICATION.md](VERIFICATION.md) § "v1.0 release journey" on the branch deploy, then again on `main` after merge.
- [ ] Fill the evidence checklist (CI URL, Pages URL, device/browser, FPS numbers, persistence result, audio result, known limitations).
- [ ] Commit, PR, merge only when the checklist is complete. Tag or GitHub release `v1.0.0` if the team uses tags (optional but recommended).

## Implementation notes

- **No new systems:** if a fix needs a new autoload or combat behavior, it is out of scope unless a must-fix debt requires a tiny bugfix. Prefer data and copy.
- **Debt honesty beats calendar:** shipping with documented limitations is OK; shipping with silent cut debt is not.
- **map_lint bounds:** if authored pads fail lint, fix the lint bounds or the pads — don't weaken asserts to greenwash.
- **README is the storefront:** itch/GitHub visitors see README first; pitch + Play link above contributor chrome.

## Acceptance criteria

- [ ] Every Stage 2–7 follow-up is fixed or listed under README known limitations.
- [ ] All three maps lint-clean and beatable in the 5–10 minute band; endless eventually overwhelms a maxed board on each map.
- [ ] First-run hint exists and does not nag returning players.
- [ ] Copy is short/bouncy; no scaffold "placeholder" language in player-facing UI.
- [ ] README describes the game; `config/version` is the v1.0 value; attribution complete.
- [ ] CI runs `map_lint` + new headless regressions and fails on violation.
- [ ] `PerfBudget` is `MEASURED` on a real mid-range Android Chrome run, or caps were consciously lowered and documented.
- [ ] Evidence pack complete per [VERIFICATION.md](VERIFICATION.md); blueprint §11 checklist all checked.

## Verification

Follow [VERIFICATION.md](VERIFICATION.md) in full — this stage owns the consolidated gate. Minimum:

1. Headless: import + map_lint + schema/economy/save scripts + web export.
2. Local Chrome journey (Pixel 7 + iPhone SE presets).
3. Branch deploy RC → phone journey + stress + persistence + audio.
4. PR green → merge → live Pages repeat once → record evidence.

## Out of scope

- New towers, enemies, maps, modes, meta progression, accounts, cloud saves, monetization.
- Landscape redesign, gamepad, localization.
- Enabling threads / changing renderer / rewriting deploy hosting.
- Large narrative/tutorial systems.

## Handoff

v1.0 is released. Further work is post-1.0 (new content, PWA, etc.) and starts from a new plan — not silent edits to these stage docs without a new roadmap entry.
