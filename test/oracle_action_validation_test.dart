import 'package:flutter_test/flutter_test.dart';

import 'package:mindreader/core/models/oracle_action.dart';

void main() {
  group('OracleAction wire names', () {
    test('all nine actions round-trip their wire name', () {
      for (final a in OracleAction.values) {
        expect(OracleActionX.fromWire(a.wireName), a);
      }
    });

    test('unknown/absent action degrades to respond', () {
      expect(OracleActionX.fromWire('mutateCards'), OracleAction.respond);
      expect(OracleActionX.fromWire(null), OracleAction.respond);
      expect(OracleActionX.fromWire(''), OracleAction.respond);
    });
  });

  group('parseOracleActionResponse', () {
    test('plain prose -> respond carrying the prose', () {
      final cmd = parseOracleActionResponse('The Fool begins a journey.');
      expect(cmd.action, OracleAction.respond);
      expect(cmd.text, 'The Fool begins a journey.');
      expect(cmd.hasAction, isFalse);
    });

    test('malformed JSON -> respond carrying the raw text', () {
      final cmd = parseOracleActionResponse('{"action": not-json');
      expect(cmd.action, OracleAction.respond);
      expect(cmd.text, '{"action": not-json');
    });

    test('valid action JSON parses the action and text', () {
      final cmd = parseOracleActionResponse(
        '{"action": "requestNextCard", "text": "Draw one more card."}',
      );
      expect(cmd.action, OracleAction.requestNextCard);
      expect(cmd.text, 'Draw one more card.');
      expect(cmd.hasAction, isTrue);
    });

    test('requestReveal carries a validated non-negative position', () {
      final cmd = parseOracleActionResponse(
        '{"action": "requestReveal", "text": "Reveal this.", "position": 2}',
      );
      expect(cmd.action, OracleAction.requestReveal);
      expect(cmd.position, 2);
    });

    test('position is dropped for non-positional actions and negatives', () {
      final respond = parseOracleActionResponse(
        '{"action": "respond", "text": "hi", "position": 5}',
      );
      expect(respond.position, isNull);

      final negative = parseOracleActionResponse(
        '{"action": "requestReveal", "text": "hi", "position": -1}',
      );
      expect(negative.position, isNull);
    });

    test('the app is authoritative: forbidden keys are silently dropped', () {
      final cmd = parseOracleActionResponse(
        '{"action": "requestNextCard", "text": "ok", '
        '"cards": [{"cardId": "tarot:99", "orientation": "reversed"}], '
        '"canonicalCardId": "tarot:99", "orientation": "reversed", '
        '"bypassLimit": true, "pro": true, "history": []}',
      );
      // The injected card/identity/limit/PRO/history keys cannot reach the
      // command type — it only ever carries action + text + (safe) position.
      expect(cmd.action, OracleAction.requestNextCard);
      expect(cmd.text, 'ok');
      expect(cmd.position, isNull);
    });
  });
}
