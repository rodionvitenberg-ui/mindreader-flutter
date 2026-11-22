import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mindreader/core/data/zodiac_almanac_data.dart';
import 'package:mindreader/core/l10n/app_strings.dart';
import 'package:mindreader/core/models/natal_chart.dart';
import 'package:mindreader/design_system/taro.dart';
import 'package:mindreader/features/almanac/widgets/zodiac_sky_planetarium.dart';

/// The zodiac sky atlas (commit 1197208) merged onto the localized Almanac.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a birth date maps onto the civil sign boundaries', () {
    expect(almanacBirthSign(DateTime(1990, 3, 21)), ZodiacSign.aries);
    expect(almanacBirthSign(DateTime(1990, 3, 20)), ZodiacSign.pisces);
    expect(almanacBirthSign(DateTime(1990, 12, 22)), ZodiacSign.capricorn);
    expect(almanacBirthSign(DateTime(1990, 12, 21)), ZodiacSign.sagittarius);
    expect(almanacBirthSign(DateTime(1990, 1, 1)), ZodiacSign.capricorn);
    expect(almanacBirthSign(DateTime(1990, 1, 20)), ZodiacSign.aquarius);
  });

  testWidgets('the atlas shows the sign chips and reports Explore', (
    tester,
  ) async {
    var explored = false;
    final changed = <ZodiacSign>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTaroTheme(),
        home: Scaffold(
          body: ZodiacSkyPlanetarium(
            sign: ZodiacSign.aries,
            header: const SizedBox(height: 8),
            language: AppLanguage.en,
            onChanged: changed.add,
            onExplore: () => explored = true,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.byKey(const ValueKey('zodiac-sign-aries')), findsOneWidget);
    expect(find.byKey(const ValueKey('zodiac-sign-taurus')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('zodiac-explore')));
    expect(explored, isTrue);

    // Choosing another sign is a request, never a silent mutation.
    await tester.tap(find.byKey(const ValueKey('zodiac-sign-taurus')));
    expect(changed, [ZodiacSign.taurus]);
  });
}
