import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;

import '../l10n/app_strings.dart';
import 'birth_time_service.dart';
import 'local_storage_service.dart';
import 'lunar_phase_service.dart';

/// Result of syncing or toggling a notification section.
class NotificationSyncResult {
  const NotificationSyncResult({
    required this.permissionGranted,
    required this.scheduledCount,
  });

  /// `false` only when the OS explicitly denied notification permission.
  final bool permissionGranted;
  final int scheduledCount;
}

/// One scheduled notification payload passed to [NotificationBackend].
class ScheduledNotificationRequest {
  const ScheduledNotificationRequest({
    required this.id,
    required this.channelId,
    required this.channelName,
    required this.channelDescription,
    required this.title,
    required this.body,
    required this.scheduledDate,
    this.matchDateTimeComponents,
    this.highPriority = true,
  });

  final int id;
  final String channelId;
  final String channelName;
  final String channelDescription;
  final String title;
  final String body;
  final tz.TZDateTime scheduledDate;
  final DateTimeComponents? matchDateTimeComponents;
  final bool highPriority;
}

/// Platform delivery seam so unit & widget tests can verify exact scheduled
/// notification payloads and cancellations without a real device channel.
abstract class NotificationBackend {
  Future<String?> getLocalTimezoneName();
  Future<void> initialize();
  Future<bool> requestPermission();
  Future<void> ensureChannel({
    required String id,
    required String name,
    required String description,
    bool highPriority = true,
  });
  Future<void> schedule(ScheduledNotificationRequest request);
  Future<void> cancel(int id);
}

class _FlutterLocalNotificationsBackend implements NotificationBackend {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  @override
  Future<String?> getLocalTimezoneName() => FlutterTimezone.getLocalTimezone();

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    _initialized = true;
  }

  @override
  Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? true;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      final granted = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? true;
    }
    return true;
  }

  @override
  Future<void> ensureChannel({
    required String id,
    required String name,
    required String description,
    bool highPriority = true,
  }) async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return;
    await android.createNotificationChannel(
      AndroidNotificationChannel(
        id,
        name,
        description: description,
        importance: highPriority ? Importance.high : Importance.defaultImportance,
        playSound: true,
        enableVibration: highPriority,
      ),
    );
  }

  @override
  Future<void> schedule(ScheduledNotificationRequest request) async {
    final androidDetails = AndroidNotificationDetails(
      request.channelId,
      request.channelName,
      channelDescription: request.channelDescription,
      importance:
          request.highPriority ? Importance.high : Importance.defaultImportance,
      priority: request.highPriority ? Priority.high : Priority.defaultPriority,
      playSound: true,
      enableVibration: request.highPriority,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBanner: true,
      presentList: true,
      presentSound: true,
    );
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    var mode = AndroidScheduleMode.inexactAllowWhileIdle;
    if (android != null) {
      try {
        if (await android.canScheduleExactNotifications() == true) {
          mode = AndroidScheduleMode.exactAllowWhileIdle;
        }
      } catch (_) {
        mode = AndroidScheduleMode.inexactAllowWhileIdle;
      }
    }
    try {
      await _plugin.zonedSchedule(
        request.id,
        request.title,
        request.body,
        request.scheduledDate,
        details,
        androidScheduleMode: mode,
        matchDateTimeComponents: request.matchDateTimeComponents,
      );
    } catch (_) {
      if (mode == AndroidScheduleMode.exactAllowWhileIdle) {
        await _plugin.zonedSchedule(
          request.id,
          request.title,
          request.body,
          request.scheduledDate,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: request.matchDateTimeComponents,
        );
      } else {
        rethrow;
      }
    }
  }

  @override
  Future<void> cancel(int id) => _plugin.cancel(id);
}

/// Local push notification manager covering three independent sections:
/// 1. Daily Ritual reminders (selectable ISO weekdays 1..7 + morning/evening).
/// 2. Lunar Phase reminders (upcoming astronomical New Moon and/or Full Moon).
/// 3. App News & Updates subscription channel.
///
/// Each section owns a disjoint notification ID range and never wipes another
/// section's scheduled alerts.
class RitualNotificationService {
  RitualNotificationService._();

  static const String dailyChannelId = 'daily_ritual_v2';
  static const String lunarChannelId = 'lunar_phases';
  static const String newsChannelId = 'app_news';

  /// Disjoint notification ID ranges per category.
  static const List<int> legacyDailyIds = [1, 2];
  static const int morningIdBase = 100; // 101..107 (Mon..Sun)
  static const int eveningIdBase = 200; // 201..207 (Mon..Sun)
  static const int newMoonIdBase = 300; // 301..306
  static const int fullMoonIdBase = 400; // 401..406
  static const int lunarHorizonCount = 6;
  static const int newsNotificationId = 500;
  static const int checkInIdBase = 600; // 600..619 (Zeigarnik spread check-ins)
  static const int checkInIdRange = 20;

  static final NotificationBackend _defaultBackend =
      _FlutterLocalNotificationsBackend();
  static bool _timezoneReady = false;

  @visibleForTesting
  static NotificationBackend? debugBackendOverride;

  @visibleForTesting
  static bool? debugSupportedOverride;

  @visibleForTesting
  static void resetForTest() {
    debugBackendOverride = null;
    debugSupportedOverride = null;
    _timezoneReady = false;
  }

  static NotificationBackend get _backend =>
      debugBackendOverride ?? _defaultBackend;

  static bool get supported =>
      debugSupportedOverride ??
      (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS));

  static Future<void> _ensureTimezone() async {
    if (_timezoneReady) return;
    BirthTimeService.initialize();
    try {
      final tzName = await _backend.getLocalTimezoneName();
      if (tzName != null && tzName.isNotEmpty) {
        tz.setLocalLocation(tz.getLocation(tzName));
        _timezoneReady = true;
        return;
      }
    } catch (_) {
      // Fallback: pick an IANA zone matching the device's current UTC offset
      // so scheduled wall-clock times never silently drift to UTC.
    }
    try {
      final offsetMs = DateTime.now().timeZoneOffset.inMilliseconds;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      tz.Location? matched;
      for (final loc in tz.timeZoneDatabase.locations.values) {
        if (loc.timeZone(nowMs).offset == offsetMs) {
          matched = loc;
          if (loc.name.startsWith('Etc/')) break;
        }
      }
      if (matched != null) {
        tz.setLocalLocation(matched);
      }
    } catch (_) {
      // tz.local remains UTC if no zone database is available.
    }
    _timezoneReady = true;
  }

  static Future<bool> _prepare({required bool requestPermission}) async {
    await _ensureTimezone();
    await _backend.initialize();
    if (!requestPermission) return true;
    try {
      return await _backend.requestPermission();
    } catch (_) {
      return true;
    }
  }

  static Future<void> _cancelDailyIds() async {
    for (final id in legacyDailyIds) {
      await _backend.cancel(id);
    }
    for (var day = DateTime.monday; day <= DateTime.sunday; day++) {
      await _backend.cancel(morningIdBase + day);
      await _backend.cancel(eveningIdBase + day);
    }
  }

  static Future<void> _cancelLunarIds({
    required bool cancelNewMoon,
    required bool cancelFullMoon,
  }) async {
    if (cancelNewMoon) {
      for (var i = 1; i <= lunarHorizonCount; i++) {
        await _backend.cancel(newMoonIdBase + i);
      }
    }
    if (cancelFullMoon) {
      for (var i = 1; i <= lunarHorizonCount; i++) {
        await _backend.cancel(fullMoonIdBase + i);
      }
    }
  }

  /// Schedules Morning Anchor and Evening Reflection reminders on the chosen
  /// ISO [weekdays] (`DateTime.monday` 1 .. `DateTime.sunday` 7).
  static Future<NotificationSyncResult> scheduleDailyRituals({
    required int morningMinutes,
    required int eveningMinutes,
    Set<int> weekdays = const {1, 2, 3, 4, 5, 6, 7},
    bool requestPermission = true,
    DateTime? now,
  }) async {
    if (!supported) {
      return const NotificationSyncResult(
        permissionGranted: true,
        scheduledCount: 0,
      );
    }
    try {
      final granted = await _prepare(requestPermission: requestPermission);
      await _cancelDailyIds();
      final validDays = weekdays
          .where((d) => d >= DateTime.monday && d <= DateTime.sunday)
          .toList()
        ..sort();
      if (!granted || validDays.isEmpty) {
        return NotificationSyncResult(
          permissionGranted: granted,
          scheduledCount: 0,
        );
      }

      final channelName = AppStrings.g('ritual.notification.channel');
      final channelDesc = AppStrings.g('ritual.notification.channelDescription');
      await _backend.ensureChannel(
        id: dailyChannelId,
        name: channelName,
        description: channelDesc,
        highPriority: true,
      );

      final referenceNow = now != null
          ? tz.TZDateTime.from(now.toUtc(), tz.local)
          : tz.TZDateTime.now(tz.local);
      var count = 0;
      for (final day in validDays) {
        await _backend.schedule(
          ScheduledNotificationRequest(
            id: morningIdBase + day,
            channelId: dailyChannelId,
            channelName: channelName,
            channelDescription: channelDesc,
            title: AppStrings.g('ritual.notification.morningTitle'),
            body: AppStrings.g('ritual.notification.morningBody'),
            scheduledDate: nextInstanceOfWeekday(
              day,
              morningMinutes,
              now: referenceNow,
            ),
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
            highPriority: true,
          ),
        );
        count++;
        await _backend.schedule(
          ScheduledNotificationRequest(
            id: eveningIdBase + day,
            channelId: dailyChannelId,
            channelName: channelName,
            channelDescription: channelDesc,
            title: AppStrings.g('ritual.notification.eveningTitle'),
            body: AppStrings.g('ritual.notification.eveningBody'),
            scheduledDate: nextInstanceOfWeekday(
              day,
              eveningMinutes,
              now: referenceNow,
            ),
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
            highPriority: true,
          ),
        );
        count++;
      }
      return NotificationSyncResult(
        permissionGranted: true,
        scheduledCount: count,
      );
    } catch (_) {
      return const NotificationSyncResult(
        permissionGranted: true,
        scheduledCount: 0,
      );
    }
  }

  /// Cancels ONLY the daily ritual reminders (leaving lunar & news untouched).
  static Future<void> cancelRituals() async {
    if (!supported) return;
    try {
      await _prepare(requestPermission: false);
      await _cancelDailyIds();
    } catch (_) {
      // Nothing scheduled, or the platform channel is missing.
    }
  }

  /// Schedules upcoming astronomical New Moon and/or Full Moon notifications
  /// (next [lunarHorizonCount] cycles per enabled phase) and cancels disabled
  /// lunar phases without touching daily rituals.
  static Future<NotificationSyncResult> scheduleLunarPhases({
    required bool newMoon,
    required bool fullMoon,
    bool requestPermission = true,
    DateTime? now,
  }) async {
    if (!supported) {
      return const NotificationSyncResult(
        permissionGranted: true,
        scheduledCount: 0,
      );
    }
    try {
      final anyEnabled = newMoon || fullMoon;
      final granted = await _prepare(
        requestPermission: requestPermission && anyEnabled,
      );
      await _cancelLunarIds(cancelNewMoon: true, cancelFullMoon: true);
      if (!anyEnabled || !granted) {
        return NotificationSyncResult(
          permissionGranted: granted,
          scheduledCount: 0,
        );
      }

      final channelName = AppStrings.g('ritual.lunar.channel');
      final channelDesc = AppStrings.g('ritual.lunar.channelDescription');
      await _backend.ensureChannel(
        id: lunarChannelId,
        name: channelName,
        description: channelDesc,
        highPriority: true,
      );

      final referenceNow = now != null
          ? tz.TZDateTime.from(now.toUtc(), tz.local)
          : tz.TZDateTime.now(tz.local);
      final fromUtc = referenceNow.toUtc();
      var count = 0;

      if (newMoon) {
        final events = LunarPhaseService.upcoming(
          LunarPhase.newMoon,
          fromUtc: fromUtc,
          count: lunarHorizonCount,
        );
        for (var i = 0; i < events.length; i++) {
          final fireAt = friendlyLunarFireTime(
            events[i].utcTime,
            now: referenceNow,
          );
          if (!fireAt.isAfter(referenceNow)) continue;
          await _backend.schedule(
            ScheduledNotificationRequest(
              id: newMoonIdBase + i + 1,
              channelId: lunarChannelId,
              channelName: channelName,
              channelDescription: channelDesc,
              title: AppStrings.g('ritual.lunar.newMoonTitle'),
              body: AppStrings.g('ritual.lunar.newMoonBody'),
              scheduledDate: fireAt,
              highPriority: true,
            ),
          );
          count++;
        }
      }

      if (fullMoon) {
        final events = LunarPhaseService.upcoming(
          LunarPhase.fullMoon,
          fromUtc: fromUtc,
          count: lunarHorizonCount,
        );
        for (var i = 0; i < events.length; i++) {
          final fireAt = friendlyLunarFireTime(
            events[i].utcTime,
            now: referenceNow,
          );
          if (!fireAt.isAfter(referenceNow)) continue;
          await _backend.schedule(
            ScheduledNotificationRequest(
              id: fullMoonIdBase + i + 1,
              channelId: lunarChannelId,
              channelName: channelName,
              channelDescription: channelDesc,
              title: AppStrings.g('ritual.lunar.fullMoonTitle'),
              body: AppStrings.g('ritual.lunar.fullMoonBody'),
              scheduledDate: fireAt,
              highPriority: true,
            ),
          );
          count++;
        }
      }

      return NotificationSyncResult(
        permissionGranted: true,
        scheduledCount: count,
      );
    } catch (_) {
      return const NotificationSyncResult(
        permissionGranted: true,
        scheduledCount: 0,
      );
    }
  }

  /// Registers or unregisters the News & Updates notification channel.
  static Future<NotificationSyncResult> setNewsSubscribed(
    bool enabled, {
    bool requestPermission = true,
  }) async {
    if (!supported) {
      return const NotificationSyncResult(
        permissionGranted: true,
        scheduledCount: 0,
      );
    }
    try {
      final granted = await _prepare(
        requestPermission: requestPermission && enabled,
      );
      if (!enabled || !granted) {
        await _backend.cancel(newsNotificationId);
        return NotificationSyncResult(
          permissionGranted: granted,
          scheduledCount: 0,
        );
      }
      await _backend.ensureChannel(
        id: newsChannelId,
        name: AppStrings.g('ritual.news.channel'),
        description: AppStrings.g('ritual.news.channelDescription'),
        highPriority: false,
      );
      return const NotificationSyncResult(
        permissionGranted: true,
        scheduledCount: 0,
      );
    } catch (_) {
      return const NotificationSyncResult(
        permissionGranted: true,
        scheduledCount: 0,
      );
    }
  }

  /// Schedules a gentle local Zeigarnik check-in reminder for a saved spread
  /// (only when local ritual notifications are already enabled; zero server
  /// retention). Uses disjoint IDs `600..619`.
  static Future<void> scheduleSpreadCheckIn({
    required String sessionTimestamp,
    required DateTime dueAt,
    required String prompt,
    LocalStorageService? storage,
    DateTime? now,
  }) async {
    if (!supported) return;
    try {
      final store = storage ?? LocalStorageService();
      if (!await store.loadRitualEnabled()) return;
      final granted = await _prepare(requestPermission: false);
      if (!granted) return;
      final channelName = AppStrings.g('ritual.notification.channel');
      final channelDesc = AppStrings.g('ritual.notification.channelDescription');
      await _backend.ensureChannel(
        id: dailyChannelId,
        name: channelName,
        description: channelDesc,
        highPriority: false,
      );
      final referenceNow = now != null
          ? tz.TZDateTime.from(now.toUtc(), tz.local)
          : tz.TZDateTime.now(tz.local);
      final fireAt = friendlyLunarFireTime(dueAt.toUtc(), now: referenceNow);
      if (!fireAt.isAfter(referenceNow)) return;
      final id = checkInIdBase + (sessionTimestamp.hashCode.abs() % checkInIdRange);
      await _backend.schedule(
        ScheduledNotificationRequest(
          id: id,
          channelId: dailyChannelId,
          channelName: channelName,
          channelDescription: channelDesc,
          title: AppStrings.g('checkin.notificationTitle'),
          body: prompt,
          scheduledDate: fireAt,
          highPriority: false,
        ),
      );
    } catch (_) {
      // Best-effort local reminder.
    }
  }

  /// Refreshes all active local notification schedules on app startup without
  /// prompting the user if nothing is enabled.
  static Future<void> syncFromStorage({LocalStorageService? storage}) async {
    if (!supported) return;
    try {
      final store = storage ?? LocalStorageService();
      final dailyEnabled = await store.loadRitualEnabled();
      final newMoon = await store.loadLunarNewMoonEnabled();
      final fullMoon = await store.loadLunarFullMoonEnabled();
      final newsEnabled = await store.loadNewsNotificationsEnabled();
      if (!dailyEnabled && !newMoon && !fullMoon && !newsEnabled) return;

      if (dailyEnabled) {
        final morning = await store.loadMorningMinutes();
        final evening = await store.loadEveningMinutes();
        final weekdays = await store.loadRitualWeekdays();
        await scheduleDailyRituals(
          morningMinutes: morning,
          eveningMinutes: evening,
          weekdays: weekdays,
          requestPermission: false,
        );
      }
      if (newMoon || fullMoon) {
        await scheduleLunarPhases(
          newMoon: newMoon,
          fullMoon: fullMoon,
          requestPermission: false,
        );
      }
      if (newsEnabled) {
        await setNewsSubscribed(true, requestPermission: false);
      }
    } catch (_) {
      // Startup notification sync is best-effort.
    }
  }

  /// Next wall-clock instance of [minutes] minutes after midnight on ISO
  /// [weekday] (`DateTime.monday` 1 .. `DateTime.sunday` 7), strictly after [now].
  @visibleForTesting
  static tz.TZDateTime nextInstanceOfWeekday(
    int weekday,
    int minutes, {
    tz.TZDateTime? now,
  }) {
    final ref = now ?? tz.TZDateTime.now(tz.local);
    var daysAhead = (weekday - ref.weekday) % 7;
    if (daysAhead < 0) daysAhead += 7;
    var scheduled = tz.TZDateTime(
      ref.location,
      ref.year,
      ref.month,
      ref.day + daysAhead,
      minutes ~/ 60,
      minutes % 60,
    );
    if (!scheduled.isAfter(ref)) {
      scheduled = tz.TZDateTime(
        ref.location,
        scheduled.year,
        scheduled.month,
        scheduled.day + 7,
        minutes ~/ 60,
        minutes % 60,
      );
    }
    return scheduled;
  }

  /// Maps an astronomical UTC peak to a respectful local delivery time:
  /// exact peak between 08:00 and 22:00 local time; 09:00 on the same local
  /// day if the peak occurs before 08:00; 20:00 if it occurs at/after 22:00
  /// (falling back to the exact peak if the shifted time is already past [now]).
  @visibleForTesting
  static tz.TZDateTime friendlyLunarFireTime(
    DateTime peakUtc, {
    required tz.TZDateTime now,
  }) {
    final exactLocal = tz.TZDateTime.from(peakUtc.toUtc(), now.location);
    if (exactLocal.hour >= 8 && exactLocal.hour < 22) {
      return exactLocal;
    }
    final targetHour = exactLocal.hour < 8 ? 9 : 20;
    final shifted = tz.TZDateTime(
      now.location,
      exactLocal.year,
      exactLocal.month,
      exactLocal.day,
      targetHour,
      0,
    );
    return shifted.isAfter(now) ? shifted : exactLocal;
  }
}
