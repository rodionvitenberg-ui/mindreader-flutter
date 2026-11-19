import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/core/models/natal_chart.dart';
import 'package:mindreader/core/services/local_storage_service.dart';
import 'package:mindreader/core/services/natal_calculator_service.dart';
import 'package:mindreader/features/astral/astral_screen.dart';
import 'package:mindreader/main.dart';
import 'package:mindreader/state/astral_controller.dart';

/// ASTRAL Phase 2 — the 2-profile free tier, the PRO gate, instant
/// house-system switching and the 4th nav tab.
///
/// The controller tests use a hermetic fake store so nothing touches
/// `SharedPreferences` and the assertions stay deterministic.

class _FakeStorage extends LocalStorageService {
  List<Map<String, dynamic>> profiles = const [];
  int totalCharts = 0;
  bool proUnlocked = false;
  int activeIndex = 0;
  String? houseSystem;

  @override
  Future<List<Map<String, dynamic>>> loadAstralProfiles() async => profiles;

  @override
  Future<void> saveAstralProfiles(List<Map<String, dynamic>> value) async {
    profiles = value;
  }

  @override
  Future<int> loadAstralTotalChartsGenerated() async => totalCharts;

  @override
  Future<void> saveAstralTotalChartsGenerated(int count) async {
    totalCharts = count;
  }

  @override
  Future<bool> loadAstralProUnlocked() async => proUnlocked;

  @override
  Future<void> saveAstralProUnlocked(bool unlocked) async {
    proUnlocked = unlocked;
  }

  @override
  Future<int> loadAstralActiveProfileIndex() async => activeIndex;

  @override
  Future<void> saveAstralActiveProfileIndex(int index) async {
    activeIndex = index;
  }

  @override
  Future<String?> loadAstralHouseSystem() async => houseSystem;

  @override
  Future<void> saveAstralHouseSystem(String system) async {
    houseSystem = system;
  }
}

NatalChart _chart(String name, {HouseSystem house = HouseSystem.placidus}) =>
    NatalCalculatorService.calculateNatalChart(
      id: 'chart-$name',
      profileName: name,
      birthDateUtc: DateTime.utc(1988, 6, 15, 14, 30),
      birthLocalYear: 1988,
      birthLocalMonth: 6,
      birthLocalDay: 15,
      birthLocalHour: 20,
      birthLocalMinute: 30,
      timeKnown: true,
      cityName: 'Bishkek',
      country: 'Kyrgyzstan',
      latitude: 42.87,
      longitude: 74.57,
      timezoneOffsetHours: 6,
      houseSystem: house,
      createdAt: DateTime.utc(2026, 11, 17),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AstralController — 2-profile free tier & PRO gate', () {
    late AstralController ctrl;

    setUp(() {
      ctrl = AstralController(storage: _FakeStorage());
    });

    test('profile 1 and 2 generate (PRO restrictions disabled)', () {
      expect(ctrl.profiles, isEmpty);
      expect(ctrl.canCreateOrGenerateChart(), isTrue);

      expect(ctrl.generateChart(_chart('Self')), AstralGenerateResult.generated);
      expect(ctrl.profiles.length, 1);
      expect(ctrl.activeProfile?.profileName, 'Self');
      expect(ctrl.canCreateOrGenerateChart(), isTrue);

      expect(
        ctrl.generateChart(_chart('Partner')),
        AstralGenerateResult.generated,
      );
      expect(ctrl.profiles.length, 2);
      expect(ctrl.totalChartsGeneratedCount, 2);
      // PRO restrictions are disabled centrally (kProRestrictionsEnabled =
      // false), so the 2-profile free-tier cap does NOT apply.
      expect(ctrl.canCreateOrGenerateChart(), isTrue);
    });

    test('a 3rd chart generates (PRO cap bypassed)', () {
      ctrl.generateChart(_chart('Self'));
      ctrl.generateChart(_chart('Partner'));

      expect(
        ctrl.generateChart(_chart('Third')),
        AstralGenerateResult.generated,
      );
      expect(ctrl.profiles.length, 3);
      expect(ctrl.totalChartsGeneratedCount, 3);
      expect(ctrl.canCreateOrGenerateChart(), isTrue);
    });

    test('isProUnlocked is always true while PRO restrictions are disabled', () {
      // The gate logic (free-tier cap / unlockPro) stays intact for the
      // future commercial phase, but is bypassed centrally right now.
      expect(ctrl.isProUnlocked, isTrue);
      ctrl.unlockPro();
      expect(ctrl.isProUnlocked, isTrue);
      expect(ctrl.canCreateOrGenerateChart(), isTrue);
      expect(
        ctrl.generateChart(_chart('Third')),
        AstralGenerateResult.generated,
      );
      expect(ctrl.profiles.length, 1);
    });

    test('house system switches in place and never counts as a generation',
        () {
      ctrl.generateChart(_chart('Self'));
      final placidusCusps = ctrl.activeProfile!.houseCusps;

      ctrl.setHouseSystem(HouseSystem.koch);
      expect(ctrl.activeHouseSystem, HouseSystem.koch);
      expect(ctrl.profiles.length, 1);
      expect(ctrl.totalChartsGeneratedCount, 1);

      ctrl.setHouseSystem(HouseSystem.wholeSign);
      expect(ctrl.activeHouseSystem, HouseSystem.wholeSign);
      expect(ctrl.profiles.first.houseSystem, HouseSystem.wholeSign);
      expect(ctrl.totalChartsGeneratedCount, 1);
      // Same profile, re-mapped cusps — nothing re-generated.
      expect(placidusCusps.isNotEmpty, isTrue);
      expect(ctrl.profiles.first.houseCusps, isNot(equals(placidusCusps)));
    });

    test('switching the active profile re-targets the daily horoscope', () {
      ctrl.generateChart(_chart('Self'));
      ctrl.generateChart(_chart('Partner'));
      expect(ctrl.activeProfile?.profileName, 'Partner');

      ctrl.setActiveProfile(0);
      expect(ctrl.activeProfile?.profileName, 'Self');
      expect(ctrl.activeHoroscope, isNotNull);
    });
  });

  testWidgets('the shell exposes a 4th ASTRAL tab', (tester) async {
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();

    expect(find.text('ASTRAL'), findsOneWidget);
    await tester.tap(find.text('ASTRAL'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(AstralScreen), findsOneWidget);
  });
}
