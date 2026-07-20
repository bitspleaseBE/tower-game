# Bubble Pop — Style bible

**Mood:** Modern HD candy land — glossy **white plastic frosting** terrain with sparse colored swirls and toy-like plastic bubbles; Alice/Up! softness without muddy pastel washes. Everything is **big, simple, and juicy**. Prefer one readable silhouette over busy detail.

## North stars

- **Bloons TD** — pop satisfaction, abstract readability
- **Alice / candy land** — pastel wonder, swirls, lollipops
- **Up!** — soft rounded volumes, friendly clouds of color
- **Chewing gum / bubble pop** — glossy spheres, stretch, burst
- **Main menu** — ice-cream scoop bubbles (one flavor each) float up and pop; **shake the phone** to spill more
- **Boot / web loading** — candy title card `assets/ui/boot_splash.png` (Godot boot splash + HTML `$GODOT_SPLASH`)

![boot splash](images/boot_splash.png)

## Visual rules

1. **Big shapes only** — one clear read at phone size; no tiny filigree.
2. **Thick outlines** + flat candy fills; soft glossy highlight is enough.
3. **Pastels with punch** — pink, mint, lilac, cream, cyan; avoid muddy greys.
4. **Top-down friendly** — weapons face **up** at rest so rotation stays honest.
5. **Kenney backups** live under `assets/tower_kenney/` and `assets/background_kenney/`; live candy art is in `assets/tower/` and `assets/background/`.
6. **Upgrades change the sprite** — each tower has `_t2` / `_t3` weapon + base art and grows footprint (~1.0 → 1.28 → 1.55). No yellow stripe pips.

## Palette (working)

| Role | Feel | Notes |
|------|------|--------|
| Meadow | White glossy frosting + pink/cyan/lilac plastic swirls & bubbles | `ground_meadow.png`, clear color ≈ `(0.988, 0.988, 1.0)` |
| Path | Strawberry frosting | Line2D pinks in `game.tscn` |
| Pads | Lilac marshmallow | `pad.png` |
| UI | Cream + gumdrop buttons | `theme/candy_theme.tres` |
| Boot splash | Lilac candy sky + title | `assets/ui/boot_splash.png`, bg ≈ `(0.929, 0.729, 0.945)` |
| Slow tint | Icy blue wash on critters | `enemy.gd` `SLOW_TINT` |

## World dressing

All map props are **top-down orthographic** (footprints looking straight down — no side-view cones or standing profiles).

| Asset | Fantasy | Image |
|-------|---------|-------|
| Ground | White plastic frosting with colored swirls / bubbles | ![meadow](images/ground_candy_meadow.png) (`ground_meadow.png` on board) |
| Pad | Marshmallow squircle | ![pad](images/pad_marshmallow.png) |
| Tree | Planted swirl lollipop (disk + tiny stick tip) | ![tree](images/decor_lollipop_tree.png) |
| Lolli blue | Smurf-blue swirl lollipop | ![lolli blue](images/decor_lollipop_blue.png) |
| Bush | Cotton-candy puff | ![bush](images/decor_cotton_bush.png) |
| Rock | Jellybean lump | ![rock](images/decor_jelly_rock.png) |
| Gumdrop | Faceted sugar gumdrop (pink / blue) | ![gumdrop](images/decor_gumdrop.png) ![gumdrop blue](images/decor_gumdrop_blue.png) |
| Swirl | Soft-serve scoop from above | ![swirl](images/decor_swirl.png) ![mint](images/decor_swirl_mint.png) |
| Candy cane | Red/white cane flat on the frosting | ![cane](images/decor_candy_cane.png) |
| Bubble gum | Chewed gum blob + blue bubble | ![gum](images/decor_bubblegum.png) |

## Juice verbs

Everything that moves should **squash, wobble, or pop**. Kills = confetti. Water = puddles *under* enemies. Lasers = thin red flash. Bubbles = gum swirl that bursts.

## Don’t

- Military metal, realistic grass blades, gravel roads
- Full-field pastel camouflage washes (meadow must stay **white-first**)
- Tiny high-frequency noise on tiles (kills the “big candy” read)
- Heavy tint overlays on already-colored candy sprites
- Side-view / standing-profile props on the board — map candy is top-down footprints
