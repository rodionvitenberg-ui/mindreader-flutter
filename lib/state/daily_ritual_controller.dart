import 'dart:math';

import 'package:flutter/foundation.dart';

import '../core/data/tarot_deck_data.dart';
import '../core/l10n/app_strings.dart';
import '../core/models/divination_system.dart';
import '../core/models/reading_mode.dart';
import '../core/models/reading_source.dart';
import '../core/models/spread_type.dart';
import '../core/models/tarot_card_model.dart';
import '../core/services/local_storage_service.dart';
import 'session_history_controller.dart';
import 'spread_session_snapshot.dart';

/// Persisted "Card of the Day" entry for one local calendar date (`YYYY-MM-DD`).
class DailyCardEntry {
  const DailyCardEntry({
    required this.dayKey,
    required this.cardId,
    required this.isReversed,
    required this.drawnAt,
    required this.sessionTimestamp,
  });

  final String dayKey;
  final int cardId;
  final bool isReversed;
  final String drawnAt;
  final String sessionTimestamp;

  TarotCard get card => tarotDeck[cardId.clamp(0, tarotDeck.length - 1)];

  Map<String, dynamic> toJson() => {
    'dayKey': dayKey,
    'cardId': cardId,
    'isReversed': isReversed,
    'drawnAt': drawnAt,
    'sessionTimestamp': sessionTimestamp,
  };

  static DailyCardEntry? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final dayKey = json['dayKey'];
    final cardId = json['cardId'];
    final isReversed = json['isReversed'];
    final drawnAt = json['drawnAt'];
    if (dayKey is! String || cardId is! int || isReversed is! bool) return null;
    return DailyCardEntry(
      dayKey: dayKey,
      cardId: cardId.clamp(0, tarotDeck.length - 1),
      isReversed: isReversed,
      drawnAt: drawnAt is String ? drawnAt : DateTime.now().toIso8601String(),
      sessionTimestamp: json['sessionTimestamp'] is String
          ? json['sessionTimestamp'] as String
          : (drawnAt is String ? drawnAt : DateTime.now().toIso8601String()),
    );
  }
}

/// Manages the 30-second Daily Card ritual, reading streak, and 7-day rhythm.
/// UI-first persistence: updates memory & notifies immediately, writes disk in
/// the background so tests and UI never block.
class DailyRitualController extends ChangeNotifier {
  DailyRitualController({
    LocalStorageService? storage,
    DateTime Function()? clock,
  }) : _storage = storage ?? LocalStorageService(),
       _clock = clock ?? DateTime.now;

  final LocalStorageService _storage;
  final DateTime Function() _clock;

  DailyCardEntry? _entry;
  final Set<String> _readingDays = <String>{};
  bool loaded = false;
  bool _disposed = false;
  Future<void>? _initialLoad;

  Future<void> get initialLoad => _initialLoad ?? Future<void>.value();

  static String dayKeyFor(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  String get todayKey => dayKeyFor(_clock());

  /// Today's drawn Card of the Day, or null if not drawn yet today.
  DailyCardEntry? get todayCard =>
      _entry != null && _entry!.dayKey == todayKey ? _entry : null;

  bool get drawnToday => todayCard != null;

  int get streak => computeStreak(_readingDays.toList(), today: _clock());

  /// Last 7 local calendar days ending today (oldest -> today).
  List<({DateTime date, bool completed})> get last7Days {
    final now = _clock();
    final today = DateTime(now.year, now.month, now.day);
    return [
      for (var offset = 6; offset >= 0; offset--)
        () {
          final day = today.subtract(Duration(days: offset));
          return (date: day, completed: _readingDays.contains(dayKeyFor(day)));
        }(),
    ];
  }

  Future<void> load() {
    final future = _loadInternal();
    _initialLoad ??= future;
    return future;
  }

  Future<void> _loadInternal() async {
    try {
      final results = await Future.wait([
        _storage.loadDailyCard(),
        _storage.loadReadingDays(),
      ]);
      if (_disposed) return;
      final storedEntry = DailyCardEntry.fromJson(
        results[0] as Map<String, dynamic>?,
      );
      if (storedEntry != null && _entry == null) {
        _entry = storedEntry;
      }
      _readingDays.addAll(results[1] as List<String>);
    } catch (_) {
      // Storage unavailable — keep in-memory state.
    } finally {
      loaded = true;
      if (!_disposed) notifyListeners();
    }
  }

  /// Marks today as a completed reading day (called by Table autosave as well
  /// as Daily Card draws) so the live streak updates immediately.
  void recordReadingDayNow({DateTime? now}) {
    final at = now ?? _clock();
    final key = dayKeyFor(at);
    if (_readingDays.add(key)) {
      if (!_disposed) notifyListeners();
    }
    _storage.recordReadingDay(now: at).then((_) {}, onError: (Object _) {});
  }

  /// Draws today's 30-second Daily Card, records the streak day, and persists
  /// a 1-card snapshot into [history] so it also lives in Spread History.
  Future<DailyCardEntry> drawTodayCard({
    required SessionHistoryController history,
    Random? rng,
  }) async {
    final existing = todayCard;
    if (existing != null) return existing;

    final now = _clock();
    final random = rng ?? Random.secure();
    final cardId = random.nextInt(tarotDeck.length);
    final isReversed = random.nextBool();
    final iso = now.toIso8601String();
    final entry = DailyCardEntry(
      dayKey: dayKeyFor(now),
      cardId: cardId,
      isReversed: isReversed,
      drawnAt: iso,
      sessionTimestamp: iso,
    );

    _entry = entry;
    _readingDays.add(entry.dayKey);
    if (!_disposed) notifyListeners();

    _storage.saveDailyCard(entry.toJson()).then((_) {}, onError: (Object _) {});
    _storage.recordReadingDay(now: now).then((_) {}, onError: (Object _) {});

    final checkInDays = history.defaultCheckInDays;
    final snapshot = SpreadSessionSnapshot(
      timestamp: iso,
      system: DivinationSystem.tarot,
      spreadType: SpreadType.one,
      notebook: 'all',
      cards: [
        RestoredSpreadCard(
          cardId: cardId,
          reversed: isReversed,
          role: AppStrings.g('ritual.dailyCard.title'),
        ),
      ],
      sessionNotes: const [],
      synthesis: null,
      chapters: const [],
      messages: const [],
      sessionId: iso,
      readingSource: ReadingSource.digital,
      readingMode: ReadingMode.standard,
      checkInDays: checkInDays,
      checkInDueAt: now.add(Duration(days: checkInDays)).toIso8601String(),
    );
    await history.upsert(snapshot);
    return entry;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
