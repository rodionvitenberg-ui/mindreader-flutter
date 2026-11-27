import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mindreader/core/models/spread_type.dart';
import 'package:mindreader/core/services/voice/audio_recorder_engine.dart';
import 'package:mindreader/core/services/voice/cloud_transcription_service.dart';
import 'package:mindreader/design_system/taro.dart';
import 'package:mindreader/features/digital_table/widgets/gemini_input_capsule.dart';
import 'package:mindreader/features/digital_table/widgets/spread_check_in_sheet.dart';
import 'package:mindreader/state/app_settings_controller.dart';
import 'package:mindreader/state/deck_pack_controller.dart';
import 'package:mindreader/state/session_history_controller.dart';
import 'package:mindreader/state/spread_session_snapshot.dart';
import 'package:mindreader/state/voice_input_controller.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes/fake_voice_pipeline.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('VoiceInputController safeguards & privacy cleanup', () {
    test(
      'triggers pre-roll haptic, polls amplitude, transcribes Russian with punctuation, and deletes temp file',
      () async {
        var now = DateTime(2026, 11, 24, 19, 30, 0);
        var hapticCount = 0;
        final recorder = FakeAudioRecorderEngine(
          amplitudeSamples: const [
            AudioAmplitudeSample(currentDb: -22.0, maxDb: -20.0),
            AudioAmplitudeSample(currentDb: -12.0, maxDb: -10.0),
          ],
        );
        final tempStore = FakeVoiceTempFileStore();
        final transcriber = FakeAudioTranscriber(
          nextTranscript: 'Что ждёт меня в новом проекте, стоит ли соглашаться?',
        );

        final ctrl = VoiceInputController(
          recorder: recorder,
          transcriber: transcriber,
          tempStore: tempStore,
          clock: () => now,
          hapticConfirm: () async => hapticCount++,
          preRollDelay: const Duration(milliseconds: 10),
          amplitudePollInterval: const Duration(milliseconds: 10),
        );
        final owner = Object();

        final startErr = await ctrl.startRecording(owner: owner);
        expect(startErr, isNull);
        expect(ctrl.state, VoiceInputState.recording);
        expect(hapticCount, 1);
        expect(tempStore.existingFiles, hasLength(1));

        // Let amplitude polling tick once and advance clock beyond 0.6s guard.
        await Future<void>.delayed(const Duration(milliseconds: 25));
        expect(ctrl.amplitudeLevel, greaterThan(0.5));
        now = now.add(const Duration(milliseconds: 1500));

        final result = await ctrl.stopAndTranscribe(owner: owner);
        expect(result.isSuccess, isTrue);
        expect(
          result.text,
          'Что ждёт меня в новом проекте, стоит ли соглашаться?',
        );
        expect(transcriber.calls, 1);
        expect(transcriber.lastMimeType, 'audio/mp4');
        // Privacy invariant: temp file is immediately removed.
        expect(tempStore.existingFiles, isEmpty);
        expect(tempStore.deletedFiles, hasLength(1));
        expect(ctrl.state, VoiceInputState.idle);
        ctrl.dispose();
      },
    );

    test('short accidental tap (< 0.6s) skips network call and deletes temp file', () async {
      var now = DateTime(2026, 11, 24, 19, 30, 0);
      final recorder = FakeAudioRecorderEngine();
      final tempStore = FakeVoiceTempFileStore();
      final transcriber = FakeAudioTranscriber();

      final ctrl = VoiceInputController(
        recorder: recorder,
        transcriber: transcriber,
        tempStore: tempStore,
        clock: () => now,
        hapticConfirm: () async {},
        preRollDelay: Duration.zero,
      );
      final owner = Object();

      await ctrl.startRecording(owner: owner);
      now = now.add(const Duration(milliseconds: 350));
      final result = await ctrl.stopAndTranscribe(owner: owner);

      expect(result.kind, VoiceInputOutcomeKind.tooShort);
      expect(transcriber.calls, 0);
      expect(tempStore.existingFiles, isEmpty);
      expect(tempStore.deletedFiles, hasLength(1));
      ctrl.dispose();
    });

    test('silent recording (< -45 dBFS) skips network call and deletes temp file', () async {
      var now = DateTime(2026, 11, 24, 19, 30, 0);
      final recorder = FakeAudioRecorderEngine(
        amplitudeSamples: const [
          AudioAmplitudeSample(currentDb: -60.0, maxDb: -52.0),
        ],
      );
      final tempStore = FakeVoiceTempFileStore();
      final transcriber = FakeAudioTranscriber();

      final ctrl = VoiceInputController(
        recorder: recorder,
        transcriber: transcriber,
        tempStore: tempStore,
        clock: () => now,
        hapticConfirm: () async {},
        preRollDelay: Duration.zero,
      );
      final owner = Object();

      await ctrl.startRecording(owner: owner);
      now = now.add(const Duration(seconds: 2));
      final result = await ctrl.stopAndTranscribe(owner: owner);

      expect(result.kind, VoiceInputOutcomeKind.tooQuiet);
      expect(transcriber.calls, 0);
      expect(tempStore.existingFiles, isEmpty);
      expect(tempStore.deletedFiles, hasLength(1));
      ctrl.dispose();
    });

    test('deletes temp file even when cloud transcription fails with network error', () async {
      var now = DateTime(2026, 11, 24, 19, 30, 0);
      final recorder = FakeAudioRecorderEngine();
      final tempStore = FakeVoiceTempFileStore();
      final transcriber = FakeAudioTranscriber(
        errorToThrow: const TranscriptionException(
          TranscriptionErrorKind.network,
          'offline',
        ),
      );

      final ctrl = VoiceInputController(
        recorder: recorder,
        transcriber: transcriber,
        tempStore: tempStore,
        clock: () => now,
        hapticConfirm: () async {},
        preRollDelay: Duration.zero,
      );
      final owner = Object();

      await ctrl.startRecording(owner: owner);
      now = now.add(const Duration(seconds: 2));
      final result = await ctrl.stopAndTranscribe(owner: owner);

      expect(result.kind, VoiceInputOutcomeKind.networkError);
      expect(tempStore.existingFiles, isEmpty);
      expect(tempStore.deletedFiles, hasLength(1));
      expect(ctrl.state, VoiceInputState.idle);
      ctrl.dispose();
    });

    test('denied microphone permission returns permissionDenied cleanly', () async {
      final recorder = FakeAudioRecorderEngine(permissionGranted: false);
      final tempStore = FakeVoiceTempFileStore();
      final ctrl = VoiceInputController(
        recorder: recorder,
        transcriber: FakeAudioTranscriber(),
        tempStore: tempStore,
        hapticConfirm: () async {},
        preRollDelay: Duration.zero,
      );

      final early = await ctrl.startRecording(owner: Object());
      expect(early?.kind, VoiceInputOutcomeKind.permissionDenied);
      expect(recorder.startCount, 0);
      expect(tempStore.existingFiles, isEmpty);
      ctrl.dispose();
    });
  });

  group('CloudTranscriptionService multilingual routes', () {
    test('Gemini native route sends inline_data audio and returns clean Cyrillic with punctuation', () async {
      Uri? capturedUri;
      Map<String, dynamic>? capturedBody;
      final client = MockClient((request) async {
        capturedUri = request.url;
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': '«Привет! Как пройдёт эта неделя?»'},
                  ],
                },
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = CloudTranscriptionService(
        client: client,
        sttUrl: '',
        cloudUrl:
            'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions',
        cloudKey: 'test-gemini-key',
        cloudModel: 'gemini-2.5-flash',
      );
      final text = await service.transcribe(
        audioBytes: Uint8List.fromList([10, 20, 30]),
        mimeType: 'audio/mp4',
      );

      expect(
        capturedUri.toString(),
        contains('/models/gemini-2.5-flash:generateContent'),
      );
      final parts =
          ((capturedBody!['contents'] as List).first as Map)['parts'] as List;
      expect((parts.first as Map)['inline_data']['mime_type'], 'audio/mp4');
      expect(text, 'Привет! Как пройдёт эта неделя?');
    });

    test('Whisper multipart route omits fixed language for true Auto Language Detection', () async {
      String? bodyText;
      final client = MockClient((request) async {
        bodyText = request.body;
        return http.Response(
          jsonEncode({'text': 'Should I move — или лучше подождать до весны?'}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = CloudTranscriptionService(
        client: client,
        sttUrl: 'https://api.example.com/v1/audio/transcriptions',
        sttKey: 'whisper-key',
        sttModel: 'whisper-large-v3',
      );
      final text = await service.transcribe(
        audioBytes: Uint8List.fromList([1, 2, 3, 4]),
        mimeType: 'audio/mp4',
      );

      expect(bodyText, contains('whisper-large-v3'));
      expect(bodyText, isNot(contains('name="language"')));
      expect(text, 'Should I move — или лучше подождать до весны?');
    });
  });

  testWidgets(
    'GeminiInputCapsule & SpreadCheckInSheet wire upgraded VoiceInputController end-to-end',
    (tester) async {
      var now = DateTime(2026, 11, 24, 19, 30, 0);
      final voice = VoiceInputController(
        recorder: FakeAudioRecorderEngine(),
        transcriber: FakeAudioTranscriber(
          nextTranscript: 'Да, всё сложилось именно так!',
        ),
        tempStore: FakeVoiceTempFileStore(),
        clock: () => now,
        hapticConfirm: () async {},
        preRollDelay: Duration.zero,
      );
      addTearDown(voice.dispose);

      final capsuleController = TextEditingController();
      addTearDown(capsuleController.dispose);

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: voice,
          child: MaterialApp(
            theme: buildTaroTheme(),
            home: Scaffold(
              body: GeminiInputCapsule(
                controller: capsuleController,
                onSend: (_) {},
                onPlus: () {},
              ),
            ),
          ),
        ),
      );

      final mic = find.byKey(const ValueKey('capsule-voice-mic'));
      await tester.tap(mic);
      await tester.pump();
      expect(voice.isRecording, isTrue);

      now = now.add(const Duration(seconds: 2));
      await tester.tap(mic);
      await tester.pumpAndSettle();
      expect(capsuleController.text, 'Да, всё сложилось именно так!');

      // Also verify Reflection Notes sheet has the upgraded voice mic button.
      final history = SessionHistoryController()..load();
      final snapshot = SpreadSessionSnapshot(
        timestamp: DateTime(2026, 11, 10).toIso8601String(),
        spreadType: SpreadType.one,
        notebook: 'all',
        cards: const [
          RestoredSpreadCard(cardId: 17, reversed: false, role: 'Anchor'),
        ],
        sessionNotes: const [],
        synthesis: null,
        chapters: const [],
        messages: const [],
      );
      await history.upsert(snapshot);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AppSettingsController()),
            ChangeNotifierProvider(create: (_) => DeckPackController()),
            ChangeNotifierProvider.value(value: history),
            ChangeNotifierProvider.value(value: voice),
          ],
          child: MaterialApp(
            theme: buildTaroTheme(),
            home: Scaffold(body: SpreadCheckInSheet(snapshot: snapshot)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final reflectionMic = find.byKey(const ValueKey('checkin-note-mic'));
      expect(reflectionMic, findsOneWidget);
      await tester.tap(reflectionMic);
      await tester.pump();
      now = now.add(const Duration(seconds: 2));
      await tester.tap(reflectionMic);
      await tester.pumpAndSettle();
      expect(find.text('Да, всё сложилось именно так!'), findsOneWidget);
    },
  );
}
