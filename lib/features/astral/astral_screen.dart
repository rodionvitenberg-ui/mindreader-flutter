import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/models/natal_chart.dart';
import '../../core/models/oracle_handoff.dart';
import '../../core/models/zodiac_forecast.dart';
import '../../core/services/local_storage_service.dart';
import '../../core/services/natal_calculator_service.dart';
import '../../core/services/oracle_synthesis_service.dart';
import '../../core/services/transit_forecast_service.dart';
import '../../design_system/taro.dart';
import '../../state/app_settings_controller.dart';
import '../../state/astral_controller.dart';
import '../profile/widgets/profile_header.dart';
import 'natal_profile_detail_sheet.dart';
import 'astral_copy.dart';
import 'widgets/synastry_window.dart';
import 'widgets/astral_cosmic_bar.dart';
import 'widgets/astral_gradient_button.dart';
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
  const AstralScreen({
    super.key,
    this.onOpenOracle,
    this.browseZodiacSign,
    this.isActive = true,
  });

  final bool isActive;

  /// Shell callback: hands a natal, horoscope or synastry reading to the
  /// Oracle Chat pane (Table tab) and switches the tab.
  final ValueChanged<OracleHandoff>? onOpenOracle;

  /// Shell signal: the Almanac asks ASTRAL to open the Horoscope window for
  /// a specific zodiac sign.
  final ValueNotifier<ZodiacSign?>? browseZodiacSign;

  @override
  State<AstralScreen> createState() => _AstralScreenState();
}

class _AstralScreenState extends State<AstralScreen>
    with WidgetsBindingObserver {
  final LocalStorageService _storage = LocalStorageService();
  DateTime _now = DateTime.now();
  Timer? _midnight;
  bool _showWeek = false;
  int _dayOffset = 0;
  NatalChart? _forecastChart;
  final _reports = <int, DailyHoroscopeReport>{};

  DateTime get _today => DateTime(_now.year, _now.month, _now.day);
  DateTime _dayAt(int offset) =>
      DateTime(_today.year, _today.month, _today.day + offset);

  void _scheduleRefresh() {
    _midnight?.cancel();
    if (!widget.isActive) return;
    final tomorrow = _dayAt(1);
    _midnight = Timer(
      tomorrow.difference(DateTime.now()).isNegative
          ? Duration.zero
          : tomorrow.difference(DateTime.now()),
      _refreshSky,
    );
  }

  void _refreshSky() {
    if (!mounted || !widget.isActive) return;
    final now = DateTime.now();
    if (DateTime(now.year, now.month, now.day) != _today) {
      _reports.clear();
      _dayOffset = 0;
    }
    setState(() => _now = now);
    _scheduleRefresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshSky();
  }

  DailyHoroscopeReport _reportFor(NatalChart chart, int offset) {
    if (_forecastChart != chart) {
      _forecastChart = chart;
      _reports.clear();
    }
    return _reports.putIfAbsent(
      offset,
      () => TransitForecastService.forDay(chart, _dayAt(offset)),
    );
  }

  int _streak = 0;

  AstralWindow _window = AstralWindow.natalChart;
  AstralWindow? _animatingToWindow;

  late final PageController _windowController = PageController();

  /// Quick-sign browse state: null = the personal (natal) horoscope.
  ZodiacSign? _quickSign;

  /// The sign to show when no natal profile exists yet — the current Sun.
  ZodiacSign get _defaultSign => ZodiacSignX.fromLongitude(
    NatalCalculatorService.computeEclipticLongitude(PlanetId.sun, _now.toUtc()),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleRefresh();
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
    if (oldWidget.isActive != widget.isActive) {
      if (widget.isActive) {
        _refreshSky();
      } else {
        _midnight?.cancel();
      }
    }
    if (oldWidget.browseZodiacSign != widget.browseZodiacSign) {
      oldWidget.browseZodiacSign?.removeListener(_onBrowseSign);
      widget.browseZodiacSign?.addListener(_onBrowseSign);
    }
  }

  @override
  void dispose() {
    widget.browseZodiacSign?.removeListener(_onBrowseSign);
    WidgetsBinding.instance.removeObserver(this);
    _midnight?.cancel();
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

  Future<NatalChart?> _openNewChart() async {
    final astral = context.read<AstralController>();
    if (astral.canCreateOrGenerateChart()) {
      return BirthDataFormSheet.show(context);
    } else {
      await AstralProPaywallSheet.show(context);
      return null;
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
    final horoscope = NatalCalculatorService.computeDailyHoroscope(
      chart,
      forDate: _now,
    );
    onOpenOracle(
      OracleHandoff(
        prompt: OracleSynthesisService.buildNatalPrompt(chart, horoscope),
        kind: OracleHandoffKind.natalChart,
        chart: chart,
        horoscope: horoscope,
      ),
    );
  }

  void _handoffHoroscopeToOracle(
    NatalChart chart,
    DailyHoroscopeReport report,
    DailyTransitItem? transit,
  ) {
    final onOpenOracle = widget.onOpenOracle;
    if (onOpenOracle == null) return;
    onOpenOracle(
      OracleHandoff(
        prompt: OracleSynthesisService.buildHoroscopePrompt(
          chart,
          report,
          transit: transit,
        ),
        kind: OracleHandoffKind.horoscope,
        chart: chart,
        horoscope: report,
        transit: transit,
      ),
    );
  }

  void _handoffZodiacToOracle(ZodiacSign sign, ZodiacSignForecast forecast) {
    final onOpenOracle = widget.onOpenOracle;
    if (onOpenOracle == null) return;
    onOpenOracle(
      OracleHandoff(
        prompt: OracleSynthesisService.buildZodiacForecastPrompt(
          sign,
          forecast,
        ),
        kind: OracleHandoffKind.zodiac,
        zodiacSign: sign,
        zodiacForecast: forecast,
      ),
    );
  }

  void _selectWindow(AstralWindow w) {
    if (_window == w && _animatingToWindow == null) return;
    HapticFeedback.selectionClick();
    setState(() {
      _window = w;
      _animatingToWindow = w;
    });
    if (_windowController.hasClients) {
      _windowController
          .animateToPage(
            w.index,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
          )
          .whenComplete(() {
            if (mounted && _animatingToWindow == w) {
              _animatingToWindow = null;
            }
          });
    } else {
      _animatingToWindow = null;
    }
  }

  void _openSynastry(AstralController astral) {
    if (astral.profiles.length < 2) return;
    _selectWindow(AstralWindow.synastry);
  }

  @override
  Widget build(BuildContext context) {
    final astral = context.watch<AstralController>();
    final chart = astral.activeProfile;
    // Keep the cached daily report available across swipes so the Horoscope
    // window never flashes an empty fallback while sliding into view.
    final report = widget.isActive && chart != null && _quickSign == null
        ? _reportFor(chart, _showWeek ? _dayOffset : 0)
        : null;
    // Quick-sign mode: an explicit sign wins; without a chart the current
    // Sun's sign keeps the Horoscope window populated.
    final sign = _quickSign ?? (chart == null ? _defaultSign : null);
    final forecast = sign == null
        ? null
        : NatalCalculatorService.computeZodiacSignForecast(
            sign,
            forDate: _now.toUtc(),
          );
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ProfileHeader(
              child: AstralCosmicBar(
                phase: NatalCalculatorService.computeMoonPhase(_now.toUtc()),
                streak: _streak,
              ),
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
                  TaroGlassLayer(
                    child: _AstralWindowSwitcher(
                      window: _window,
                      onChanged: _selectWindow,
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _windowController,
                onPageChanged: (i) {
                  final next = AstralWindow.values[i];
                  if (_animatingToWindow != null && next != _animatingToWindow) {
                    return;
                  }
                  _animatingToWindow = null;
                  if (_window != next) {
                    setState(() => _window = next);
                  }
                },
                children: [
                  RepaintBoundary(child: _buildNatalWindow(astral, chart)),
                  RepaintBoundary(
                    child: _buildHoroscopeWindow(chart, report, sign, forecast),
                  ),
                  RepaintBoundary(child: _buildSynastryWindow(astral)),
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
      key: const PageStorageKey<String>('astral-natal-scroll'),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (chart == null)
            const AstralWheelPlaceholder(chart: null)
          else
            NatalWheelWidget(chart: chart, now: _now),
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
              label: context.astralRussian
                  ? context.astralText('discuss')
                  : AppStrings.g('astral.discussNatal'),
              onTap: () => _handoffNatalToOracle(chart),
            ),
            if (astral.profiles.length >= 2) ...[
              const SizedBox(height: 10),
              AstralGradientButton(
                label: AppStrings.g('ui.astral_astral_screen.compare_2_profiles_synastry'),
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
      key: const PageStorageKey<String>('astral-horoscope-scroll'),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      child: HoroscopeWindow(
        chart: chart,
        report: report,
        selectedSign: chart == null ? sign : _quickSign,
        forecast: forecast,
        days: [for (var i = 0; i < 7; i++) _dayAt(i)],
        showWeek: _showWeek,
        selectedDay: _dayOffset,
        onToggleWeek: (value) => setState(() => _showWeek = value),
        onSelectDay: (value) => setState(() => _dayOffset = value),
        onSelectSign: (s) => setState(() => _quickSign = s),
        onPersonal: () => setState(() => _quickSign = null),
        onDiscuss: (transit) {
          if (_quickSign == null && chart != null && report != null) {
            _handoffHoroscopeToOracle(chart, report, transit);
          } else if (sign != null && forecast != null) {
            _handoffZodiacToOracle(sign, forecast);
          }
        },
      ),
    );
  }

  Widget _buildSynastryWindow(AstralController astral) {
    return SingleChildScrollView(
      key: const PageStorageKey<String>('astral-synastry-scroll'),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      child: SynastryPairPicker(
        profiles: astral.profiles,
        active: astral.activeProfile,
        onAdd: _openNewChart,
        onDiscuss: widget.onOpenOracle,
      ),
    );
  }
}

/// The `[ NATAL CHART | HOROSCOPE | SYNASTRY ]` window switcher (Phase G5:
/// migrated to [TaroGlassSegmentedControl]).
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
    return TaroGlassSegmentedControl<AstralWindow>(
      segments: [
        for (final w in AstralWindow.values)
          TaroGlassSegment<AstralWindow>(
            key: ValueKey('astral-window-${w.name}'),
            value: w,
            label: labels[w]!,
          ),
      ],
      value: window,
      onChanged: onChanged,
    );
  }
}
