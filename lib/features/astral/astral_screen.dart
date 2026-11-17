import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/models/natal_chart.dart';
import '../../core/services/local_storage_service.dart';
import '../../core/services/natal_calculator_service.dart';
import '../../core/theme/app_colors.dart';
import '../../state/astral_controller.dart';
import '../digital_table/widgets/ritual_settings_sheet.dart';
import 'widgets/astral_cosmic_bar.dart';
import 'widgets/astral_house_selector.dart';
import 'widgets/astral_profile_bar.dart';
import 'widgets/astral_pro_paywall_sheet.dart';
import 'widgets/astral_summary_card.dart';
import 'widgets/astral_wheel_placeholder.dart';
import 'widgets/birth_data_form_sheet.dart';

/// Pillar 5: ASTRAL — multi-profile natal charts with a 2-profile free
/// tier, instant house-system switching and a daily horoscope. The animated
/// wheel itself lands in Phase 3; this screen owns the data + controls.
class AstralScreen extends StatefulWidget {
  const AstralScreen({super.key});

  @override
  State<AstralScreen> createState() => _AstralScreenState();
}

class _AstralScreenState extends State<AstralScreen> {
  final LocalStorageService _storage = LocalStorageService();
  final MoonPhase _phase =
      NatalCalculatorService.computeMoonPhase(DateTime.now().toUtc());
  int _streak = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AstralController>().load();
    });
    _loadStreak();
  }

  Future<void> _loadStreak() async {
    try {
      final days = await _storage.loadReadingDays();
      if (!mounted) return;
      setState(() => _streak = computeStreak(days));
    } catch (_) {
      // Storage unavailable — streak stays at 0.
    }
  }

  void _openNewChart() {
    final astral = context.read<AstralController>();
    if (astral.canCreateOrGenerateChart()) {
      BirthDataFormSheet.show(context);
    } else {
      AstralProPaywallSheet.show(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final astral = context.watch<AstralController>();
    final chart = astral.activeProfile;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AstralCosmicBar(
                phase: _phase,
                streak: _streak,
                onRituals: () => RitualSettingsSheet.show(context),
              ),
              const SizedBox(height: 16),
              AstralProfileBar(
                profiles: astral.profiles,
                activeIndex: astral.activeProfileIndex,
                canCreate: astral.canCreateOrGenerateChart(),
                onSelect: astral.setActiveProfile,
                onAdd: _openNewChart,
              ),
              const SizedBox(height: 14),
              Text(
                'HOUSE SYSTEM',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 9,
                  letterSpacing: 1.8,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 6),
              AstralHouseSelector(
                value: astral.activeHouseSystem,
                onChanged: astral.setHouseSystem,
              ),
              const SizedBox(height: 16),
              AstralWheelPlaceholder(chart: chart),
              const SizedBox(height: 16),
              if (chart == null)
                AstralEmptyState(onGenerate: _openNewChart)
              else
                AstralSummaryCard(
                  chart: chart,
                  report: astral.activeHoroscope,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
