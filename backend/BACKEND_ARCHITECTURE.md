# Tarot Tree backend architecture

Flutter reference: master at 5e822bb. The Django monolith has independent Oracle and Vision routes, with PostgreSQL as the source of truth for server sessions, orders and ownership. Local Flutter history, profiles and deck settings are a separate data store.

| Flutter reference | V1 server representation |
| --- | --- |
| core/models/oracle_payload.dart | Keep camelCase, schemaVersion 1, zero-based position, source and mode. Card IDs are tarot:0–77, lenormand:0–35, runes:0–23. |
| state/spread_controller.dart | Store ordered base positions and distinct clarifiers. Custom spreads use 1–12 questions. The Digital Table supports three clarifiers and requires face-up base cards for synthesis. |
| state/spread_session_snapshot.dart | Map integer cardId through the session system, reversed through orientation, and timestamp or sessionId to an owner-scoped clientSessionId. Preserve session ID mapping and ChatMessage role, text and slotIndex. |
| core/services/vision/vision_engine.dart | HTTP accepts extracted images only. Map canonical card IDs back to system plus integer for Dart VisionCardCandidate. Keep optional track ID, orientation, recognition status and score type. Geometry and tracking stay on device. |
| features/camera_scan/camera_scan_screen.dart | Existing Tarot legacy scan uses a review sheet for base cards and directly appends a physical clarifier. Both require confirmation when the server API is integrated. |
| core/models/oracle_handoff.dart | Oracle sessions support Astral kinds with a separate versioned, minimized text context. Flutter remains responsible for calculating natal charts, forecasts and transits. |
| core/services/oracle_synthesis_service.dart | Flutter performs direct worker/cloud calls and has a local synthesis fallback. Replace remote calls when integrating. Server provider settings are independent and credentials stay server-side. |
| state/deck_pack_controller.dart | Use the existing per-system active pack selection in a future client integration. Store product ownership, package versions and asset mappings on server. Bundled defaults remain available offline. |
| features/almanac/deck_shop_screen.dart | This screen is the future catalog entry. Its current external link only contains system and deck ID. API checkout starts an order with a verified owner. |
| state/user_profile_controller.dart | Keep the local profile and backup local. Account membership requires verified proof and the Oracle accepts only session-specific subject context. |

The server assigns its own UUID before generation. The client can pass its current local ISO-style ID as clientSessionId. A future client adapter handles field conversion and preserves existing offline paths. Server persistence begins with explicitly submitted API data. No automatic upload of local archives, local profiles or camera rolls occurs.

The remaining sections of this document are developed as the modules are implemented.
