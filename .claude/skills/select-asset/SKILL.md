---
name: select-asset
description: Promote a chosen proposal from inspiration/ into assets/ and keep assets/ATTRIBUTION.md crediting exactly the files the game actually uses. Use whenever the user picks or approves an asset or pack ("use this one", "take the Kenney crosshairs", "promote the zombie pack"), wants inspiration files moved into the game, removes assets, or asks for the credits/attribution file to be updated.
---

# select-asset

Move the team's chosen proposal from `inspiration/` into `assets/` and update
`assets/ATTRIBUTION.md`. The attribution file's contract: **it lists exactly
the files the game ships — nothing more, nothing less.** That's what makes it
trustworthy enough to paste into an itch.io page or credits screen later.

## 1. Resolve and verify the proposal

The user names a proposal ("the Kenney crosshair one") or gives a path
(`inspiration/ui/kenney-crosshair-pack`). Before copying anything:

- The folder must contain a `SOURCE.md` with an explicit license. No
  SOURCE.md or license marked UNCLEAR → stop and re-verify the source page
  (or ask the user); promoting unattributable files creates legal debt.
- Check the license against blueprint §13's policy. CC-BY is fine only if
  the policy allows it — and it makes the credit entry mandatory, not
  courtesy.
- If the proposal is marked manual-download, the files aren't there yet;
  tell the user what to download and where to drop it.

## 2. Copy the minimal set into assets/

- Copy only the files the game will actually use — the user may name specific
  files, otherwise propose a sensible subset (e.g. one crosshair sheet, not
  40 variants) and confirm if the choice is significant.
- Destination: `assets/<category>/` mirroring the inspiration category, with
  clean `snake_case` names (`crosshair_white.png`), decoupled from pack
  naming. Keep spritesheet + metadata files together when they belong
  together.
- Never re-encode or edit the files during promotion; transformations happen
  later as normal game work.

## 3. Update assets/ATTRIBUTION.md

One section per source pack, files listed per repo path. Create the file on
first promotion:

```markdown
# Asset attribution

Files in assets/ and where they came from. Maintained by /select-asset —
every shipped third-party file appears here, and only shipped files do.

## <Pack name> — <Author>
- License: <license + version> (<license url>)
- Source: <page url>
- Files used:
  - assets/ui/crosshair_white.png (pack: crosshairs64.png, cropped none)
```

Rules that keep the contract true:

- Add entries only for files actually copied this run.
- When assets are later deleted or replaced, prune their lines — and drop the
  whole section when its last file goes. If asked to "update attribution",
  reconcile the file list against what's really in `assets/`.
- CC0 packs get entries too: it's courtesy to the artist and provenance for
  us, and it costs one line.
- Original art made by the team doesn't need an entry (note it as
  `— original` only if someone asks).

## 4. Godot follow-ups

- On the next editor open (or CI import), Godot generates `.import` and
  `.uid` files for the new assets — those should be committed.
- Sanity-check size: if the promotion added more than a few MB, mention the
  web build impact (the whole game currently ships ~40 MB).

## 5. Clean up inspiration/ (ask first)

Once a category is decided, offer to delete the rejected sibling proposals
and the promoted folder (git history keeps them recoverable). Never delete
without the user's go-ahead — "decided" is their call, not the skill's.

## 6. Commit

One commit per selection: the new `assets/` files, `ATTRIBUTION.md`, and any
agreed inspiration cleanup, e.g.
`assets: adopt Kenney crosshair pack for ui (CC0)`.
