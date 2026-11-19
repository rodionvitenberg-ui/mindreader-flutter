import 'package:flutter_test/flutter_test.dart';

import 'package:mindreader/core/models/voice_language.dart';
import 'package:mindreader/core/models/voice_state.dart';
import 'package:mindreader/core/services/oracle_voice_service.dart';

import 'fakes/fake_tts_engine.dart';

void main() {
  test('supports exactly the six required spoken languages', () {
    expect(VoiceLanguage.values.map((l) => l.locale).toList(), [
      'en-US',
      'ru-RU',
      'es-ES',
      'pt-BR',
      'de-DE',
      'fr-FR',
    ]);
    expect(VoiceLanguage.fromLocale('ru-RU'), VoiceLanguage.ru);
    expect(VoiceLanguage.fromLocale('xx-XX'), isNull);
  });

  test('VoiceState distinguishes the speaking half from the listening half', () {
    expect(VoiceState.speaking.isSpeaking, isTrue);
    expect(VoiceState.paused.isSpeaking, isTrue);
    expect(VoiceState.idle.isSpeaking, isFalse);
    expect(VoiceState.listening.isListeningHalf, isTrue);
    expect(VoiceState.speaking.isListeningHalf, isFalse);
  });

  test('initialize probes availability and reports a healthy engine', () async {
    final engine = FakeTtsEngine();
    final svc = OracleVoiceService(engine: engine);
    await svc.initialize();
    expect(svc.isAvailable, isTrue);
    expect(svc.state, VoiceState.idle);
    expect(svc.availableLanguages, engine.languages);
  });

  test('initialize reports unavailable when the engine has no voices', () async {
    final engine = FakeTtsEngine()..languages = const [];
    final svc = OracleVoiceService(engine: engine);
    await svc.initialize();
    expect(svc.isAvailable, isFalse);
    expect(svc.state, VoiceState.unavailable);
  });

  test('speak enters the speaking state and notifies the STT duck hook',
      () async {
    final engine = FakeTtsEngine();
    final svc = OracleVoiceService(engine: engine);
    await svc.initialize();

    var started = 0;
    svc.onSpeakingStarted = () => started++;

    await svc.speak('The Fool begins a journey.');
    expect(svc.state, VoiceState.speaking);
    expect(svc.isSpeaking, isTrue);
    expect(engine.lastSpokenText, 'The Fool begins a journey.');
    expect(started, 1);
  });

  test('natural completion returns to idle and releases the mic', () async {
    final engine = FakeTtsEngine();
    final svc = OracleVoiceService(engine: engine);
    await svc.initialize();

    var stopped = 0;
    svc.onSpeakingStopped = () => stopped++;

    await svc.speak('hello');
    engine.fireCompletion();
    expect(svc.state, VoiceState.idle);
    expect(svc.isSpeaking, isFalse);
    expect(stopped, 1);
  });

  test('stop interrupts playback immediately', () async {
    final engine = FakeTtsEngine();
    final svc = OracleVoiceService(engine: engine);
    await svc.initialize();

    await svc.speak('a long answer');
    await svc.stop();
    expect(svc.state, VoiceState.idle);
    expect(engine.stopCalls, 1);
  });

  test('never plays two responses at once: a new speak flushes the old',
      () async {
    final engine = FakeTtsEngine();
    final svc = OracleVoiceService(engine: engine);
    await svc.initialize();

    await svc.speak('first');
    await svc.speak('second');

    expect(engine.stopCalls, 1); // the first was interrupted
    expect(engine.speakCalls, 2);
    expect(engine.lastSpokenText, 'second');
    expect(svc.state, VoiceState.speaking);
  });

  test('unavailable TTS degrades to text-only: speak is a silent no-op',
      () async {
    final engine = FakeTtsEngine()..languages = const [];
    final svc = OracleVoiceService(engine: engine);
    await svc.initialize();

    await svc.speak('the reading continues as text');
    expect(engine.speakCalls, 0); // no speech attempt at all
    expect(svc.state, VoiceState.unavailable);
  });

  test('mute silences playback and is idempotent', () async {
    final engine = FakeTtsEngine();
    final svc = OracleVoiceService(engine: engine);
    await svc.initialize();

    await svc.setMuted(true);
    expect(svc.isMuted, isTrue);
    expect(svc.state, VoiceState.muted);

    await svc.speak('should not speak');
    expect(engine.speakCalls, 0);

    await svc.setMuted(false);
    expect(svc.isMuted, isFalse);
    expect(svc.state, VoiceState.idle);
  });

  test('muting mid-sentence stops the current utterance', () async {
    final engine = FakeTtsEngine();
    final svc = OracleVoiceService(engine: engine);
    await svc.initialize();

    await svc.speak('ongoing');
    await svc.setMuted(true);
    expect(engine.stopCalls, 1);
    expect(svc.state, VoiceState.muted);
  });

  test('setLanguage delegates to the engine and updates the locale', () async {
    final engine = FakeTtsEngine();
    final svc = OracleVoiceService(engine: engine);
    await svc.initialize();

    await svc.setLanguage('ru-RU');
    expect(svc.locale, 'ru-RU');
    expect(engine.lastSetLanguage, 'ru-RU');
  });

  test('isLanguageAvailable delegates to the engine per locale', () async {
    final engine = FakeTtsEngine();
    final svc = OracleVoiceService(engine: engine);
    await svc.initialize();

    expect(await svc.isLanguageAvailable('de-DE'), isTrue);
    expect(await svc.isLanguageAvailable('xx-XX'), isFalse);
  });

  test('an engine error moves the state to error and releases the mic',
      () async {
    final engine = FakeTtsEngine();
    final svc = OracleVoiceService(engine: engine);
    await svc.initialize();

    var stopped = 0;
    svc.onSpeakingStopped = () => stopped++;

    await svc.speak('hello');
    engine.fireError('engine exploded');
    expect(svc.state, VoiceState.error);
    expect(stopped, 1);
  });
}
