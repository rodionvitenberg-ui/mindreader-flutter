# PLAN.md — ASTRAL Feature (4 Atomic Phases)

> mindreader.quest (Flutter/Dart, Impeller). Pure-Dart offline astrology.
> Execution protocol: 4 strictly isolated sessions, each 100% test-verified
> (`flutter analyze` = 0 issues, `flutter test` = green) before the next starts.
> SSOT: `TASK_STATE.json`.

---

## Global design decisions (fixed during pre-code analysis)

1. **Single source of truth for astronomy**: standard formulas from
   Meeus "Astronomical Algorithms":
   - Sun: ch.25 coarse (accuracy 0.01°).
   - Moon: ch.47 truncated main series (60 LR terms + 60 B terms + additive
     terms; accuracy ≈0.01°).
   - Mercury..Neptune: ch.32 VSOP87 truncated series (L0..L5, B0..B4, R0..R4),
     assembled in Horner order in units of 100 Julian centuries, /1e8 → rad.
   - Pluto: ch.37 (argument table J·(34.35+3034.9057T) / S·(50.08+1222.1138T) /
     P·(238.96+144.96T), amplitudes /1e6, R /1e7). The series is
     **J2000**-referred (same convention as PyMeeus' `Pluto`), so the
     geocentric path precesses its longitude into the mean equinox of date
     (Meeus 21.5: 5029.0966"T + 1.11113"T²) before differencing — mixing
     frames costs the whole accumulated precession (0.16° for 1988).
   - Geocentric conversion: rectangular ecliptic difference in the mean
     equinox of date (planet − Earth), one light-time iteration
     (τ = 0.0057755183·Δ days).
   - Nutation (main 4 terms Δψ/Δε), mean obliquity (Meeus 22.3), GMST
     (12.4) → GAST = GMST + Δψ·cos ε → RAMC = GAST + λ_east.
   - ASC = swehouse `Asc1(RAMC + 90°, φ, sin ε, cos ε)` quadrant dispatch
     (the raw atan2 form of the same triangle returns the opposite point,
     ASC + 180°); MC = atan2(sin RAMC, cos RAMC·cos ε) — both verified
     against swetest to 0.001°.
2. **House systems** ported 1:1 from Swiss Ephemeris `swehouse.cpp`
   (same algorithms as Astrodienst):
   - `placidus`: polar guard `|φ| ≥ 90 − ε` → Porphyry fallback; otherwise
     iterative semi-arc trisection via `Asc1`/`Asc2` (max 100 iterations,
     break at |Δcusp| < 1e-10°).
   - `koch`: direct — `ad3 = asind(sind(c)·sina)/3` from MC declination;
     same polar guard → Porphyry.
   - `wholeSign`: cusp1 = floor(ASC/30)·30, +30° each.
   - Porphyry fallback: trisect short arc ASC↔MC (with ASC-swap when
     `difdeg2n(ac,mc) < 0`), matching swetest 'O' exactly.
3. **Time scale**: RAMC/houses/ASC/MC from UT (matches swetest ARMC to
   0.004°); planetary longitudes from UT too (ΔT≈60s shifts Moon by only
   0.01° — covered by test tolerances). Documented as deliberate.

4. **Verified against Swiss Ephemeris (swetest 2.10.04) test anchors**
   (exact numbers recorded in `test/natal_calculator_test.dart`):
   - 2000-01-01 00:00 UT, lon 0, lat 52.5 — planets + Placidus + Koch + Whole.
   - 1988-06-15 14:30 UT, lon 74.57, lat 42.87 (Bishkek) — planets + Placidus.
   - 2000-01-01 00:00 UT, lat 68.0 — Placidus→Porphyry fallback + Whole.
   - Meeus book anchors: Sun 1992-10-13 (199°54'36"/199°54'32", R 0.99766),
     Moon 1992-04-12 (λ 133.162655), Pluto helio 1992-10-13
     (L 232.74071, B 14.58782, R 29.711111).
   - NASA moon phases: new 2000-01-06 18:14 UT, 1Q 2000-01-14 13:34,
     full 2000-01-21 04:40, 3Q 2000-01-28 07:57 → elongation 0/90/180/270.
   - Mercury retrograde window 2024-08-05..28 (daily-delta detection).
5. **Domain models** are immutable, pure Dart (no Flutter imports),
   JSON-serializable `toJson()/fromJson()` in the codebase's established
   style (conditional keys, tolerant enum parsing). The existing `Element`
   enum (fire/water/air/earth) is reused for zodiac signs instead of a
   duplicate `CardElement`.
6. **Interpretations** (sign+house, aspects, daily advice) are deterministic,
   grounded, non-fatalistic template compositions over small const tables
   (12 sign traits, 12 house themes, 12 planet archetypes) — the same
   "one-sentence psychological meaning" style as the tarot/lenormand data.
7. **No new dependencies.** All math is `dart:math`; tests use `flutter_test`.

---

## Phase 1 (DONE — offline ephemeris engine, gated 2026-11-17): Offline Ephemeris Engine + Models + Cities + Tests

### 1.1 Domain models — `lib/core/models/natal_chart.dart`
- `HouseSystem` enum: `placidus`, `koch`, `wholeSign` + display labels
  (`PLACIDUS`, `KOCH`, `WHOLE SIGN`) + Russian subtitles.
- `ZodiacSign` enum (12): glyph ♈..♓, title, `Element`, modality
  (cardinal/fixed/mutable), ruler planet.
- `PlanetId` enum (12): 10 bodies + `ascendant`/`midheaven`, glyphs
  ☉☽☿♀♂♃♄♅♆♇/ASC/MC, titles, archetype themes.
- `NatalPlanetPosition`: planet, longitude 0..360, sign, degreeInSign,
  `formattedDegree` (`18°24'`), house 1..12, isRetrograde, interpretation
  (sign + house composed text).
- `AspectType` enum: conjunction 0° orb 8°, sextile 60° orb 5°, square 90°
  orb 7°, trine 120° orb 7°, opposition 180° orb 8°; glyphs ☌⚹□△☍; harmony
  (harmonious/tense/intense).
- `NatalAspect`: bodyA, bodyB, type, exactAngle, orb, strength 0..1,
  synthesis text.
- `DailyTransitItem` + `DailyHoroscopeReport`: date, moonPhaseName/Glyph,
  moonIllumination 0..1, transitingMoonSign/House, overallTheme,
  energyScore 1..100, top 3–5 transits (title, `Transit Mars □ Natal Moon`
  label, orb, advice).
- `NatalChart`: id, profileName, createdAt, birthDateUtc, birthLocal Y/M/D/H/
  Min, timeKnown, cityName, country, latitude, longitude,
  timezoneOffsetHours, houseSystem, houseCusps (12), planets, aspects,
  `toJson()`/`fromJson()`.

### 1.2 Engine — `lib/core/services/natal_calculator_service.dart`
- Pure static, 100% offline, deterministic:
  `julianDay()`, `julianCenturies()`, `meanObliquity()`, `trueObliquity()`,
  `nutation()`, `greenwichMeanSiderealTime()`, `localSiderealTime()`,
  `ascendant()`, `midheaven()`.
- `computeEclipticLongitude(PlanetId, DateTime)` for all 10 bodies
  (+ retrograde detection via daily longitude delta).
- `computeHouseCusps(latitude, longitude, DateTime, HouseSystem)` -> 12 cusps
  + ASC + MC (Placidus/Koch/Whole + Porphyry high-lat fallback, never NaN).
- `calculateNatalChart(...)` -> full `NatalChart` (planets, houses, aspects).
- `computeAspects(positions)` — orb detection, strength = 1 − orb/maxOrb,
  sorted tightest-first.
- `recalculateWithHouseSystem(chart, system)` — instant cusp/house re-map,
  no re-entry of birth data.
- `computeMoonPhase(DateTime)` — elongation-based 8 phases + illumination.
- `computeDailyHoroscope(chart, {forDate})` — live transits (Sun..Saturn)
  vs natal planets + ASC, Moon transit house, deterministic
  `DailyHoroscopeReport`.

### 1.3 Tables — `lib/core/data/astro_ephemeris_tables.dart`
- GENERATED const Dart tables (VSOP87 L/B/R for Mercury..Neptune, Meeus
  ch.47 Moon LR/B, Meeus ch.37 Pluto), trimmed at |A| >= 1000 (L/B) and
  >= 5000 (R) — accuracy loss far below test tolerances.
- Generator committed for reproducibility: `tool/gen_ephemeris_tables.py`
  (downloads PyMeeus sdist from PyPI, parses tables, emits Dart).

### 1.4 City catalog — `lib/core/data/astro_cities_data.dart`
- 75+ major world & CIS cities (Bishkek, Karakol, Osh, Almaty, Astana,
  Tashkent, Moscow, Saint Petersburg, Novosibirsk, Yekaterinburg, Kyiv,
  Minsk, Tbilisi, Yerevan, Baku, London, Paris, Berlin, New York,
  Los Angeles, Tokyo, …) with latitude, longitude, standard
  `timezoneOffsetHours`; `searchAstroCities(query)` case-insensitive.

### 1.5 Tests — `test/natal_calculator_test.dart` (TDD: red -> green)
- Sun/Moon/planets vs swetest anchors (2000-01-01 and Bishkek 1988-06-15)
  with tight tolerances (Sun 0.01°, Moon 0.06°, Mercury..Pluto 0.05°).
- Meeus anchors: Sun 1992-10-13, Moon 1992-04-12, Pluto 1992-10-13.
- ASC/MC + Placidus/Koch/Whole cusps vs swetest (0.01° tolerance).
- High-latitude 68°N: Placidus/Koch -> valid 12-cusp Porphyry fallback
  (matches swetest), Whole sign boundaries, no NaN.
- Aspect detection, orb sorting, strength bounds.
- Moon phase names/illumination at NASA phase moments.
- Mercury retrograde detection (2024-08 window).
- `recalculateWithHouseSystem` (cusps change, houses re-mapped, planets kept).
- `computeDailyHoroscope` invariants (3–5 transits sorted by orb, moon house
  1..12, illumination 0..1, energyScore 1..100, non-empty texts).
- `NatalChart` JSON round-trip.
- City catalog >= 75 entries + search.

### Phase 1 gate (hard stop) — PASSED
- [x] `flutter analyze` -> 0 issues (`No issues found!`)
- [x] `flutter test` -> all green (`test/natal_calculator_test.dart` 56/56,
      full suite 221/221)
- [x] `PLAN.md` Phase 1 marked `[x] DONE`, `TASK_STATE.json` updated -> **STOP**

### Phase 1 execution status (DONE, 2026-11-17)
- [x] `lib/core/models/natal_chart.dart` — all domain models + JSON round-trip.
- [x] `lib/core/services/natal_calculator_service.dart` — full engine
  (Sun/Moon/VSOP87/Pluto, ASC/MC/RAMC, Placidus/Koch/Whole/Porphyry,
  aspects, moon phase, daily horoscope, recalculateWithHouseSystem).
- [x] `lib/core/data/astro_ephemeris_tables.dart` — generated const tables.
- [x] `tool/gen_ephemeris_tables.py` — reproducible generator (PyMeeus
  0.5.12 pinned, PyPI sdist, terms trimmed |A|>=1000/5000).
- [x] `lib/core/data/astro_cities_data.dart` — 96 cities + search.
- [x] `test/natal_calculator_test.dart` — 56 tests, all green.

Resolved at the root cause (no tolerance was widened for a real defect):
1. **ASC +180°**: `ascendant()` used the raw atan2 triangle; now uses the
   ported swehouse `_asc1(ramc + 90, latitude, sine, cose)` →
   186.9377° vs swetest 186.9378° (lat 52.5), 263.2330° vs 263.2330°
   (Bishkek). ASC house is 1 again, whole-sign starts in the ASC sign.
2. **Moon illumination sign**: `(1 + cos e)/2` → `(1 − cos e)/2`; NASA 2000
   instants now give new 0.000 / quarters 0.500 / full 1.000.
3. **Obliquity test tolerance**: 2e-6 → 1e-5 (main 4-term Δε differs from
   swetest's full nutation by 0.013", i.e. 3.7e-6° — test-side only).
4. **Whole-sign test expectation**: Bishkek cusps start at 240°
   (ASC 263.23° = Sagittarius), not 180° — test bug, fixed in the test.
5. **Pluto +0.162° at 1988-06-15**: frame mismatch, not a transcription
   error. Meeus ch.37 is **J2000**-referred (PyMeeus converts it with J2000
   obliquity and Sun J2000 coordinates), while VSOP87D, the Sun and the
   house frame are **date**-referred. The Pluto geocentric path now applies
   the general precession in longitude (Meeus 21.5) before differencing:
   1988 residual 0.1617° → 0.004°, 2000 residual 0.005° (limited by the
   ch.25 Sun). `plutoHeliocentricPosition` stays J2000 and still matches the
   Meeus 37.a example (232.74071°).

Verified anchors unchanged: Sun/Moon/Mercury..Neptune vs swetest 2.10.04
(both epochs), Placidus/Koch/Whole Sign + 68°N Porphyry fallback, aspects,
GMST/RAMC/ASC/MC, Meeus 25.a/37/47.a, NASA moon phases, Mercury
retrograde 2024-08, JSON round-trip, horoscope invariants, city catalog.

---

## Phase 2 (DONE — multi-profile state + 4th nav tab, gated 2026-11-17): Multi-Profile State + 4th Nav Tab
- `AstralController` (ChangeNotifier, UI-first persistence like
  `SessionHistoryController`): profile CRUD, `maxFreeProfiles = 2`,
  3rd chart gated behind `PRO`, selected profile, last horoscope cache.
- 4th bottom nav tab `ASTRAL` in `main_navigation_shell.dart`
  (wheel UI is a Phase 3 placeholder — data/profile screens only).

### Phase 2 gate (hard stop) — PASSED
- [x] `flutter analyze` -> 0 issues (`No issues found!`)
- [x] `flutter test` -> all green (`test/astral_controller_test.dart` 6/6,
  full suite 227/227)
- [x] `PLAN.md` Phase 2 marked `[x] DONE`, `TASK_STATE.json` updated -> **STOP**

### Phase 2 execution status (DONE, 2026-11-17)
- [x] `lib/state/astral_controller.dart` — `AstralGenerateResult`
  (`generated` / `proGateBlocked`), `maxFreeProfiles = 2`,
  `generateChart` / `setActiveProfile` / `setHouseSystem` / `unlockPro` /
  `deleteProfile` / `load`, non-destructive disk merge, fire-and-forget
  persistence.
- [x] `lib/core/services/local_storage_service.dart` — astral keys:
  profiles JSON, lifetime generation count, PRO flag, active index,
  default house system.
- [x] `lib/main.dart` — `ChangeNotifierProvider(AstralController)`.
- [x] `lib/features/shell/main_navigation_shell.dart` — 4th `ASTRAL` tab +
  `AstralScreen` in the `IndexedStack`.
- [x] `lib/features/astral/astral_screen.dart` + `widgets/` — cosmic bar
  (moon phase, streak, rituals re-home), profile switcher, house-system
  selector, PRO paywall, birth-data form, horoscope summary and a
  `ValueKey('natal-wheel-placeholder')` slot for Phase 3.
- [x] `test/astral_controller_test.dart` — free-tier 2 profiles, PRO gate,
  PRO unlock, in-place Placidus→Koch→Whole Sign without re-generation,
  profile switch horoscope refresh, 4-tab nav test.

## Phase 3: Real-Time Animated Natal Wheel (next sessions)
- `NatalWheelWidget` + `NatalWheelPainter`: 3-stage calibration/orbit/
  aspect-flash animation (SpringSimulation 320/24), continuous particle
  flow, `RepaintBoundary` isolation, 120 FPS Impeller contract.
- Planet/aspect tap inspector, haptics on snap thresholds. (The
  `PLACIDUS | KOCH | WHOLE SIGN` switcher already shipped in Phase 2 via
  `recalculateWithHouseSystem`.)

## Phase 4: Detail Page, Transit Feed, Rituals Re-homing, Synastry (final)
- Full profile detail page, daily horoscope & transit feed UI,
  Rituals Hub re-homed to the ASTRAL dock, 2-chart synastry comparison,
  Oracle Chat handoff (astral context -> `OracleSynthesisService`).

