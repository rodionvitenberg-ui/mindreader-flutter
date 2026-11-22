import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/models/natal_chart.dart';
import '../../core/models/oracle_handoff.dart';
import '../../design_system/taro.dart';
import '../../state/app_settings_controller.dart';
import '../almanac/almanac_screen.dart';
import '../astral/astral_screen.dart';
import '../camera_scan/camera_scan_screen.dart';
import '../digital_table/table_workspace.dart';
import '../rituals/daily_rituals_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: TaroDuskBackground()),
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
                    ),
                  )
                else
                  const SizedBox.shrink(),
              ],
            ),
            bottomNavigationBar: TaroGlassLayer(
              child: _TaroNavDock(index: _index, onTap: _switchTo),
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

  static const _tabs = [
    (Icons.camera_alt_outlined, 'nav.camera'),
    (Icons.style_outlined, 'nav.table'),
    (Icons.menu_book_outlined, 'nav.almanac'),
    (Icons.auto_awesome_outlined, 'nav.astral'),
    (Icons.notifications_outlined, 'nav.rituals'),
  ];

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppSettingsController>().language;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: TaroGlassDock(
        items: [
          for (final tab in _tabs)
            TaroDockItem(icon: tab.$1, label: AppStrings.t(lang, tab.$2)),
        ],
        index: index,
        onTap: onTap,
      ),
    );
  }
}
