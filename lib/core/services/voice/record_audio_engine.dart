import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:record/record.dart';

import 'audio_recorder_engine.dart';

/// Production [AudioRecorderEngine] backed by the native `record` plugin.
///
/// Captures lightweight 16 kHz mono AAC-LC (`.m4a`) on mobile/desktop and
/// Opus (`.ogg`) on Web for fast upload and clean multilingual transcription.
class RecordAudioEngine implements AudioRecorderEngine {
  RecordAudioEngine({AudioRecorder? recorder})
    : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;

  @override
  Future<bool> hasPermission({bool request = true}) async {
    try {
      return await _recorder.hasPermission(request: request);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> start({
    required String path,
    int sampleRate = 16000,
    int bitRate = 32000,
  }) async {
    final config = RecordConfig(
      encoder: kIsWeb ? AudioEncoder.opus : AudioEncoder.aacLc,
      sampleRate: sampleRate,
      bitRate: bitRate,
      numChannels: 1,
      autoGain: true,
      echoCancel: true,
      noiseSuppress: true,
    );
    await _recorder.start(config, path: path);
  }

  @override
  Future<String?> stop() => _recorder.stop();

  @override
  Future<void> cancel() async {
    try {
      await _recorder.cancel();
    } catch (_) {
      // Best-effort abort.
    }
  }

  @override
  Future<AudioAmplitudeSample> getAmplitude() async {
    try {
      final amp = await _recorder.getAmplitude();
      return AudioAmplitudeSample(
        currentDb: amp.current.isFinite ? amp.current : -160.0,
        maxDb: amp.max.isFinite ? amp.max : -160.0,
      );
    } catch (_) {
      return const AudioAmplitudeSample(currentDb: -160.0, maxDb: -160.0);
    }
  }

  @override
  Future<bool> isRecording() async {
    try {
      return await _recorder.isRecording();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> dispose() async {
    try {
      await _recorder.dispose();
    } catch (_) {
      // Best-effort cleanup.
    }
  }
}
