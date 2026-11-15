import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'features/shell/main_navigation_shell.dart';
import 'state/spread_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MindreaderApp());
}

class MindreaderApp extends StatelessWidget {
  const MindreaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SpreadController(),
      child: MaterialApp(
        title: 'mindreader.quest',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const MainNavigationShell(),
      ),
    );
  }
}
