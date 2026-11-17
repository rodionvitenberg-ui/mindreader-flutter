import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/models/natal_chart.dart';
import '../../core/models/oracle_handoff.dart';
import '../../core/services/local_storage_service.dart';
import '../../core/services/natal_calculator_service.dart';
import '../../core/services/oracle_synthesis_service.dart';
import '../../core/theme/app_colors.dart';
import '../../state/astral_controller.dart';
import '../digital_table/widgets/ritual_settings_sheet.dart';
import 'natal_profile_detail_sheet.dart';
import 'synastry_summary_sheet.dart';
import 'widgets/astral_cosmic_bar.dart';
import 'widgets/astral_gradient_button.dart';
import 'widgets/astral_house_selector.dart';
import 'widgets/astral_profile_bar.dart';
import 'widgets/astral_pro_paywall_sheet.dart';
import 'widgets/astral_summary_card.dart';
import 'widgets/astral_wheel_placeholder.dart';
import 'widgets/birth_data_form_sheet.dart';
import 'widgets/daily_horoscope_card.dart';
import 'widgets/natal_wheel_widget.dart';

/// Pillar 5: ASTRAL — multi-profile natal charts with a 2-profile free
/// tier, instant house-system switching, a daily horoscope, the full natal
/// profile sheet, 2-profile synastry and an Oracle Chat handoff.
class AstralScreen extends StatefulWidget {
  const AstralScreen({super.key, this.onOpenOracle});

  /// Shell callback: hands a natal or synastry reading to the Oracle Chat
  /// pane (Table tab) and switches the tab.
  final ValueChanged<OracleHandoff>? onOpenOracle;

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

  void _openProfile(NatalChart chart) {
    final astral = context.read<AstralController>();
    NatalProfileDetailSheet.show(
      context,
      chart: chart,
      onHouseSystemChanged: astral.setHouseSystem,
    );
  }

  void _handoffNatalToOracle(NatalChart chart) {
    final onOpenOracle = widget.onOpenOracle;
    if (onOpenOracle == null) return;
    final horoscope = context.read<AstralController>().activeHoroscope;
    onOpenOracle(
      OracleHandoff(
        prompt: OracleSynthesisService.buildNatalPrompt(chart, horoscope),
        chart: chart,
        horoscope: horoscope,
      ),
    );
  }

  void _openSynastry(AstralController astral) {
    final active = astral.activeProfile;
    if (active == null) return;
    NatalChart? other;
    for (final p in astral.profiles) {
      if (p.id != active.id) {
        other = p;
        break;
      }
    }
    if (other == null) return;
    SynastrySummarySheet.show(
      context,
      a: active,
      b: other,
      onSendToOracle: widget.onOpenOracle,
    );
  }

  @override
  Widget build(BuildContext context) {
    final astral = context.watch<AstralController>();
    final chart = astral.activeProfile;
    final report = astral.activeHoroscope;
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
              if (chart == null)
                const AstralWheelPlaceholder(chart: null)
              else
                NatalWheelWidget(chart: chart),
              const SizedBox(height: 16),
              if (chart == null)
                AstralEmptyState(onGenerate: _openNewChart)
              else ...[
                AstralSummaryCard(
                  chart: chart,
                  onOpenProfile: () => _openProfile(chart),
                ),
                if (report != null) ...[
                  const SizedBox(height: 14),
                  DailyHoroscopeCard(report: report),
                ],
                const SizedBox(height: 14),
                AstralGradientButton(
                  label: '✦ DISCUSS WITH THE ORACLE',
                  onTap: () => _handoffNatalToOracle(chart),
                ),
                if (astral.profiles.length >= 2) ...[
                  const SizedBox(height: 10),
                  AstralGradientButton(
                    label: '⚡ COMPARE 2 PROFILES · SYNASTRY',
                    onTap: () => _openSynastry(astral),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
