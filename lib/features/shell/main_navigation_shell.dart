import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/models/natal_chart.dart';
import '../../core/models/oracle_handoff.dart';
import '../../core/theme/app_colors.dart';
import '../../state/app_settings_controller.dart';
import '../almanac/almanac_screen.dart';
import '../astral/astral_screen.dart';
import '../camera_scan/camera_scan_screen.dart';
import '../digital_table/table_workspace.dart';
import '../profile/profile_screen.dart';

/// Bottom dock: Camera (0) | Table (1, default) | Almanac (2) | Astral (3) |
/// Profile (4). The Table tab hosts the 3-pane horizontal workspace
/// (Digital Table ⇄ Oracle AI Chat ⇄ History). Rituals and Settings are no
/// longer dock actions — they live on the full-page ProfileScreen.
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
  final ValueNotifier<ZodiacSign?> _browseSign =
      ValueNotifier<ZodiacSign?>(null);

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
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          CameraScanScreen(
            isActiveTab: _index == 0,
            onHandoff: () => _switchTo(1),
          ),
          TableWorkspace(
            onOpenCameraClarifier: () => _switchTo(0),
            astralHandoff: _handoff,
          ),
          AlmanacScreen(onOpenZodiacHoroscope: _openZodiacHoroscope),
          AstralScreen(
            onOpenOracle: _openOracle,
            browseZodiacSign: _browseSign,
          ),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: _GlassNavBar(index: _index, onTap: _switchTo),
    );
  }
}

class _GlassNavBar extends StatelessWidget {
  const _GlassNavBar({required this.index, required this.onTap});

  final int index;
  final ValueChanged<int> onTap;

  /// The 5 real tabs, in IndexedStack order.
  static const _tabs = [
    (Icons.camera_alt_outlined, 'nav.camera'),
    (Icons.style_outlined, 'nav.table'),
    (Icons.menu_book_outlined, 'nav.almanac'),
    (Icons.auto_awesome_outlined, 'nav.astral'),
    (Icons.person_outline, 'nav.profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppSettingsController>().language;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      height: 62,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          for (var i = 0; i < _tabs.length; i++)
            Expanded(
              child: _NavItem(
                icon: _tabs[i].$1,
                label: AppStrings.t(lang, _tabs[i].$2),
                active: i == index,
                onTap: () => onTap(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.lavender : AppColors.textMuted;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 2),
          // Six dock segments must fit a 360 px screen: the label scales
          // down rather than overflowing.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 8,
                  letterSpacing: 0.6,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
