---
name: find-assets
description: Hunt free game asset packs (sprites, tilesets, UI, later audio) and stage them as reviewable proposals under inspiration/<category>/<pack>/ with SOURCE.md provenance notes. Use whenever the user wants to find, search for, gather, or propose art, sprites, sound, or asset packs for the game, mentions Kenney, OpenGameArt, itch.io, or free/CC0 assets, or asks to fill the inspiration folder — even if they don't say "find assets" literally.
---

# find-assets

Find free asset packs that fit the game's blueprint and stage them as
**proposals** in `inspiration/` for team review. This skill never touches
`assets/` — promotion happens later via `/select-asset`, which is also what
keeps attribution truthful.

## 1. Gather inputs

Read `blueprint.md`:

- **§9 Visual style** — pixel vs vector, tile size, palette mood. This is the
  main fit criterion.
- **§13 Asset search inputs** — license policy, keywords, category priority.

Arguments override the blueprint (e.g. `/find-assets background enemies`).
If §13 is still unfilled and no args were given, ask the user for keywords +
license policy instead of guessing — a hunt with wrong inputs wastes review
time. Default to images first; only hunt audio when asked or when all image
categories have proposals (audio taste is harder to judge from thumbnails,
so it benefits from the style being settled first).

## 2. Detect which mode you're in

Interactive browsing beats scraping (you can see thumbnails, click download
buttons, read license text in context), but some sandboxed environments
kill full-browser connections at the egress proxy. Probe once:

```sh
node .claude/skills/find-assets/scripts/browse.js shot https://kenney.nl /tmp/probe.png
```

- **SHOT OK** → interactive mode: use `browse.js` `shot`/`dump`/`download`
  for everything. Judge style by reading the screenshots.
- **NET_BLOCKED** → degraded mode: `browse.js dump`/`get` still work via curl.
  Site support differs, see the source notes below. Judge style by
  downloading preview images (`get`) and reading them.

If playwright is missing, `npm install playwright` in a scratch directory
(Chromium is preinstalled in Claude sandboxes; locally run
`npx playwright install chromium` once).

## 3. Where to hunt, in order

Prefer **complete packs by a single author** over best-single-file-per-need:
one style family per category is what makes placeholder art look coherent,
and a pack means one license to check instead of ten.

1. **kenney.nl** — CC0, huge, internally consistent. Search
   `https://kenney.nl/assets?q=<kw>`. Degraded-mode note: search results are
   JS-rendered, so discover packs via WebSearch ("kenney <thing>") or the OGA
   mirrors; pack downloads need interactive mode or a mirror.
2. **opengameart.org** — search
   `https://opengameart.org/art-search-advanced?keys=<kw>`; content pages
   state the license and link files directly under
   `sites/default/files/...` (curl-friendly in every environment). Filter to
   the blueprint's license policy.
3. **itch.io** — `https://itch.io/game-assets/free/tag-<kw>`. Rich but
   licenses vary per pack: read the pack page's license text, never assume.
   Degraded-mode note: itch blocks curl; use WebFetch for discovery and mark
   downloads manual if the button flow can't run.

## 4. Judge fit before downloading

For each candidate check, against the blueprint: style match (pixel art vs
vector, tile/sprite size), completeness (characters need walk + death frames;
tilesets need enough variety), palette mood, and license. Look at the
thumbnails/previews — filename keywords lie. Skip anything whose license you
cannot quote from the page.

Aim for **2–4 proposals per category**, each under ~10 MB. For huge packs,
keep the relevant subset and note the omission in SOURCE.md.

## 5. Stage proposals

```
inspiration/<category>/<pack-slug>/
  SOURCE.md
  ...pack files (unzipped; delete __MACOSX, .DS_Store and other junk)
```

Categories come from blueprint §13 (e.g. `background`, `enemies`, `player`,
`tower`, `ui`, `fx`, `audio`). `inspiration/` has a `.gdignore`, so nothing
here is imported by Godot or shipped in the web build.

`SOURCE.md` template — fill every line; a proposal without provenance cannot
be promoted later:

```markdown
# <Pack name>
- Source: <page url>
- Author: <name> (<profile url>)
- License: <exact license + version as stated on the page> (<license url>)
- Downloaded: YYYY-MM-DD  (or: Status: manual-download needed — <direct url>)
- Contents: full pack | subset (<what was left out and why>)
- Why it fits: <1–2 lines referencing blueprint §9/§13>
```

If a download can't be automated in the current environment, still create the
folder with a complete SOURCE.md and the manual-download status — the
proposal is then a 30-second human task instead of a lost find.

## 6. Report

End with a short summary per category: proposals staged, one-line
recommendation each, anything marked UNCLEAR license or manual-download.
Remind the user: review `inspiration/`, then `/select-asset <winner>`.
Commit the proposals (they're reviewable in the PR) unless the user asked
otherwise.
