import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/models/custom_spread.dart';
import '../../core/models/divination_card.dart';
import '../../core/models/divination_system.dart';
import '../../core/models/natal_chart.dart';
import '../../core/models/oracle_handoff.dart';
import '../../core/models/spread_type.dart';
import '../../core/services/pwa_install_service.dart';
import '../../core/services/telegram_webapp_service.dart';
import '../../design_system/taro.dart';
import '../../state/app_settings_controller.dart';
import '../../state/daily_ritual_controller.dart';
import '../../state/session_history_controller.dart';
import '../../state/spread_controller.dart';
import '../almanac/almanac_screen.dart';
import '../astral/astral_screen.dart';
import '../camera_scan/camera_scan_screen.dart';
import '../digital_table/table_workspace.dart';
import '../rituals/daily_rituals_screen.dart';
import 'widgets/pwa_install_banner.dart';

/// Bottom dock and independent navigation state for each tab.
class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  static const _ritualsIndex = 4;
  int _index = 1; // Digital Table is the core tab
  bool _ritualsOpened = false;
  bool _precachedBackgrounds = false;
  AlmanacTab _almanacTab = AlmanacTab.tarot;

  final PwaInstallBridge _pwaBridge = createPwaInstallBridge();
  final TelegramWebAppBridge _tmaBridge = createTelegramWebAppBridge();
  bool _pwaDismissed = true; // stays hidden until loaded & eligible on Web

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      if (_tmaBridge.isTelegram) {
        _tmaBridge.initialize();
      } else {
        unawaited(_loadPwaBannerState());
      }
      final deepTab = tabIndexForStartParam(_tmaBridge.startParam);
      if (deepTab != null) {
        _index = deepTab;
        if (deepTab == _ritualsIndex) _ritualsOpened = true;
      }
    }
  }

  Future<void> _loadPwaBannerState() async {
    final dismissed = await PwaInstallBanner.isDismissed();
    if (!mounted) return;
    setState(() => _pwaDismissed = dismissed);
  }

  Future<void> _dismissPwaBanner() async {
    setState(() => _pwaDismissed = true);
    await PwaInstallBanner.markDismissed();
  }

  Future<void> _triggerPwaInstall() async {
    final accepted = await _pwaBridge.promptInstall();
    if (accepted || !mounted) {
      await _dismissPwaBanner();
    } else {
      setState(() {});
    }
  }

  String? get _backgroundAsset => switch (_index) {
    1 => TaroBackgroundAssets.forest,
    2 => _almanacTab == AlmanacTab.zodiac ? null : TaroBackgroundAssets.forest,
    3 => TaroBackgroundAssets.oak,
    4 => TaroBackgroundAssets.oak,
    _ => null,
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_precachedBackgrounds ||
        WidgetsBinding.instance is! WidgetsFlutterBinding) {
      return;
    }
    _precachedBackgrounds = true;
    precacheImage(const AssetImage(TaroBackgroundAssets.forest), context);
    precacheImage(const AssetImage(TaroBackgroundAssets.oak), context);
  }

  /// Cross-tab ASTRAL to Table handoff: ASTRAL publishes a reading request
  /// here; the Oracle Chat pane consumes it and streams the answer.
  final ValueNotifier<OracleHandoff?> _handoff = ValueNotifier<OracleHandoff?>(
    null,
  );

  /// Almanac → ASTRAL: open the Horoscope window for a specific sign.
  final ValueNotifier<ZodiacSign?> _browseSign = ValueNotifier<ZodiacSign?>(
    null,
  );

  @override
  void dispose() {
    _handoff.dispose();
    _browseSign.dispose();
    super.dispose();
  }

  void _openZodiacHoroscope(ZodiacSign sign) {
    _browseSign.value = sign;
    _switchTo(3);
  }

  void _switchTo(int index) {
    if (index == _index) return;
    HapticFeedback.selectionClick();
    setState(() {
      _index = index;
      if (index == _ritualsIndex) _ritualsOpened = true;
    });
  }

  void _openOracle(OracleHandoff handoff) {
    _handoff.value = handoff;
    _switchTo(1);
  }

  void _startLunarSpread(CustomSpreadConfig spread) {
    final ctrl = context.read<SpreadController>();
    ctrl.setSystem(DivinationSystem.tarot);
    ctrl.setCustomSpread(spread);
    ctrl.activateSpread();
    _switchTo(1);
  }

  void _openDailyCardOnTable(DailyCardEntry entry) {
    final ctrl = context.read<SpreadController>();
    ctrl.loadScannedSpread(
      system: DivinationSystem.tarot,
      cards: [TarotDivinationCard(entry.card)],
      reversed: [entry.isReversed],
      spreadType: SpreadType.one,
    );
    _switchTo(1);
  }

  @override
  Widget build(BuildContext context) {
    final hasCompletedReading = kIsWeb &&
        (context.watch<SessionHistoryController?>()?.sessions.isNotEmpty ??
            false);
    final pwaMode =
        (kIsWeb && !_tmaBridge.isTelegram && !_pwaDismissed && hasCompletedReading)
            ? _pwaBridge.currentMode()
            : PwaInstallMode.unavailable;

    return Stack(
      children: [
        Positioned.fill(
          child: TaroDuskBackground(imageAsset: _backgroundAsset),
        ),
        // Share one GPU backdrop readback across non-overlapping glass chrome
        // (tab controls + bottom dock) so Impeller pays for a single screen
        // capture per frame while each control keeps its own compact bounds.
        BackdropGroup(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            // A glass layer also paints the shapes of mounted, hidden children.
            // Keep each layer inside its tab so IndexedStack hides it as well.
            body: IndexedStack(
              index: _index,
              children: [
                TaroGlassLayer(
                  child: CameraScanScreen(
                    isActiveTab: _index == 0,
                    onHandoff: () => _switchTo(1),
                  ),
                ),
                TableWorkspace(
                  onOpenCameraClarifier: () => _switchTo(0),
                  onResumeCamera: () => _switchTo(0),
                  astralHandoff: _handoff,
                ),
                TaroGlassLayer(
                  child: AlmanacScreen(
                    onOpenZodiacHoroscope: _openZodiacHoroscope,
                    onTabChanged: (tab) {
                      if (_almanacTab != tab) {
                        setState(() => _almanacTab = tab);
                      }
                    },
                  ),
                ),
                TaroGlassLayer(
                  child: AstralScreen(
                    isActive: _index == 3,
                    onOpenOracle: _openOracle,
                    browseZodiacSign: _browseSign,
                  ),
                ),
                if (_ritualsOpened)
                  TaroGlassLayer(
                    child: DailyRitualsScreen(
                      isActive: _index == _ritualsIndex,
                      onStartLunarSpread: _startLunarSpread,
                      onDiscussDailyCard: _openDailyCardOnTable,
                    ),
                  )
                else
                  const SizedBox.shrink(),
              ],
            ),
            bottomNavigationBar: TaroGlassLayer(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (pwaMode != PwaInstallMode.unavailable)
                    PwaInstallBanner(
                      mode: pwaMode,
                      onInstall: _triggerPwaInstall,
                      onDismiss: _dismissPwaBanner,
                    ),
                  _TaroNavDock(index: _index, onTap: _switchTo),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Стеклянный нижний док на [TaroGlassDock] с безопасной областью.
class _TaroNavDock extends StatelessWidget {
  const _TaroNavDock({required this.index, required this.onTap});

  final int index;
  final ValueChanged<int> onTap;

  static Widget _buildAstralIcon(Color color, double size) =>
      AstralZodiacIcon(size: size, color: color);

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppSettingsController>().language;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: TaroGlassDock(
        items: [
          TaroDockItem(
            icon: Icons.camera_alt_outlined,
            label: AppStrings.t(lang, 'nav.camera'),
          ),
          TaroDockItem(
            icon: Icons.style_outlined,
            label: AppStrings.t(lang, 'nav.table'),
          ),
          TaroDockItem(
            icon: Icons.menu_book_outlined,
            label: AppStrings.t(lang, 'nav.almanac'),
          ),
          TaroDockItem(
            iconBuilder: _buildAstralIcon,
            label: AppStrings.t(lang, 'nav.astral'),
          ),
          TaroDockItem(
            icon: Icons.notifications_outlined,
            label: AppStrings.t(lang, 'nav.rituals'),
          ),
        ],
        index: index,
        onTap: onTap,
      ),
    );
  }
}
