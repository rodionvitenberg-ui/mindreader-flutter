import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/models/store_models.dart';
import '../../../core/theme/app_typography.dart';
import '../../../design_system/taro.dart';
import '../../../state/app_settings_controller.dart';
import '../../../state/store_controller.dart';
import 'store_price_format.dart';

/// Rich editorial showcase bottom sheet for a store product, loading full
/// preview artwork from `/api/v1/store/decks/{slug}/`.
class StoreProductDetailSheet extends StatefulWidget {
  const StoreProductDetailSheet({
    super.key,
    required this.product,
    required this.onPrimaryAction,
    required this.onUninstallLocal,
  });

  final StoreProduct product;
  final Future<void> Function(StoreProduct product) onPrimaryAction;
  final Future<void> Function(StoreProduct product) onUninstallLocal;

  static Future<void> show(
    BuildContext context, {
    required StoreProduct product,
    required Future<void> Function(StoreProduct product) onPrimaryAction,
    required Future<void> Function(StoreProduct product) onUninstallLocal,
  }) {
    return showTaroGlassSheet<void>(
      context: context,
      builder: (_) => StoreProductDetailSheet(
        product: product,
        onPrimaryAction: onPrimaryAction,
        onUninstallLocal: onUninstallLocal,
      ),
    );
  }

  @override
  State<StoreProductDetailSheet> createState() =>
      _StoreProductDetailSheetState();
}

class _StoreProductDetailSheetState extends State<StoreProductDetailSheet> {
  StoreProductDetail? _detail;
  bool _loadingPreviews = true;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    try {
      final detail = await context
          .read<StoreController>()
          .fetchDetail(widget.product.slug);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loadingPreviews = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingPreviews = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppSettingsController>().language;
    final store = context.watch<StoreController>();
    final product = _detail?.product ?? widget.product;
    final owned = store.isOwned(product);
    final installed = store.isInstalled(product);
    final active = store.isActive(product);
    final installState = store.installStateFor(product.id);
    final previews = _detail?.previews ?? const <StorePreviewAsset>[];

    return TaroGlassSheet(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.84,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    AppStrings.t(
                      lang,
                      'almanac.${product.system.name}',
                    ).toUpperCase(),
                    style: AppTypography.label(
                      fontSize: 10,
                      letterSpacing: 1.4,
                      color: TaroColors.lavender,
                    ),
                  ),
                  const Spacer(),
                  if (owned)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: TaroColors.emerald.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: TaroColors.emerald.withValues(alpha: 0.55),
                        ),
                      ),
                      child: Text(
                        '✓ ${AppStrings.t(lang, 'shop.badge.owned').toUpperCase()}',
                        style: AppTypography.label(
                          fontSize: 9.5,
                          letterSpacing: 1.0,
                          fontWeight: FontWeight.w700,
                          color: TaroColors.emerald,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                product.title,
                style: Theme.of(context).textTheme.displayMedium,
              ),
              if (product.artist.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  product.artist,
                  style: const TextStyle(
                    fontSize: 13,
                    color: TaroColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              if (_loadingPreviews)
                const SizedBox(
                  height: 150,
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: TaroColors.lavender,
                    ),
                  ),
                )
              else if (previews.isNotEmpty) ...[
                Text(
                  AppStrings.t(lang, 'shop.detail.previews').toUpperCase(),
                  style: AppTypography.label(
                    fontSize: 9.5,
                    letterSpacing: 1.4,
                    color: TaroColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 168,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: previews.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (_, i) => ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        color: TaroColors.preloaderBackground,
                        child: Image.network(
                          previews[i].url,
                          height: 168,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const SizedBox(
                            width: 104,
                            height: 168,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Text(
                product.description,
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.55,
                  color: TaroColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: TaroColors.background.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: TaroColors.mist.withValues(alpha: TaroOpacity.border),
                  ),
                ),
                child: Column(
                  children: [
                    if (product.license.isNotEmpty)
                      _MetaRow(
                        label: AppStrings.t(lang, 'shop.detail.license'),
                        value: product.license,
                      ),
                    if (product.version != null) ...[
                      _MetaRow(
                        label: AppStrings.t(lang, 'shop.detail.size'),
                        value: formatStoreBytes(product.version!.sizeBytes),
                      ),
                      _MetaRow(
                        label: AppStrings.t(lang, 'shop.detail.version'),
                        value: 'v${product.version!.version}',
                      ),
                    ],
                  ],
                ),
              ),
              if (installState.stage == StoreInstallStage.error &&
                  installState.errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  installState.errorMessage!,
                  style: const TextStyle(fontSize: 12, color: TaroColors.error),
                ),
              ],
              const SizedBox(height: 18),
              if (installState.isBusy)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LinearProgressIndicator(
                      value: installState.stage == StoreInstallStage.downloading
                          ? installState.progress
                          : null,
                      color: TaroColors.lavender,
                      backgroundColor: TaroColors.background,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppStrings.t(lang, 'shop.state.downloading'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: TaroColors.lavender,
                      ),
                    ),
                  ],
                )
              else if (owned) ...[
                TaroGlassButton(
                  icon: active
                      ? Icons.check_circle_outline
                      : installed
                          ? Icons.auto_awesome_outlined
                          : Icons.download_outlined,
                  label: active
                      ? AppStrings.t(lang, 'shop.action.active')
                      : installed
                          ? AppStrings.t(lang, 'shop.action.equip')
                          : AppStrings.t(lang, 'shop.action.download'),
                  variant: TaroGlassButtonVariant.primary,
                  onPressed: active
                      ? null
                      : () async {
                          await widget.onPrimaryAction(product);
                          if (context.mounted && store.isInstalled(product)) {
                            Navigator.of(context).pop();
                          }
                        },
                ),
                if (installed) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () async {
                      await widget.onUninstallLocal(product);
                    },
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 16,
                      color: TaroColors.textSecondary,
                    ),
                    label: Text(
                      AppStrings.t(lang, 'shop.action.removeLocal'),
                      style: const TextStyle(color: TaroColors.textSecondary),
                    ),
                  ),
                ],
              ] else
                TaroGlassButton(
                  icon: product.free
                      ? Icons.card_giftcard_outlined
                      : Icons.open_in_new,
                  label: product.free
                      ? AppStrings.t(lang, 'shop.action.claimGift')
                      : '${AppStrings.t(lang, 'shop.action.buyOnWeb')} · ${formatStorePrice(product, lang)}',
                  variant: TaroGlassButtonVariant.primary,
                  onPressed: () => widget.onPrimaryAction(product),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                color: TaroColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                color: TaroColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
