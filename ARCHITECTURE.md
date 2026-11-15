# mindreader.quest — Flutter Architecture

Pure Flutter/Dart mobile app (Android APK + iOS). No legacy JS. Impeller renderer target: 60–120 FPS game-feel on touch.

## The 3 Pillars (3-Tab Bottom Navigation)

| Tab | Feature | Core loop |
|-----|---------|-----------|
| 0 | Camera Scanner | Physical spread → vision detect → handoff to Table (cards already face-up) |
| 1 | Digital Table (default, core) | Tactile deck, shuffle, deal, flip, elemental threads, live reading |
| 2 | Almanac | Offline searchable 78-card RWS library + element legend |

## State architecture

- Single `SpreadController` (`ChangeNotifier`, injected via `provider`) is the SSOT for both Camera and Table flows.
- Domain logic is pure and testable: shuffle (Fisher–Yates, `Random.secure()`, 156 states = 78 cards × `isReversed`), dealing, flipping, elemental dignity, synthesis text.
- Local-first: completed readings persist via `shared_preferences`. No accounts, no cloud required.

```
SpreadController
├── deck: 78 TarotCard + isReversed (156 states)
├── spreadType: SpreadType.one|three|four|seven
├── slots: List<DealtCardSlot> (empty → faceDown → faceUp)
├── dealNextCard() / flipSlot() / loadScannedSpreadFaceUp()
└── threads: computed dignity per adjacent face-up pair (pure fn in oracle service)
```

## Digital Table physics (game-feel contract)

- Deck gestures are touch-scoped **only** to `InteractiveDeckWidget` (`HitTestBehavior.opaque`); table scrolling never triggers shuffle/deal.
- Horizontal drag on deck → 2.5D fan (`Matrix4` rotation/translation), haptic tick per ~24 px (`selectionClick`), `shuffleDeck()` on release.
- Swipe down (>60 px or >450 px/s) → card flight along curved bezier path into pillar, slot fills at flight end (`mediumImpact`).
- Tap face-down card → 600 ms `rotateY(π)` flip with `SpringSimulation`, `mediumImpact` at 90° midpoint; reversed cards show face rotated 180°.
- Pillar: `InteractiveViewer` (pinch zoom 0.35–1.15, vertical pan) over fixed-size card column. All motion via `Transform`/`Matrix4`/`CustomPaint`/`RepaintBoundary`. No layout-property animation.
- Elemental threads: `CustomPainter` bezier between adjacent face-up slots; harmony (same element or Water+Earth) = cyan/emerald pulse, conflict (Fire+Water, Air+Fire) = rose/amber pulse, else neutral indigo glow.

## Services

- `VisionScannerService`: compress captured image to ≤1024 px JPEG (`package:image`), then detect. With `VISION_API_KEY`/`VISION_API_URL` dart-defines set → OpenAI-compatible vision POST; otherwise 100% deterministic offline mock (scan flow fully testable before keys exist).
- `OracleSynthesisService`: pure elemental dignity calculator + local-first cohesive synthesis text (no generic dictionary lists). UI reveals it with a typewriter effect (streaming feel without SSE). Remote LLM hook = documented extension point.
- `LocalStorageService`: spread history via `shared_preferences` (JSON).

## Folder map

```
lib/
├── main.dart
├── core/
│   ├── theme/            # Obsidian + Lavender design tokens & ThemeData
│   ├── models/           # TarotCard, SpreadType, DealtCardSlot
│   ├── data/             # 78-card RWS dataset + Socratic questions
│   └── services/         # vision, oracle (dignity + synthesis), local storage
├── state/                # SpreadController (ChangeNotifier)
└── features/
    ├── shell/            # 3-tab bottom bar (Camera | Digital Table | Almanac)
    ├── camera_scan/      # native camera UI + lock-on animation
    ├── digital_table/    # deck, pillar, 3D cards, threads, reading sheet
    └── almanac/          # filterable library + 3D detail sheet
```

## Verification

- `flutter analyze` — zero errors/warnings. ✅
- `flutter test` — 27 tests green: domain (deck integrity 78/22/56/14×4, shuffle permutation, deal order, flip, scanned face-up load, dignity classification, synthesis) + widget smoke (boot → deal → flip → reading sheet, spread switching, mock camera scan → face-up handoff, almanac → detail sheet). ✅
- `flutter build apk --debug` (Android SDK present on host; Gradle auto-installs Platform 35).
- iOS: config kept clean (Info.plist permissions) for cloud CI; no local xcodebuild on Linux.

## Known shortcuts (documented, deliberate)

- Deck flight animation follows a curved path toward the pillar region (not a per-slot pixel target); the slot fills at flight end.
- Card art is procedural/typographic; drop files into `assets/cards/<id>.png` (0–77) to replace faces — the UI already prefers assets via `Image.asset` errorBuilder fallback.
- Synthesis is local-first (offline); remote LLM = set `VISION_API_URL`/`VISION_API_KEY` dart-defines for live vision (OpenAI-compatible endpoint).
- `google_fonts` caches fonts after first fetch and falls back to system fonts offline.
