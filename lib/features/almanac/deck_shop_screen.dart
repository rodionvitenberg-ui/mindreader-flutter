import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/models/divination_system.dart';
import '../../core/models/store_models.dart';
import '../../core/theme/app_typography.dart';
import '../../design_system/taro.dart';
import '../../state/app_settings_controller.dart';
import '../../state/backend_auth_controller.dart';
import '../../state/store_controller.dart';
import '../profile/widgets/profile_header.dart';
import '../shop/widgets/email_auth_sheet.dart';
import '../shop/widgets/store_product_card.dart';
import '../shop/widgets/store_product_detail_sheet.dart';

/// Helper retained for external checkout URL tests & deep-link construction.
const _checkoutUrl = String.fromEnvironment('PROMO_SHOP_URL');
final _shopWebsite = Uri.https('soshallitbe.cyou', '/shop/');

Uri deckShopDestination(
  DivinationSystem system,
  String deckId, {
  String checkout = _checkoutUrl,
}) {
  final uri = Uri.tryParse(checkout);
  if (uri == null ||
      (uri.scheme != 'https' && uri.scheme != 'http') ||
      uri.host.isEmpty) {
    return _shopWebsite.replace(
      queryParameters: {'system': system.name, 'deck': deckId},
    );
  }
  final target =
      (uri.path.isEmpty || uri.path == '/') ? uri.resolve('/shop/') : uri;
  return target.replace(
    queryParameters: {
      ...uri.queryParameters,
      'system': system.name,
      'deck': deckId,
    },
  );
}

/// Obsidian & Lavender Digital Boutique:
/// - Displays ONLY backend-published store items (never built-in bundled packs).
/// - Keeps owned items in the catalog with `УЖЕ КУПЛЕНО` + Equip/Download CTA.
/// - Free gifts claim & install in 1 tap directly inside the app.
/// - Paid items hand off seamlessly to the promo website `/shop/` and auto-download
///   when the user returns to the app.
class DeckShopScreen extends StatefulWidget {
  const DeckShopScreen({super.key, required this.system});

  final DivinationSystem system;

  @override
  State<DeckShopScreen> createState() => _DeckShopScreenState();
}

class _DeckShopScreenState extends State<DeckShopScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final store = context.read<StoreController>();
      if (store.isConfigured && store.allProducts.isEmpty && !store.loading) {
        unawaited(store.refresh());
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      final store = context.read<StoreController>();
      if (store.hasPendingWebCheckout) {
        unawaited(store.refresh(autoInstallNewlyOwned: true));
      }
    }
  }

  Future<void> _handlePrimaryAction(StoreProduct product) async {
    final store = context.read<StoreController>();
    final auth = context.read<BackendAuthController>();
    final lang = context.read<AppSettingsController>().language;

    // Already owned: equip if installed, or download if owned on another device.
    if (store.isOwned(product)) {
      if (store.isInstalled(product)) {
        await store.equip(product);
        if (mounted) {
          showTaroGlassSnackbar(
            context,
            message: AppStrings.t(
              lang,
              'shop.snack.equipped',
              {'title': product.title},
            ),
          );
        }
      } else {
        final ok = await store.downloadAndInstall(product);
        if (mounted && ok) {
          showTaroGlassSnackbar(
            context,
            message: AppStrings.t(
              lang,
              'shop.snack.installed',
              {'title': product.title},
            ),
          );
        }
      }
      return;
    }

    // Free gift: 1-tap claim + download + install.
    if (product.free) {
      final ok = await store.claimFreeGift(product);
      if (mounted && ok) {
        showTaroGlassSnackbar(
          context,
          message: AppStrings.t(
            lang,
            'shop.snack.installed',
            {'title': product.title},
          ),
        );
      }
      return;
    }

    // Paid item: require verified email account first, then hand off to promo site /shop/.
    if (!auth.isVerified) {
      final signedIn = await EmailAuthSheet.show(context);
      if (!signedIn || !mounted) return;
      // Refresh in case this email account already owns the item!
      await store.refresh();
      if (!mounted) return;
      if (store.isOwned(product)) {
        await store.downloadAndInstall(product);
        return;
      }
    }

    try {
      final returnUrl = kIsWeb ? Uri.base.toString() : null;
      final uri = await store.buildWebCheckoutUri(
        product,
        returnUrl: returnUrl,
      );
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
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

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppSettingsController>().language;
    final auth = context.watch<BackendAuthController>();
    final store = context.watch<StoreController>();

    final hero = store.featuredProduct;
    final visible = store.visibleProducts;
    final gridItems = hero == null
        ? visible
        : [for (final p in visible) if (p.id != hero.id) p];

    return Stack(
      children: [
        const Positioned.fill(child: TaroDuskBackground()),
        TaroGlassLayer(
          useBackdropGroup: false,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: Column(
                children: [
                  ProfileHeader(
                    leading: const BackButton(color: TaroColors.lavender),
                    trailing: _AccountPill(
                      email: auth.email,
                      verified: auth.isVerified,
                      language: lang,
                      onTap: () => EmailAuthSheet.show(context),
                    ),
                    child: const ProfileHeaderTitle('almanac.shop'),
                  ),
                  _FilterStrip(
                    language: lang,
                    selectedSystem: store.systemFilter,
                    ownedOnly: store.ownedOnly,
                    onSelectSystem: store.setSystemFilter,
                    onToggleOwned: store.setOwnedOnly,
                  ),
                  Expanded(
                    child: !store.isConfigured && store.allProducts.isEmpty
                        ? Center(
                            child: TaroGlassEmptyState(
                              icon: Icons.storefront_outlined,
                              title: AppStrings.t(lang, 'shop.state.offline'),
                              subtitle: AppStrings.t(
                                lang,
                                'shop.state.offlineHint',
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            color: TaroColors.lavender,
                            backgroundColor: TaroColors.surface,
                            onRefresh: () => store.refresh(
                              autoInstallNewlyOwned: true,
                            ),
                            child: _buildBody(
                              context,
                              lang,
                              store,
                              hero,
                              gridItems,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLanguage lang,
    StoreController store,
    StoreProduct? hero,
    List<StoreProduct> gridItems,
  ) {
    if (store.loading && store.allProducts.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: TaroColors.lavender),
      );
    }

    if (store.error != null && store.allProducts.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 64),
          TaroGlassEmptyState(
            icon: Icons.cloud_off_outlined,
            title: AppStrings.t(lang, 'shop.state.offline'),
            subtitle: store.error,
            actionLabel: AppStrings.t(lang, 'shop.action.retry'),
            onAction: () => store.refresh(),
          ),
        ],
      );
    }

    if (hero == null && gridItems.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 64),
          TaroGlassEmptyState(
            icon: Icons.auto_awesome_outlined,
            title: AppStrings.t(lang, 'shop.state.empty'),
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, bounds) {
        final maxWidth = bounds.maxWidth;
        final isWide = maxWidth >= 720;
        final horizontalPad = isWide
            ? ((maxWidth - 1040).clamp(32.0, double.infinity)) / 2
            : 16.0;
        final columns = maxWidth >= 980
            ? 3
            : maxWidth >= 640
                ? 2
                : 1;
        final contentWidth = maxWidth - horizontalPad * 2;
        final colWidth = (contentWidth - (columns - 1) * 16) / columns;
        final artHeight = (colWidth * 10 / 16).clamp(140.0, 220.0);
        final gridExtent = artHeight + 210.0;

        return CustomScrollView(
          key: const ValueKey('shop-scroll'),
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (hero != null)
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPad,
                  10,
                  horizontalPad,
                  16,
                ),
                sliver: SliverToBoxAdapter(
                  child: StoreProductCard(
                    product: hero,
                    language: lang,
                    owned: store.isOwned(hero),
                    installed: store.isInstalled(hero),
                    active: store.isActive(hero),
                    installState: store.installStateFor(hero.id),
                    isHero: true,
                    onOpenDetail: () => _openDetail(hero),
                    onPrimaryAction: () => _handlePrimaryAction(hero),
                    onCheckCheckout: () =>
                        store.refresh(autoInstallNewlyOwned: true),
                  ),
                ),
              ),
            if (gridItems.isNotEmpty)
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPad,
                  hero == null ? 10 : 4,
                  horizontalPad,
                  28,
                ),
                sliver: columns == 1
                    ? SliverList.separated(
                        itemCount: gridItems.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 14),
                        itemBuilder: (_, i) {
                          final product = gridItems[i];
                          return StoreProductCard(
                            product: product,
                            language: lang,
                            owned: store.isOwned(product),
                            installed: store.isInstalled(product),
                            active: store.isActive(product),
                            installState: store.installStateFor(product.id),
                            onOpenDetail: () => _openDetail(product),
                            onPrimaryAction: () =>
                                _handlePrimaryAction(product),
                            onCheckCheckout: () =>
                                store.refresh(autoInstallNewlyOwned: true),
                          );
                        },
                      )
                    : SliverGrid.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          mainAxisExtent: gridExtent,
                        ),
                        itemCount: gridItems.length,
                        itemBuilder: (_, i) {
                          final product = gridItems[i];
                          return StoreProductCard(
                            product: product,
                            language: lang,
                            owned: store.isOwned(product),
                            installed: store.isInstalled(product),
                            active: store.isActive(product),
                            installState: store.installStateFor(product.id),
                            onOpenDetail: () => _openDetail(product),
                            onPrimaryAction: () =>
                                _handlePrimaryAction(product),
                            onCheckCheckout: () =>
                                store.refresh(autoInstallNewlyOwned: true),
                          );
                        },
                      ),
              ),
          ],
        );
      },
    );
  }

  void _openDetail(StoreProduct product) {
    final store = context.read<StoreController>();
    StoreProductDetailSheet.show(
      context,
      product: product,
      onPrimaryAction: _handlePrimaryAction,
      onUninstallLocal: (p) => store.uninstallLocal(p),
    );
  }
}

class _AccountPill extends StatelessWidget {
  const _AccountPill({
    required this.email,
    required this.verified,
    required this.language,
    required this.onTap,
  });

  final String? email;
  final bool verified;
  final AppLanguage language;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey('shop-account-pill'),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: verified
              ? TaroColors.emerald.withValues(alpha: 0.14)
              : TaroColors.surface.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: verified
                ? TaroColors.emerald.withValues(alpha: 0.5)
                : TaroColors.lavender.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              verified ? Icons.verified_outlined : Icons.person_outline,
              size: 14,
              color: verified ? TaroColors.emerald : TaroColors.lavender,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                verified && email != null && email!.isNotEmpty
                    ? email!
                    : AppStrings.t(language, 'shop.account.signIn'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: verified ? TaroColors.emerald : TaroColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterStrip extends StatelessWidget {
  const _FilterStrip({
    required this.language,
    required this.selectedSystem,
    required this.ownedOnly,
    required this.onSelectSystem,
    required this.onToggleOwned,
  });

  final AppLanguage language;
  final DivinationSystem? selectedSystem;
  final bool ownedOnly;
  final ValueChanged<DivinationSystem?> onSelectSystem;
  final ValueChanged<bool> onToggleOwned;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        children: [
          _FilterPill(
            key: const ValueKey('shop-filter-all'),
            label: AppStrings.t(language, 'almanac.all'),
            active: selectedSystem == null && !ownedOnly,
            onTap: () {
              onToggleOwned(false);
              onSelectSystem(null);
            },
          ),
          for (final sys in DivinationSystem.values)
            _FilterPill(
              key: ValueKey('shop-filter-${sys.name}'),
              label: AppStrings.t(language, 'almanac.${sys.name}'),
              active: selectedSystem == sys && !ownedOnly,
              onTap: () {
                onToggleOwned(false);
                onSelectSystem(sys);
              },
            ),
          _FilterPill(
            key: const ValueKey('shop-filter-owned'),
            label: AppStrings.t(language, 'shop.filter.owned'),
            active: ownedOnly,
            onTap: () {
              onSelectSystem(null);
              onToggleOwned(!ownedOnly);
            },
          ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: active
                ? TaroColors.lavender.withValues(alpha: 0.22)
                : TaroColors.surface.withValues(alpha: 0.62),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: active
                  ? TaroColors.lavender
                  : TaroColors.mist.withValues(alpha: TaroOpacity.border),
            ),
          ),
          child: Text(
            label.toUpperCase(),
            style: AppTypography.label(
              fontSize: 10,
              letterSpacing: 1.0,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? TaroColors.textPrimary : TaroColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
