import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/core/services/oracle_voice_service.dart';
import 'package:mindreader/core/services/pwa_install_service.dart';
import 'package:mindreader/core/services/telegram_webapp_service.dart';
import 'package:mindreader/features/camera_scan/camera_scan_screen.dart';
import 'package:mindreader/features/shell/widgets/pwa_install_banner.dart';
import 'package:mindreader/state/app_settings_controller.dart';
import 'package:mindreader/state/daily_quota_controller.dart';
import 'package:mindreader/state/live_oracle_controller.dart';
import 'package:mindreader/state/live_reading_controller.dart';
import 'package:mindreader/state/oracle_session_controller.dart';
import 'package:mindreader/state/spread_controller.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Web/PWA Camera tab shows photo capture stage without MOCK MODE', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AppSettingsController()),
          ChangeNotifierProvider(create: (_) => SpreadController()),
          ChangeNotifierProvider(create: (_) => OracleSessionController()),
          ChangeNotifierProvider(create: (_) => OracleVoiceService()),
          ChangeNotifierProvider(create: (_) => LiveReadingController()),
          ChangeNotifierProvider(create: (_) => LiveOracleController()),
          ChangeNotifierProvider(create: (_) => DailyQuotaController()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: CameraScanScreen(
              onHandoff: () {},
              webCaptureModeOverride: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('camera-web-capture-stage')), findsOneWidget);
    expect(find.byKey(const ValueKey('camera-web-take-photo')), findsOneWidget);
    expect(find.byKey(const ValueKey('camera-web-choose-gallery')), findsOneWidget);
    expect(find.textContaining('MOCK MODE'), findsNothing);
  });

  testWidgets('PwaInstallBanner renders native CTA and persists dismissal', (
    tester,
  ) async {
    var installed = false;
    var dismissed = false;

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppSettingsController(),
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: PwaInstallBanner(
                mode: PwaInstallMode.nativePrompt,
                onInstall: () => installed = true,
                onDismiss: () => dismissed = true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('pwa-install-banner')), findsOneWidget);
    expect(find.byKey(const ValueKey('pwa-install-cta')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('pwa-install-cta')));
    expect(installed, isTrue);

    await tester.tap(find.byKey(const ValueKey('pwa-install-later')));
    expect(dismissed, isTrue);

    expect(await PwaInstallBanner.isDismissed(), isFalse);
    await PwaInstallBanner.markDismissed();
    expect(await PwaInstallBanner.isDismissed(), isTrue);
  });

  testWidgets('PwaInstallBanner renders iOS manual hint without native install CTA', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppSettingsController(),
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: PwaInstallBanner(
                mode: PwaInstallMode.iosManualHint,
                onInstall: () {},
                onDismiss: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('pwa-install-banner')), findsOneWidget);
    expect(find.byKey(const ValueKey('pwa-install-cta')), findsNothing);
    expect(find.byIcon(Icons.ios_share_rounded), findsOneWidget);
  });

  test('tabIndexForStartParam maps Telegram Mini App deep links to shell tabs', () {
    expect(tabIndexForStartParam('camera'), 0);
    expect(tabIndexForStartParam('scan'), 0);
    expect(tabIndexForStartParam('table'), 1);
    expect(tabIndexForStartParam('almanac'), 2);
    expect(tabIndexForStartParam('astral'), 3);
    expect(tabIndexForStartParam('daily'), 4);
    expect(tabIndexForStartParam('lunar'), 4);
    expect(tabIndexForStartParam('checkin'), 4);
    expect(tabIndexForStartParam(''), isNull);
    expect(tabIndexForStartParam('unknown'), isNull);
  });
}
