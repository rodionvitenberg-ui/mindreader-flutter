import 'package:flutter/material.dart';

import '../../../core/config/app_build_config.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/models/divination_system.dart';
import '../../../core/models/store_models.dart';
import '../../../core/theme/app_typography.dart';
import '../../../design_system/taro.dart';
import 'store_price_format.dart';

/// Gallery card for one backend-published store item.
/// Never hides owned items — replaces price & buy CTA with `УЖЕ КУПЛЕНО` +
/// context action (`Использовать` / `Активна` / `Скачать` / progress).
class StoreProductCard extends StatelessWidget {
  const StoreProductCard({
    super.key,
    required this.product,
    required this.language,
    required this.owned,
    required this.installed,
    required this.active,
    required this.installState,
    required this.onOpenDetail,
    required this.onPrimaryAction,
    this.onCheckCheckout,
    this.isHero = false,
  });

  final StoreProduct product;
  final AppLanguage language;
  final bool owned;
  final bool installed;
  final bool active;
  final StoreInstallState installState;
  final VoidCallback onOpenDetail;
  final VoidCallback onPrimaryAction;
  final VoidCallback? onCheckCheckout;
  final bool isHero;

  String _countCaption() {
    final n = product.version?.cardCount ?? 0;
    if (n <= 0) return '';
    final unit = product.system == DivinationSystem.runes
        ? AppStrings.t(language, 'shop.unit.runes')
        : AppStrings.t(language, 'shop.unit.cards');
    return '$n $unit';
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = active
        ? TaroColors.lavender
        : owned
            ? TaroColors.emerald.withValues(alpha: 0.45)
            : isHero
                ? TaroColors.lavender.withValues(alpha: 0.45)
                : TaroColors.mist.withValues(alpha: TaroOpacity.border);

    return Material(
      key: ValueKey('shop-card-${product.slug}'),
      color: TaroColors.surface.withValues(alpha: isHero ? 0.84 : 0.74),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isHero ? 22 : 18),
        side: BorderSide(color: borderColor, width: isHero || active ? 1.3 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpenDetail,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ArtworkHeader(
              product: product,
              language: language,
              owned: owned,
              isHero: isHero,
              countCaption: _countCaption(),
            ),
            Padding(
              padding: EdgeInsets.all(isHero ? 18 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (product.artist.isNotEmpty)
                    Text(
                      product.artist.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.label(
                        fontSize: 9.5,
                        letterSpacing: 1.4,
                        color: TaroColors.textSecondary,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    product.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.display(
                      fontSize: isHero ? 24 : 19,
                      fontWeight: FontWeight.w600,
                      color: TaroColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    product.tagline.isNotEmpty
                        ? product.tagline
                        : product.description,
                    maxLines: isHero ? 3 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      color: TaroColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Divider(
                    height: 1,
                    color: TaroColors.mist.withValues(alpha: 0.16),
                  ),
                  const SizedBox(height: 12),
                  _CardFooter(
                    product: product,
                    language: language,
                    owned: owned,
                    installed: installed,
                    active: active,
                    installState: installState,
                    onPrimaryAction: onPrimaryAction,
                    onCheckCheckout: onCheckCheckout,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArtworkHeader extends StatelessWidget {
  const _ArtworkHeader({
    required this.product,
    required this.language,
    required this.owned,
    required this.isHero,
    required this.countCaption,
  });

  final StoreProduct product;
  final AppLanguage language;
  final bool owned;
  final bool isHero;
  final String countCaption;

  @override
  Widget build(BuildContext context) {
    final url = product.artworkUrl;
    final systemLabel = AppStrings.t(language, 'almanac.${product.system.name}');

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: isHero ? 260 : 220),
      child: AspectRatio(
        aspectRatio: isHero ? 16 / 9 : 16 / 10,
        child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  TaroColors.background,
                  Color.lerp(
                    TaroColors.duskMid,
                    product.free ? TaroColors.emerald : TaroColors.lavender,
                    0.22,
                  )!,
                ],
              ),
            ),
            child: url != null
                ? Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const _ArtworkFallbackIcon(),
                  )
                : const _ArtworkFallbackIcon(),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color(0xC80C101B), Color(0x000C101B)],
                stops: [0.0, 0.58],
              ),
            ),
          ),
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Row(
              children: [
                _TagPill(
                  label: countCaption.isEmpty
                      ? systemLabel.toUpperCase()
                      : '${systemLabel.toUpperCase()} · ${countCaption.toUpperCase()}',
                ),
                const Spacer(),
                if (owned)
                  _TagPill(
                    label: '✓ ${AppStrings.t(language, 'shop.badge.owned')}',
                    borderColor: TaroColors.emerald.withValues(alpha: 0.7),
                    textColor: TaroColors.emerald,
                  )
                else if (product.free)
                  _TagPill(
                    label: AppStrings.t(language, 'shop.badge.gift'),
                    borderColor: TaroColors.emerald.withValues(alpha: 0.65),
                    textColor: TaroColors.emerald,
                  )
                else if (product.featured)
                  _TagPill(
                    label: AppStrings.t(language, 'shop.badge.featured'),
                    borderColor: TaroColors.lavender.withValues(alpha: 0.7),
                    textColor: TaroColors.lavender,
                  ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _ArtworkFallbackIcon extends StatelessWidget {
  const _ArtworkFallbackIcon();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        Icons.auto_awesome_outlined,
        size: 38,
        color: TaroColors.lavender.withValues(alpha: 0.45),
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({
    required this.label,
    this.borderColor,
    this.textColor,
  });

  final String label;
  final Color? borderColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: TaroColors.preloaderBackground.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: borderColor ?? TaroColors.mist.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        label,
        style: AppTypography.label(
          fontSize: 9,
          letterSpacing: 1.0,
          fontWeight: FontWeight.w700,
          color: textColor ?? TaroColors.textPrimary,
        ),
      ),
    );
  }
}

class _CardFooter extends StatelessWidget {
  const _CardFooter({
    required this.product,
    required this.language,
    required this.owned,
    required this.installed,
    required this.active,
    required this.installState,
    required this.onPrimaryAction,
    this.onCheckCheckout,
  });

  final StoreProduct product;
  final AppLanguage language;
  final bool owned;
  final bool installed;
  final bool active;
  final StoreInstallState installState;
  final VoidCallback onPrimaryAction;
  final VoidCallback? onCheckCheckout;

  @override
  Widget build(BuildContext context) {
    if (installState.isBusy) {
      final status = switch (installState.stage) {
        StoreInstallStage.claiming => AppStrings.t(language, 'shop.state.processing'),
        StoreInstallStage.downloading =>
          '${AppStrings.t(language, 'shop.state.downloading')} ${(installState.progress * 100).round()}%',
        StoreInstallStage.verifying => AppStrings.t(language, 'shop.state.verifying'),
        StoreInstallStage.installing => AppStrings.t(language, 'shop.state.installing'),
        _ => AppStrings.t(language, 'shop.state.processing'),
      };
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: installState.stage == StoreInstallStage.downloading
                  ? installState.progress
                  : null,
              minHeight: 6,
              backgroundColor: TaroColors.background,
              valueColor: const AlwaysStoppedAnimation(TaroColors.lavender),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            status,
            style: const TextStyle(
              fontSize: 11.5,
              color: TaroColors.lavender,
            ),
          ),
        ],
      );
    }

    // Rule #2: Owned items NEVER show price or Buy button!
    if (owned) {
      return Row(
        children: [
          Container(
            key: ValueKey('shop-owned-badge-${product.slug}'),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: TaroColors.emerald.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: TaroColors.emerald.withValues(alpha: 0.55),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  size: 14,
                  color: TaroColors.emerald,
                ),
                const SizedBox(width: 5),
                Text(
                  AppStrings.t(language, 'shop.badge.owned').toUpperCase(),
                  style: AppTypography.label(
                    fontSize: 9.5,
                    letterSpacing: 1.0,
                    fontWeight: FontWeight.w700,
                    color: TaroColors.emerald,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          if (active)
            Text(
              AppStrings.t(language, 'shop.action.active').toUpperCase(),
              style: AppTypography.label(
                fontSize: 10,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w700,
                color: TaroColors.lavender,
              ),
            )
          else
            _CompactActionChip(
              key: ValueKey('shop-action-${product.slug}'),
              label: installed
                  ? AppStrings.t(language, 'shop.action.equip')
                  : AppStrings.t(language, 'shop.action.download'),
              icon: installed
                  ? Icons.auto_awesome_outlined
                  : Icons.download_outlined,
              primary: !installed,
              onTap: onPrimaryAction,
            ),
        ],
      );
    }

    if (installState.stage == StoreInstallStage.awaitingWebCheckout) {
      return Row(
        children: [
          Expanded(
            child: Text(
              AppStrings.t(language, 'shop.state.awaitingWeb'),
              style: const TextStyle(
                fontSize: 11.5,
                color: TaroColors.dawn,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _CompactActionChip(
            label: AppStrings.t(language, 'shop.action.checkPayment'),
            icon: Icons.refresh,
            primary: true,
            onTap: onCheckCheckout ?? onPrimaryAction,
          ),
        ],
      );
    }

    if (!product.free && !showExternalPurchaseUi) {
      return Row(
        children: [
          Expanded(
            child: Text(
              AppStrings.t(language, 'shop.reader.managedNote'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                color: TaroColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _CompactActionChip(
            key: ValueKey('shop-sync-${product.slug}'),
            label: AppStrings.t(language, 'shop.action.checkPayment'),
            icon: Icons.sync_rounded,
            primary: false,
            onTap: onPrimaryAction,
          ),
        ],
      );
    }

    return Row(
      children: [
        Text(
          formatStorePrice(product, language),
          key: ValueKey('shop-price-${product.slug}'),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: product.free ? TaroColors.emerald : TaroColors.textPrimary,
          ),
        ),
        const Spacer(),
        _CompactActionChip(
          key: ValueKey('shop-buy-${product.slug}'),
          label: product.free
              ? AppStrings.t(language, 'shop.action.claimGift')
              : AppStrings.t(language, 'shop.action.buyOnWeb'),
          icon: product.free
              ? Icons.card_giftcard_outlined
              : Icons.open_in_new,
          primary: true,
          onTap: onPrimaryAction,
        ),
      ],
    );
  }
}

class _CompactActionChip extends StatelessWidget {
  const _CompactActionChip({
    super.key,
    required this.label,
    required this.icon,
    required this.primary,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: primary
          ? TaroColors.lavender
          : TaroColors.background.withValues(alpha: 0.72),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: primary
            ? BorderSide.none
            : BorderSide(
                color: TaroColors.lavender.withValues(alpha: 0.45),
              ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: primary
                    ? TaroColors.preloaderBackground
                    : TaroColors.lavender,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: primary
                      ? TaroColors.preloaderBackground
                      : TaroColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
