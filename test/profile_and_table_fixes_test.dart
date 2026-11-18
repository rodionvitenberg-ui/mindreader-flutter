import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/core/data/tarot_deck_data.dart';
import 'package:mindreader/core/models/dealt_card_slot.dart';
import 'package:mindreader/core/models/divination_card.dart';
import 'package:mindreader/core/models/divination_system.dart';
import 'package:mindreader/core/models/natal_chart.dart';
import 'package:mindreader/core/services/natal_calculator_service.dart';
import 'package:mindreader/core/services/oracle_synthesis_service.dart';
import 'package:mindreader/features/digital_table/widgets/elemental_threads_painter.dart';
import 'package:mindreader/main.dart';
import 'package:mindreader/state/astral_controller.dart';
import 'package:mindreader/state/user_profile_controller.dart';

void main() {
  testWidgets('bottom dock exposes exactly 5 tabs incl. PROFILE',
      (tester) async {
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();

    expect(find.text('CAMERA'), findsOneWidget);
    expect(find.text('TABLE'), findsOneWidget);
    expect(find.text('ALMANAC'), findsOneWidget);
    expect(find.text('ASTRAL'), findsOneWidget);
    expect(find.text('PROFILE'), findsOneWidget);
    // Rituals / Settings are page content now, not dock actions.
    expect(find.text('RITUALS'), findsNothing);
    expect(find.text('SETTINGS'), findsNothing);
  });

  test('elemental threads render for TAROT only', () {
    expect(elementalThreadsVisibleFor(DivinationSystem.tarot), isTrue);
    expect(elementalThreadsVisibleFor(DivinationSystem.lenormand), isFalse);
    expect(elementalThreadsVisibleFor(DivinationSystem.runes), isFalse);
  });

  test('profile context is injected into the Oracle prompt only for self', () {
    final slot = DealtCardSlot(index: 0, role: 'Current State')
      ..placeCardFaceUp(TarotDivinationCard(tarotDeck.first), false);
    final slots = [slot];

    String synth(String? context) => synthesizeSpreadFor(
          slots,
          system: DivinationSystem.tarot,
          spreadLabel: 'Triad Flow',
          focusLine: 'past · present · future',
          profileContext: context,
        );

    expect(synth('Career crossroads, single parent'), contains('Career'));
    expect(synth(null), isNot(contains('Career crossroads')));
  });

  test('readingForSelf gates what the Oracle may see', () {
    final profile = _SilentProfile()
      ..setDisplayName('Ada')
      ..setPersonalBioContext('Between jobs, rebuilding trust.')
      ..setTargetPersonNote('My brother');

    expect(profile.readingForSelf, isTrue);
    expect(profile.oracleContext, contains('Between jobs'));

    profile.setReadingForSelf(false);
    expect(profile.oracleContext, contains('My brother'));
    expect(profile.oracleContext, isNot(contains('Between jobs')));
  });

  test('1-tap profile birth data feeds AstralController', () {
    final profile = _SilentProfile()
      ..setDisplayName('Ada')
      ..setBirthData(
        date: DateTime(1990, 4, 12),
        time: const TimeOfDay(hour: 8, minute: 30),
        cityName: 'Bishkek',
        latitude: 42.8746,
        longitude: 74.5698,
        timezoneOffset: 6,
      );
    expect(profile.hasBirthData, isTrue);

    final astral = AstralController();
    final utc = DateTime.utc(1990, 4, 12, 8, 30)
        .subtract(const Duration(hours: 6));
    final chart = NatalCalculatorService.calculateNatalChart(
      id: 'profile-fill-chart',
      profileName: profile.displayName,
      birthDateUtc: utc,
      birthLocalYear: 1990,
      birthLocalMonth: 4,
      birthLocalDay: 12,
      birthLocalHour: 8,
      birthLocalMinute: 30,
      timeKnown: true,
      cityName: profile.cityName,
      country: 'Kyrgyzstan',
      latitude: profile.latitude!,
      longitude: profile.longitude!,
      timezoneOffsetHours: profile.timezoneOffset!,
      houseSystem: HouseSystem.placidus,
    );

    expect(astral.generateChart(chart), AstralGenerateResult.generated);
    expect(astral.profiles.single.profileName, 'Ada');
    expect(astral.profiles.single.cityName, 'Bishkek');
  });
}

/// In-memory-only controller: the test never touches SharedPreferences.
class _SilentProfile extends UserProfileController {}
