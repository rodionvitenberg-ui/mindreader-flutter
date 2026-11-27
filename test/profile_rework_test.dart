import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/core/l10n/app_strings.dart';
import 'package:mindreader/design_system/taro.dart';
import 'package:mindreader/features/profile/profile_screen.dart';
import 'package:mindreader/features/profile/widgets/profile_legal_sheet.dart';
import 'package:mindreader/main.dart';
import 'package:mindreader/state/app_settings_controller.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> openProfile(
    WidgetTester tester, {
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('profile-avatar-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  test('all 6 languages define complete Profile tab, migration warning, and legal copy', () {
    const keys = [
      'profile.tab.profile',
      'profile.tab.dataAndLanguage',
      'profile.language.hint',
      'profile.signIn.emailButton',
      'profile.migration.warning',
      'profile.legal.termsTitle',
      'profile.legal.privacyTitle',
      'profile.legal.version',
      'profile.legal.updated',
      'profile.legal.terms.s1.title',
      'profile.legal.terms.s1.body',
      'profile.legal.terms.s2.title',
      'profile.legal.terms.s2.body',
      'profile.legal.terms.s3.title',
      'profile.legal.terms.s3.body',
      'profile.legal.terms.s4.title',
      'profile.legal.terms.s4.body',
      'profile.legal.terms.s5.title',
      'profile.legal.terms.s5.body',
      'profile.legal.privacy.s1.title',
      'profile.legal.privacy.s1.body',
      'profile.legal.privacy.s2.title',
      'profile.legal.privacy.s2.body',
      'profile.legal.privacy.s3.title',
      'profile.legal.privacy.s3.body',
      'profile.legal.privacy.s4.title',
      'profile.legal.privacy.s4.body',
      'profile.legal.privacy.s5.title',
      'profile.legal.privacy.s5.body',
    ];

    for (final lang in AppLanguage.values) {
      for (final key in keys) {
        final value = AppStrings.t(lang, key, {'version': kProfileAppVersion});
        expect(value, isNot(equals(key)), reason: '$lang missing $key');
        expect(value.trim(), isNotEmpty, reason: '$lang empty $key');
      }
    }
  });

  testWidgets(
    'ProfileScreen syncs [PROFILE | DATA & LANGUAGE] switcher with horizontal swipe and removes duplicate Google button',
    (tester) async {
      await openProfile(tester, size: const Size(390, 900));

      final switcher = find.byKey(const ValueKey('profile-tab-switcher'));
      expect(
        tester.widget<TaroGlassSegmentedControl<ProfileTab>>(switcher).value,
        ProfileTab.profile,
      );

      // Tab 1 has Email Sign-In & PRO (no fake local-only Google button).
      expect(find.byKey(const ValueKey('profile-signin-google')), findsNothing);
      expect(find.byKey(const ValueKey('profile-signin-email')), findsOneWidget);
      expect(find.text('PRO MONTHLY'), findsOneWidget);
      expect(find.text('PRO ANNUAL'), findsOneWidget);

      // Swipe left -> switches to Tab 2 (DATA & LANGUAGE).
      await tester.drag(
        find.byKey(const ValueKey('profile-page-view')),
        const Offset(-320, 0),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<TaroGlassSegmentedControl<ProfileTab>>(switcher).value,
        ProfileTab.dataAndLanguage,
      );

      // Tab 2 shows Language, Account & Cloud Library (without duplicate Google),
      // and Device Migration with encrypted snapshot warning.
      expect(find.byKey(const ValueKey('language-en')), findsOneWidget);
      expect(find.byKey(const ValueKey('language-ru')), findsOneWidget);
      expect(find.byKey(const ValueKey('language-es')), findsOneWidget);
      expect(find.byKey(const ValueKey('language-pt')), findsOneWidget);
      expect(find.byKey(const ValueKey('language-de')), findsOneWidget);
      expect(find.byKey(const ValueKey('language-fr')), findsOneWidget);
      expect(find.byKey(const ValueKey('profile-account-login')), findsOneWidget);
      expect(find.byKey(const ValueKey('profile-account-register')), findsOneWidget);
      expect(find.byKey(const ValueKey('profile-account-google')), findsNothing);
      expect(find.byKey(const ValueKey('profile-migration-warning')), findsOneWidget);

      // Swipe right -> returns to Tab 1 (PROFILE).
      await tester.drag(
        find.byKey(const ValueKey('profile-page-view')),
        const Offset(320, 0),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<TaroGlassSegmentedControl<ProfileTab>>(switcher).value,
        ProfileTab.profile,
      );
    },
  );

  testWidgets(
    'Legal footer displays app version and opens Terms of Use & Privacy Policy sheets',
    (tester) async {
      await openProfile(tester, size: const Size(390, 844));

      final list = find.byKey(const PageStorageKey<String>('profile-tab-main-scroll'));
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('profile-app-version')),
        240,
        scrollable: find
            .descendant(of: list, matching: find.byType(Scrollable))
            .first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Tarot Tree · v$kProfileAppVersion'), findsOneWidget);

      // Open Terms of Use sheet.
      await tester.tap(find.byKey(const ValueKey('profile-terms-link')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('profile-legal-sheet-terms')),
        findsOneWidget,
      );
      expect(find.textContaining('Tarot Tree provides Tarot'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('profile-legal-done')));
      await tester.pumpAndSettle();

      // Open Privacy Policy sheet.
      await tester.tap(find.byKey(const ValueKey('profile-privacy-link')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('profile-legal-sheet-privacy')),
        findsOneWidget,
      );
      expect(find.textContaining('downscaled JPEG image'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('profile-legal-done')));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'Narrow 320px viewport renders both Profile tabs without overflow in all 6 languages',
    (tester) async {
      await openProfile(tester, size: const Size(320, 650));
      final settings = tester
          .element(find.byType(ProfileScreen))
          .read<AppSettingsController>();

      for (final lang in AppLanguage.values) {
        settings.setLanguage(lang);
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'Tab 1 overflow in $lang');

        await tester.tap(find.byKey(const ValueKey('profile-tab-data')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(tester.takeException(), isNull, reason: 'Tab 2 overflow in $lang');

        await tester.tap(find.byKey(const ValueKey('profile-tab-profile')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
      }
    },
  );
}
