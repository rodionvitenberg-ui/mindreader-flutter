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

/// Bottom dock: Camera (0) | Table (1, default) | Almanac (2) | Astral (3).
/// Profile moved OUT of the dock — it is now pushed full-page from the
/// profile action in the top-right corner of each non-camera page. Index 4 is RESERVED
/// for the upcoming ACADEMY learning tab (append a child + a tab entry when
/// that sprint lands). Rituals and Settings live on the full-page
/// ProfileScreen.
class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _index = 1; // Digital Table is the core tab

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
    setState(() => _index = index);
  }

  void _openOracle(OracleHandoff handoff) {
    _handoff.value = handoff;
    _switchTo(1);
  }

  @override
  Widget build(BuildContext context) {
    final stack = IndexedStack(
      index: _index,
      children: [
        CameraScanScreen(
          isActiveTab: _index == 0,
          onHandoff: () => _switchTo(1),
        ),
        TableWorkspace(
          onOpenCameraClarifier: () => _switchTo(0),
          onResumeCamera: () => _switchTo(0),
          astralHandoff: _handoff,
        ),
        AlmanacScreen(onOpenZodiacHoroscope: _openZodiacHoroscope),
        AstralScreen(
          isActive: _index == 3,
          onOpenOracle: _openOracle,
          browseZodiacSign: _browseSign,
        ),
      ],
    );

    // Один общий TaroGlassLayer на уровне shell: все стеклянные поверхности
    // делят один backdrop sample поверх градиента сумерек TaroDuskBackground
    // (сам фон не в стекле).
    return Stack(
      children: [
        const Positioned.fill(child: TaroDuskBackground()),
        TaroGlassLayer(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: stack,
            bottomNavigationBar: _TaroNavDock(
              index: _index,
              onTap: _switchTo,
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

  /// The 4 core tabs, in IndexedStack order. The 5th slot (Academy) is
  /// reserved for the upcoming learning sprint — add `Icons.school_outlined,
  /// 'nav.academy'` here and a matching IndexedStack child.
  static const _tabs = [
    (Icons.camera_alt_outlined, 'nav.camera'),
    (Icons.style_outlined, 'nav.table'),
    (Icons.menu_book_outlined, 'nav.almanac'),
    (Icons.auto_awesome_outlined, 'nav.astral'),
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
            TaroDockItem(
              icon: tab.$1,
              label: AppStrings.t(lang, tab.$2),
            ),
        ],
        index: index,
        onTap: onTap,
      ),
    );
  }
}
