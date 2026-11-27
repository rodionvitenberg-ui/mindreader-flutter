import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_build_config.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/services/billing/store_iap_service.dart';
import '../../../core/theme/app_typography.dart';
import '../../../design_system/taro.dart';
import '../../../state/app_settings_controller.dart';
import '../../../state/astral_controller.dart';
import '../../../state/backend_auth_controller.dart';
import '../../shop/widgets/email_auth_sheet.dart';

const _promoBaseEnv = String.fromEnvironment('PROMO_SHOP_URL');
final _defaultPromoOrigin = Uri.https('soshallitbe.cyou');

/// Why the PRO paywall sheet was opened (tailors the subtitle copy).
enum ProGateReason {
  general,
  oracleMessages,
  cameraQuota,
  astralProfiles,
  synastry,
}

Uri _promoOrigin([String override = _promoBaseEnv]) {
  final parsed = Uri.tryParse(override);
  if (parsed != null &&
      (parsed.scheme == 'https' || parsed.scheme == 'http') &&
      parsed.host.isNotEmpty) {
    return Uri(
      scheme: parsed.scheme,
      host: parsed.host,
      port: parsed.hasPort ? parsed.port : null,
    );
  }
  return _defaultPromoOrigin;
}

/// Builds the external promo-site PRO checkout URL, pre-filling the user's
/// email if already signed in.
Uri proCheckoutDestination({
  required String plan,
  String? email,
  String? locale,
  String promoOverride = _promoBaseEnv,
}) {
  final origin = _promoOrigin(promoOverride);
  final cleanEmail = email?.trim();
  return origin.replace(
    path: '/pro/',
    queryParameters: {
      'plan': plan,
      if (cleanEmail != null && cleanEmail.isNotEmpty) 'email': cleanEmail,
      if (locale != null && locale.isNotEmpty) 'lang': locale,
      if (kIsWeb) 'return': Uri.base.toString(),
    },
  );
}

/// Builds the external project-support URL (Solana donations on promo site).
Uri proSupportDestination({String promoOverride = _promoBaseEnv}) =>
    _promoOrigin(promoOverride).replace(path: '/support/');

/// Checks the user's live PRO entitlement on the Django backend (prompting for
/// Email sign-in first if needed), caches `isPro` locally, and lifts all locks.
Future<bool> syncProStatusWithFeedback(BuildContext context) async {
  final lang = context.read<AppSettingsController>().language;
  final auth = context.read<BackendAuthController?>();
  final settings = context.read<AppSettingsController>();
  final astral = context.read<AstralController?>();

  if (auth == null || !auth.isConfigured) {
    if (context.mounted) {
      showTaroGlassSnackbar(
        context,
        message: AppStrings.t(lang, 'pro.status.offline'),
        tone: TaroGlassSnackbarTone.warning,
      );
    }
    return settings.isProUnlocked;
  }

  if (!auth.isVerified) {
    final signedIn = await EmailAuthSheet.show(
      context,
      initialMode: AuthFormMode.login,
    );
    if (!signedIn || !context.mounted) return false;
  }

  try {
    final active = await auth.refreshProStatus();
    if (!context.mounted) return active;
    settings.setProUnlocked(active);
    astral?.setProUnlocked(active);
    if (active) {
      showTaroGlassSnackbar(
        context,
        message: AppStrings.t(lang, 'pro.status.unlocked'),
        tone: TaroGlassSnackbarTone.success,
      );
      return true;
    }
    showTaroGlassSnackbar(
      context,
      message: AppStrings.t(lang, 'pro.status.notActiveYet'),
      tone: TaroGlassSnackbarTone.info,
    );
    return false;
  } catch (_) {
    if (context.mounted) {
      showTaroGlassSnackbar(
        context,
        message: AppStrings.t(lang, 'pro.status.checkError'),
        tone: TaroGlassSnackbarTone.warning,
      );
    }
    return false;
  }
}

/// Synchronizes live PRO entitlements from the user's backend account into
/// local UI-first state (`AppSettingsController` + `AstralController`).
Future<bool> syncEntitlements(BuildContext context) =>
    syncProStatusWithFeedback(context);

/// Shared Tarot Tree PRO sheet supporting all 3 [BillingMode] flavors:
/// - [BillingMode.web] (`BILLING_MODE=web`, default): Early Supporter pricing
///   (`$4.99/mo` vs `$6.99/mo`), Annual (`$39.99/yr`), external web checkout,
///   status sync, and Solana project support.
/// - [BillingMode.reader] (`BILLING_MODE=reader`): Strictly hides all prices,
///   currency badges, payment gateway mentions, and external checkout URLs;
///   renders a calm Reader App account-sync card with sign-in & status refresh.
/// - [BillingMode.storeIap] (`BILLING_MODE=store_iap`): Shows PRO plan cards
///   with store IAP prices from [StoreIapService] (fallback `$4.99` / `$39.99`),
///   hides all external web/Solana checkout buttons, and routes CTA to
///   [StoreIapService.purchaseProduct] + Restore Purchases.
class ProSubscriptionSheet extends StatefulWidget {
  const ProSubscriptionSheet({
    super.key,
    this.reason = ProGateReason.general,
    this.initialAnnual = false,
    this.billingModeOverride,
    this.isStoreBuildOverride,
    this.storeIapService,
    this.entitlementsService,
  });

  final ProGateReason reason;
  final bool initialAnnual;

  /// Optional test override for [activeBillingMode].
  final BillingMode? billingModeOverride;

  /// Legacy test override (`true` -> [BillingMode.reader], `false` ->
  /// [BillingMode.web]) used only when [billingModeOverride] is `null`.
  final bool? isStoreBuildOverride;

  /// Optional injected [StoreIapService] for `storeIap` mode / tests.
  final StoreIapService? storeIapService;

  /// Optional injected [EntitlementsService] for receipt verification / tests.
  final EntitlementsService? entitlementsService;

  static Future<void> show(
    BuildContext context, {
    ProGateReason reason = ProGateReason.general,
    bool initialAnnual = false,
    BillingMode? billingModeOverride,
    bool? isStoreBuildOverride,
    StoreIapService? storeIapService,
    EntitlementsService? entitlementsService,
  }) {
    return showTaroGlassSheet<void>(
      context: context,
      builder: (_) => ProSubscriptionSheet(
        reason: reason,
        initialAnnual: initialAnnual,
        billingModeOverride: billingModeOverride,
        isStoreBuildOverride: isStoreBuildOverride,
        storeIapService: storeIapService,
        entitlementsService: entitlementsService,
      ),
    );
  }

  @override
  State<ProSubscriptionSheet> createState() => _ProSubscriptionSheetState();
}

class _ProSubscriptionSheetState extends State<ProSubscriptionSheet>
    with WidgetsBindingObserver {
  late bool _annual = widget.initialAnnual;
  bool _openedCheckout = false;
  bool _checking = false;
  bool _purchasing = false;
  Map<String, StoreProductInfo> _iapProducts = const {};

  BillingMode get _mode {
    if (widget.billingModeOverride != null) return widget.billingModeOverride!;
    if (widget.isStoreBuildOverride != null) {
      return widget.isStoreBuildOverride!
          ? BillingMode.reader
          : BillingMode.web;
    }
    return activeBillingMode;
  }

  StoreIapService _resolveStoreIap() {
    if (widget.storeIapService != null) return widget.storeIapService!;
    try {
      return context.read<StoreIapService>();
    } catch (_) {
      return const UnconfiguredStoreIapService();
    }
  }

  EntitlementsService _resolveEntitlements() {
    if (widget.entitlementsService != null) return widget.entitlementsService!;
    try {
      return context.read<EntitlementsService>();
    } catch (_) {
      return EntitlementsService();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_mode == BillingMode.web) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final auth = context.read<BackendAuthController?>();
        if (auth != null && auth.isConfigured) {
          unawaited(auth.refreshProOffer());
        }
      });
    } else if (_mode == BillingMode.storeIap) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_loadStoreIapProducts());
      });
    }
  }

  Future<void> _loadStoreIapProducts() async {
    try {
      final products = await _resolveStoreIap().fetchProducts(
        StoreProductIds.allPro,
      );
      if (!mounted || products.isEmpty) return;
      setState(() {
        _iapProducts = {for (final p in products) p.productId: p};
      });
    } catch (_) {
      // Fall back cleanly to default display prices.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _openedCheckout && mounted) {
      _openedCheckout = false;
      final auth = context.read<BackendAuthController?>();
      if (auth != null && auth.isVerified) {
        unawaited(_checkStatus());
      }
    }
  }

  String _reasonSubtitle(AppLanguage lang) => switch (widget.reason) {
        ProGateReason.oracleMessages => AppStrings.t(lang, 'pro.reason.oracle'),
        ProGateReason.cameraQuota => AppStrings.t(lang, 'pro.reason.camera'),
        ProGateReason.astralProfiles => AppStrings.t(lang, 'pro.reason.astral'),
        ProGateReason.synastry => AppStrings.t(lang, 'pro.reason.synastry'),
        ProGateReason.general => AppStrings.t(lang, 'pro.subtitle'),
      };

  Future<void> _openCheckout() async {
    if (_mode != BillingMode.web) return;
    final lang = context.read<AppSettingsController>().language;
    final auth = context.read<BackendAuthController?>();
    final hasEarly = auth?.proOffer.hasEarlySlots ?? true;
    final plan = _annual
        ? 'annual'
        : (hasEarly ? 'early_monthly' : 'monthly');
    final uri = proCheckoutDestination(
      plan: plan,
      email: auth?.email,
      locale: lang.code,
    );
    _openedCheckout = true;
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        showTaroGlassSnackbar(
          context,
          message: AppStrings.t(lang, 'almanac.launchError'),
          tone: TaroGlassSnackbarTone.warning,
        );
      }
    } catch (_) {
      if (mounted) {
        showTaroGlassSnackbar(
          context,
          message: AppStrings.t(lang, 'almanac.launchError'),
          tone: TaroGlassSnackbarTone.warning,
        );
      }
    }
  }

  Future<void> _openSupport() async {
    if (_mode != BillingMode.web) return;
    final lang = context.read<AppSettingsController>().language;
    try {
      final launched = await launchUrl(
        proSupportDestination(),
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        showTaroGlassSnackbar(
          context,
          message: AppStrings.t(lang, 'almanac.launchError'),
          tone: TaroGlassSnackbarTone.warning,
        );
      }
    } catch (_) {
      if (mounted) {
        showTaroGlassSnackbar(
          context,
          message: AppStrings.t(lang, 'almanac.launchError'),
          tone: TaroGlassSnackbarTone.warning,
        );
      }
    }
  }

  Future<void> _signInAndSync() async {
    final signedIn = await EmailAuthSheet.show(
      context,
      initialMode: AuthFormMode.login,
    );
    if (!signedIn || !mounted) return;
    await _checkStatus();
  }

  Future<void> _checkStatus() async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      final unlocked = await syncEntitlements(context);
      if (unlocked && mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  static String _fmtUsd(int minor) => '\$${(minor / 100).toStringAsFixed(2)}';

  Widget _buildStoreReaderBody(
    BuildContext context, {
    required AppLanguage lang,
    required BackendAuthController? auth,
    required bool unlocked,
  }) {
    final signedIn = auth != null && auth.isVerified;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TaroGlassPanel(
          radius: 18,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 1; i <= 4; i++)
                _Benefit(benefitKey: 'pro.benefit$i'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        TaroGlassPanel(
          key: const ValueKey('pro-reader-account-sync-card'),
          radius: 18,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.account_circle_outlined,
                    size: 18,
                    color: TaroColors.lavender,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppStrings.t(lang, 'pro.reader.title'),
                      style: AppTypography.heading(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: TaroColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.t(lang, 'pro.reader.body'),
                style: AppTypography.body(
                  fontSize: 12.5,
                  height: 1.45,
                  color: TaroColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (unlocked)
          TaroGlassButton(
            key: const ValueKey('pro-reader-active-button'),
            icon: Icons.verified_outlined,
            label: AppStrings.t(lang, 'pro.active'),
            variant: TaroGlassButtonVariant.secondary,
            onPressed: () => Navigator.of(context).pop(),
          )
        else ...[
          if (!signedIn && auth != null) ...[
            TaroGlassButton(
              key: const ValueKey('pro-reader-signin-button'),
              icon: Icons.mail_outline_rounded,
              label: AppStrings.t(lang, 'profile.signIn.emailButton'),
              variant: TaroGlassButtonVariant.primary,
              onPressed: _checking ? null : _signInAndSync,
            ),
            const SizedBox(height: 10),
          ],
          TaroGlassButton(
            key: const ValueKey('pro-check-status-button'),
            icon: Icons.sync_rounded,
            loading: _checking,
            label: AppStrings.t(lang, 'pro.reader.refreshCta'),
            variant: signedIn
                ? TaroGlassButtonVariant.primary
                : TaroGlassButtonVariant.secondary,
            onPressed: _checking ? null : _checkStatus,
          ),
        ],
      ],
    );
  }

  Future<void> _purchaseViaStoreIap() async {
    if (_purchasing || _mode != BillingMode.storeIap) return;
    final lang = context.read<AppSettingsController>().language;
    final settings = context.read<AppSettingsController>();
    final astral = context.read<AstralController?>();
    final auth = context.read<BackendAuthController?>();
    final productId = _annual
        ? StoreProductIds.proAnnual
        : StoreProductIds.proMonthly;

    setState(() => _purchasing = true);
    try {
      final result = await _resolveStoreIap().purchaseProduct(productId);
      if (!mounted) return;

      if (result.isSuccess) {
        if (result.provider != null &&
            result.receiptData != null &&
            result.receiptData!.isNotEmpty &&
            auth != null &&
            auth.isVerified) {
          final token = await auth.ensureToken();
          if (token != null && token.isNotEmpty) {
            await _resolveEntitlements().verifyStoreReceipt(
              request: StoreReceiptVerificationRequest(
                provider: result.provider!,
                productId: result.productId ?? productId,
                receiptData: result.receiptData!,
                purchaseToken: result.purchaseToken,
              ),
              bearerToken: token,
            );
          }
        }
        if (!mounted) return;
        settings.setProUnlocked(true);
        astral?.setProUnlocked(true);
        showTaroGlassSnackbar(
          context,
          message: AppStrings.t(lang, 'pro.status.unlocked'),
          tone: TaroGlassSnackbarTone.success,
        );
        Navigator.of(context).pop();
        return;
      }

      if (result.status == StorePurchaseStatus.unconfigured) {
        showTaroGlassSnackbar(
          context,
          message: result.message ?? AppStrings.t(lang, 'pro.iap.unconfigured'),
          tone: TaroGlassSnackbarTone.info,
        );
        return;
      }

      if (result.status == StorePurchaseStatus.error) {
        showTaroGlassSnackbar(
          context,
          message: result.message ?? AppStrings.t(lang, 'pro.status.checkError'),
          tone: TaroGlassSnackbarTone.warning,
        );
      }
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  Future<void> _restoreStorePurchases() async {
    if (_checking || _mode != BillingMode.storeIap) return;
    final lang = context.read<AppSettingsController>().language;
    final auth = context.read<BackendAuthController?>();
    setState(() => _checking = true);
    try {
      await _resolveStoreIap().restorePurchases();
      if (!mounted) return;
      if (auth != null && auth.isVerified) {
        final unlocked = await syncEntitlements(context);
        if (unlocked && mounted) {
          Navigator.of(context).pop();
        }
      } else {
        showTaroGlassSnackbar(
          context,
          message: AppStrings.t(lang, 'pro.iap.restoreComplete'),
          tone: TaroGlassSnackbarTone.info,
        );
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Widget _buildStoreIapBody(
    BuildContext context, {
    required AppLanguage lang,
    required bool unlocked,
  }) {
    final monthlyPrice =
        _iapProducts[StoreProductIds.proMonthly]?.formattedPrice ?? '\$4.99';
    final annualPrice =
        _iapProducts[StoreProductIds.proAnnual]?.formattedPrice ?? '\$39.99';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _PlanTile(
                key: const ValueKey('pro-plan-monthly'),
                label: AppStrings.t(lang, 'pro.monthly'),
                price: monthlyPrice,
                period: AppStrings.t(lang, 'pro.perMonth'),
                selected: !_annual,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _annual = false);
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _PlanTile(
                key: const ValueKey('pro-plan-annual'),
                label: AppStrings.t(lang, 'pro.annual'),
                price: annualPrice,
                period: AppStrings.t(lang, 'pro.perYear'),
                badge: AppStrings.t(lang, 'pro.bestValue'),
                selected: _annual,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _annual = true);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        TaroGlassPanel(
          radius: 18,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 1; i <= 4; i++)
                _Benefit(benefitKey: 'pro.benefit$i'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        TaroGlassButton(
          key: const ValueKey('pro-store-iap-button'),
          icon: unlocked ? Icons.verified_outlined : Icons.auto_awesome_rounded,
          loading: _purchasing,
          label: AppStrings.t(lang, unlocked ? 'pro.active' : 'pro.checkoutCta'),
          variant: unlocked
              ? TaroGlassButtonVariant.secondary
              : TaroGlassButtonVariant.primary,
          onPressed: unlocked
              ? () => Navigator.of(context).pop()
              : (_purchasing ? null : _purchaseViaStoreIap),
        ),
        if (!unlocked) ...[
          const SizedBox(height: 10),
          TaroGlassButton(
            key: const ValueKey('pro-restore-purchases-button'),
            icon: Icons.restore_rounded,
            loading: _checking,
            label: AppStrings.t(lang, 'pro.iap.restoreCta'),
            variant: TaroGlassButtonVariant.secondary,
            onPressed: _checking ? null : _restoreStorePurchases,
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsController>();
    final auth = context.watch<BackendAuthController?>();
    final lang = settings.language;
    final unlocked = settings.isProUnlocked;

    if (_mode == BillingMode.reader) {
      return TaroGlassSheet(
        key: const ValueKey('pro-subscription-sheet'),
        title: AppStrings.t(lang, 'pro.reader.title'),
        subtitle: _reasonSubtitle(lang),
        child: _buildStoreReaderBody(
          context,
          lang: lang,
          auth: auth,
          unlocked: unlocked,
        ),
      );
    }

    if (_mode == BillingMode.storeIap) {
      return TaroGlassSheet(
        key: const ValueKey('pro-subscription-sheet'),
        title: AppStrings.t(lang, 'pro.title'),
        subtitle: _reasonSubtitle(lang),
        child: _buildStoreIapBody(
          context,
          lang: lang,
          unlocked: unlocked,
        ),
      );
    }
    final offer = auth?.proOffer;
    final remaining = offer?.earlySupporterRemaining ?? 100;
    final total = offer?.earlySupporterTotal ?? 100;
    final hasEarly = offer?.hasEarlySlots ?? true;
    final monthlyPrice = _fmtUsd(
      hasEarly
          ? (offer?.earlyMonthlyMinor ?? 499)
          : (offer?.standardMonthlyMinor ?? 699),
    );
    final monthlyOldPrice = hasEarly
        ? _fmtUsd(offer?.standardMonthlyMinor ?? 699)
        : null;
    final annualPrice = _fmtUsd(
      hasEarly
          ? (offer?.annualMinor ?? 3999)
          : (offer?.standardAnnualMinor ?? 5999),
    );
    final annualOldPrice = hasEarly
        ? _fmtUsd(offer?.standardAnnualMinor ?? 5999)
        : null;

    return TaroGlassSheet(
      key: const ValueKey('pro-subscription-sheet'),
      title: AppStrings.t(lang, 'pro.title'),
      subtitle: _reasonSubtitle(lang),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Early Supporter lock-in banner ($4.99 forever vs $6.99 standard)
          if (hasEarly) ...[
            Container(
              key: const ValueKey('pro-early-supporter-banner'),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    TaroColors.dawn.withValues(alpha: 0.18),
                    TaroColors.lavender.withValues(alpha: 0.14),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: TaroColors.dawn.withValues(alpha: 0.45),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    size: 16,
                    color: TaroColors.dawn,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      AppStrings.t(lang, 'pro.earlyBanner', {
                        'remaining': '$remaining',
                        'total': '$total',
                      }),
                      style: AppTypography.body(
                        fontSize: 11.5,
                        height: 1.35,
                        color: TaroColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: _PlanTile(
                  key: const ValueKey('pro-plan-monthly'),
                  label: AppStrings.t(lang, 'pro.monthly'),
                  price: monthlyPrice,
                  oldPrice: monthlyOldPrice,
                  period: AppStrings.t(lang, 'pro.perMonth'),
                  badge: hasEarly
                      ? AppStrings.t(lang, 'pro.first100Badge')
                      : null,
                  selected: !_annual,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _annual = false);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PlanTile(
                  key: const ValueKey('pro-plan-annual'),
                  label: AppStrings.t(lang, 'pro.annual'),
                  price: annualPrice,
                  oldPrice: annualOldPrice,
                  period: AppStrings.t(lang, 'pro.perYear'),
                  badge: AppStrings.t(lang, 'pro.bestValue'),
                  selected: _annual,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _annual = true);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TaroGlassPanel(
            radius: 18,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 1; i <= 4; i++)
                  _Benefit(benefitKey: 'pro.benefit$i'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          TaroGlassButton(
            key: const ValueKey('pro-checkout-button'),
            icon: unlocked ? Icons.verified_outlined : Icons.open_in_new_rounded,
            label: AppStrings.t(lang, unlocked ? 'pro.active' : 'pro.checkoutCta'),
            variant: unlocked
                ? TaroGlassButtonVariant.secondary
                : TaroGlassButtonVariant.primary,
            onPressed: unlocked
                ? () => Navigator.of(context).pop()
                : _openCheckout,
          ),
          if (!unlocked) ...[
            const SizedBox(height: 10),
            TaroGlassButton(
              key: const ValueKey('pro-check-status-button'),
              icon: Icons.sync_rounded,
              loading: _checking,
              label: AppStrings.t(lang, 'pro.checkStatusCta'),
              variant: TaroGlassButtonVariant.secondary,
              onPressed: _checking ? null : _checkStatus,
            ),
          ],
          const SizedBox(height: 6),
          Center(
            child: TextButton.icon(
              key: const ValueKey('pro-support-project-button'),
              onPressed: _openSupport,
              icon: const Icon(
                Icons.favorite_border_rounded,
                size: 14,
                color: TaroColors.lavender,
              ),
              label: Text(
                AppStrings.t(lang, 'pro.supportProject'),
                style: AppTypography.body(
                  fontSize: 11.5,
                  color: TaroColors.lavender.withValues(alpha: 0.92),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({
    super.key,
    required this.label,
    required this.price,
    this.oldPrice,
    required this.period,
    this.badge,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String price;
  final String? oldPrice;
  final String period;
  final String? badge;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$label $price $period',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: TaroGlassPanel(
          radius: 16,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          tint: selected
              ? TaroColors.lavender.withValues(alpha: 0.22)
              : TaroColors.mist.withValues(alpha: 0.08),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.label(
                  fontSize: 9,
                  letterSpacing: 0.7,
                  fontWeight: FontWeight.w700,
                  color: selected ? TaroColors.lavender : TaroColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.end,
                spacing: 5,
                children: [
                  Text(
                    price,
                    style: AppTypography.display(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: TaroColors.textPrimary,
                    ),
                  ),
                  if (oldPrice != null)
                    Text(
                      oldPrice!,
                      style: AppTypography.body(
                        fontSize: 11,
                        color: TaroColors.textSecondary.withValues(alpha: 0.75),
                      ).copyWith(decoration: TextDecoration.lineThrough),
                    ),
                ],
              ),
              Text(
                period,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body(
                  fontSize: 10,
                  color: TaroColors.textSecondary,
                ),
              ),
              if (badge != null) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [TaroColors.lavender, TaroColors.indigo],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badge!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.label(
                      fontSize: 7.5,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w800,
                      color: TaroColors.background,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.benefitKey});

  final String benefitKey;

  @override
  Widget build(BuildContext context) {
    final lang = context.select<AppSettingsController, AppLanguage>(
      (c) => c.language,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Text(
              '✦',
              style: TextStyle(fontSize: 12, color: TaroColors.lavender),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              AppStrings.t(lang, benefitKey),
              style: AppTypography.body(
                fontSize: 12.5,
                height: 1.35,
                color: TaroColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
