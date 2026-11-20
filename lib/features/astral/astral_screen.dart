import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/models/natal_chart.dart';
import '../../core/models/oracle_handoff.dart';
import '../../core/models/zodiac_forecast.dart';
import '../../core/services/local_storage_service.dart';
import '../../core/services/natal_calculator_service.dart';
import '../../core/services/oracle_synthesis_service.dart';
import '../../core/theme/app_colors.dart';
import '../../state/app_settings_controller.dart';
import '../../state/astral_controller.dart';
import '../profile/widgets/profile_header.dart';
import 'natal_profile_detail_sheet.dart';
import 'widgets/synastry_window.dart';
import 'widgets/astral_cosmic_bar.dart';
import 'widgets/astral_gradient_button.dart';
import 'widgets/astral_house_selector.dart';
import 'widgets/astral_profile_bar.dart';
import 'widgets/astral_pro_paywall_sheet.dart';
import 'widgets/astral_summary_card.dart';
import 'widgets/astral_wheel_placeholder.dart';
import 'widgets/birth_data_form_sheet.dart';
import 'widgets/horoscope_window.dart';
import 'widgets/natal_wheel_widget.dart';

/// The three ASTRAL windows.
enum AstralWindow { natalChart, horoscope, synastry }

/// Pillar 5: ASTRAL — multi-profile natal charts with a 2-profile free
/// tier, instant house-system switching, a 2-window architecture
/// `[ NATAL CHART | HOROSCOPE ]`, 2-profile synastry and an Oracle Chat
/// handoff.
class AstralScreen extends StatefulWidget {
  const AstralScreen({super.key, this.onOpenOracle, this.browseZodiacSign});

  /// Shell callback: hands a natal, horoscope or synastry reading to the
  /// Oracle Chat pane (Table tab) and switches the tab.
  final ValueChanged<OracleHandoff>? onOpenOracle;

  /// Shell signal: the Almanac asks ASTRAL to open the Horoscope window for
  /// a specific zodiac sign.
  final ValueNotifier<ZodiacSign?>? browseZodiacSign;

  @override
  State<AstralScreen> createState() => _AstralScreenState();
}

class _AstralScreenState extends State<AstralScreen> {
  final LocalStorageService _storage = LocalStorageService();
  final MoonPhase _phase =
      NatalCalculatorService.computeMoonPhase(DateTime.now().toUtc());
  int _streak = 0;

  AstralWindow _window = AstralWindow.natalChart;

  late final PageController _windowController = PageController();

  /// Quick-sign browse state: null = the personal (natal) horoscope.
  ZodiacSign? _quickSign;

  /// The sign to show when no natal profile exists yet — the current Sun.
  ZodiacSign get _defaultSign => ZodiacSignX.fromLongitude(
        NatalCalculatorService.computeEclipticLongitude(
          PlanetId.sun,
          DateTime.now().toUtc(),
        ),
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AstralController>().load();
    });
    widget.browseZodiacSign?.addListener(_onBrowseSign);
    _loadStreak();
  }

  @override
  void didUpdateWidget(covariant AstralScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.browseZodiacSign != widget.browseZodiacSign) {
      oldWidget.browseZodiacSign?.removeListener(_onBrowseSign);
      widget.browseZodiacSign?.addListener(_onBrowseSign);
    }
  }

  @override
  void dispose() {
    widget.browseZodiacSign?.removeListener(_onBrowseSign);
    _windowController.dispose();
    super.dispose();
  }

  /// The Almanac asked for a sign's horoscope: switch to window 1 and
  /// consume the signal.
  void _onBrowseSign() {
    final sign = widget.browseZodiacSign?.value;
    if (sign == null || !mounted) return;
    HapticFeedback.selectionClick();
    setState(() => _quickSign = sign);
    _selectWindow(AstralWindow.horoscope);
    widget.browseZodiacSign?.value = null;
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
        kind: OracleHandoffKind.natalChart,
        chart: chart,
        horoscope: horoscope,
      ),
    );
  }

  void _handoffHoroscopeToOracle(NatalChart chart, DailyHoroscopeReport report) {
    final onOpenOracle = widget.onOpenOracle;
    if (onOpenOracle == null) return;
    onOpenOracle(
      OracleHandoff(
        prompt: OracleSynthesisService.buildHoroscopePrompt(chart, report),
        kind: OracleHandoffKind.horoscope,
        chart: chart,
        horoscope: report,
      ),
    );
  }

  void _handoffZodiacToOracle(ZodiacSign sign, ZodiacSignForecast forecast) {
    final onOpenOracle = widget.onOpenOracle;
    if (onOpenOracle == null) return;
    onOpenOracle(
      OracleHandoff(
        prompt: OracleSynthesisService.buildZodiacForecastPrompt(sign, forecast),
        kind: OracleHandoffKind.zodiac,
        zodiacSign: sign,
        zodiacForecast: forecast,
      ),
    );
  }

  void _selectWindow(AstralWindow w) {
    if (_window == w) return;
    HapticFeedback.selectionClick();
    setState(() => _window = w);
    if (_windowController.hasClients) {
      _windowController.animateToPage(
        w.index,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _openSynastry(AstralController astral) {
    if (astral.profiles.length < 2) return;
    _selectWindow(AstralWindow.synastry);
  }

  NatalChart? _otherProfile(AstralController astral) {
    final active = astral.activeProfile;
    if (active == null) return null;
    for (final p in astral.profiles) {
      if (p.id != active.id) return p;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final astral = context.watch<AstralController>();
    final chart = astral.activeProfile;
    final report = astral.activeHoroscope;
    // Quick-sign mode: an explicit sign wins; without a chart the current
    // Sun's sign keeps the Horoscope window populated.
    final sign = _quickSign ?? (chart == null ? _defaultSign : null);
    final forecast = sign == null
        ? null
        : NatalCalculatorService.computeZodiacSignForecast(
            sign,
            forDate: DateTime.now().toUtc(),
          );
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ProfileHeader(
              child: AstralCosmicBar(phase: _phase, streak: _streak),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AstralProfileBar(
                    profiles: astral.profiles,
                    activeIndex: astral.activeProfileIndex,
                    canCreate: astral.canCreateOrGenerateChart(),
                    onSelect: astral.setActiveProfile,
                    onAdd: _openNewChart,
                  ),
                  const SizedBox(height: 12),
                  _AstralWindowSwitcher(
                    window: _window,
                    onChanged: _selectWindow,
                  ),
                  const SizedBox(height: 14),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _windowController,
                onPageChanged: (i) =>
                    setState(() => _window = AstralWindow.values[i]),
                children: [
                  _buildNatalWindow(astral, chart),
                  _buildHoroscopeWindow(chart, report, sign, forecast),
                  _buildSynastryWindow(astral),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNatalWindow(AstralController astral, NatalChart? chart) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
            const SizedBox(height: 14),
            AstralGradientButton(
              label: '✦ DISCUSS NATAL CHART WITH ORACLE',
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
    );
  }

  Widget _buildHoroscopeWindow(
    NatalChart? chart,
    DailyHoroscopeReport? report,
    ZodiacSign? sign,
    ZodiacSignForecast? forecast,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      child: HoroscopeWindow(
        chart: chart,
        report: report,
        selectedSign: _quickSign,
        forecast: forecast,
        sevenDayPeaks: chart == null
            ? null
            : NatalCalculatorService.computeSevenDayForecast(chart),
        onSelectSign: (s) => setState(() => _quickSign = s),
        onPersonal: () => setState(() => _quickSign = null),
        onDiscuss: () {
          if (_quickSign == null && chart != null && report != null) {
            _handoffHoroscopeToOracle(chart, report);
          } else if (sign != null && forecast != null) {
            _handoffZodiacToOracle(sign, forecast);
          }
        },
      ),
    );
  }

  Widget _buildSynastryWindow(AstralController astral) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      child: SynastryWindow(
        a: astral.activeProfile,
        b: _otherProfile(astral),
        onDiscuss: widget.onOpenOracle,
      ),
    );
  }
}

/// The `[ NATAL CHART | HOROSCOPE ]` two-segment window switcher.
class _AstralWindowSwitcher extends StatelessWidget {
  const _AstralWindowSwitcher({required this.window, required this.onChanged});

  final AstralWindow window;
  final ValueChanged<AstralWindow> onChanged;

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppSettingsController>().language;
    final labels = {
      AstralWindow.natalChart: AppStrings.t(lang, 'astral.natal'),
      AstralWindow.horoscope: AppStrings.t(lang, 'astral.horoscope'),
      AstralWindow.synastry: AppStrings.t(lang, 'astral.synastry'),
    };
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          for (final w in AstralWindow.values)
            Expanded(
              child: GestureDetector(
                key: ValueKey('astral-window-${w.name}'),
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(w),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: window == w
                        ? AppColors.lavender.withValues(alpha: 0.16)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      labels[w]!,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w700,
                        color: window == w
                            ? AppColors.lavender
                            : AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

