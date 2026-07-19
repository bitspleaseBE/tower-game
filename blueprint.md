# Bubble Pop — Game Blueprint

One page, short answers. This drives build order, scope, and the automated
asset search — keep the **bold field labels** and `[ ]` checkboxes intact so
tooling can parse it. Mark a checkbox like `[x]`.

**Status:** [ ] draft · [x] agreed — **Last updated:** 2026-07-18

## 1. Pitch

Two sentences, max. What is this game and why is it fun?

**Pitch:** **Bubble Pop** — a candy-bright tower defense built for one thumb:
drop cute turrets onto fixed pads and pop waves of wobbling critters before
they reach your base. Everything squashes, stretches, and bursts into confetti —
a TD that feels as good as it plays.

## 2. Story & setting

- **Setting / era:** Abstract candy-land. Bright shapes, soft pastel ground, zero lore.
- **Why are we in a tower:** No fiction needed — the towers are cute turrets on build pads.
- **Who are the enemies and what do they want:** Round wobbling critters that march the path because marching is what critters do. Variety comes from speed/HP/armor archetypes, not backstory.
- **How much story in v1:** [x] none · [ ] intro screen only · [ ] light between-wave flavor text · [ ] more

## 3. Perspective & presentation

- **View:** [ ] 2D side-view · [ ] 2D top-down · [ ] first-person scope view · [x] other: angled top-down (Kingdom Rush-style 2D — mostly overhead, sprites get a hint of perspective/height)
- **Dimension:** [x] 2D · [ ] 3D
- **Orientation:** [ ] landscape · [x] portrait

## 4. Core loop

- **The 30-second loop:** countdown ticks → place/upgrade turrets on pads → wave auto-starts → critters pop, coins drop → spend mid-wave → breather countdown → next wave.
- **Aiming:** N/A — towers auto-target (first-in-range default). No manual aiming anywhere; the player's skill is placement and spending.
- **Ammo & reload:** N/A — towers fire continuously; tension comes from wave pressure and economy, not reloads.
- **Weak points / headshots:** none — enemy variety via archetypes (fast/swarm/armored/boss).
- **Between waves:** [ ] upgrade shop · [x] auto-continue · [ ] repair/ability choices — waves auto-start after a short 5–10s countdown; building/upgrading is allowed at any time, including mid-wave.
- **The hook — what makes it OUR game (one sentence):** Maximum juice — jelly-wobble critters, squash-and-stretch turrets, confetti kill-pops; the most satisfying-feeling TD you can open from a link.

## 5. Win / lose

- **Lose when:** leaked critters each cost a life; at 0 lives the run is lost.
- **Run structure:** [ ] endless + score · [ ] survive N waves = win · [x] level-based campaign — small handcrafted-map campaign; beating a map unlocks **endless mode** on it (waves scale forever, best wave saved locally).
- **Target run length:** 5–10 minutes per map.

## 6. Player persona

- **Who's playing:** casual phone players of any age who tapped a shared link; no TD literacy assumed.
- **They come back because:** the game feels great under the thumb, the campaign is finishable, and endless mode gives score-chasers a reason to return.
- **Session context:** [x] 5-min break · [ ] 15-min session · [ ] longer sittings

## 7. Target platform & input

- **Primary:** [ ] desktop browser · [x] mobile browser · [ ] both (deployed on GitHub Pages either way) — portrait; desktop gets a tall centered canvas.
- **Input:** [ ] mouse + keyboard · [ ] touch · [x] both — designed for one thumb; mouse gets the same tap interactions for free. No gamepad.
- **Performance floor:** smooth on a ~3-year-old mid-range Android phone in Chrome (web export runs without threads, so keep effect counts honest).
- **Note:** `project.godot` is still the scaffold's 1280×720 landscape — flip the viewport to portrait (e.g. 720×1280) when game work starts.

## 8. Tone of voice

- **In-game text sounds like:** minimal and playful — short bouncy words that pop like the art; never a paragraph, never lore.
- **Example line we'd actually ship:** > "Wave 12 wants a word."

## 9. Visual style

- **Style:** [ ] pixel art — tile size: 16 / 32 / 64 · [x] flat vector · [ ] hand-drawn · [ ] low-poly 3D — rounded shapes, thick outlines.
- **Palette / mood:** candy-bright pieces on soft pastel ground; kills read as confetti bursts, UI is chunky and friendly.
- **Reference games / images:** Bloons TD (readability, pop-feel), Kingdom Rush (angled top-down staging, fixed pads), Kenney flat-style packs (e.g. "Tower Defense Top-Down") for the shape language.

## 10. Audio direction

- **SFX character:** punchy arcade — pops, boings, and coin tinks on every interaction. SFX ship in v1; they're half the juice hook.
- **Music:** one cheerful upbeat gameplay loop (menu can reuse it quieter). CC0 sources only, same as art.

## 11. Scope & success (the honesty section)

- **v1.0 is done when:** (max 5 bullets)
  - 3 handcrafted portrait maps, ~12–15 waves each, beatable and balanced.
  - 4 tower types × 3 linear tiers; place / upgrade / sell, fully one-thumb.
  - Auto-wave pacing with countdown, lives, win/lose flow — and endless mode unlocking per beaten map with local best-wave.
  - Juice pass on everything that moves + full SFX + music loop.
  - Live on GitHub Pages, smooth on a mid-range phone.
- **Explicit non-goals for v1.0:** (things we agree NOT to build)
  - Monetization, accounts, or cloud saves (local save only).
  - Meta progression between runs (no permanent upgrades).
  - Landscape/desktop-optimized layouts, gamepad support, localization.
  - More enemy/tower content beyond the roster above.
- **Time budget / target date:** steady weekly progress; release-quality gates beat calendar dates — but scope above is deliberately small enough to finish.
- **Why we're building this:** [ ] fun & learning · [ ] portfolio piece · [x] real release ambitions

## 12. Inspirations

- **Games we're borrowing from, and what exactly:** Bloons TD — cute-abstract readability and pop satisfaction; Kingdom Rush — fixed build pads, angled view, wave rhythm; the juice canon (Peggle, Nintendo UI feel) — over-delivering feedback on every tap.

## 13. Asset search inputs (machine-read by the asset finder)

- **License policy:** [x] CC0 only · [ ] CC0 + CC-BY with credits file · [ ] anything free for commercial use — commercial release planned, keep it obligation-free.
- **Search keywords:** flat vector, rounded, cute, candy, pastel, top-down tower defense, turret, blob, critter, path tiles, portrait UI, hearts, coins, confetti, pop sfx, cheerful loop
- **Asset needs, in priority order:** ground/path tileset · critter sprites (walk + death/pop) · tower sprites (4 types × 3 tiers) · UI (buttons, hearts, coins, wave counter) · FX (confetti, pops, muzzle puffs) · SFX (pop, place, upgrade, coin, leak, win/lose sting) · music loop
