# Tarot Tree (`soshallitbe.cyou`)

**Tarot Tree** is a local-first, cross-platform (PWA / Android / iOS / Telegram Mini App) sanctuary for **Tarot, Petit Lenormand, Elder Futhark Runes, Physical Spread Scanning (CV + VLM), and Offline Natal Astrology**.

- **Web / PWA:** `https://app.soshallitbe.cyou`
- **Promo & Store:** `https://soshallitbe.cyou`

---

## Core Pillars

1. **Digital Table (`lib/features/digital_table/`)** — 3 authentic divination systems (78-card Tarot with 6 historical decks, 36-card Petit Lenormand with no reversals, 24 Elder Futhark 3D rune stones with symmetrical merkstave rules), 20-layer tactile 3D riffle physics, Focus View & panoramic Spread View, elemental dignity threads, Custom Spread builder (1–12 questions), AI Oracle dialogue with +1 clarifier cards, and automatic local history.
2. **Phygital Camera Scanner (`lib/features/camera_scan/`, `enginetaro/`, `backend/apps/vision/`)** — scan real physical Tarot spreads from mobile camera or PWA browser photo upload (`Quick Scan`, `Guided Spread`, `Live Oracle`) via OpenCV quad detection/cropping (`enginetaro`) + Cloud VLM (`deepseek-flash`).
3. **Almanac & Micro-Learning (`lib/features/almanac/`, `lib/features/training/`)** — offline searchable library across Tarot, Lenormand, Runes, and Zodiac Sky Atlas, plus 2-minute offline micro-learning drills (0 API calls) and expandable Deck Shop.
4. **Astral (`lib/features/astral/`)** — 100% offline deterministic astronomical engine (`NatalCalculatorService`: Meeus / VSOP87 + Swiss Ephemeris house port for Placidus, Koch, Whole Sign, Porphyry), multi-profile natal charts, 7-day transit horoscopes, synastry, and Oracle handoff.
5. **Daily Rituals & Viral Sharing (`lib/features/rituals/`, `lib/features/share/`)** — 30-second Daily Card, streaks, New/Full Moon ritual windows, Zeigarnik spread reality check-ins (3 / 7 / 14 days), and 9:16 editorial PNG Story cards (`1080×1920`).

---

## Repository Map

| Path | Role |
| --- | --- |
| `lib/` | Flutter app (Android, iOS, Web/PWA, Telegram Mini App) |
| `web/` | PWA entry (`index.html` with instant splash + A2HS + TMA bridge, `manifest.json`, custom `sw.js`) |
| `l10n/` | Localization TSV sources (`en`, `ru`, `es`, `pt`, `de`, `fr`; generated via `python3 tool/gen_l10n_dart.py`) |
| `backend/` | Django REST API + PostgreSQL (`accounts`, `ai_gateway`, `oracle`, `vision`, `catalog`, `store`, `entitlements`, `payments`, `telegram_bot`) |
| `enginetaro/` | OpenCV physical Tarot card detector, perspective cropper, reading-order sorter, and evaluation benchmarks |
| `promo-tarottree/` | Next.js 16 multilingual promo site, `/pro/` checkout, `/shop/`, and APK downloads |
| `test/` | Flutter unit & widget test suite (100+ test files) |

---

## Documentation Index

- [ARCHITECTURE.md](ARCHITECTURE.md) — Flutter domain, physics, Astral engine, PWA & server AI proxy architecture
- [PLAN.md](PLAN.md) — Product audit, competitive analysis, and phased Go-To-Market roadmap (Phases A–G)
- [PRIVACY.md](PRIVACY.md) — Local-first guarantees, network surfaces, and zero-key client policy
- [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md) & [GLASS.md](GLASS.md) — Obsidian/Forest design tokens and glass renderer architecture
- [VISION_ENGINE_CONTRACT.md](VISION_ENGINE_CONTRACT.md) — `VisionEngine` contract and camera pipeline specification
- [backend/BACKEND_ARCHITECTURE.md](backend/BACKEND_ARCHITECTURE.md) — Django modules & Flutter contract mapping
- [backend/API.md](backend/API.md) — Versioned `/api/v1/` HTTP reference
- [backend/DEPLOYMENT.md](backend/DEPLOYMENT.md) — Production deployment, AI providers, and retention guide

---

## Local Development & Verification

### Flutter (App & PWA)
```sh
flutter analyze
flutter test
flutter build web --release
```

### Regenerating Localization Dictionaries
```sh
python3 tool/gen_l10n_dart.py
```

### Django Backend
```sh
cd backend
cp .env.example .env   # set DEEPSEEK_API_KEY and DATABASE_URL
DJANGO_ENV=test TAROT_TEST_SQLITE=1 .venv/bin/python manage.py test
DJANGO_ENV=test TAROT_TEST_SQLITE=1 .venv/bin/python manage.py makemigrations --check --dry-run
DJANGO_ENV=test TAROT_TEST_SQLITE=1 .venv/bin/python manage.py spectacular --validate --fail-on-warn --file /tmp/tarot-tree-openapi.yaml
```
