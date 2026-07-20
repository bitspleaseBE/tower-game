# Style review pass 1 (2026-07-20)

Screens: in-level HUD + build sheet; paused overlay (user captures).

## What works
- Pink gumdrop buttons (build / CONTINUE) — keep
- White frosting meadow + plastic bubbles direction
- Pink frosting path read
- Decor candy props (lollipops, canes) exist

## Clashes (why it feels incoherent)
1. **Enemies** — yellow Kenney smileys read emoji, not candy
2. **Tower names** — "Water Cannon" / "Space Gun" are sci-fi vs Lollipop/Ballooner
3. **Tower icons** — mechanical/toy-gun silhouettes fight soft-serve world
4. **Pads** — flat lilac squircles look UI-placeholder vs marshmallow world
5. **Green stars** — only green on board; breaks pink/white/blue candy palette
6. **Font** — Kenney Future is techy; OK short-term, softer candy type later
7. **HUD chrome** — plain white card vs juicy plastic candy

## Fix order (mobile-first)
A. Rename + remount chiller/longshot as candy weapons
B. Remount enemies as gumball/marshmallow critters (keep faces optional)
C. Marshmallow pads + bases
D. Replace green star with sugar/candy star
E. Later: HUD panel ninepatch / softer type

## Applied in pass 1
- Renamed Water Cannon → **Slushie**, Space Gun → **Candy Cane**
- Installed candy remounts (gpt-image-2 from duplicated sources in `assets/_style_pass/src/`):
  critters, slushie + candy-cane weapons t1–t3, marshmallow pad + base_square, candy star icon
- Enemy Kenney face overlay disabled (faces baked into candy bodies)
- Pink buttons left untouched

## Still open
- HUD / pause card still plain vs juicy meadow
- Kenney Future font still techy
- `base_hex` + square t2/t3 pedestals not fully rematched
- Green spark FX on board if still present (track particle modulates)
- Ballooner / Lollipop icons could match meadow gloss more tightly
