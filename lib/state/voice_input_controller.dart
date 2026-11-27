import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show TextEditingController;
import 'package:path_provider/path_provider.dart';

import '../core/services/voice/audio_recorder_engine.dart';
import '../core/services/voice/cloud_transcription_service.dart';
import '../core/services/voice/record_audio_engine.dart';

/// Lifecycle phase of a single voice-input capture.
enum VoiceInputState { idle, starting, recording, transcribing }

/// Final outcome of stopping or attempting a voice capture.
enum VoiceInputOutcomeKind {
  transcribed,
  tooShort,
  tooQuiet,
  permissionDenied,
  notConfigured,
  networkError,
  emptyTranscript,
  cancelled,
}

class VoiceInputResult {
  const VoiceInputResult(this.kind, {this.text});

  final VoiceInputOutcomeKind kind;
  final String? text;

  bool get isSuccess =>
      kind == VoiceInputOutcomeKind.transcribed &&
      text != null &&
      text!.isNotEmpty;
}

/// Abstracts temp-file allocation, reading, and deletion so tests can verify
/// privacy clean-up without touching real OS paths when desired.
abstract class VoiceTempFileStore {
  Future<String> createTempPath({required String extension});
  Future<Uint8List?> readBytes(String path);
  Future<void> deleteQuietly(String path);
}

class IoVoiceTempFileStore implements VoiceTempFileStore {
  const IoVoiceTempFileStore();

  @override
  Future<String> createTempPath({required String extension}) async {
    final dir = await getTemporaryDirectory();
    final ts = DateTime.now().microsecondsSinceEpoch;
    return '${dir.path}/tarot_voice_$ts.$extension';
  }

  @override
  Future<Uint8List?> readBytes(String path) async {
    final file = File(path);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  @override
  Future<void> deleteQuietly(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Best-effort privacy cleanup.
    }
  }
}

/// Shared, language-independent voice input orchestrator.
///
/// Captures lightweight 16 kHz mono AAC/Opus audio via [AudioRecorderEngine],
/// runs pre-roll haptics (~150 ms), polls live microphone amplitude for UI
/// pulse/waveform visualization, guards against accidental taps (< 600 ms) and
/// silent clips (< -45 dBFS), transcribes via [AudioTranscriber] with auto
/// language detection and punctuation, and ALWAYS deletes the temporary audio
/// file immediately afterwards.
class VoiceInputController extends ChangeNotifier {
  VoiceInputController({
    AudioRecorderEngine? recorder,
    AudioTranscriber? transcriber,
    VoiceTempFileStore? tempStore,
    DateTime Function()? clock,
    Future<void> Function()? hapticConfirm,
    this.preRollDelay = const Duration(milliseconds: 150),
    this.minRecordingDuration = const Duration(milliseconds: 600),
    this.maxRecordingDuration = const Duration(seconds: 60),
    this.amplitudePollInterval = const Duration(milliseconds: 70),
    this.minPeakAmplitudeDb = -45.0,
  }) : _recorder = recorder ?? RecordAudioEngine(),
       _transcriber = transcriber ?? CloudTranscriptionService(),
       _tempStore = tempStore ?? const IoVoiceTempFileStore(),
       _clock = clock ?? DateTime.now,
       _hapticConfirm = hapticConfirm ?? HapticFeedback.lightImpact;

  final AudioRecorderEngine _recorder;
  final AudioTranscriber _transcriber;
  final VoiceTempFileStore _tempStore;
  final DateTime Function() _clock;
  final Future<void> Function() _hapticConfirm;

  final Duration preRollDelay;
  final Duration minRecordingDuration;
  final Duration maxRecordingDuration;
  final Duration amplitudePollInterval;

  /// Clips whose peak loudness stays strictly below this dBFS threshold are
  /// treated as silence and discarded locally without calling the cloud API.
  final double minPeakAmplitudeDb;

  VoiceInputState _state = VoiceInputState.idle;
  Object? _activeOwner;
  double _amplitudeLevel = 0.0; // normalized 0.0..1.0 for UI pulse
  double _peakDb = -160.0;
  DateTime? _startedAt;
  String? _currentPath;
  int _epoch = 0;
  Timer? _amplitudeTimer;
  Timer? _maxDurationTimer;
  Completer<VoiceInputResult>? _inFlightStop;
  bool _disposed = false;

  VoiceInputState get state => _state;
  Object? get activeOwner => _activeOwner;

  /// Normalized live loudness `0.0..1.0` driving the mic waveform/pulse UI.
  double get amplitudeLevel => _amplitudeLevel;

  /// Peak dBFS measured in the current or most recent recording.
  double get peakDb => _peakDb;

  bool get isIdle => _state == VoiceInputState.idle;
  bool get isRecording =>
      _state == VoiceInputState.starting || _state == VoiceInputState.recording;
  bool get isTranscribing => _state == VoiceInputState.transcribing;

  bool isOwnedBy(Object owner) => identical(_activeOwner, owner);

  bool isRecordingFor(Object owner) => isOwnedBy(owner) && isRecording;

  bool isTranscribingFor(Object owner) => isOwnedBy(owner) && isTranscribing;

  /// Maps dBFS (-55 dB silence floor .. -5 dB loud speech) to 0.0..1.0.
  static double normalizeDb(double db) {
    if (!db.isFinite || db <= -55.0) return 0.0;
    if (db >= -5.0) return 1.0;
    return ((db + 55.0) / 50.0).clamp(0.0, 1.0);
  }

  /// Starts native microphone capture for [owner].
  ///
  /// Returns `null` when capture started successfully (user should tap again to
  /// stop & transcribe), or an immediate [VoiceInputResult] on permission failure.
  Future<VoiceInputResult?> startRecording({
    required Object owner,
    VoidCallback? onAutoStop,
  }) async {
    if (_disposed) return const VoiceInputResult(VoiceInputOutcomeKind.cancelled);

    // If another field currently owns the mic, cancel it cleanly first.
    if (_state != VoiceInputState.idle) {
      await cancel();
    }

    final myEpoch = ++_epoch;
    _activeOwner = owner;
    _state = VoiceInputState.starting;
    _amplitudeLevel = 0.0;
    _peakDb = -160.0;
    _startedAt = null;
    _currentPath = null;
    _notify();

    bool permitted;
    try {
      permitted = await _recorder.hasPermission(request: true);
    } catch (_) {
      permitted = false;
    }
    if (_disposed || myEpoch != _epoch) {
      return const VoiceInputResult(VoiceInputOutcomeKind.cancelled);
    }
    if (!permitted) {
      _resetToIdle();
      return const VoiceInputResult(VoiceInputOutcomeKind.permissionDenied);
    }

    final ext = kIsWeb ? 'ogg' : 'm4a';
    String path;
    try {
      path = await _tempStore.createTempPath(extension: ext);
      _currentPath = path;
      await _recorder.start(path: path, sampleRate: 16000, bitRate: 32000);
    } catch (_) {
      final stale = _currentPath;
      _resetToIdle();
      if (stale != null) await _tempStore.deleteQuietly(stale);
      return const VoiceInputResult(VoiceInputOutcomeKind.permissionDenied);
    }

    if (_disposed || myEpoch != _epoch) {
      await _abortRecorderAndDelete(path);
      return const VoiceInputResult(VoiceInputOutcomeKind.cancelled);
    }

    _startedAt = _clock();

    // Pre-roll (~150 ms) so the audio stream is genuinely capturing before we
    // vibrate — preventing the speaker's first syllable from ever clipping.
    if (preRollDelay > Duration.zero) {
      await Future<void>.delayed(preRollDelay);
    }
    if (_disposed || myEpoch != _epoch) {
      await _abortRecorderAndDelete(path);
      return const VoiceInputResult(VoiceInputOutcomeKind.cancelled);
    }

    _state = VoiceInputState.recording;
    unawaited(_hapticConfirm().catchError((Object _) {}));
    _startAmplitudePolling(myEpoch);
    _maxDurationTimer = Timer(maxRecordingDuration, () {
      if (!_disposed && myEpoch == _epoch && isRecording) {
        onAutoStop?.call();
      }
    });
    _notify();
    return null;
  }

  /// Stops active capture, applies accidental-tap & silence guards, transcribes
  /// via the cloud multilingual AI service, and unconditionally deletes the
  /// temporary audio file.
  Future<VoiceInputResult> stopAndTranscribe({Object? owner}) async {
    if (_inFlightStop != null) return _inFlightStop!.future;
    if (!isRecording) {
      return const VoiceInputResult(VoiceInputOutcomeKind.cancelled);
    }
    if (owner != null && !isOwnedBy(owner)) {
      return const VoiceInputResult(VoiceInputOutcomeKind.cancelled);
    }

    final completer = Completer<VoiceInputResult>();
    _inFlightStop = completer;

    final myEpoch = _epoch;
    final startedAt = _startedAt;
    final fallbackPath = _currentPath;
    _stopTimers();

    // Capture one final amplitude sample before stopping so short utterances
    // that ended right before stop still register their peak loudness.
    try {
      final sample = await _recorder.getAmplitude();
      _recordSample(sample);
    } catch (_) {
      // Ignore amplitude failure on stop.
    }

    String? recordedPath;
    try {
      recordedPath = await _recorder.stop() ?? fallbackPath;
    } catch (_) {
      recordedPath = fallbackPath;
    }

    final elapsed = startedAt == null
        ? Duration.zero
        : _clock().difference(startedAt);
    final peakDb = _peakDb;

    VoiceInputResult result = const VoiceInputResult(
      VoiceInputOutcomeKind.cancelled,
    );
    try {
      if (_disposed || myEpoch != _epoch) {
        result = const VoiceInputResult(VoiceInputOutcomeKind.cancelled);
      } else if (elapsed < minRecordingDuration) {
        result = const VoiceInputResult(VoiceInputOutcomeKind.tooShort);
      } else if (peakDb < minPeakAmplitudeDb) {
        result = const VoiceInputResult(VoiceInputOutcomeKind.tooQuiet);
      } else if (recordedPath == null || recordedPath.isEmpty) {
        result = const VoiceInputResult(VoiceInputOutcomeKind.emptyTranscript);
      } else {
        _state = VoiceInputState.transcribing;
        _amplitudeLevel = 0.0;
        _notify();

        final bytes = await _tempStore.readBytes(recordedPath);
        if (_disposed || myEpoch != _epoch) {
          result = const VoiceInputResult(VoiceInputOutcomeKind.cancelled);
        } else if (bytes == null || bytes.isEmpty) {
          result = const VoiceInputResult(VoiceInputOutcomeKind.emptyTranscript);
        } else {
          final isOgg = recordedPath.endsWith('.ogg');
          final transcript = await _transcriber.transcribe(
            audioBytes: bytes,
            mimeType: isOgg ? 'audio/ogg' : 'audio/mp4',
            filename: isOgg ? 'voice_note.ogg' : 'voice_note.m4a',
          );
          if (_disposed || myEpoch != _epoch) {
            result = const VoiceInputResult(VoiceInputOutcomeKind.cancelled);
          } else {
            result = VoiceInputResult(
              VoiceInputOutcomeKind.transcribed,
              text: transcript,
            );
          }
        }
      }
    } on TranscriptionException catch (e) {
      result = switch (e.kind) {
        TranscriptionErrorKind.notConfigured => const VoiceInputResult(
          VoiceInputOutcomeKind.notConfigured,
        ),
        TranscriptionErrorKind.empty => const VoiceInputResult(
          VoiceInputOutcomeKind.emptyTranscript,
        ),
        TranscriptionErrorKind.unauthorized ||
        TranscriptionErrorKind.quotaExceeded ||
        TranscriptionErrorKind.network ||
        TranscriptionErrorKind.failed => const VoiceInputResult(
          VoiceInputOutcomeKind.networkError,
        ),
      };
    } catch (_) {
      result = const VoiceInputResult(VoiceInputOutcomeKind.networkError);
    } finally {
      // Privacy invariant: ALWAYS remove temporary audio immediately.
      if (recordedPath != null && recordedPath.isNotEmpty) {
        await _tempStore.deleteQuietly(recordedPath);
      }
      if (fallbackPath != null &&
          fallbackPath.isNotEmpty &&
          fallbackPath != recordedPath) {
        await _tempStore.deleteQuietly(fallbackPath);
      }
      if (myEpoch == _epoch) {
        _resetToIdle();
      }
      _inFlightStop = null;
      if (!completer.isCompleted) {
        completer.complete(result);
      }
    }

    return result;
  }

  /// Cancels any active recording or transcription immediately and wipes temp audio.
  Future<void> cancel({Object? owner}) async {
    if (owner != null && !isOwnedBy(owner)) return;
    if (_state == VoiceInputState.idle) return;
    _epoch++;
    final stalePath = _currentPath;
    _stopTimers();
    _resetToIdle();
    await _abortRecorderAndDelete(stalePath);
    if (_inFlightStop != null && !_inFlightStop!.isCompleted) {
      _inFlightStop!.complete(
        const VoiceInputResult(VoiceInputOutcomeKind.cancelled),
      );
      _inFlightStop = null;
    }
  }

  void _startAmplitudePolling(int epoch) {
    _amplitudeTimer?.cancel();
    _amplitudeTimer = Timer.periodic(amplitudePollInterval, (_) async {
      if (_disposed || epoch != _epoch || !isRecording) return;
      try {
        final sample = await _recorder.getAmplitude();
        if (_disposed || epoch != _epoch || !isRecording) return;
        _recordSample(sample);
        _notify();
      } catch (_) {
        // Ignore transient amplitude poll errors.
      }
    });
  }

  void _recordSample(AudioAmplitudeSample sample) {
    final candidate = sample.currentDb > sample.maxDb
        ? sample.currentDb
        : sample.maxDb;
    if (candidate > _peakDb) {
      _peakDb = candidate;
    }
    _amplitudeLevel = normalizeDb(sample.currentDb);
  }

  void _stopTimers() {
    _amplitudeTimer?.cancel();
    _amplitudeTimer = null;
    _maxDurationTimer?.cancel();
    _maxDurationTimer = null;
  }

  Future<void> _abortRecorderAndDelete(String? path) async {
    try {
      await _recorder.cancel();
    } catch (_) {
      // Best-effort abort.
    }
    if (path != null && path.isNotEmpty) {
      await _tempStore.deleteQuietly(path);
    }
  }

  void _resetToIdle() {
    _stopTimers();
    _state = VoiceInputState.idle;
    _activeOwner = null;
    _amplitudeLevel = 0.0;
    _startedAt = null;
    _currentPath = null;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    _stopTimers();
    final stale = _currentPath;
    unawaited(_abortRecorderAndDelete(stale));
    unawaited(_recorder.dispose());
    super.dispose();
  }
}

/// Inserts transcribed [spoken] text cleanly into [controller] at the current
/// caret/selection (adding natural spacing around existing text).
String insertVoiceTranscript(
  TextEditingController controller,
  String spoken,
) {
  final words = spoken.trim();
  if (words.isEmpty) return controller.text;
  final value = controller.value;
  final sel = value.selection.isValid
      ? value.selection
      : TextSelection.collapsed(offset: value.text.length);
  final before = value.text.substring(0, sel.start);
  final after = value.text.substring(sel.end);
  final prefix = before.isEmpty || before.trimRight() != before
      ? before
      : '$before ';
  final suffix = after.isEmpty || after.trimLeft() != after ? after : ' $after';
  final next = '$prefix$words$suffix';
  controller.value = TextEditingValue(
    text: next,
    selection: TextSelection.collapsed(offset: prefix.length + words.length),
  );
  return next;
}
