import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/core/services/local_storage_service.dart';
import 'package:mindreader/core/services/lunar_phase_service.dart';
import 'package:mindreader/core/services/ritual_notification_service.dart';
import 'package:mindreader/design_system/taro.dart';
import 'package:mindreader/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

class _FakeNotificationBackend implements NotificationBackend {
  bool initialized = false;
  int permissionRequests = 0;
  bool grantPermission = true;
  String timezoneName = 'UTC';
  final Set<String> createdChannels = {};
  final Map<int, ScheduledNotificationRequest> scheduled = {};
  final List<int> cancelledIds = [];

  @override
  Future<String?> getLocalTimezoneName() async => timezoneName;

  @override
  Future<void> initialize() async {
    initialized = true;
  }

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return grantPermission;
  }

  @override
  Future<void> ensureChannel({
    required String id,
    required String name,
    required String description,
    bool highPriority = true,
  }) async {
    createdChannels.add(id);
  }

  @override
  Future<void> schedule(ScheduledNotificationRequest request) async {
    scheduled[request.id] = request;
  }

  @override
  Future<void> cancel(int id) async {
    cancelledIds.add(id);
    scheduled.remove(id);
  }
}

void main() {
  late _FakeNotificationBackend backend;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    backend = _FakeNotificationBackend();
    RitualNotificationService.resetForTest();
    RitualNotificationService.debugSupportedOverride = true;
    RitualNotificationService.debugBackendOverride = backend;
  });

  tearDown(RitualNotificationService.resetForTest);

  group('LunarPhaseService', () {
    test('computes accurate upcoming 2026 New Moons and Full Moons', () {
      final start = DateTime.utc(2026, 11, 20, 0, 0);
      final fullMoons = LunarPhaseService.upcoming(
        LunarPhase.fullMoon,
        fromUtc: start,
        count: 3,
      );
      final newMoons = LunarPhaseService.upcoming(
        LunarPhase.newMoon,
        fromUtc: start,
        count: 3,
      );

      expect(fullMoons, hasLength(3));
      expect(newMoons, hasLength(3));

      // Astronomical Full Moon: 2026-11-24 ~14:53 UTC
      expect(fullMoons[0].utcTime.year, 2026);
      expect(fullMoons[0].utcTime.month, 11);
      expect(fullMoons[0].utcTime.day, 24);

      // Astronomical New Moon: 2026-12-09 ~00:52 UTC
      expect(newMoons[0].utcTime.year, 2026);
      expect(newMoons[0].utcTime.month, 12);
      expect(newMoons[0].utcTime.day, 9);

      // Consecutive lunations are ~29.53 days apart.
      final deltaHours = fullMoons[1].utcTime
          .difference(fullMoons[0].utcTime)
          .inHours;
      expect(deltaHours, inInclusiveRange(29 * 24, 30 * 24));
    });
  });

  group('RitualNotificationService scheduling', () {
    test('schedules only selected weekdays and cancels daily IDs without touching lunar IDs', () async {
      final now = DateTime.utc(2026, 11, 24, 10, 0); // Tuesday

      // Schedule lunar phases first.
      final lunarRes = await RitualNotificationService.scheduleLunarPhases(
        newMoon: true,
        fullMoon: false,
        now: now,
      );
      expect(lunarRes.permissionGranted, isTrue);
      expect(lunarRes.scheduledCount, 6);
      expect(
        backend.scheduled.keys.where((id) => id >= 301 && id <= 306),
        hasLength(6),
      );

      // Schedule daily rituals for Mon, Wed, Fri only.
      final dailyRes = await RitualNotificationService.scheduleDailyRituals(
        morningMinutes: 8 * 60 + 30,
        eveningMinutes: 21 * 60 + 15,
        weekdays: {DateTime.monday, DateTime.wednesday, DateTime.friday},
        now: now,
      );
      expect(dailyRes.permissionGranted, isTrue);
      expect(dailyRes.scheduledCount, 6); // 3 morning + 3 evening

      // Legacy IDs 1 & 2 are cancelled; exact Mon/Wed/Fri IDs are scheduled.
      expect(backend.cancelledIds, containsAll([1, 2]));
      expect(
        backend.scheduled.keys,
        containsAll([101, 201, 103, 203, 105, 205, 301, 302, 303, 304, 305, 306]),
      );
      expect(backend.scheduled.containsKey(102), isFalse);
      expect(backend.scheduled.containsKey(202), isFalse);
      expect(
        backend.scheduled[103]!.matchDateTimeComponents,
        DateTimeComponents.dayOfWeekAndTime,
      );
      expect(backend.scheduled[103]!.scheduledDate.weekday, DateTime.wednesday);
      expect(backend.scheduled[103]!.scheduledDate.hour, 8);
      expect(backend.scheduled[103]!.scheduledDate.minute, 30);
      expect(backend.scheduled[205]!.scheduledDate.weekday, DateTime.friday);
      expect(backend.scheduled[205]!.scheduledDate.hour, 21);
      expect(backend.scheduled[205]!.scheduledDate.minute, 15);

      // Cancelling daily rituals leaves New Moon schedules untouched!
      await RitualNotificationService.cancelRituals();
      expect(backend.scheduled.keys.where((id) => id < 300), isEmpty);
      expect(
        backend.scheduled.keys.where((id) => id >= 301 && id <= 306),
        hasLength(6),
      );
    });

    test('toggling New Moon and Full Moon independently manages IDs 301..306 and 401..406', () async {
      final now = DateTime.utc(2026, 11, 24, 10, 0);
      await RitualNotificationService.scheduleLunarPhases(
        newMoon: true,
        fullMoon: true,
        now: now,
      );
      expect(backend.scheduled.keys, containsAll([301, 306, 401, 406]));

      // Turn off New Moon, keep Full Moon.
      await RitualNotificationService.scheduleLunarPhases(
        newMoon: false,
        fullMoon: true,
        now: now,
      );
      expect(backend.scheduled.keys.where((id) => id >= 301 && id <= 306), isEmpty);
      expect(
        backend.scheduled.keys.where((id) => id >= 401 && id <= 406),
        hasLength(6),
      );
    });

    test('syncFromStorage restores all active sections on startup without prompting', () async {
      final storage = LocalStorageService();
      await storage.saveRitualEnabled(true);
      await storage.saveRitualWeekdays({DateTime.tuesday, DateTime.thursday});
      await storage.saveLunarFullMoonEnabled(true);
      await storage.saveNewsNotificationsEnabled(true);

      await RitualNotificationService.syncFromStorage(storage: storage);

      expect(backend.permissionRequests, 0);
      expect(backend.scheduled.keys, containsAll([102, 202, 104, 204, 401, 406]));
      expect(backend.createdChannels, containsAll(['daily_ritual_v2', 'lunar_phases', 'app_news']));
    });

    test('friendlyLunarFireTime avoids 3 AM wakes while keeping daytime peaks exact', () {
      final loc = tz.UTC;
      final now = tz.TZDateTime(loc, 2026, 11, 20, 12, 0);

      final nightPeak = DateTime.utc(2026, 12, 9, 2, 15);
      final nightFire = RitualNotificationService.friendlyLunarFireTime(
        nightPeak,
        now: now,
      );
      expect(nightFire.hour, 9);
      expect(nightFire.minute, 0);
      expect(nightFire.day, 9);

      final daytimePeak = DateTime.utc(2026, 11, 24, 14, 53);
      final dayFire = RitualNotificationService.friendlyLunarFireTime(
        daytimePeak,
        now: now,
      );
      expect(dayFire.hour, 14);
      expect(dayFire.minute, 53);
    });
  });

  group('DailyRitualsScreen UI', () {
    Future<void> openRituals(WidgetTester tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MindreaderApp());
      await tester.pump();
      final bell = find.descendant(
        of: find.byType(TaroGlassDock),
        matching: find.byIcon(Icons.notifications_outlined),
      );
      await tester.tap(bell);
      await tester.pumpAndSettle();
    }

    testWidgets(
      'renders three distinct sections, removes DISABLE RITUALS, and wires all toggles & weekdays live',
      (tester) async {
        await openRituals(tester);

        // Three distinct sections exist; DISABLE RITUALS is gone.
        expect(find.byKey(const ValueKey('ritual-section-daily')), findsOneWidget);
        expect(find.byKey(const ValueKey('ritual-section-lunar')), findsOneWidget);
        expect(find.byKey(const ValueKey('ritual-section-news')), findsOneWidget);
        expect(find.text('DISABLE RITUALS'), findsNothing);

        // Flipping DAILY RITUAL REMINDERS ON immediately persists & schedules all 7 days (14 pushes).
        final dailyToggle = find.byKey(const ValueKey('ritual-daily-toggle'));
        await tester.tap(dailyToggle);
        await tester.pumpAndSettle();
        expect(tester.widget<TaroGlassToggle>(dailyToggle).value, isTrue);
        expect(
          (await SharedPreferences.getInstance()).getBool('ritual_enabled'),
          isTrue,
        );
        expect(backend.permissionRequests, 1);
        expect(backend.scheduled.keys.where((id) => id >= 101 && id <= 207), hasLength(14));

        // Deselect Tuesday (2) and Sunday (7) -> immediately reschedules 5 days (10 pushes).
        await tester.tap(find.byKey(const ValueKey('ritual-weekday-2')));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('ritual-weekday-7')));
        await tester.pumpAndSettle();
        expect(backend.scheduled.containsKey(102), isFalse);
        expect(backend.scheduled.containsKey(202), isFalse);
        expect(backend.scheduled.containsKey(107), isFalse);
        expect(backend.scheduled.containsKey(207), isFalse);
        expect(backend.scheduled.keys.where((id) => id >= 101 && id <= 207), hasLength(10));
        final savedDays = await LocalStorageService().loadRitualWeekdays();
        expect(savedDays, {1, 3, 4, 5, 6});

        // Enable New Moon & Full Moon in the Lunar Phases section.
        final newMoonToggle = find.byKey(const ValueKey('ritual-new-moon-toggle'));
        final fullMoonToggle = find.byKey(const ValueKey('ritual-full-moon-toggle'));
        await tester.ensureVisible(newMoonToggle);
        await tester.pumpAndSettle();
        await tester.tap(newMoonToggle);
        await tester.pumpAndSettle();
        expect(backend.scheduled.keys.where((id) => id >= 301 && id <= 306), hasLength(6));

        await tester.ensureVisible(fullMoonToggle);
        await tester.pumpAndSettle();
        await tester.tap(fullMoonToggle);
        await tester.pumpAndSettle();
        expect(backend.scheduled.keys.where((id) => id >= 401 && id <= 406), hasLength(6));

        // Subscribe to News in the News & Updates section.
        final newsToggle = find.byKey(const ValueKey('ritual-news-toggle'));
        await tester.ensureVisible(newsToggle);
        await tester.pumpAndSettle();
        // Dismiss any active toast before tapping the bottom-most section.
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
        await tester.tap(newsToggle);
        await tester.pumpAndSettle();
        expect(
          await LocalStorageService().loadNewsNotificationsEnabled(),
          isTrue,
        );
        expect(backend.createdChannels, contains('app_news'));

        // Turning DAILY RITUAL REMINDERS OFF cancels only daily pushes, leaving lunar pushes intact!
        await tester.ensureVisible(dailyToggle);
        await tester.pumpAndSettle();
        await tester.tap(dailyToggle);
        await tester.pumpAndSettle();
        expect(tester.widget<TaroGlassToggle>(dailyToggle).value, isFalse);
        expect(
          (await SharedPreferences.getInstance()).getBool('ritual_enabled'),
          isFalse,
        );
        expect(backend.scheduled.keys.where((id) => id >= 101 && id <= 207), isEmpty);
        expect(backend.scheduled.keys.where((id) => id >= 301 && id <= 406), hasLength(12));
      },
    );

    testWidgets('shows warning snackbar if OS notification permission is denied', (tester) async {
      backend.grantPermission = false;
      await openRituals(tester);

      await tester.tap(find.byKey(const ValueKey('ritual-daily-toggle')));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Notifications are disabled in device settings. Enable them to receive reminders.',
        ),
        findsOneWidget,
      );
      expect(backend.scheduled, isEmpty);
    });
  });
}
