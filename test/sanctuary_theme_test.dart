import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/core/l10n/app_strings.dart';
import 'package:mindreader/core/services/local_storage_service.dart';
import 'package:mindreader/design_system/taro.dart';
import 'package:mindreader/features/profile/profile_screen.dart';
import 'package:mindreader/main.dart';
import 'package:mindreader/state/app_settings_controller.dart';
import 'package:mindreader/state/user_profile_controller.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _DelayedStorage extends LocalStorageService {
  _DelayedStorage({this.savedTheme});

  final String? savedTheme;
  final Completer<void> writeGate = Completer<void>();
  String? lastWrittenTheme;

  @override
  Future<Map<String, dynamic>?> loadUserProfile() async => null;

  @override
  Future<void> saveUserProfile(Map<String, dynamic> json) async {}

  @override
  Future<String?> loadSanctuaryThemeMode() async => savedTheme;

  @override
  Future<void> saveSanctuaryThemeMode(String mode) async {
    await writeGate.future;
    lastWrittenTheme = mode;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Dual dark sanctuary theme tokens', () {
    test('twilight preserves original palette and moonlit exposes nocturnal tokens', () {
      final twilight = buildTaroTheme(mode: SanctuaryThemeMode.twilight);
      expect(twilight.scaffoldBackgroundColor, TaroColors.background);
      expect(twilight.colorScheme.surface, TaroColors.surface);
      final twilightPalette = twilight.extension<TaroPalette>()!;
      expect(twilightPalette.mode, SanctuaryThemeMode.twilight);
      expect(twilightPalette.isMoonlit, isFalse);

      final moonlit = buildTaroTheme(mode: SanctuaryThemeMode.moonlit);
      expect(moonlit.scaffoldBackgroundColor, const Color(0xFF06070B));
      expect(moonlit.colorScheme.surface, const Color(0xFF0B0D14));
      final moonlitPalette = moonlit.extension<TaroPalette>()!;
      expect(moonlitPalette.mode, SanctuaryThemeMode.moonlit);
      expect(moonlitPalette.isMoonlit, isTrue);
      expect(moonlitPalette.surface, const Color(0xFF0B0D14));
      expect(moonlitPalette.surfaceAlpha, closeTo(0.86, 0.001));
      expect(moonlitPalette.borderHairline.a, closeTo(0.22, 0.002));
      expect(moonlitPalette.borderHairline.r, closeTo(TaroColors.lavender.r, 0.001));
      expect(moonlitPalette.borderHairline.g, closeTo(TaroColors.lavender.g, 0.001));
      expect(moonlitPalette.borderHairline.b, closeTo(TaroColors.lavender.b, 0.001));
      expect(moonlitPalette.lanternGlow, const Color(0xFFF59E0B));
      expect(moonlitPalette.lanternAccent, const Color(0xFFFBBF24));
      expect(moonlitPalette.scrim, const Color(0xFF05060A));
      expect(moonlitPalette.scrimAlpha, closeTo(0.45, 0.001));

      final mid = twilightPalette.lerp(moonlitPalette, 0.5);
      expect(mid.mode, SanctuaryThemeMode.moonlit);
      expect(
        mid.surfaceAlpha,
        closeTo(
          (twilightPalette.surfaceAlpha + moonlitPalette.surfaceAlpha) / 2,
          0.001,
        ),
      );
      expect(twilightPalette.lerp(null, 0.5), same(twilightPalette));
    });

    test('maps twilight background assets to dedicated night variants', () {
      expect(
        TaroBackgroundAssets.nightVariantFor(TaroBackgroundAssets.forest),
        'assets/images/forest_night.webp',
      );
      expect(
        TaroBackgroundAssets.nightVariantFor(TaroBackgroundAssets.oak),
        'assets/images/oak_night.webp',
      );
      expect(TaroBackgroundAssets.nightVariantFor('other.webp'), isNull);
    });
  });

  group('UserProfileController UI-first theme persistence', () {
    test('updates memory and notifies synchronously before async storage completes', () async {
      final storage = _DelayedStorage();
      final ctrl = UserProfileController(storage: storage);
      expect(ctrl.themeMode, SanctuaryThemeMode.twilight);

      var notified = 0;
      ctrl.addListener(() => notified++);

      ctrl.setThemeMode(SanctuaryThemeMode.moonlit);

      // Synchronous UI-first update: state and listener fired before storage wrote.
      expect(ctrl.themeMode, SanctuaryThemeMode.moonlit);
      expect(notified, 1);
      expect(storage.lastWrittenTheme, isNull);

      storage.writeGate.complete();
      await Future<void>.delayed(Duration.zero);
      expect(storage.lastWrittenTheme, 'moonlit');
    });

    test('persists to LocalStorageService and restores on fresh controller', () async {
      final storage = LocalStorageService();
      final writer = UserProfileController(storage: storage);
      writer.setThemeMode(SanctuaryThemeMode.moonlit);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(await storage.loadSanctuaryThemeMode(), 'moonlit');

      final reader = UserProfileController(storage: storage);
      expect(reader.themeMode, SanctuaryThemeMode.twilight);
      await reader.load();
      expect(reader.themeMode, SanctuaryThemeMode.moonlit);

      // Backup export/import preserves themeMode.
      final backup = reader.exportAllUserDataJson();
      final imported = UserProfileController(storage: storage);
      expect(imported.importUserDataJson(backup), isTrue);
      expect(imported.themeMode, SanctuaryThemeMode.moonlit);
    });

    test('in-session setThemeMode is not overwritten by delayed load()', () async {
      final storage = _DelayedStorage(savedTheme: 'twilight');
      final ctrl = UserProfileController(storage: storage);
      final loading = ctrl.load();
      ctrl.setThemeMode(SanctuaryThemeMode.moonlit);
      await loading;
      expect(ctrl.themeMode, SanctuaryThemeMode.moonlit);
    });
  });

  group('TaroDuskBackground moonlit fallback', () {
    testWidgets('falls back to forest.webp with #05060A 0.45 nocturnal scrim', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTaroTheme(mode: SanctuaryThemeMode.moonlit),
          home: const Scaffold(
            body: TaroDuskBackground(imageAsset: TaroBackgroundAssets.forest),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scrimFinder = find.byKey(const ValueKey('moonlit-nocturnal-scrim'));
      expect(scrimFinder, findsOneWidget);
      final scrim = tester.widget<ColoredBox>(scrimFinder);
      expect(
        scrim.color,
        const Color(0xFF05060A).withValues(alpha: 0.45),
      );
    });
  });

  group('ProfileScreen theme switcher & l10n', () {
    test('all 6 languages define theme setting and both option labels', () {
      const keys = [
        'reading.theme',
        'reading.theme.twilight',
        'reading.theme.moonlit',
      ];
      for (final lang in AppLanguage.values) {
        for (final key in keys) {
          final value = AppStrings.t(lang, key);
          expect(value, isNot(equals(key)), reason: '$lang missing $key');
          expect(value.trim(), isNotEmpty, reason: '$lang empty $key');
        }
      }
    });

    testWidgets(
      'switching [🌘 TWILIGHT | 🏮 MOONLIT NIGHT] updates MaterialApp theme immediately without restart',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(const MindreaderApp());
        await tester.pump();

        expect(
          tester.widget<MaterialApp>(find.byType(MaterialApp))
              .theme
              ?.scaffoldBackgroundColor,
          TaroColors.background,
        );

        await tester.tap(find.byKey(const ValueKey('profile-avatar-button')));
        await tester.pumpAndSettle();

        final list = find.byKey(
          const PageStorageKey<String>('profile-tab-main-scroll'),
        );
        final scrollable = find
            .descendant(of: list, matching: find.byType(Scrollable))
            .first;

        final readingHeader = find.byKey(
          const ValueKey(SettingsSection.readingExperience),
        );
        await tester.scrollUntilVisible(
          readingHeader,
          200,
          scrollable: scrollable,
        );
        await tester.pumpAndSettle();

        if (find.byKey(const ValueKey('sanctuary-theme-switcher')).evaluate().isEmpty) {
          await tester.tap(readingHeader);
          await tester.pumpAndSettle();
        }

        final switcherFinder = find.byKey(
          const ValueKey('sanctuary-theme-switcher'),
        );
        await tester.scrollUntilVisible(
          switcherFinder,
          120,
          scrollable: scrollable,
        );
        await tester.pumpAndSettle();

        expect(find.text('🌘 TWILIGHT'), findsOneWidget);
        expect(find.text('🏮 MOONLIT NIGHT'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('theme-mode-moonlit')));
        await tester.pump();

        expect(
          tester.widget<MaterialApp>(find.byType(MaterialApp))
              .theme
              ?.scaffoldBackgroundColor,
          const Color(0xFF06070B),
        );
        expect(
          tester
              .widget<MaterialApp>(find.byType(MaterialApp))
              .theme
              ?.extension<TaroPalette>()
              ?.mode,
          SanctuaryThemeMode.moonlit,
        );

        // Switch back to Twilight immediately without restart.
        await tester.tap(find.byKey(const ValueKey('theme-mode-twilight')));
        await tester.pump();

        expect(
          tester.widget<MaterialApp>(find.byType(MaterialApp))
              .theme
              ?.scaffoldBackgroundColor,
          TaroColors.background,
        );

        // Verify all 6 languages render the expanded theme switcher on a narrow 320px viewport without overflow.
        tester.view.physicalSize = const Size(320, 700);
        await tester.pump();
        final settings = tester
            .element(find.byType(ProfileScreen))
            .read<AppSettingsController>();
        for (final lang in AppLanguage.values) {
          settings.setLanguage(lang);
          await tester.pump();
          expect(
            tester.takeException(),
            isNull,
            reason: 'Theme switcher overflow in $lang',
          );
        }
      },
    );
  });
}
