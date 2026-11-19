import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'features/shell/main_navigation_shell.dart';
import 'state/app_settings_controller.dart';
import 'state/astral_controller.dart';
import 'state/deck_pack_controller.dart';
import 'state/live_reading_controller.dart';
import 'state/oracle_session_controller.dart';
import 'state/session_history_controller.dart';
import 'state/spread_controller.dart';
import 'state/user_profile_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MindreaderApp());
}

class MindreaderApp extends StatelessWidget {
  const MindreaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SpreadController()),
        // One Oracle dialogue for the WHOLE app: the Camera, the Digital
        // Table and the Oracle Chat share this single session source of
        // truth (stable sessionId + source/mode/status + messages).
        ChangeNotifierProvider(create: (_) => OracleSessionController()),
        // The Guided Physical Spread process (FSM). Holds NO cards — those
        // stay in SpreadController; this only orchestrates the interaction.
        ChangeNotifierProvider(create: (_) => LiveReadingController()),
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
        theme: buildAppTheme(),
        home: const MainNavigationShell(),
      ),
    );
  }
}
