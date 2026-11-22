import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:provider/provider.dart';

import 'core/services/oracle_voice_service.dart';
import 'design_system/taro.dart';
import 'features/shell/main_navigation_shell.dart';
import 'state/app_settings_controller.dart';
import 'state/astral_controller.dart';
import 'state/deck_pack_controller.dart';
import 'state/live_oracle_controller.dart';
import 'state/live_reading_controller.dart';
import 'state/oracle_session_controller.dart';
import 'state/session_history_controller.dart';
import 'state/spread_controller.dart';
import 'state/user_profile_controller.dart';

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
    this.preloaderLogo,
    this.shaderPrecache,
    this.preloaderReady,
    this.onPreloaderCompleted,
  });

  /// При `null` прелоадер включается автоматически в реальном приложении
  /// (`WidgetsFlutterBinding`) и не мешает существующим `testWidgets`-тестам,
  /// если тест не передал `showPreloader: true` явно.
  final bool? showPreloader;
  final ui.Image? preloaderLogo;
  final Future<void>? shaderPrecache;
  final Future<void>? preloaderReady;
  final VoidCallback? onPreloaderCompleted;

  @override
  Widget build(BuildContext context) {
    final enablePreloader =
        showPreloader ?? (WidgetsBinding.instance is WidgetsFlutterBinding);

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
        // The Guided Physical Spread process (FSM). Holds NO cards — those
        // stay in SpreadController; this only orchestrates the interaction.
        ChangeNotifierProvider(create: (_) => LiveReadingController()),
        // The Live Oracle FREEFORM session state (intention + last requested
        // action). Holds NO cards and NO dialogue — those stay in
        // SpreadController / OracleSessionController respectively.
        ChangeNotifierProvider(create: (_) => LiveOracleController()),
        ChangeNotifierProvider(create: (_) => DeckPackController()),
        ChangeNotifierProvider(create: (_) => AstralController()),
        ChangeNotifierProvider(create: (_) => AppSettingsController()),
        // One writer for the reading archive: the Table mutates it and the
        // ProfileScreen reads it for the device-migration backup.
        ChangeNotifierProvider(
          create: (_) => SessionHistoryController()..load(),
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
    required this.preloaderLogo,
    required this.shaderPrecache,
    required this.preloaderReady,
    required this.onPreloaderCompleted,
  });

  final bool enablePreloader;
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
    if (_preloaderActive) {
      _warmupFuture = widget.preloaderReady ?? _collectStartupWarmup();
    }
  }

  /// Собирает все реальные асинхронные задачи старта приложения, чтобы
  /// прелоадер держался ровно столько, сколько реально инициализируется экран.
  Future<void> _collectStartupWarmup() {
    final tasks = <Future<void>>[
      if (widget.shaderPrecache != null) widget.shaderPrecache!,
      TaroGlassCapability.whenResolved,
      context.read<AppSettingsController>().initialLoad,
      context.read<DeckPackController>().initialLoad,
      context.read<SessionHistoryController>().initialLoad,
      context.read<UserProfileController>().initialLoad,
    ];
    return Future.wait(tasks).then((_) {}, onError: (Object _) {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'mindreader.quest',
      debugShowCheckedModeBanner: false,
      theme: buildTaroTheme(),
      builder: (context, child) {
        final content = child ?? const SizedBox.shrink();
        if (!_preloaderActive) return content;
        return Stack(
          fit: StackFit.expand,
          children: [
            content,
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
