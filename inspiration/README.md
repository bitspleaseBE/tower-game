# inspiration/ — asset proposals, not game assets

Candidate asset packs live here for team review before anything enters the
game. Nothing in this folder ships: the `.gdignore` file makes Godot skip the
whole tree (no imports, not in the web export), so it is safe to dump packs
here without bloating the build.

## Structure

```
inspiration/
  <category>/            e.g. player/ enemies/ background/ tower/ ui/ fx/ audio/
    <pack-slug>/         one folder per proposal (one source pack)
      SOURCE.md          provenance: where it came from, author, license, why it fits
      ...files           the pack contents (or a subset — see SOURCE.md)
```

Categories follow the "asset needs" list in [blueprint.md](../blueprint.md) §13.
Aim for 2–4 proposals per category and keep each proposal under ~10 MB
(take a subset of huge packs and say so in SOURCE.md).

## Rules

- Every proposal folder must contain a `SOURCE.md` — a pack without provenance
  can't be promoted later, because we can't attribute it.
- Prefer complete packs from a single author over mixing single files: one
  style family per category is what makes placeholder art look intentional.
- Nothing gets copied from here into `assets/` by hand — use the
  `/select-asset` skill so `assets/ATTRIBUTION.md` stays truthful.
- After a category is decided, prune the rejected proposals (git keeps the
  history if we ever want them back).

## Workflow

1. Fill in `blueprint.md` §9 (visual style) and §13 (license policy, keywords).
2. Run `/find-assets` — proposals appear here with SOURCE.md notes.
3. Review them (the folder is browsable in any PR).
4. Run `/select-asset` on the winner — files move to `assets/`,
   `assets/ATTRIBUTION.md` gets the credit entry.

## Audio note (OGG)

Kenney packs ship as **Ogg Vorbis** on purpose — that is the *light* web format
(Stage 7 prefers OGG over WAV/MP3). A full pack in `inspiration/audio/` can be
~1–2 MB because it holds dozens of unused takes; **the live game only loads what
`/select-asset` copies into `assets/audio/`** (roughly ~20 short SFX + one music
loop, usually a few hundred KB). `inspiration/` has `.gdignore`, so nothing here
is imported by Godot or bundled in the Pages build.
