# PRIVACY & NETWORK — Tarot Tree (`soshallitbe.cyou`)

> Local-first by default. Your device is the primary store of truth for your
> spreads, natal charts, and diary notes. This document records exactly what
> leaves the device and what never does, auditable directly against the code.

## 1. Where data lives

| Data | Location | Leaves the device? |
| --- | --- | --- |
| Reading sessions (spread + synthesis + Oracle chat + check-in reflections) | `SharedPreferences` via `LocalStorageService` | No |
| User profile / birth data / natal charts | `SharedPreferences` (`UserProfileController`, `AstralController`) | No |
| App settings / active deck / streaks / micro-learning stats | `SharedPreferences` | No |
| Downloaded store deck assets | Private app directory (Mobile) / IndexedDB `tarot_tree_store_packs` (Web) | No |
| Optional account identity (PRO status, receipts, store deck ownership) | Django PostgreSQL (`apps.accounts`, `apps.entitlements`, `apps.payments`) | Only if you sign in / purchase |

There are **no** ad trackers, **no** third-party analytics SDKs, and **no** mandatory registration.

## 2. What is sent over the network

All AI and store requests route through the Tarot Tree Django backend (`https://soshallitbe.cyou/api/v1/` or `https://app.soshallitbe.cyou/api/v1/`) using a revocable guest or account bearer token:

1. **Oracle AI (`POST /api/v1/oracle/complete/`):** sends the text prompt for the current reading (card names, orientations, spread positions, optional reader note or minimized Astral summary) to the server-side AI gateway (`deepseek-chat` / configured LLM) to produce reflective guidance. When offline or unreachable, `OracleSynthesisService` falls back cleanly to the deterministic local engine. It never sends images, video, or audio.
2. **Vision recognition (`POST /api/v1/vision/scan-spread/`):** sends a single downscaled JPEG (≤1280 px, quality 84) of the photographed spread. The server runs OpenCV quad detection (`enginetaro`) and forwards crops to the configured Vision VLM (`deepseek-flash`). Uploaded images are processed transiently in memory and never retained on disk.
3. **Cloud Voice Transcription (`POST /api/v1/oracle/transcribe/`):** when the reader explicitly taps the mic button, sends a short compressed audio clip (≤5 MiB, `.ogg` Opus on Web / `.m4a` on mobile) for language-independent transcription (DeepSeek ASR `/v1/tools/asr` or Whisper). The temporary recording file is deleted immediately in a `finally` block on the device and is **never** persisted to disk on the server.
4. **Optional Store / Account / PRO (`/api/v1/auth/*`, `/api/v1/store/*`, `/api/v1/payments/*`):** used only when claiming/downloading store decks, verifying PRO entitlement, or signing in.
5. **Optional Telegram Reminder Bot (`/api/v1/telegram/*`):** only if the user explicitly opens the Telegram bot or schedules a reminder from Telegram Mini App; stores only `chat_id`, language preference, reminder toggles, and the short check-in title/due date.

## 3. What is NEVER sent or stored

- **No continuous camera/microphone recording.** Camera hardware opens only while the Camera tab is active and runs with `enableAudio: false`; microphone capture starts only on an explicit tap and stops automatically (max 60s).
- **Camera frames are never sent to the Oracle.** The Oracle receives only canonical card text/metadata — never raw photos or bounding boxes.
- **No AI API keys in the client or PWA.** All upstream LLM, Vision, and STT credentials live strictly in server-side environment variables (`backend/.env` / process env) and are never compiled into `build/web/main.dart.js`.
- **No PII or secrets in logs.** Client logs record only exception runtime types, never prompts, tokens, or personal profile data.

## 4. Keys & Secrets Policy

- **Server-side only:** `DEEPSEEK_API_KEY`, `VISION_VLM_API_KEY`, `ORACLE_LLM_API_KEY`, `STT_API_KEY`, `DJANGO_SECRET_KEY`, `TELEGRAM_BOT_TOKEN`, `TELEGRAM_WEBHOOK_SECRET` are stored solely in gitignored server `.env` files.
- **Web/PWA client:** direct client-side LLM/Vision/STT API keys are disabled on `kIsWeb`.
