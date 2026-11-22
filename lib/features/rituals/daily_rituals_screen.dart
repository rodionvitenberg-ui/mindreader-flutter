import 'package:flutter/material.dart';

import '../../design_system/taro.dart';
import '../digital_table/widgets/ritual_settings_sheet.dart';
import '../profile/widgets/profile_header.dart';

class DailyRitualsScreen extends StatelessWidget {
  const DailyRitualsScreen({super.key, required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          const ProfileHeader(
            child: FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: ProfileHeaderTitle('rituals.title'),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              children: [
                TaroGlassPanel(
                  padding: const EdgeInsets.all(16),
                  child: RitualSettingsSheet(inline: true, isActive: isActive),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
