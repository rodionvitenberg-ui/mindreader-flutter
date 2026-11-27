/// Normalized dBFS amplitude sample polled from the live microphone stream.
class AudioAmplitudeSample {
  const AudioAmplitudeSample({
    required this.currentDb,
    required this.maxDb,
  });

  /// Instantaneous loudness in dBFS (typically -160.0 = digital silence to 0.0 = full scale).
  final double currentDb;

  /// Peak loudness observed by the native recorder in dBFS.
  final double maxDb;
}

/// Platform-agnostic native microphone capture seam.
///
/// Production code uses [RecordAudioEngine] (`package:record`); unit and widget
/// tests inject a deterministic fake without touching OS audio channels.
abstract class AudioRecorderEngine {
  /// Returns true if microphone permission is granted (requesting it when [request] is true).
  Future<bool> hasPermission({bool request = true});

  /// Starts capturing mono compressed audio into [path] (e.g. `.m4a` AAC-LC at 16 kHz).
  Future<void> start({
    required String path,
    int sampleRate = 16000,
    int bitRate = 32000,
  });

  /// Stops capture and returns the final file path (or null if nothing was captured).
  Future<String?> stop();

  /// Aborts capture immediately and discards any temporary output.
  Future<void> cancel();

  /// Polls live microphone amplitude in dBFS for UI waveform/pulse feedback and silence detection.
  Future<AudioAmplitudeSample> getAmplitude();

  /// Returns true while the native microphone stream is actively recording.
  Future<bool> isRecording();

  /// Releases underlying native recorder resources.
  Future<void> dispose();
}
