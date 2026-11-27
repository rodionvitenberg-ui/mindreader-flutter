import 'package:flutter/foundation.dart' show visibleForTesting;

/// Compile-time distribution billing flavor for Tarot Tree:
///
/// - [BillingMode.web] (`BILLING_MODE=web`, default): Direct website APK, PWA,
///   and Telegram Mini App — shows PRO pricing cards, Solana/web checkout cues,
///   and external web checkout links.
/// - [BillingMode.reader] (`BILLING_MODE=reader` or legacy `STORE_BUILD=true`):
///   RuStore and zero-billing store catalogs — strictly hides all prices,
///   currency badges, payment gateway mentions, and external checkout URLs;
///   operates as a compliant Reader App with account sign-in and entitlement
///   sync only.
/// - [BillingMode.storeIap] (`BILLING_MODE=store_iap`): Samsung Galaxy Store &
///   Huawei AppGallery — shows PRO plan cards with store IAP prices, hides
///   external web/Solana checkout links, and routes purchases through
///   `StoreIapService` + Restore Purchases.
enum BillingMode { web, reader, storeIap }

const String _rawBillingMode = String.fromEnvironment(
  'BILLING_MODE',
  defaultValue: '',
);

/// Legacy boolean flag kept for backward compatibility (`STORE_BUILD=true`
/// falls back to [BillingMode.reader] when `BILLING_MODE` is not explicitly
/// supplied).
const bool kIsStoreBuild = bool.fromEnvironment(
  'STORE_BUILD',
  defaultValue: false,
);

/// Parses a `BILLING_MODE` string with optional legacy `STORE_BUILD` fallback.
BillingMode parseBillingMode(String raw, {bool legacyStoreBuild = false}) {
  return switch (raw.trim().toLowerCase()) {
    'web' => BillingMode.web,
    'reader' => BillingMode.reader,
    'store_iap' || 'storeiap' => BillingMode.storeIap,
    '' => legacyStoreBuild ? BillingMode.reader : BillingMode.web,
    _ => BillingMode.web,
  };
}

/// Compile-time resolved [BillingMode].
const BillingMode kCompiledBillingMode = _rawBillingMode == 'reader'
    ? BillingMode.reader
    : _rawBillingMode == 'store_iap'
    ? BillingMode.storeIap
    : _rawBillingMode == 'web'
    ? BillingMode.web
    : (kIsStoreBuild ? BillingMode.reader : BillingMode.web);

/// Test-only runtime override for [activeBillingMode] so widget tests can
/// exercise all 3 billing flavors in a single run. Always `null` in release.
@visibleForTesting
BillingMode? billingModeOverride;

/// Legacy test override mapping `true` -> [BillingMode.reader] and
/// `false` -> [BillingMode.web] when [billingModeOverride] is unset.
@visibleForTesting
bool? isStoreBuildOverride;

/// Active billing mode for the running app.
BillingMode get activeBillingMode {
  if (billingModeOverride != null) return billingModeOverride!;
  if (isStoreBuildOverride != null) {
    return isStoreBuildOverride! ? BillingMode.reader : BillingMode.web;
  }
  return kCompiledBillingMode;
}

/// Direct website / PWA / TMA mode allowing external web & Solana checkout.
bool get isWebCheckoutMode => activeBillingMode == BillingMode.web;

/// Zero-billing Reader App mode (RuStore, etc.): zero prices, zero checkout.
bool get isReaderStoreMode => activeBillingMode == BillingMode.reader;

/// Native store IAP mode (Samsung Galaxy Store / Huawei AppGallery).
bool get isStoreIapMode => activeBillingMode == BillingMode.storeIap;

/// True when PRO pricing cards should be rendered (`web` and `storeIap`).
bool get showPricingCards => activeBillingMode != BillingMode.reader;

/// True only when external web/crypto checkout links are permitted (`web`).
bool get showExternalPurchaseUi => isWebCheckoutMode;

/// True for any store-distributed build (`reader` or `storeIap`).
bool get isStoreBuild => !isWebCheckoutMode;
