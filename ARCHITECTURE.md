# mindreader.quest — Flutter Architecture

Pure Flutter/Dart mobile app (Android APK + iOS). No legacy JS. Impeller renderer target: 60–120 FPS game-feel on touch.

## SPRINT 1/2 — Multi-System Divination (Tarot | Lenormand | Runes)

The Digital Table, Oracle Chat, Session History and Almanac now host **three authentic divination systems** behind one unified domain:

| System | Deck size | Pieces | Reversals | Canonical spreads |
|--------|-----------|--------|-----------|-------------------|
| `DivinationSystem.tarot` | 78 | `TarotDivinationCard` | reversed allowed | 1 Daily Anchor · 3 Triad Flow · 4 Target & Shadow · 7 Deep Synthesis |
| `DivinationSystem.lenormand` | 36 | `LenormandDivinationCard` | **never** (tradition) | 1 Daily Sign · 3 Lenormand Line · 5 Cross of 5 · 9 3×3 Portrait Box |
| `DivinationSystem.runes` | 24 | `RuneDivinationCard` | merkstave only for non-symmetrical runes (Gebo/Isa/Hagalaz/Jera/Eihwaz/Sowilo/Ingwaz/Dagaz stay upright) | 1 Odin's Rune · 3 Three Norns · 5 Thor's Cross · 7 Heimdall's Bridge |

Core pieces:

- **`DivinationCard` sealed union** (`lib/core/models/divination_card.dart`) — one interface (`id`, `name`, `shortLabel`, `categoryLabel`, `element`, `keywords`, `upright`, `reversed?`, `reflection`, `supportsReversal`) consumed by threads, oracle, history and inspectors.
- **Datasets:** `lenormand_data.dart` — the canonical 36 Petit Lenormand cards (Rider..Cross) with Blue Owl playing-card insets (9 per suit ♥♦♣♠), elemental affinities, pair-combinatory meanings and timing; `runes_data.dart` — all 24 Elder Futhark runes across the 3 Aetts with glyph/phonetic/element/upright/merkstave/lore.
- **Packs:** 3 Lenormand packs (Antique Petit / Obsidian Gilded / Botanical Noir) + 3 rune stone sets (Obsidian & Lavender Quartz / Nordic Carved Bone & Gold / Blood Jasper & Runic Fire), each with procedural fallbacks and drop-in asset folders `assets/lenormand/<id>/NN.jpg` and `assets/runes/<id>/<rune_id>.png`.
- **SpreadController** holds `system` + one spread enum per system; `setSystem()` resets the table AND the physical stack to the system's canonical size. `dealCardAt()` is the single orientation authority: Lenormand always upright, symmetrical runes always upright.
- **3D tactile rune stones:** `InteractiveRuneStonesWidget` replaces the paper deck for RUNES — an organic pebble heap (radial rock shader, chiseled rim light, specular glint, deep shadows); horizontal drag swirls/clatters with `mediumImpact` haptics + ledger re-weaves, downward drag grabs the top stone and casts it past 60 px / 450 px/s; tapping a face-down cast stone etches the glowing glyph (650 ms ignite).
- **Digital Table header (3 rows):** Row 1 `[FOCUS VIEW | SPREAD VIEW]`, Row 2 `[TAROT | LENORMAND | RUNES]`, Row 3 system-filtered pack pill + concise spread pill. The RITUAL button and the "78 IN DECK" / "78 •" counters are removed (ritual moves to the Astral dock later). The physical-sync badge moved to a slim ribbon above the table.
- **Almanac:** Row 1 system switcher (synced with the table), Row 2 search + pack pill, Rows 3/4 context-aware filters (Tarot: elements + arcana/suits; Lenormand: playing-card suits; Runes: elements + Aetts).
- **Oracle & history compatibility:** `synthesizeSpreadFor`/prompt builders are system-aware (pair-reading hint for Lenormand, merkstave wording for runes); `SpreadSessionSnapshot` persists `system` + all three spread enums and restores any of the 3 systems 1-tap.

## The 3 Pillars (3-Tab Bottom Navigation)

| Tab | Feature | Core loop |
|-----|---------|-----------|
| 0 | Camera Scanner | Physical spread → vision detect → handoff to Table (cards already face-up) |
| 1 | Digital Table (default, core) | Tactile deck/stones, shuffle, deal, flip, elemental threads, live reading |
| 2 | Almanac | Offline searchable library: 78 tarot + 36 Lenormand + 24 runes |

## State architecture

- Single `SpreadController` (`ChangeNotifier`, injected via `provider`) is the SSOT for both Camera and Table flows.
- Domain logic is pure and testable: shuffle (Fisher–Yates, `Random.secure()`), dealing, flipping, elemental dignity, synthesis text.
- Local-first: completed readings persist via `shared_preferences`. No accounts, no cloud required.

```
SpreadController
├── system: DivinationSystem.tarot|lenormand|runes
├── deck: active system's 78/36/24 DivinationCard + isReversed
├── spreads: spreadType (1/3/4/7) | lenormandSpread (1/3/5/9) | runeCast (1/3/5/7)
├── slots: List<DealtCardSlot> (empty → faceDown → faceUp)
├── dealNextCard() / flipSlot() / setSystem() / loadScannedSpreadFaceUp()
└── threads: computed dignity per adjacent face-up pair (pure fn in oracle service)
```

## Digital Table physics (game-feel contract)

- Deck gestures are touch-scoped **only** to `InteractiveDeckWidget` (`HitTestBehavior.opaque`); table scrolling never triggers shuffle/deal.
- **Real 78-layer 3D deck:** the physical stack IS `remainingDeck` (78 → 0, configurable `totalCards`). Every remaining layer `i` renders at `dy = -i * 0.35` px with depth shading (`DeckStackPainter`), forming a visible 3D card-edge stack whose thickness and the live counter badge deplete by 1 on every deal.
- **Uncompromised multi-card riffle** (Phase 3): horizontal drag on the deck fans **20 real, individually articulated card layers** (visual cap 18–20 — the Poco C65 performance fix; the logical 78-card state stays fully intact for the counter and probabilities) in 3D under the permanent isometric table camera — per-card `Matrix4` with `setEntry(3,2,0.0014)`, `rotateX(0.16)`, `rotateY`/`rotateZ`/`translateX` and `translateZ` depth, staggered sine phases `sin(dragPhase + layer × 0.45)` so cards arc, lift, cascade and interleave. Every **18 px** of drag fires `selectionClick` + an adjacent-layer z-swap (the visible weave) + `weaveShuffleRemaining()` (`Random.secure()` permutation of ONLY the remaining cards — depletion and dealt cards preserved). Release → the **exact finger-release pose is BAKED as the new permanent rest state** in the same frame — at most an 80ms `Curves.easeOutCubic` micro-damp drifts the fan FORWARD along the release velocity (`ShuffleMicroDamp`, `to >= from` enforced), so the cards NEVER roll/settle backward toward an older pose — the deck never snaps back into a laser-aligned brick, and the interleaved layer order is kept. Every visible layer also carries a persistent lived-in `CardRestPose` imperfection (dx ±6, dy ±3, rotZ ±0.045 rad) so even an untouched deck sits unevenly. Product decision: realism over max FPS — target 40–60 FPS during active shuffling (20 GPU-composited layers, each inside its own `RepaintBoundary`, ZERO per-card `BoxShadow`s — one soft ambient shadow under the stack as a whole).
- **Foil specular glint:** a diagonal lavender/indigo `LinearGradient` overlay (`FoilGlint`) slides across card backs and faces as `rotateX`/`rotateY` change — during shuffle, the dealt-card flight and the **680ms ceremonial flip** (`Curves.easeInOutCubic`, clean edge-on perspective with ZERO protruding side strips/bevel bars outside the card's rounded border) — so the user feels each card's angle and weight.
- **Deal (pick ANY exposed card):** vertical drag on the deck hit-tests the card layer under the finger (`pickLayerAt` — the most exposed card at that spot wins), lifts it toward the camera (`translateZ` +26, lavender glow) and follows the finger 1:1. Released past the deal threshold (>60 px or >450 px/s), the exact grabbed card is extracted (`dealCardAt(depth)` — physically removed from the stack) and flies in ONE continuous motion from the finger's release point into its slot: `extractedFlightMatrix(pose, t)` is pixel-identical to the deck's lifted card at t=0 and to the slot card's tilt matrix at t=1, so there is ZERO pop and ZERO scale mismatch (220×360 from extraction to landing).
- **One unified scrollable table canvas (Focus View):** header (84) → `SingleChildScrollView` with ONE `ScrollController` → bottom control bar. The full-size 220×360 deck sits at the top of the scroll content, the dealt 220×360 cards (gap 28 px, slot gap 20) sit directly below it on the same central axis. Scrolling moves the deck off the top edge naturally; it NEVER shrinks/collapses into a header. Touching the deck captures shuffle/deal gestures; touching anywhere else scrolls the table. **Dealing never auto-scrolls** — the camera stays on the deck while the card flies below the fold; the user scrolls down manually.
- **The Pillar:** a plain vertical column of dealt cards (220×360 — 1:1 with the deck) inside the unified scroll view; no inner scrolling, no placeholders.
- **Dual view modes:** a `FOCUS VIEW ↔ SPREAD VIEW` pill toggle in the top bar switches the table. **Spread Overview** puts the ENTIRE spread on one screen like a real tarot table: a compact **90×148 mini-deck** (tap to draw the next card — a scale-aware flight from 90/220 to the slot scale) in the corner, the dealt slots in their **true spread geometry** (Triad row / Target & Shadow 2×2 / Deep Synthesis 3-1-3 with a centered crossing card) inside a `FittedBox` that scales the design canvas to the viewport; empty slots render hairline role placeholders, dealt slots are full interactive `TarotCard3DWidget`s (tap = flip / open reading). Landscape is unlocked via `SystemChrome.setPreferredOrientations`: the deck panel anchors LEFT and the wide canvas expands right (badge beside the deck to fit the short viewport).
- **Full spread reset:** when every slot is dealt, the badge hugging the deck's bottom edge switches to *"Tap to Reset / New Spread"*; tapping it calls `resetTable()`, which re-inserts ALL dealt cards into the 78-card stack (`_resetDeck` — the deck itself never shrinks). The ledger invariant `remaining + dealtCount == 78` holds through deals, weaves, resets and spread switches.
- Elemental threads: `CustomPainter` bezier between adjacent face-up cards; harmony (same element or Water+Earth) = cyan/emerald pulse, conflict (Fire+Water, Air+Fire) = rose/amber pulse, else neutral indigo glow.

## Multi-deck engine (7–8 selectable decks)

- `TarotDeckPack` (`core/models/tarot_deck_pack.dart`): id, name, subtitle, `assetFolder`, `cardBackStyle` (7 procedural back patterns), ARGB palettes, `backAsset` (optional `back.jpg/png`), `isLocked/isPro`, license/attribution.
- `deckPacksRegistry` (`core/data/deck_packs_registry.dart`): 8 packs (Rider-Waite, Marseille, Thoth Obsidian, Botanical, Hermetic, Visconti-Sforza, Shadow Minimal, Cyber Arcana) pointing at `assets/decks/<id>/` — drop the downloaded deck images there (id-based `00.jpg`..`77.jpg` or RWS naming) and they replace the procedural artwork automatically.
- **Smart asset resolver with zero-crash fallback:** `_CardFace` tries legacy `assets/cards/<id>.png` → pack candidates (`<id>.jpg/png`, padded, RWS names) → a bespoke procedural face in the pack's palette. Missing files never crash — every deck works 100% offline.
- `DeckPackController` (`state/`): SSOT of the active pack, persisted via `SharedPreferences` (`LocalStorageService.saveDeckId/loadDeckId`), restored on startup.
- **Deck Selector:** pill in the Digital Table header AND the Almanac header opens a horizontal 3D carousel bottom sheet (`DeckPickerSheet`) — live preview of each pack's back, PRO badges, license lines, instant switch.

## Local ritual notifications (zero server retention)

- `RitualNotificationService` (`core/services/`): daily local reminders — **09:00 "Morning Anchor — Draw your Daily Anchor card."** and **22:00 "Evening Reflection — Ground your thoughts before sleep."** (`flutter_local_notifications` + `timezone` + `flutter_timezone`, inexact daily repeat, battery friendly). Abstracted so unsupported platforms (desktop/web/tests) degrade to no-ops; every plugin error is swallowed — settings persist regardless.
- Bell pill in the table header opens `RitualSettingsSheet`: enable toggle, per-ritual time pickers, current reading streak.
- Streak: `LocalStorageService.recordReadingDay()` is called when a reading is saved; `computeStreak()` (pure) counts consecutive days ending today/yesterday.

## Services (dual AI pipeline)

- `VisionScannerService`: compress captured image to ≤1024 px JPEG (`package:image`), then detect through: **1) PRIMARY local/tunneled RTX 3080 worker** (`PRIMARY_WORKER_URL`, OpenAI/Ollama-compatible, **3500 ms timeout**) → **2) FALLBACK Gemini Flash cloud** (`VISION_API_URL`/`VISION_API_KEY`) → **3) OFFLINE deterministic mock**. Any worker timeout/error falls through automatically; the app never crashes without network/keys. Zero-Knowledge: keys and payloads are never logged.
- `OracleSynthesisService.synthesize()`: same chain for the reading text — RTX 3080 chat (3500 ms) → Gemini Flash (`ORACLE_API_URL`, `GEMINI_API_KEY`) → local `synthesizeSpread` engine. The reading sheet awaits it and reveals the result with the typewriter effect.
- `LocalStorageService`: spread history, active deck id, ritual prefs, reading days — all via `shared_preferences` (JSON).

## Sprint 2/3 — Gemini-inspired 3-pane workspace & decluttered table

The TABLE tab now hosts `TableWorkspace` — a horizontal 3-pane `PageView` with a
3-pill indicator (`TABLE • ORACLE CHAT • HISTORY`) for 1-tap switching:

- **Pane 0 — Digital Table** (decluttered): no `BEFORE YOU DRAW` box above the
  deck, no bottom spread carousel. The spread method lives in the tappable
  header subtitle (`3 · TRIAD FLOW · 78 IN DECK ▾` → `SpreadSelectorSheet`).
- **Pane 1 — Oracle AI Chat**: full-width Gemini-style conversation — pinned
  spread header strip (mini card glyphs + elemental balance badges, tap/swipe
  → back to the table), the structured synthesis as the first message,
  clarifier expansion chapters, free Q&A via `OracleSynthesisService.answerChat`
  (dual AI chain + deterministic local fallback).
- **Pane 2 — Spread History & Notebooks** (`PRO` badge): local-first archive,
  `+ NEW SPREAD`, notebook filters (All Readings / Relationships / Career &
  Path — derived from context chips), **1-tap full session restore**
  (`SpreadSessionSnapshot` JSON round-trip: exact cards/orientations/roles,
  session notes, synthesis, clarifiers, whole dialog).

**Gesture disambiguation:** the 3D deck (220×360) sits deepest in the gesture
arena, so horizontal drags on it always riffle the deck; swiping anywhere else
(background, header, dealt cards) pans the PageView.

**Gemini input capsule** (shared Table/Chat, above the bottom nav dock):
`+` action sheet (context chips / 📷 attach camera card / ✦ new spread),
expandable text field, mic dictation, circular accent send.
On the table, submits play **"Sent to Cosmos"** — the thought rises from the
capsule and dissolves into stardust (`CosmosSendBurst`, deterministic painter)
and lands in `SpreadController.sessionContextNotes`; the next dealt card also
inherits the pending context. Synthesis + chat turns upsert the session into
`SessionHistoryController` (in-memory first, background `shared_preferences`
write — the UI never waits on storage).

## Sprint 3/3 — Authentic spread caps, Deal Lock & AI-guided +1 Clarifiers

**Canonical spread caps & slot roles** (`SpreadType.cardCount` / `slotRoles`):

- `1 • Daily Anchor` — 1 card (*Core Daily Impulse*).
- `3 • Triad Flow` — 3 cards (*Current State / Essence, Hidden Shadow / Block,
  Vector / Action*).
- `4 • Target & Shadow` (Two Shores Cross) — 4 cards (*Your Shore,
  The Other / Environment, What Bridges or Blocks, Turning Point*).
- `7 • Deep Synthesis` (Horseshoe) — 7 cards (*Past, Present,
  Hidden Influences, Obstacle, External Forces, Advice, Outcome*).

**Deal Lock** (`SpreadController.isDealLocked` / `allowedCardsLimit`): as soon
as `dealtCount == baseCardLimit` the deck refuses further draws — the whole
deck can never be dumped onto the table. A swipe on the locked deck springs
the card back and shows the subtle haptic/visual prompt
*"Flip all cards face-up and synthesize in Chat before drawing a clarifier."*
(`showDealLockPrompt`, shared by the tactile deck and the overview mini-deck).

**AI-generated Clarifier Questions** (`buildClarifierSuggestions`): the
synthesis in Pane 1 ends with 2–3 tappable probes
(`🃏 +1 CARD: …`) that dynamically reference the actual cards and elemental
tensions on the table — the sharpest reversed/shadow card's resistance, a
concrete conflict thread pair, the dominant element. Pure + deterministic,
recomputed from the live table after every clarifier flip.

**The +1 unlock loop**: tapping an AI question (or typing a custom question
in the input capsule and tapping `🃏 +1 CARD FOR MY QUESTION`) arms
`pendingClarifierQuestion` and raises `allowedCardsLimit` to exactly
`dealtCount + 1`. The PageView slides back to the table where the armed
question shows as a banner (`clarifier-banner`; the deck badge reads
`PULL CLARIFIER ↓` and toggles the arm off on tap). Pulling the single
unlocked card consumes the question into `Clarifier N+1` and **relocks the
deck immediately**. Flipping it face-up streams a `CLARIFIER EXPANSION`
chapter answering exactly that question, followed by fresh follow-up
prompts. In `physicalCameraSync` mode the same arm routes through the camera.

**Hard 10-card ceiling** (`SpreadController.maxTableCards = 10`): at 10
cards arming fails, every deal path returns null, and the chat shows
*"MAXIMUM OF 10 CARDS REACHED FOR THIS READING — THE CONVERSATION STAYS
OPEN"* while text/voice Q&A continues freely.

## Sprint 6 (screenshot-driven polish — 1000049361–1000049372)

- **Uncropped full-bleed card art** (`TarotDeckPack.isIllustrated`, `_CardFace`):
  the 7 real decks (rider_waite, marseille, oswald_wirth, etteilla,
  visconti_sforza, vieville, soimoi) render the historical scan edge-to-edge
  inside the rounded card border — NO `Nine / ▽ WATER` / `CUPS · WATER` /
  `MAJOR ARCANA` header/footer bars over the artwork, on the Digital Table
  and in the Almanac grid. `obsidian_minimal` keeps the typographic face
  with its bars; missing scans still fall back to the typographic face.
- **Taut slow elemental threads** (`ElementalThreadsPainter`): transverse
  deviation capped at 3.0 logical px with a single gentle sine (no
  rubber-noodle S-curves); the wave period is exact wall-clock seconds —
  5.0 s harmony / 4.75 s neutral / 4.5 s conflict (~3x slower) — and the
  4 luminous particles glide the full cord in the same period.
- **Card Inspector Sheet** (`ReadingBottomSheet` with `cardIndex`): tapping
  a face-up card now opens a clean inspector — large title + `· REVERSED`
  orientation, element badge (`EARTH ▫ / WATER ▽ / FIRE △ / AIR ◇`),
  `SLOT N · ROLE` line, the drawn orientation's meaning + keywords,
  3 single-select resonance pills (`Resonates / Challenging / Unclear`),
  and a compact text+mic note field that auto-saves into
  `slot.userContext` (`SpreadController.updateSlotUserContext`). The
  `READING CONTEXT` chips and `SYNTHESIZE SPREAD` button are GONE from
  this modal (the Live Reading sheet keeps them).
- **Oracle chat context pills** (`_ChatContextChips`): single-select radio
  behavior, one active pill at a time; all 3 pills in one `Row` of
  `Expanded` children (equal width, 8 px gaps, 16 px screen padding) —
  zero size change on tap, zero overflow; selection is a soft lavender
  tint (#A78BFA @ 22%) + glowing 1.2 px border, no `✓` icon; tapping a
  pill silently updates the context state and NEVER appends
  `Context woven into the reading` lines to the chat log.
- **Spread history pills**: the double-`+` (`+  + NEW SPREAD · НОВЫЙ
  РАСКЛАД`) is fixed (single `+` icon); `ALL READINGS / RELATIONSHIPS /
  CAREER & PATH` live in an equal-width `Expanded` row with `FittedBox`
  labels — no right-edge clipping.
- **Almanac element filter bar**: the static `ELEMENTS` label is deleted;
  4 equal-width interactive element filter buttons (`△ Fire · ▽ Water ·
  ◇ Air · ▫ Earth`) with a soft elemental glow filter the grid to that
  element; tapping the active one clears the filter. Earth's glyph is now
  `▫` (was `□`).
- Tests: 137 green (new `almanac_element_filter_test.dart`; updated
  `app_smoke_test`, `workspace_layout_test`, `phase2_flow_test`,
  `workspace_swipe_test`), `flutter analyze` clean.

## Folder map

```
lib/
├── main.dart
├── core/
│   ├── theme/            # Obsidian + Lavender design tokens & ThemeData
│   ├── models/           # TarotCard, SpreadType, DealtCardSlot, ChatMessage
│   ├── data/             # 78-card RWS dataset + Socratic questions + chips
│   └── services/         # vision, oracle (dignity + synthesis + chat), local storage
├── state/                # SpreadController, SynthesisSession, SessionHistoryController,
│                         # SpreadSessionSnapshot (ChangeNotifiers)
└── features/
    ├── shell/            # 3-tab bottom bar (Camera | Table | Almanac)
    ├── camera_scan/      # native camera UI + lock-on animation
    ├── digital_table/    # table_workspace (3-pane PageView), oracle_chat_pane,
    │                     # spread_history_pane, deck, pillar, 3D cards, threads,
    │                     # gemini_input_capsule, cosmos_send_burst, sheets
    └── almanac/          # filterable library + 3D detail sheet
```

## Verification

- `flutter analyze` — zero errors/warnings. ✅
- `flutter test` — 133 tests green: domain (deck integrity, shuffle, deal,
  flip, dignity, synthesis, session notes, snapshot round-trip, restore,
  spread caps, deal lock, +1 unlock loop, 10-card ceiling, AI clarifier
  suggestions) + widget (boot → deal → flip → reading sheet, workspace
  swipes & deck gesture isolation, capsule → cosmos, synthesize → chat pane,
  AI question → unlock → pull → clarifier reading, custom-question arming,
  locked-deck prompt, camera sync, history save/restore). ✅
- `flutter build apk --debug` (Android SDK present on host; Gradle auto-installs Platform 35).
- iOS: config kept clean (Info.plist permissions) for cloud CI; no local xcodebuild on Linux.

## Known shortcuts (documented, deliberate)

- Deck flight is ONE continuous scene in unified content coordinates: spring (320/24) from the finger's release point to the exact slot rectangle while the unified camera `animateTo`s after the landing card; the flight overlay lives INSIDE the scroll content stack, so it scrolls with the table and lands pixel-exactly on the already-materialized slot card.
- Card art is procedural/typographic; drop files into `assets/cards/<id>.png` (0–77) to replace faces — the UI already prefers assets via `Image.asset` errorBuilder fallback.
- Synthesis is local-first (offline); remote LLM = set `VISION_API_URL`/`VISION_API_KEY` dart-defines for live vision (OpenAI-compatible endpoint).
- `google_fonts` caches fonts after first fetch and falls back to system fonts offline.

## Phase 2 (interactive + visual upgrade)

- **+50% spacing & Elemental Fate Threads**: `deckToPillarGap` 28→52, `slotGapPx` 20→56 logical px — the expanded gap hosts `ElementalThreadsPainter`: smooth plucked-string oscillation (transverse amplitude 2.5–4.0 px), luminous traveling energy particles, gradient color-blended per elemental pairing (Fire = amber-crimson, Water = cyan-indigo, Air = silver-violet, Earth = emerald-gold; tension pulses faster than harmony). Threads render in the focus pillar AND across the spread overview geometry (`SpreadThreadsLayer`).
- **Pre-draw intention prompts** (`intention_prompts.dart` + `IntentionPromptBar`): a translucent obsidian card above the deck asks the slot-specific question (Slot 1: "What is on your mind right now? Where is the tension?", …), offers 4 zero-friction context chips (Relationships & Feelings / Career-Money Crossroads / Inner Doubt / Let the Deck Decide) + a compact expandable text/voice input (mic = `speech_to_text`, graceful snackbar fallback). The chip/text is stored in `DealtCardSlot.userContext` when the card is drawn.
- **SYNTHESIZE READING** (✦ / СИНТЕЗИРОВАТЬ ПРОГНОЗ): ceremonial CTA revealed once the initial spread is dealt AND flipped face-up (below the spread + upgraded dock pill). The payload carries cards + orientations + slot roles + user contexts + elemental balance/thread dynamics; `OracleSynthesisService.synthesizeStructured` returns the 3 sections — Core Narrative Synthesis (AI chain w/ local fallback), Elemental Alchemy + Actionable Verdict (pure local). Rendered in the on-table glassmorphic `SynthesisPanel` (inline in Focus, modal sheet in Spread Overview).
- **Endless clarifiers**: `SpreadController.addClarifierSlot` appends Card N+1 (role `Clarifier N`, question stored in `userContext`) without ever locking the spread; flipping it auto-appends a "Clarifier Expansion" chapter via `synthesizeClarifier`. Suggested follow-ups: hidden obstacle / concrete step / own question. Spread geometry functions accept `totalSlots` so clarifiers append rows below the base layout.
- **Phygital camera-to-table sync** (`TableSourceMode.physicalCameraSync`): the camera handoff marks the session; the table shows the PHYSICAL SYNC pill, lets the user tag photographed cards with context chips/text/voice, synthesizes identically, and offers `📷 Photograph Next Physical Card` (camera armed for ONE card → `completeClarifierScan` appends it face-up, digital 78-ledger untouched) or `🃏 Draw from Digital Deck`.
- Tests: 95 green (`phase2_clarifier_test.dart` domain + `phase2_flow_test.dart` e2e flows), `flutter analyze` clean.
