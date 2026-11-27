import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/services/share_card_service.dart';
import '../../core/theme/app_typography.dart';
import '../../design_system/taro.dart';
import '../../state/app_settings_controller.dart';
import 'share_card_canvas.dart';
import 'share_card_payload.dart';

/// Interactive 9:16 editorial Story card studio: lets the reader preview their
/// obsidian-forest card, switch background atmosphere, cycle through strong
/// phrases, and share a crisp 1080x1920 PNG to Stories / messengers.
class ShareCardPreviewSheet extends StatefulWidget {
  const ShareCardPreviewSheet({
    super.key,
    required this.payload,
    this.adapter,
  });

  final ShareCardPayload payload;
  final ShareAdapter? adapter;

  static Future<void> show(
    BuildContext context, {
    required ShareCardPayload payload,
    ShareAdapter? adapter,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.78),
      builder: (_) => ShareCardPreviewSheet(
        payload: payload,
        adapter: adapter,
      ),
    );
  }

  @override
  State<ShareCardPreviewSheet> createState() => _ShareCardPreviewSheetState();
}

class _ShareCardPreviewSheetState extends State<ShareCardPreviewSheet> {
  final GlobalKey _boundaryKey = GlobalKey();
  late ShareCardAtmosphere _atmosphere = widget.payload.defaultAtmosphere;
  int _phraseIndex = 0;
  bool _sharing = false;

  void _cyclePhrase() {
    if (widget.payload.phraseOptions.length <= 1) return;
    HapticFeedback.selectionClick();
    setState(() {
      _phraseIndex = (_phraseIndex + 1) % widget.payload.phraseOptions.length;
    });
  }

  Future<void> _share() async {
    if (_sharing) return;
    HapticFeedback.mediumImpact();
    setState(() => _sharing = true);
    try {
      final outcome = await ShareCardService.shareBoundaryDetailed(
        _boundaryKey,
        filename: 'tarot_tree_story.png',
        caption: 'Tarot Tree · soshallitbe.cyou',
        adapter: widget.adapter,
      );
      if (!mounted) return;
      if (outcome == ShareDeliveryOutcome.failed) {
        showTaroGlassSnackbar(
          context,
          message: AppStrings.g('share.failed'),
          tone: TaroGlassSnackbarTone.warning,
        );
      } else if (outcome == ShareDeliveryOutcome.downloaded) {
        showTaroGlassSnackbar(
          context,
          message: AppStrings.g('share.downloaded'),
          tone: TaroGlassSnackbarTone.success,
        );
      }
    } catch (_) {
      if (mounted) {
        showTaroGlassSnackbar(
          context,
          message: AppStrings.g('share.failed'),
          tone: TaroGlassSnackbarTone.warning,
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppSettingsController?>()?.language ??
        AppStrings.current;
    final phrasesCount = widget.payload.phraseOptions.length;
    final media = MediaQuery.of(context);
    final maxHeight = media.size.height * 0.92;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0E101B).withValues(alpha: 0.98),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(
                color: TaroColors.lavender.withValues(alpha: 0.30),
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: TaroColors.mist.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        AppStrings.t(lang, 'share.sheetTitle'),
                        style: AppTypography.label(
                          fontSize: 11,
                          letterSpacing: 1.6,
                          fontWeight: FontWeight.w700,
                          color: TaroColors.lavender,
                        ),
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('share-sheet-close'),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: TaroColors.textSecondary,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Live 9:16 editorial card preview
                Flexible(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio:
                          ShareCardCanvas.logicalWidth /
                          ShareCardCanvas.logicalHeight,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.65),
                              blurRadius: 28,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: RepaintBoundary(
                              key: _boundaryKey,
                              child: ShareCardCanvas(
                                payload: widget.payload,
                                phraseIndex: _phraseIndex,
                                atmosphere: _atmosphere,
                                language: lang,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                // Atmosphere pills + Phrase cycler (Wrap prevents overflow in any language)
                Wrap(
                  spacing: 6,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (final bg in ShareCardAtmosphere.values)
                      _AtmospherePill(
                        key: ValueKey('share-bg-${bg.name}'),
                        label: AppStrings.t(lang, 'share.bg.${bg.name}'),
                        selected: _atmosphere == bg,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _atmosphere = bg);
                        },
                      ),
                    if (phrasesCount > 1)
                      _AtmospherePill(
                        key: const ValueKey('share-cycle-phrase'),
                        label:
                            '${AppStrings.t(lang, 'share.cyclePhrase')} ${_phraseIndex + 1}/$phrasesCount',
                        icon: Icons.auto_fix_high_rounded,
                        selected: false,
                        accent: true,
                        onTap: _cyclePhrase,
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: TaroGlassLayer(
                    useBackdropGroup: false,
                    child: TaroGlassButton(
                      key: const ValueKey('share-confirm-button'),
                      label: _sharing
                          ? AppStrings.t(lang, 'share.preparing')
                          : AppStrings.t(lang, 'share.cta'),
                      icon: Icons.ios_share_rounded,
                      loading: _sharing,
                      variant: TaroGlassButtonVariant.primary,
                      onPressed: _sharing ? null : _share,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AtmospherePill extends StatelessWidget {
  const _AtmospherePill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.accent = false,
  });

  final String label;
  final bool selected;
  final bool accent;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected || accent
        ? TaroColors.lavender.withValues(alpha: selected ? 0.85 : 0.45)
        : TaroColors.mist.withValues(alpha: TaroOpacity.border);
    final fillColor = selected
        ? TaroColors.lavender.withValues(alpha: 0.22)
        : TaroColors.surface.withValues(alpha: 0.65);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: fillColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: TaroColors.lavender),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: AppTypography.label(
                fontSize: 9,
                letterSpacing: 0.6,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected || accent
                    ? TaroColors.textPrimary
                    : TaroColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
