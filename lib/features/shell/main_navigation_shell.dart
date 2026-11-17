import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../almanac/almanac_screen.dart';
import '../astral/astral_screen.dart';
import '../camera_scan/camera_scan_screen.dart';
import '../digital_table/table_workspace.dart';

/// 4-Tab shell: Camera (0) | Table Workspace (1, default) | Almanac (2) |
/// Astral (3). The Table tab hosts the 3-pane horizontal workspace
/// (Digital Table ⇄ Oracle AI Chat ⇄ Spread History).
class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _index = 1; // Digital Table is the core tab

  void _switchTo(int index) {
    if (index == _index) return;
    HapticFeedback.selectionClick();
    setState(() => _index = index);
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
          TableWorkspace(onOpenCameraClarifier: () => _switchTo(0)),
          const AlmanacScreen(),
          const AstralScreen(),
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

  static const _tabs = [
    (Icons.camera_alt_outlined, 'CAMERA'),
    (Icons.style_outlined, 'TABLE'),
    (Icons.menu_book_outlined, 'ALMANAC'),
    (Icons.auto_awesome_outlined, 'ASTRAL'),
  ];

  @override
  Widget build(BuildContext context) {
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
                label: _tabs[i].$2,
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
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              letterSpacing: 1.6,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
