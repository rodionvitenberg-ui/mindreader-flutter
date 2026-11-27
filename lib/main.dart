import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:provider/provider.dart';

import 'core/services/backend_auth_service.dart';
import 'core/services/billing/store_iap_service.dart';
import 'core/services/oracle_synthesis_service.dart';
import 'core/services/oracle_voice_service.dart';
import 'core/services/ritual_notification_service.dart';
import 'core/services/voice/cloud_transcription_service.dart';
import 'design_system/taro.dart';
import 'features/onboarding/onboarding_flow.dart';
import 'features/shell/main_navigation_shell.dart';
import 'state/app_settings_controller.dart';
import 'state/astral_controller.dart';
import 'state/backend_auth_controller.dart';
import 'state/daily_quota_controller.dart';
import 'state/daily_ritual_controller.dart';
import 'state/deck_pack_controller.dart';
import 'state/guided_reading_controller.dart';
import 'state/live_oracle_controller.dart';
import 'state/live_reading_controller.dart';
import 'state/onboarding_controller.dart';
import 'state/oracle_session_controller.dart';
import 'state/session_history_controller.dart';
import 'state/spread_controller.dart';
import 'state/store_controller.dart';
import 'state/training_controller.dart';
import 'state/user_profile_controller.dart';
import 'state/voice_input_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Преддекодируем логотип (~10 КБ) до первого кадра, чтобы переход с
  // нативного сплэша на Flutter-прелоадер прошёл без единого чёрного кадра.
  final preloaderLogo = await TaroPreloader.decodeLogoAsset();
  // На Apple (Metal) прогреваем шейдеры liquid glass сразу. На Android не
  // компилируем Flutter GPU-шейдеры до завершения TaroGlassCapability, чтобы
  // OpenGLES-устройства не тратили GPU и память на неподдерживаемое стекло.
  final isApple = !kIsWeb && (Platform.isIOS || Platform.isMacOS);
  final shaderPrecache = isApple
      ? LiquidGlass.precache().catchError((Object _) {})
      : null;
  runApp(
    MindreaderApp(
      preloaderLogo: preloaderLogo,
      shaderPrecache: shaderPrecache,
    ),
  );
}

class MindreaderApp extends StatelessWidget {
  const MindreaderApp({
    super.key,
    this.showPreloader,
    this.showOnboarding,
    this.preloaderLogo,
    this.shaderPrecache,
    this.preloaderReady,
    this.onPreloaderCompleted,
    this.voiceInput,
  });

  /// При `null` прелоадер включается автоматически в реальном приложении
  /// (`WidgetsFlutterBinding`) и не мешает существующим `testWidgets`-тестам,
  /// если тест не передал `showPreloader: true` явно.
  final bool? showPreloader;

  /// При `null` интро (G3) показывается только в реальном приложении — тем же
  /// правилом, что и прелоадер, — чтобы существующие `testWidgets`-тесты не
  /// получали внезапный полноэкранный оверлей. Тест включает его явно.
  final bool? showOnboarding;
  final ui.Image? preloaderLogo;
  final Future<void>? shaderPrecache;
  final Future<void>? preloaderReady;
  final VoidCallback? onPreloaderCompleted;
  final VoiceInputController? voiceInput;

  @override
  Widget build(BuildContext context) {
    final enablePreloader =
        showPreloader ?? (WidgetsBinding.instance is WidgetsFlutterBinding);
    final enableOnboarding =
        showOnboarding ?? (WidgetsBinding.instance is WidgetsFlutterBinding);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SpreadController()),
        // One Oracle dialogue for the WHOLE app: the Camera, the Digital
        // Table and the Oracle Chat share this single session source of
        // truth (stable sessionId + source/mode/status + messages).
        ChangeNotifierProvider(create: (_) => OracleSessionController()),
        // The Oracle voice (TTS) — one shared instance; lazily initialized on
        // first use. Swappable engine behind the TtsEngine seam.
        ChangeNotifierProvider(create: (_) => OracleVoiceService()),
        // Language-independent voice input (native audio capture + cloud AI
        // transcription with auto language detection and punctuation).
        if (voiceInput != null)
          ChangeNotifierProvider<VoiceInputController>.value(
            value: voiceInput!,
          )
        else
          ChangeNotifierProvider(create: (_) => VoiceInputController()),
        // The Guided Physical Spread process (FSM). Holds NO cards — those
        // stay in SpreadController; this only orchestrates the interaction.
        ChangeNotifierProvider(create: (_) => LiveReadingController()),
        // The Live Oracle FREEFORM session state (intention + last requested
        // action). Holds NO cards and NO dialogue — those stay in
        // SpreadController / OracleSessionController respectively.
        ChangeNotifierProvider(create: (_) => LiveOracleController()),
        ChangeNotifierProvider(create: (_) => DeckPackController()),
        ChangeNotifierProvider(create: (_) => BackendAuthController()),
        Provider<StoreIapService>(
          create: (_) => const UnconfiguredStoreIapService(),
        ),
        Provider<EntitlementsService>(
          create: (_) => EntitlementsService(),
        ),
        ChangeNotifierProvider(
          create: (context) => StoreController(
            auth: context.read<BackendAuthController>(),
            deckPacks: context.read<DeckPackController>(),
          ),
        ),
        ChangeNotifierProvider(create: (_) => AstralController()),
        ChangeNotifierProvider(create: (_) => AppSettingsController()),
        // G3 — the one-time guided-reading intro; seeds the detail level.
        ChangeNotifierProvider(
          create: (context) => OnboardingController(
            settings: context.read<AppSettingsController>(),
          ),
        ),
        // The educational mentor: a pure observer of the table + settings that
        // derives the single most relevant hint (never mutates cards).
        ChangeNotifierProvider(
          create: (context) => GuidedReadingController(
            spread: context.read<SpreadController>(),
            settings: context.read<AppSettingsController>(),
          ),
        ),
        // One writer for the reading archive: the Table mutates it and the
        // ProfileScreen reads it for the device-migration backup.
        ChangeNotifierProvider(
          create: (_) => SessionHistoryController()..load(),
        ),
        ChangeNotifierProvider(
          create: (_) => DailyQuotaController()..load(),
        ),
        ChangeNotifierProvider(
          create: (_) => DailyRitualController()..load(),
        ),
        ChangeNotifierProvider(
          create: (_) => TrainingController()..load(),
        ),
        ChangeNotifierProvider(
          create: (context) => UserProfileController(
            history: context.read<SessionHistoryController>(),
            astral: context.read<AstralController>(),
          )..load(),
        ),
      ],
      child: _AppRoot(
        enablePreloader: enablePreloader,
        enableOnboarding: enableOnboarding,
        preloaderLogo: preloaderLogo,
        shaderPrecache: shaderPrecache,
        preloaderReady: preloaderReady,
        onPreloaderCompleted: onPreloaderCompleted,
      ),
    );
  }
}

class _AppRoot extends StatefulWidget {
  const _AppRoot({
    required this.enablePreloader,
    required this.enableOnboarding,
    required this.preloaderLogo,
    required this.shaderPrecache,
    required this.preloaderReady,
    required this.onPreloaderCompleted,
  });

  final bool enablePreloader;
  final bool enableOnboarding;
  final ui.Image? preloaderLogo;
  final Future<void>? shaderPrecache;
  final Future<void>? preloaderReady;
  final VoidCallback? onPreloaderCompleted;

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  late bool _preloaderActive = widget.enablePreloader;
  Future<void>? _warmupFuture;

  @override
  void initState() {
    super.initState();
    _wireBackendAiProxies();
    if (_preloaderActive) {
      _warmupFuture = widget.preloaderReady ?? _collectStartupWarmup();
    }
  }

  /// Wires Oracle LLM & Cloud STT to route through the Django backend proxy
  /// so zero AI API keys ever ship in the PWA/client bundle.
  void _wireBackendAiProxies() {
    if (!kIsWeb && Platform.environment['FLUTTER_TEST'] == 'true') return;
    final auth = context.read<BackendAuthController>();
    if (!auth.isConfigured) return;
    Future<(String?, String?)> resolveAuth() async {
      if (!auth.isConfigured) return (null, null);
      final token = await auth.ensureToken();
      if (token == null || token.isEmpty) return (null, null);
      return (BackendAuthService.defaultBackendUrl, token);
    }

    OracleSynthesisService.registerBackendAuth(resolveAuth);
    CloudTranscriptionService.registerBackendAuth(resolveAuth);
  }

  /// Собирает все реальные асинхронные задачи старта приложения, чтобы
  /// прелоадер держался ровно столько, сколько реально инициализируется экран.
  Future<void> _collectStartupWarmup() {
    final auth = context.read<BackendAuthController>();
    final settings = context.read<AppSettingsController>();
    final astral = context.read<AstralController>();
    final tasks = <Future<void>>[
      if (widget.shaderPrecache != null) widget.shaderPrecache!,
      TaroGlassCapability.whenResolved,
      settings.initialLoad,
      if (widget.enableOnboarding)
        context.read<OnboardingController>().initialLoad,
      context.read<DeckPackController>().initialLoad,
      context.read<DailyQuotaController>().initialLoad,
      auth.initialLoad.then((_) {
        if (auth.isVerified) {
          settings.setProUnlocked(auth.isPro);
          astral.setProUnlocked(auth.isPro);
          if (auth.isConfigured &&
              (kIsWeb || Platform.environment['FLUTTER_TEST'] != 'true')) {
            unawaited(
              auth.refreshProStatus().then((active) {
                settings.setProUnlocked(active);
                astral.setProUnlocked(active);
              }, onError: (Object _) {}),
            );
          }
        }
      }),
      context.read<StoreController>().initialLoad,
      context.read<SessionHistoryController>().initialLoad,
      context.read<DailyRitualController>().initialLoad,
      context.read<TrainingController>().initialLoad,
      context.read<UserProfileController>().initialLoad,
      RitualNotificationService.syncFromStorage(),
    ];
    return Future.wait(tasks).then((_) {}, onError: (Object _) {});
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = context.select<UserProfileController, SanctuaryThemeMode>(
      (profile) => profile.themeMode,
    );
    return MaterialApp(
      title: 'Tarot Tree',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const TaroScrollBehavior(),
      theme: buildTaroTheme(mode: themeMode),
      builder: (context, child) {
        final content = child ?? const SizedBox.shrink();
        if (!_preloaderActive && !widget.enableOnboarding) return content;
        return Stack(
          fit: StackFit.expand,
          children: [
            content,
            if (widget.enableOnboarding) const OnboardingFlow(),
            if (_preloaderActive)
              TaroPreloader(
                ready: _warmupFuture!,
                predecodedLogo: widget.preloaderLogo,
                onCompleted: () {
                  if (mounted) {
                    setState(() => _preloaderActive = false);
                  }
                  widget.onPreloaderCompleted?.call();
                },
              ),
          ],
        );
      },
      home: const MainNavigationShell(),
    );
  }
}
