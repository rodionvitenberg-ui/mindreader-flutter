import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/models/natal_chart.dart';
import '../core/services/local_storage_service.dart';
import 'astral_controller.dart';
import 'session_history_controller.dart';
import 'spread_session_snapshot.dart';

/// Everything the reader tells the app about themselves — 100% local,
/// Zero-Knowledge: nothing here is ever uploaded to our own storage. The
/// social/context fields are only injected into AI prompts when the reader
/// draws for themselves.
///
/// UI-first persistence (same contract as [AstralController]): every
/// mutation updates memory + notifies SYNCHRONOUSLY, then writes the whole
/// profile to `SharedPreferences` in the background. Widget tests never
/// hang on platform channels.
class UserProfileController extends ChangeNotifier {
  UserProfileController({
    LocalStorageService? storage,
    this.history,
    this.astral,
  }) : _storage = storage ?? LocalStorageService();

  final LocalStorageService _storage;

  /// Optional collaborators used ONLY by export/import (device migration).
  final SessionHistoryController? history;
  final AstralController? astral;

  String _displayName = '';
  DateTime? _birthDate;
  TimeOfDay? _birthTime;
  bool _birthTimeKnown = true;
  String _cityName = '';
  double? _latitude;
  double? _longitude;
  double? _timezoneOffset;
  String _personalBioContext = '';
  bool _readingForSelf = true;
  String _targetPersonNote = '';
  bool _isGoogleLinked = false;

  String get displayName => _displayName;
  DateTime? get birthDate => _birthDate;
  TimeOfDay? get birthTime => _birthTime;
  bool get birthTimeKnown => _birthTimeKnown;
  String get cityName => _cityName;
  double? get latitude => _latitude;
  double? get longitude => _longitude;
  double? get timezoneOffset => _timezoneOffset;
  String get personalBioContext => _personalBioContext;
  bool get readingForSelf => _readingForSelf;
  String get targetPersonNote => _targetPersonNote;
  bool get isGoogleLinked => _isGoogleLinked;

  /// Birth data is usable by ASTRAL only when a date AND coordinates exist.
  bool get hasBirthData =>
      _birthDate != null && _latitude != null && _longitude != null;

  /// The line the Oracle is allowed to see, or null when the reading is not
  /// for the profile owner (external subject) or there is nothing to say.
  String? get oracleContext {
    if (!_readingForSelf) {
      final note = _targetPersonNote.trim();
      return note.isEmpty ? null : 'Reading for someone else: $note';
    }
    final bio = _personalBioContext.trim();
    if (bio.isEmpty) return null;
    final name = _displayName.trim();
    return name.isEmpty ? bio : '$name — $bio';
  }


  /// Restores the persisted profile without clearing anything typed in the
  /// current session (non-destructive merge).
  Future<void> load() async {
    try {
      final json = await _storage.loadUserProfile();
      if (json != null) _applyJson(json, notify: false);
    } catch (_) {
      // Corrupt JSON / unavailable storage — keep in-memory defaults.
    }
    notifyListeners();
  }

  void setDisplayName(String value) => _mutate(() => _displayName = value);

  void setBirthData({
    DateTime? date,
    TimeOfDay? time,
    bool? timeKnown,
    String? cityName,
    double? latitude,
    double? longitude,
    double? timezoneOffset,
  }) {
    _mutate(() {
      if (date != null) _birthDate = date;
      if (time != null) _birthTime = time;
      if (timeKnown != null) _birthTimeKnown = timeKnown;
      if (cityName != null) _cityName = cityName;
      if (latitude != null) _latitude = latitude;
      if (longitude != null) _longitude = longitude;
      if (timezoneOffset != null) _timezoneOffset = timezoneOffset;
    });
  }

  void setPersonalBioContext(String value) =>
      _mutate(() => _personalBioContext = value);

  void setReadingForSelf(bool value) => _mutate(() => _readingForSelf = value);

  void setTargetPersonNote(String value) =>
      _mutate(() => _targetPersonNote = value);

  /// 1-Click sign-in state. Used strictly to verify PRO ownership and to
  /// unlock optional device migration — no account is required to read.
  void setGoogleLinked(bool value) => _mutate(() => _isGoogleLinked = value);

  // ---- device migration ------------------------------------------------

  /// Bundles the profile, the session archive and the natal profiles into
  /// one portable JSON document.
  String exportAllUserDataJson() {
    return jsonEncode({
      'schema': 'mindreader.backup.v1',
      'exportedAt': DateTime.now().toIso8601String(),
      'profile': toJson(),
      'sessions': [
        for (final s in history?.sessions ?? const <SpreadSessionSnapshot>[])
          s.toJson(),
      ],
      'astralProfiles': [
        for (final p in astral?.profiles ?? const <NatalChart>[]) p.toJson(),
      ],
    });
  }
  /// Restores a document produced by [exportAllUserDataJson]. Returns false
  /// when the payload is not a valid backup — never throws on bad input.
  bool importUserDataJson(String payload) {
    final Map<String, dynamic> root;
    try {
      root = jsonDecode(payload) as Map<String, dynamic>;
    } catch (_) {
      return false;
    }
    final profile = root['profile'];
    if (profile is! Map<String, dynamic>) return false;
    try {
      _applyJson(profile, notify: true);
      final sessions = root['sessions'];
      if (sessions is List) {
        history?.restoreSessions([
          for (final s in sessions)
            if (s is Map<String, dynamic>) SpreadSessionSnapshot.fromJson(s),
        ]);
      }
      final charts = root['astralProfiles'];
      if (charts is List) {
        astral?.restoreProfiles([
          for (final c in charts)
            if (c is Map<String, dynamic>) NatalChart.fromJson(c),
        ]);
      }
    } catch (_) {
      return false;
    }
    return true;
  }

  // ---- serialization + persistence --------------------------------------

  Map<String, dynamic> toJson() => {
        'displayName': _displayName,
        'birthDate': _dateToIso(_birthDate),
        'birthTime': _timeToHm(_birthTime),
        'birthTimeKnown': _birthTimeKnown,
        'cityName': _cityName,
        'latitude': _latitude,
        'longitude': _longitude,
        'timezoneOffset': _timezoneOffset,
        'personalBioContext': _personalBioContext,
        'readingForSelf': _readingForSelf,
        'targetPersonNote': _targetPersonNote,
        'isGoogleLinked': _isGoogleLinked,
      };

  void _applyJson(Map<String, dynamic> json, {required bool notify}) {
    _displayName = _str(json['displayName']);
    _birthDate = _isoToDate(json['birthDate']);
    _birthTime = _hmToTime(json['birthTime']);
    _birthTimeKnown = json['birthTimeKnown'] as bool? ?? true;
    _cityName = _str(json['cityName']);
    _latitude = (json['latitude'] as num?)?.toDouble();
    _longitude = (json['longitude'] as num?)?.toDouble();
    _timezoneOffset = (json['timezoneOffset'] as num?)?.toDouble();
    _personalBioContext = _str(json['personalBioContext']);
    _readingForSelf = json['readingForSelf'] as bool? ?? true;
    _targetPersonNote = _str(json['targetPersonNote']);
    _isGoogleLinked = json['isGoogleLinked'] as bool? ?? false;
    if (notify) {
      notifyListeners();
      _persist();
    }
  }

  void _mutate(VoidCallback apply) {
    apply();
    notifyListeners();
    _persist();
  }

  void _persist() {
    _storage.saveUserProfile(toJson()).then((_) {}, onError: (Object _) {});
  }

  static String _str(Object? value) => value is String ? value : '';

  static String? _dateToIso(DateTime? date) => date == null
      ? null
      : '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';

  static String? _timeToHm(TimeOfDay? time) => time == null
      ? null
      : '${time.hour.toString().padLeft(2, '0')}:'
          '${time.minute.toString().padLeft(2, '0')}';

  static DateTime? _isoToDate(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;

  static TimeOfDay? _hmToTime(Object? value) {
    if (value is! String) return null;
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }
}

