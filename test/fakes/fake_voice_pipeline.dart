import 'dart:typed_data';

import 'package:mindreader/core/services/voice/audio_recorder_engine.dart';
import 'package:mindreader/core/services/voice/cloud_transcription_service.dart';
import 'package:mindreader/state/voice_input_controller.dart';

class FakeAudioRecorderEngine implements AudioRecorderEngine {
  FakeAudioRecorderEngine({
    this.permissionGranted = true,
    this.amplitudeSamples = const [
      AudioAmplitudeSample(currentDb: -18.0, maxDb: -16.0),
    ],
  });

  bool permissionGranted;
  List<AudioAmplitudeSample> amplitudeSamples;
  int _sampleCursor = 0;
  bool recording = false;
  String? activePath;
  int startCount = 0;
  int stopCount = 0;
  int cancelCount = 0;
  int disposeCount = 0;

  @override
  Future<bool> hasPermission({bool request = true}) async => permissionGranted;

  @override
  Future<void> start({
    required String path,
    int sampleRate = 16000,
    int bitRate = 32000,
  }) async {
    startCount++;
    recording = true;
    activePath = path;
  }

  @override
  Future<String?> stop() async {
    stopCount++;
    recording = false;
    final p = activePath;
    activePath = null;
    return p;
  }

  @override
  Future<void> cancel() async {
    cancelCount++;
    recording = false;
    activePath = null;
  }

  @override
  Future<AudioAmplitudeSample> getAmplitude() async {
    if (amplitudeSamples.isEmpty) {
      return const AudioAmplitudeSample(currentDb: -160.0, maxDb: -160.0);
    }
    final idx = _sampleCursor < amplitudeSamples.length
        ? _sampleCursor++
        : amplitudeSamples.length - 1;
    return amplitudeSamples[idx];
  }

  @override
  Future<bool> isRecording() async => recording;

  @override
  Future<void> dispose() async {
    disposeCount++;
  }
}

class FakeVoiceTempFileStore implements VoiceTempFileStore {
  FakeVoiceTempFileStore({Uint8List? fakeAudioBytes})
    : fakeAudioBytes = fakeAudioBytes ?? Uint8List.fromList([1, 2, 3, 4, 5, 6]);

  final Uint8List fakeAudioBytes;
  final Set<String> existingFiles = <String>{};
  final List<String> deletedFiles = <String>[];
  int _seq = 0;

  @override
  Future<String> createTempPath({required String extension}) async {
    final path = '/tmp/fake_voice_${++_seq}.$extension';
    existingFiles.add(path);
    return path;
  }

  @override
  Future<Uint8List?> readBytes(String path) async =>
      existingFiles.contains(path) ? fakeAudioBytes : null;

  @override
  Future<void> deleteQuietly(String path) async {
    existingFiles.remove(path);
    deletedFiles.add(path);
  }
}

class FakeAudioTranscriber implements AudioTranscriber {
  FakeAudioTranscriber({
    this.nextTranscript = 'Привет, что ждёт меня на следующей неделе?',
    this.errorToThrow,
  });

  String nextTranscript;
  Object? errorToThrow;
  int calls = 0;
  Uint8List? lastBytes;
  String? lastMimeType;

  @override
  Future<String> transcribe({
    required Uint8List audioBytes,
    required String mimeType,
    String filename = 'voice_note.m4a',
  }) async {
    calls++;
    lastBytes = audioBytes;
    lastMimeType = mimeType;
    if (errorToThrow != null) throw errorToThrow!;
    return nextTranscript;
  }
}
