/// Central app-wide feature flags.
///
/// Phase 2 temporarily disables every PRO restriction in ONE place while the
/// monetization metadata and infrastructure (the `isPro`/`isLocked` fields,
/// the paywall sheets, `unlockPro()`, the persisted flags) stay intact for the
/// future commercial phase. When the commercial phase lands, flip
/// [kProRestrictionsEnabled] to `true` and every gate re-engages without
/// touching the individual call sites.
library;

/// True → PRO gates are enforced (free tier caps, paywall; preset spreads stay open).
/// False → all PRO-gated content is available (pre-launch build).
const bool kProRestrictionsEnabled = false;

/// Phase G2+: enables the Tarot Tree glass theme ([buildTaroTheme]), the shared
/// twilight dusk backdrop ([TaroDuskBackground]) and the top-level
/// [TaroGlassLayer] in `MainNavigationShell`.
///
/// Flip to `false` to roll back cleanly to the legacy Dark Obsidian theme
/// ([buildAppTheme]) without touching individual screens.
const bool kTarotTreeThemeEnabled = true;
