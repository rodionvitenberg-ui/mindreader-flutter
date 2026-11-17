import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

/// Local-only daily ritual reminders (zero server retention).
///
/// Abstracted to degrade gracefully everywhere:
/// * unsupported platforms (web, desktop) → no-op;
/// * missing plugin channels (tests, emulators) → exceptions swallowed;
/// * timezone detection failure → falls back to the device's UTC offset.
class RitualNotificationService {
  RitualNotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static Future<void> _ensureInitialized() async {
    if (_initialized || !supported) return;
    _initialized = true;
    try {
      tzdata.initializeTimeZones();
      final tzName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzName));
    } catch (_) {
      // tz.local stays UTC — scheduling still works, wall-clock times may
      // shift by the device's UTC offset.
    }
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (_) {
      // Permission prompt unavailable — scheduling still proceeds.
    }
  }

  /// Schedules the two daily rituals: 09:00 Morning Anchor and 22:00
  /// Evening Reflection (repeating daily, inexact — battery friendly).
  static Future<void> scheduleDailyRituals({
    required int morningMinutes,
    required int eveningMinutes,
  }) async {
    if (!supported) return;
    try {
      await _ensureInitialized();
      await _plugin.cancelAll();
      const android = AndroidNotificationDetails(
        'daily_ritual',
        'Daily Ritual',
        channelDescription:
            'Morning anchor and evening reflection reminders.',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      );
      const ios = DarwinNotificationDetails();
      const details = NotificationDetails(android: android, iOS: ios);
      await _plugin.zonedSchedule(
        1,
        'Morning Anchor',
        'Draw your Daily Anchor card.',
        _nextInstanceOf(morningMinutes),
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      await _plugin.zonedSchedule(
        2,
        'Evening Reflection',
        'Ground your thoughts before sleep.',
        _nextInstanceOf(eveningMinutes),
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (_) {
      // Notifications unavailable — the ritual settings still persist.
    }
  }

  static Future<void> cancelRituals() async {
    if (!supported) return;
    try {
      await _ensureInitialized();
      await _plugin.cancelAll();
    } catch (_) {
      // Nothing scheduled, or the platform channel is missing.
    }
  }

  /// Next wall-clock instance of [minutes] minutes after midnight.
  static tz.TZDateTime _nextInstanceOf(int minutes) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      minutes ~/ 60,
      minutes % 60,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
