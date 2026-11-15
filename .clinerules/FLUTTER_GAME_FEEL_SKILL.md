# SKILL: High-Craft Flutter Mobile & 120 FPS Impeller Physics (`mindreader.quest`)

## 1. TOKEN & CONTEXT DISCIPLINE (CRITICAL)
- Operate strictly inside the pure Dart/Flutter codebase. Ignore any legacy JS/React patterns.
- Write concise, modular Dart files (<250 lines per widget). Extract custom painters, animations, and state logic into separate files.
- Never rewrite working files unless explicitly required by the current step in `TASK_STATE.json`.
- Output concise code diffs or complete single files without verbose conversational filler.

## 2. 120 FPS IMPELLER & GAME-FEEL PHYSICS RULES
- **Zero-Jank Animations:** Never animate layout properties (`width`, `height`, `padding`, `margin`) inside `AnimationBuilder` or gesture callbacks. Always use GPU-composited transforms: `Transform`, `Matrix4`, `Opacity`, `CustomPaint`, and `RepaintBoundary`.
- **Spring Physics Over Linear Curves:** For deck shuffling, card dealing, and bottom-sheet drawers, always drive animations with `SpringSimulation` (`SpringDescription(mass: 1.0, stiffness: 320.0, damping: 24.0)`) rather than stiff linear curves.
- **2.5D Perspective Matrix:** Construct card tilt and flips using:
  `Matrix4.identity()..setEntry(3, 2, 0.0012)..rotateX(tiltX)..rotateY(flipAngle)`
- **Isolate Heavy Repaints:** Wrap animated card stacks, `CustomPainter` elemental threads, and blurred glass panels in `RepaintBoundary` so 120 FPS touch gestures never trigger full-screen rebuilds.
- **Native Haptics Synchronization:** Pair every physical threshold (card shuffle tick, card snap into slot, 90° midpoint of 3D card flip, camera lock-on) with `HapticFeedback.selectionClick()` or `HapticFeedback.mediumImpact()`.

## 3. TOUCH-SCOPED GESTURE ARCHITECTURE
- **Deck Isolation:** Horizontal shuffle gestures (`onHorizontalDragUpdate`) and downward deal gestures (`onVerticalDragUpdate` / `onVerticalDragEnd`) MUST be bound exclusively to the `InteractiveDeckWidget` hit-box (`HitTestBehavior.opaque`), never colliding with the parent `SingleChildScrollView` / `CustomScrollView` of the vertical table.
- **Velocity-Aware Dealing:** Trigger card deal when downward drag distance > `60.0` logical pixels OR downward velocity > `450.0` px/s, carrying the user's swipe velocity directly into the `SpringSimulation` flight path.

## 4. ANTI-SLOP DARK OBSIDIAN DESIGN SYSTEM (FLUTTER)
- **Strict Prohibitions:** NO Material 3 default purple/blue pills, NO heavy `BoxShadow` elevation blobs, NO gold/yellow fortune-teller gradients, NO decorative emojis in UI labels.
- **Palette:**
  - Canvas: `Color(0xFF09090D)`
  - Surface / Glass: `Color(0xFF13131A)` with `BackdropFilter(filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16))` and `1.0` px hairline border `Color(0x29A78BFA)`.
  - Primary Lavender Accent: `Color(0xFFA78BFA)`
  - Secondary Indigo Glow: `Color(0xFF6366F1)`
  - Primary Text: `Color(0xFFE4E4E7)` | Secondary Text: `Color(0xFF94A3B8)`
- **Typography:** High-contrast serif (`Cormorant Garamond` / `Cinzel` via `google_fonts`) for Arcana titles; clean sans (`Plus Jakarta Sans` / `Inter`) for interpretations; monospace (`JetBrains Mono`) uppercase with `letterSpacing: 1.8` for card positions and metadata.

## 5. FLUTTER ENGINEERING HYGIENE
- Use `const` constructors everywhere possible to minimize widget tree allocations during 120 FPS gesture frames.
- Dispose every `AnimationController`, `CameraController`, and `ScrollController` cleanly in `dispose()`.
- Keep UI state decoupled from business logic via `ChangeNotifier` / `Provider` or `Riverpod`.