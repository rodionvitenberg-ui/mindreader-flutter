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
- Deck settle spring (riffle square-up): `mass 1.0, stiffness 380.0, damping 26.0`.
- Card flip: 600 ms, `rotateY(π)`, perspective `Matrix4..setEntry(3,2,0.0012)`.
- Riffle fan (Phase 3, realism over max FPS — 40–60 FPS while shuffling):
  - 28 individually articulated real card layers (24–36 range);
  - permanent isometric table camera `setEntry(3,2,0.0014)` + `rotateX(0.16)`;
  - per-card `rotateY`/`rotateZ`/`translateX`/`translateZ`;
  - staggered sine phases `sin(dragPhase + layer × 0.45)`, full separation at 120 px of drag travel;
  - weave tick every 18 px: haptic + adjacent-layer z-swap + `Random.secure()` permutation of the remaining stack;
  - persistent organic rest poses per layer (`dx ±6`, `dy ±3`, `rotZ ±0.045 rad`), regenerated only on table reset;
  - release NEVER snaps back to a brick: the cards settle into a new semi-fanned arrangement (55% of the release travel) that persists.
- Foil specular glint: diagonal lavender/indigo `LinearGradient` overlay sliding with `rotateX`/`rotateY` (shuffle layers, extracted card, flip).
- Hero deck: 220×360 px, 78 painted layers at `dy = -i * 0.35` px (≈27 px of edge thickness) — edge rims + soft drop shadow only, NO plate/frame/bounding box; live counter badge hugging the deck's bottom edge.
- Isometric tilt: `rotateX(-0.14)` (~8°) per pillar slot; the deck itself carries the table camera `rotateX(0.16)`.
- Haptics: `selectionClick` per shuffle/weave tick and on grabbing a card; `mediumImpact` on deal, flip midpoint, lock-on, camera capture, shuffle release.
- All animated elements: `Transform`/`Matrix4`/`Opacity`/`CustomPaint` + `RepaintBoundary`. Never animate layout properties.
- Deal trigger: downward distance > 60 px OR velocity > 450 px/s; grab ANY exposed layer (`pickLayerAt`), extract via `dealCardAt(depth)`.
- Unified scrollable table: deck + dealt cards (both 220×360, gap 28) live in ONE scroll view; the deck never shrinks — resetting is done via the badge tap.

## Multi-deck palettes (procedural, 100% offline)

| Deck | Back style | Accent / Secondary |
|------|-----------|--------------------|
| Rider-Waite | obsidian lattice + sigil | `#A78BFA` / `#6366F1` |
| Marseille | parchment frame + cross-hatch | `#E8D5B5` / `#9A6B4F` |
| Thoth Obsidian | hexagram on glass | `#8B5CF6` / `#22D3EE` |
| Botanical | fern stem arcs + leaf dots | `#34D399` / `#14532D` |
| Hermetic | minimal runic diamond | `#94A3B8` / `#FB7185` |
| Visconti-Sforza | dot lattice + petal medallion | `#D6C7A8` / `#8C6E4E` |
| Shadow Minimal | monochrome lattice | `#71717A` / `#3F3F46` |
| Cyber Arcana | circuit traces + vias | `#22D3EE` / `#F472B6` |

Dropping real images into `assets/decks/<id>/` (id-based or RWS naming)
replaces the procedural face/back automatically.

## Components

- **Glass panel**: `#13131A` + blur + 1 px lavender hairline, 24 px radius.
- **Pills**: glass capsule, mono uppercase labels, lavender active state.
- **Card back**: procedural CustomPainter — dark geometric lattice, lavender hairlines, indigo center sigil (no assets needed; optional `assets/cards/<id>.png` override supported via `Image.asset` errorBuilder fallback).

## Phase 2 additions

- **Elemental Fate Threads** between adjacent face-up cards (56 px gaps):
  plucked-string sine oscillation (2.5–4.0 px amplitude), traveling glow
  particles, gradient blend across the elemental pairing — Fire
  `#F59E0B→#DC2626`, Water `#38BDF8→#6366F1`, Air `#CBD5E1→#A78BFA`,
  Earth `#34D399→#FBBF24`. Tension threads pulse faster than harmony.
- **IntentionPromptBar**: 220-wide translucent obsidian card above the deck —
  mono eyebrow (`SLOT 1 · BEFORE YOU DRAW`), 2-line question (Inter 11.5),
  one horizontally scrollable chip row, compact text/voice input row
  (mic pill, lavender APPLY inline).
- **SynthesizeCta**: ceremonial gradient capsule `✦ SYNTHESIZE READING / СИНТЕЗИРОВАТЬ ПРОГНОЗ` (lavender→indigo, 1.2 px lavender border, 20 px radius).
- **SynthesisPanel**: glass panel with mono section headers
  `1 · CORE NARRATIVE SYNTHESIS`, `2 · ELEMENTAL ALCHEMY` (elemental count
  badges, missing muted, dominant colored), `3 · ACTIONABLE VERDICT`
  (serif italic Socratic follow-up), `EXPAND THE READING · +1 CARD`
  clarifier prompts and `CLARIFIER EXPANSION N` chapters (cyan headers).
