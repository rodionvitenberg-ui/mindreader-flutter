import 'dart:async';

import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:provider/provider.dart';

import 'core/config/app_flags.dart';
import 'core/services/oracle_voice_service.dart';
import 'core/theme/app_theme.dart';
import 'design_system/taro.dart';
import 'features/shell/main_navigation_shell.dart';
import 'state/app_settings_controller.dart';
import 'state/astral_controller.dart';
import 'state/deck_pack_controller.dart';
import 'state/live_reading_controller.dart';
import 'state/live_oracle_controller.dart';
import 'state/oracle_session_controller.dart';
import 'state/session_history_controller.dart';
import 'state/spread_controller.dart';
import 'state/user_profile_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MindreaderApp());
  // Прогрев шейдеров liquid glass в фоне, не блокируя первый кадр.
  if (kTarotTreeThemeEnabled) {
    unawaited(LiquidGlass.precache());
  }
}

class MindreaderApp extends StatelessWidget {
  const MindreaderApp({
    super.key,
    this.tarotTreeEnabled = kTarotTreeThemeEnabled,
  });

  /// Feature-flag gate for Tarot Tree (Phase G2+). Defaults to
  /// [kTarotTreeThemeEnabled]; overridable in tests to verify rollback.
  final bool tarotTreeEnabled;

  @override
  Widget build(BuildContext context) {
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
      child: MaterialApp(
        title: 'mindreader.quest',
        debugShowCheckedModeBanner: false,
        theme: tarotTreeEnabled ? buildTaroTheme() : buildAppTheme(),
        home: MainNavigationShell(tarotTreeEnabled: tarotTreeEnabled),
      ),
    );
  }
}
