# mindreader.quest — Design System: Dark Obsidian Sanctuary

Aesthetic reference: quiet, grounded, psychological, tactile (de-press.co direction). **Strictly NO gold gradients, no fortune-teller kitsch, no Material 3 default purple pills, no emojis in UI labels.**

## Palette

| Token | Hex | Usage |
|-------|-----|-------|
| Canvas | `#09090D` | app background |
| Surface / Glass | `#13131A` | cards, panels, sheets (with `BackdropFilter` blur 16) |
| Hairline Border | `rgba(167,139,250,0.16)` → `0x29A78BFA` | 1 px borders on glass |
| Primary Lavender | `#A78BFA` | primary accent, active states |
| Secondary Indigo | `#6366F1` | glow, secondary accents |
| Harmony Cyan | `#38BDF8` | elemental harmony threads |
| Harmony Emerald | `#34D399` | Water/Earth synergy |
| Conflict Rose | `#FB7185` | elemental conflict threads |
| Conflict Amber | `#F97316` | Fire tension |
| Text Primary | `#E4E4E7` | headings, main copy |
| Text Muted | `#94A3B8` | secondary copy, metadata |

## Typography (via google_fonts, cached after first fetch)

- Arcana titles / headings: **Cinzel** (high-contrast serif).
- Body & interpretations: **Plus Jakarta Sans**.
- Card positions & metadata: **JetBrains Mono**, uppercase, `letterSpacing: 1.8`.

## Motion & game-feel

- Spring default: `SpringDescription(mass: 1.0, stiffness: 320.0, damping: 24.0)`.
- Card flip: 600 ms, `rotateY(π)`, perspective `Matrix4..setEntry(3,2,0.0012)`.
- Isometric tilt: `rotateX(-0.14)` (~8°) per slot.
- Haptics: `selectionClick` per shuffle tick; `mediumImpact` on deal, flip midpoint, lock-on, camera capture.
- All animated elements: `Transform`/`Matrix4`/`Opacity`/`CustomPaint` + `RepaintBoundary`. Never animate layout properties.
- Deal trigger: downward distance > 60 px OR velocity > 450 px/s.

## Components

- **Glass panel**: `#13131A` + blur + 1 px lavender hairline, 24 px radius.
- **Pills**: glass capsule, mono uppercase labels, lavender active state.
- **Card back**: procedural CustomPainter — dark geometric lattice, lavender hairlines, indigo center sigil (no assets needed; optional `assets/cards/<id>.png` override supported via `Image.asset` errorBuilder fallback).
