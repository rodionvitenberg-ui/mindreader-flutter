/// Central app-wide feature flags.
///
/// Phase 2 temporarily disables every PRO restriction in ONE place while the
/// monetization metadata and infrastructure (the `isPro`/`isLocked` fields,
/// the paywall sheets, `unlockPro()`, the persisted flags) stay intact for the
/// future commercial phase. When the commercial phase lands, flip
/// [kProRestrictionsEnabled] to `true` and every gate re-engages without
/// touching the individual call sites.
library;

/// True → PRO gates are enforced (free tier caps, locked spreads, paywall).
/// False → all PRO-gated content is available (pre-launch build).
const bool kProRestrictionsEnabled = false;
