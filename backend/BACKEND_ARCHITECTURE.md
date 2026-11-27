# Tarot Tree backend architecture

Flutter reference: master at `5e822bb`. Django and PostgreSQL own server sessions, payment state and digital entitlements. Flutter owns device-local history, profile, rendering, deck settings, narration, camera detection and tracking. Server persistence starts when a client submits API data.

## Flutter contract audit

| Flutter reference | V1 server representation |
| --- | --- |
| `core/models/oracle_payload.dart` | Reuse camelCase, schema version 1, zero-based positions, `source` and `mode`. Card IDs are `tarot:0`–`tarot:77`, `lenormand:0`–`lenormand:35` and `runes:0`–`runes:23`. Lenormand index 0 is the printed card 1. |
| `state/spread_controller.dart` | Ordered base positions and distinct clarifiers. Custom spreads accept 1–12 questions as position roles. The Digital Table supports up to three clarifiers after base synthesis. |
| `state/oracle_session_controller.dart` and `state/spread_session_snapshot.dart` | A local session ID may be created after synthesis, with timestamps in legacy archives. The server creates a UUID before any generation, accepts optional owner-scoped `clientSessionId` and persists question, subject, positions, chapter data and chat roles. Map legacy numeric card IDs using the owning system and map `reversed` to the orientation enum. |
| `core/services/vision/vision_engine.dart` | The adapter accepts extracted images. Map qualified HTTP card IDs to system plus integer for `VisionCardCandidate` and preserve orientation, optional track ID, score type and recognition status. Images and geometry are absent from Oracle context. |
| `features/camera_scan/camera_scan_screen.dart` | Legacy Tarot scan currently has a review sheet for base cards and directly appends a physical clarifier. When integrating the API, both flows need confirmation before reading context is updated. Preserve the manual flow for unsupported systems and unavailable providers. |
| `core/models/oracle_handoff.dart` | Card-free Astral sessions store a separate versioned summary. Flutter builds the summary from natal chart, selected transit, zodiac or synastry context. Full birth data and charts remain on device. |
| `core/services/oracle_synthesis_service.dart` | Current builds can call worker and cloud endpoints directly through build-time config. A future client changes the remote call sites to API requests and retains the existing local fallback where appropriate. |
| `state/deck_pack_controller.dart` and `features/almanac/deck_shop_screen.dart` | Active selection and user-selected cover are local state. The future client fetches products and ownership in the existing Almanac storefront. The shipped app links to an external website with the system and deck ID. Order creation moves to the server when integrated. Existing bundled decks and layouts remain free. |
| `state/user_profile_controller.dart` | Account verification is independent of the local user profile. For readings on another person, explicitly supply that reading's context. Existing local backups stay local. |

The versioned public API is distinct from provider-specific wire formats. See [API.md](API.md) for examples. [The contract fixture](tests/fixtures/flutter_contract.json) pins the qualified and numeric card ID mapping.

## Modules and persistence

| Module | Models and service responsibilities |
| --- | --- |
| `core` | Atomic fixed-window counters and owner-scoped idempotency operations. Common error format, upload guard, health and canonical catalog. |
| `accounts` | `Principal`, `AccessToken` and `EmailChallenge`. Token digests at rest with timed access and revocation. |
| `ai_gateway` | `Provider`, `RoutingPolicy`, `Usage` and `Lease`. Each provider belongs to a single capability. Configuration is read on each request, and the usage reservation locks a provider row per attempt. The network call runs outside the DB transaction. |
| `oracle` | `Personality`, `Reading`, `Position`, `Message`. Persist card identity only after reveal or confirmation. Also exposes lightweight server-side proxies (`complete/`, `transcribe/`, `quota/`) keeping all LLM and STT keys off the client/PWA and enforcing Free vs PRO daily quotas (unified DeepSeek default: `deepseek-chat` + `/v1/tools/asr`). |
| `vision` | `Recognition` stores candidates and confirmation decisions. Also exposes end-to-end `scan-spread/` (`enginetaro` OpenCV crops → Cloud VLM `deepseek-flash`). Normalized images are transient. Confirmation locks the reading and commits the chosen card and decision together. |
| `catalog` and `store` | `Deck`, `DeckVersion`, `DeckAsset`. PostgreSQL stores metadata, the manifest mapping and checksums. A private storage backend holds published ZIP files. Store APIs expose public previews, catalog entries and owner-authorized package downloads. |
| `entitlements` | `Grant` records free, purchase, administrative and promotional rights independently. A deck is owned while at least one grant is active. |
| `payments` | `Order` and `ProOrder` / `ProReceipt`. Supports verified webhooks, Solana USDC/SOL transfer verification, Early Supporter slot accounting, and durable subscriber ledger backups. |
| `telegram_bot` | `TelegramSubscriber` and `TelegramCheckInReminder`. Receives verified Telegram Bot webhook updates, schedules Zeigarnik check-in reminders from Telegram Mini App (`initData` HMAC-SHA256 verified), and dispatches daily card / lunar window / check-in alerts via `manage.py send_telegram_reminders`. |

No external inference or payment account is needed for Django to start. The sample personality is installed by migration. Admin starts with no providers or catalog products, so configured health and published rights reflect only operator-supplied data. SQLite is an explicit convenience for fast unit tests. PostgreSQL is required for transactional verification and production.
