class_name PerfBudget
extends RefCounted
## Hard caps for FX / pooling. Every call site must reference these constants.
##
## Status: PROVISIONAL (Chrome 4x-throttle / local headless only — re-verify Stage 8)
## Device: local desktop + Chrome DevTools Pixel-class emulation (no physical Android)
## Browser: N/A (headless smoke + planned 4x-throttle web export sanity)
## Date: 2026-07-19
##
## Particle backend decision: CPUParticles2D (scenes/fx/confetti_cpu.tscn).
## Why: no mid-range Android phone available for a fair GPU A/B. Architecture default
## is CPU; GPUParticles2D on mobile WebGL2 often hitch on first emit. Ship CPU as the
## sole winner; delete GPU path. Caps below are architecture starting values — lower
## PARTICLES_PER_BURST / MAX_CONFETTI_BURSTS first if Stage 8 device stress dips <50 fps.
##
## SFX voice pool (Sound autoload). PROVISIONAL — re-verify Stage 8 under stress + audio.
## Voice limiting is SFX-only; music uses one dedicated player.

const MAX_ENEMIES := 96
const ENEMY_PREWARM := 32
const MAX_PROJECTILES := 64
const PROJECTILE_PREWARM := 24
const MAX_CONFETTI_BURSTS := 10
const PARTICLES_PER_BURST := 16
const MAX_FLOATERS := 20
const MAX_COIN_FLYERS := 24
const MAX_SHAKE_PX := 5.0
const MAX_SHAKE_DURATION := 0.25
const MAX_SFX_VOICES := 8
