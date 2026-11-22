import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mindreader/core/models/custom_spread.dart';
import 'package:mindreader/core/models/dealt_card_slot.dart';
import 'package:mindreader/core/models/divination_system.dart';
import 'package:mindreader/core/models/spread_type.dart';
import 'package:mindreader/core/services/oracle_backend_service.dart';
import 'package:mindreader/core/services/oracle_synthesis_service.dart';
import 'package:mindreader/core/services/oracle_voice_service.dart';
import 'package:mindreader/core/services/reading_relationships.dart';
import 'package:mindreader/design_system/taro.dart';
import 'package:mindreader/features/digital_table/oracle_chat_pane.dart';
import 'package:mindreader/features/digital_table/table_workspace.dart';
import 'package:mindreader/features/digital_table/widgets/gemini_input_capsule.dart';
import 'package:mindreader/features/digital_table/widgets/tarot_card_3d_widget.dart';
import 'package:mindreader/features/profile/widgets/profile_header.dart';
import 'package:mindreader/state/app_settings_controller.dart';
import 'package:mindreader/state/deck_pack_controller.dart';
import 'package:mindreader/state/oracle_session_controller.dart';
import 'package:mindreader/state/session_history_controller.dart';
import 'package:mindreader/state/spread_controller.dart';
import 'package:mindreader/state/spread_session_snapshot.dart';
import 'package:mindreader/state/user_profile_controller.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _reading = StructuredSynthesis(
  narrative: 'An answer from the configured service.',
  elementalAlchemy: 'Fire and water.',
  verdict: 'Take one step.',
  followUp: 'What changed?',
);

class _DeferredOracle extends OracleSynthesisService {
  final requests = <Completer<StructuredSynthesis>>[];
  final clarifiers = <Completer<String>>[];
  String? question;
  String? subject;

  @override
  Future<StructuredSynthesis> synthesizeStructured({
    required List<DealtCardSlot> slots,
    SpreadType? type,
    String? spreadLabel,
    String? focusLine,
    DivinationSystem system = DivinationSystem.tarot,
    String? contextChip,
    Map<int, String>? slotContexts,
    String? profileContext,
    List<String>? positionQuestions,
    List<ReadingRelationship>? relationships,
  }) {
    question = contextChip;
    subject = profileContext;
    final request = Completer<StructuredSynthesis>();
    requests.add(request);
    return request.future;
  }

  @override
  Future<String> synthesizeClarifier({
    required String question,
    required DealtCardSlot newSlot,
    required List<DealtCardSlot> previous,
    String? profileContext,
  }) {
    final result = Completer<String>();
    clarifiers.add(result);
    return result.future;
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });
  final start = find.text('✦ SYNTHESIZE IN CHAT →');
  final prepField = find.descendant(
    of: find.byType(OracleChatPane),
    matching: find.byKey(const ValueKey('reading-context')),
  );
  final composer = find.byType(GeminiInputCapsule);
  final toggle = find.byKey(const ValueKey('oracle-rail-toggle'));
  final rail = find.byKey(const ValueKey('oracle-card-rail'));
  final preview = find.byKey(const ValueKey('oracle-card-preview'));
  Finder thumb(int index) => find.byKey(ValueKey('oracle-rail-slot-$index'));

  Future<void> openPane(WidgetTester tester, int index) async {
    tester
        .widget<PageView>(find.byType(PageView))
        .controller!
        .jumpToPage(index);
    await tester.pump();
  }

  Future<void> open(
    WidgetTester tester,
    SpreadController spread,
    OracleSynthesisService service, {
    OracleBackendService? backend,
  }) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    spread.activateSpread();
    for (var i = 0; i < spread.spreadCardCount; i++) {
      spread.dealNextCard();
      spread.flipSlot(i);
    }
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: spread),
          ChangeNotifierProvider(create: (_) => OracleSessionController()),
          ChangeNotifierProvider(create: (_) => OracleVoiceService()),
          ChangeNotifierProvider(create: (_) => DeckPackController()),
          ChangeNotifierProvider(
            create: (_) => SessionHistoryController()..load(),
          ),
          ChangeNotifierProvider(create: (_) => AppSettingsController()),
          ChangeNotifierProvider(create: (_) => UserProfileController()),
        ],
        child: MaterialApp(
          theme: buildTaroTheme(),
          home: Scaffold(
            body: TableWorkspace(
              oracleService: service,
              oracleBackend: backend,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await openPane(tester, chatPane);
  }

  Future<void> pumpTransition(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump();
  }

  testWidgets('preparation survives waiting, failure and a successful retry', (
    tester,
  ) async {
    final service = _DeferredOracle();
    final spread = SpreadController()..setSpreadType(SpreadType.one);
    await open(tester, spread, service);
    expect(find.text('YOUR SPREAD IS READY'), findsOneWidget);
    expect(composer, findsNothing);
    expect(toggle, findsNothing);

    const question = 'What can I do about work?';
    await tester.tap(find.text('FOR SOMEONE ELSE'));
    await tester.enterText(prepField, question);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.tap(start);
    await tester.tap(start);
    await tester.pump();
    expect(service.requests, hasLength(1));
    expect(find.text('CONNECTING TO THE ORACLE…'), findsOneWidget);
    expect(tester.widget<TextField>(prepField).controller!.text, question);
    expect(composer, findsNothing);
    expect(toggle, findsNothing);
    expect(service.question, question);
    expect(service.subject, 'Reading for someone else');

    service.requests.last.completeError(StateError('request interrupted'));
    await tester.pump();
    expect(find.textContaining('could not finish'), findsOneWidget);
    expect(tester.widget<TextField>(prepField).controller!.text, question);
    expect(spread.readingForSelf, isFalse);
    expect(composer, findsNothing);
    expect(toggle, findsNothing);

    await tester.tap(find.text('RETRY SYNTHESIS'));
    await tester.pump();
    expect(service.requests, hasLength(2));
    expect(service.question, question);
    expect(service.subject, 'Reading for someone else');
    expect(composer, findsNothing);
    service.requests.last.complete(_reading);
    await tester.pump();
    expect(find.text(_reading.narrative), findsOneWidget);
    expect(prepField, findsNothing);
    expect(composer, findsOneWidget);
    expect(toggle, findsOneWidget);
    expect(find.text('CURRENT SPREAD'), findsNothing);
    for (final shortcut in [
      '✨ Relationships',
      '⚡ Crossroads',
      '🔮 Blind Draw',
    ]) {
      expect(find.text(shortcut), findsNothing);
    }
    await openPane(tester, tablePane);
    await openPane(tester, chatPane);
    expect(find.text(_reading.narrative), findsOneWidget);
    expect(service.requests, hasLength(2));
  });

  testWidgets('the chosen interpreter handles each turn and survives history', (
    tester,
  ) async {
    const root = '/api/v1';
    const sessionPath = '$root/oracle/sessions/reading-1';
    final positions = <Map<String, Object?>>[];
    final capturedTurns = <(String, Object?)>[];
    var guestRequests = 0;
    final backend = OracleBackendService(
      baseUrl: 'https://oracle.example',
      client: MockClient((request) async {
        http.Response respond(Object value) => http.Response(
          jsonEncode(value),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
        final path = request.url.path;
        if (path == '$root/auth/guest/') {
          guestRequests++;
          return respond({
            'token': 'test-token',
            'expiresAt': DateTime.now()
                .add(const Duration(days: 1))
                .toIso8601String(),
          });
        }
        expect(request.headers['authorization'], 'Bearer test-token');
        if (path == '$root/oracle/personalities/') {
          return respond([
            {'id': 'default', 'name': 'Oracle', 'description': 'Default'},
            {'id': 'sage', 'name': 'Sage', 'description': 'A different voice'},
          ]);
        }
        final post = request.method == 'POST';
        if (post) expect(request.headers['idempotency-key'], isNotEmpty);
        final body = request.body.isEmpty
            ? null
            : jsonDecode(request.body) as Map;
        if (path == '$root/oracle/sessions/') {
          expect(body?['personality'], 'sage');
          expect(body?['question'], 'What matters today?');
          return respond({'sessionId': 'reading-1', 'personality': 'sage'});
        }
        if (path == '$sessionPath/') {
          return respond({'personality': 'sage', 'positions': positions});
        }
        if (path == '$sessionPath/cards/') {
          expect(body?['clarifier'], positions.isNotEmpty);
          positions.add({'position': body?['position'], 'card': body});
          return respond({});
        }
        capturedTurns.add((path, body?['text']));
        if (path == '$sessionPath/synthesize/') {
          expect(positions, hasLength(2));
          return respond({
            'narrative': 'A remote reading by Sage',
            'elementalAlchemy': _reading.elementalAlchemy,
            'verdict': _reading.verdict,
            'followUp': _reading.followUp,
          });
        }
        return respond({'text': 'Sage answer ${capturedTurns.length}'});
      }),
    );
    addTearDown(backend.dispose);
    final local = _DeferredOracle();
    final spread = SpreadController()..setSpreadType(SpreadType.one);
    await open(tester, spread, local, backend: backend);

    final title = find.byKey(const ValueKey('oracle-personality-selector'));
    await tester.tap(title);
    await pumpTransition(tester);
    await tester.tap(find.byKey(const ValueKey('oracle-personality-sage')));
    await pumpTransition(tester);
    expect(
      find.descendant(of: title, matching: find.text('Sage')),
      findsOneWidget,
    );

    const question = 'What matters today?';
    await tester.enterText(prepField, question);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    spread.dealNextCardOrClarifier();
    spread.flipSlot(1);
    await tester.pump();
    await tester.tap(start);
    await pumpTransition(tester);
    expect(find.text('A remote reading by Sage'), findsOneWidget);

    final history = tester.element(title).read<SessionHistoryController>();
    final input = find.byKey(const ValueKey('oracle-input'));
    await tester.enterText(input, 'Can you expand?');
    await tester.tap(find.byKey(const ValueKey('oracle-send')));
    await pumpTransition(tester);
    expect(find.text('Sage answer 2'), findsOneWidget);
    await tester.enterText(input, 'What does an extra card add?');
    await tester.tap(find.text('🃏 +1 CARD FOR MY QUESTION'));
    await pumpTransition(tester);
    expect(spread.slots[2].state, SlotState.faceUp);
    expect(find.text('Sage answer 3'), findsOneWidget);
    expect(positions, hasLength(3));
    expect(capturedTurns, [
      ('$sessionPath/synthesize/', null),
      ('$sessionPath/messages/', 'Can you expand?'),
      ('$sessionPath/clarifiers/2/', 'What does an extra card add?'),
    ]);
    expect(local.requests, isEmpty);
    expect(local.clarifiers, isEmpty);
    expect(guestRequests, 1);
    final saved = SpreadSessionSnapshot.fromJson(
      history.sessions.single.toJson(),
    );
    expect(saved.remoteOracle?.sessionId, 'reading-1');
    expect(saved.remoteOracle?.personalityId, 'sage');
    expect(saved.remoteOracle?.personalityName, 'Sage');

    await tester.tap(title);
    await pumpTransition(tester);
    await tester.tap(find.byKey(const ValueKey('oracle-personality-default')));
    await pumpTransition(tester);
    final dialog = find.byType(AlertDialog);
    final newReading = find.descendant(
      of: dialog,
      matching: find.widgetWithText(TextButton, 'Start a new interpretation'),
    );
    await tester.tap(newReading);
    await pumpTransition(tester);
    expect(
      find.descendant(of: title, matching: find.text('Oracle')),
      findsOneWidget,
    );
    expect(find.text('YOUR SPREAD IS READY'), findsOneWidget);
    expect(history.sessions.single.remoteOracle?.personalityId, 'sage');

    await openPane(tester, historyPane);
    await tester.tap(find.text('1 · DAILY ANCHOR'));
    await pumpTransition(tester);
    expect(
      find.descendant(of: title, matching: find.text('Sage')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(OracleChatPane),
        matching: find.text('A remote reading by Sage'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the local interpreter stays available without the catalogue', (
    tester,
  ) async {
    final backend = OracleBackendService(
      baseUrl: 'https://oracle.example',
      client: MockClient((request) async {
        expect(request.url.path, '/api/v1/auth/guest/');
        return http.Response('{}', 503);
      }),
    );
    addTearDown(backend.dispose);
    final local = _DeferredOracle();
    final spread = SpreadController()..setSpreadType(SpreadType.one);
    await open(tester, spread, local, backend: backend);

    final title = find.byKey(const ValueKey('oracle-personality-selector'));
    await tester.tap(title);
    await pumpTransition(tester);
    expect(
      find.text('Online interpreters are currently unavailable.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('oracle-personality-')));
    await pumpTransition(tester);
    expect(
      find.descendant(of: title, matching: find.text('Local Oracle')),
      findsOneWidget,
    );
    await tester.tap(start);
    await tester.pump();
    local.requests.single.complete(_reading);
    await pumpTransition(tester);
    expect(find.text(_reading.narrative), findsOneWidget);
  });

  testWidgets('a late answer cannot open chat for a reset spread', (
    tester,
  ) async {
    final service = _DeferredOracle();
    final spread = SpreadController()..setSpreadType(SpreadType.one);
    await open(tester, spread, service);
    await tester.tap(start);
    await tester.pump();
    spread.resetTable();
    service.requests.single.complete(_reading);
    await tester.pump();
    expect(find.text('NO READING YET'), findsOneWidget);
    expect(find.text(_reading.narrative), findsNothing);
    expect(composer, findsNothing);
    expect(toggle, findsNothing);
  });

  testWidgets(
    'the 12-card rail scrolls and reflows only the message viewport',
    (tester) async {
      final service = _DeferredOracle();
      final spread = SpreadController()
        ..setCustomSpread(
          CustomSpreadConfig.fromQuestions(
            questions: [for (var i = 1; i <= 12; i++) 'Question $i'],
          ),
        );
      await open(tester, spread, service);
      spread.slots[11].isReversed = true;
      final packs = tester.element(prepField).read<DeckPackController>();
      await packs.setActivePack('marseille');
      await tester.pump();
      await tester.tap(start);
      await tester.pump();
      expect(service.question, isNull);
      service.requests.single.complete(_reading);
      await tester.pump();
      final header = find.descendant(
        of: find.byType(OracleChatPane),
        matching: find.byType(ProfileHeader),
      );
      final viewport = find.byKey(const ValueKey('oracle-message-viewport'));
      final narrative = find.text(_reading.narrative);
      final headerRect = tester.getRect(header);
      final composerRect = tester.getRect(composer);
      final viewportRect = tester.getRect(viewport);
      final narrativeWidth = tester.getSize(narrative).width;
      expect(rail, findsNothing);

      await tester.tap(toggle);
      await pumpTransition(tester);
      expect(tester.getRect(header), headerRect);
      expect(tester.getRect(composer), composerRect);
      expect(tester.getRect(viewport), viewportRect);
      expect(tester.getSize(narrative).width, lessThan(narrativeWidth));
      expect(
        tester.getTopLeft(rail).dy,
        greaterThanOrEqualTo(viewportRect.top),
      );
      expect(
        tester.getBottomLeft(rail).dy,
        lessThanOrEqualTo(viewportRect.bottom),
      );
      expect(
        tester.getTopLeft(thumb(0)).dy,
        lessThan(tester.getTopLeft(thumb(1)).dy),
      );

      final list = find.descendant(of: rail, matching: find.byType(Scrollable));
      await tester.scrollUntilVisible(thumb(11), 230, scrollable: list);
      final lastArt = find.descendant(
        of: thumb(11),
        matching: find.byType(TarotCard3DWidget),
      );
      final last = tester.widget<TarotCard3DWidget>(lastArt);
      expect(last.card.id, spread.slots[11].card!.id);
      expect(last.isReversed, spread.slots[11].isReversed);
      await tester.pumpAndSettle();
      final artName = last.card.id.toString().padLeft(2, '0');
      final selectedArt = find.descendant(
        of: lastArt,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName ==
                  'assets/decks/marseille/$artName.jpg',
        ),
      );
      expect(selectedArt, findsOneWidget);
      final thumbSize = tester.getSize(lastArt);
      await tester.tap(thumb(11));
      await pumpTransition(tester);
      expect(preview, findsOneWidget);
      final largeArt = find.descendant(
        of: preview,
        matching: find.byType(TarotCard3DWidget),
      );
      expect(tester.getSize(largeArt).width, greaterThan(thumbSize.width));
      expect(
        tester.widget<TarotCard3DWidget>(largeArt).isReversed,
        last.isReversed,
      );
      await tester.binding.handlePopRoute();
      await pumpTransition(tester);

      final position = tester.state<ScrollableState>(list).position;
      final offset = position.pixels;
      final nextId = spread.deckTop.first.id;
      await tester.enterText(
        find.byKey(const ValueKey('oracle-input')),
        'What does the next card add?',
      );
      await tester.tap(find.text('🃏 +1 CARD FOR MY QUESTION'));
      await tester.pump();
      expect(service.clarifiers.single.isCompleted, isFalse);
      expect(spread.slots[12].state, SlotState.faceUp);
      expect(spread.slots[12].card!.id, nextId);
      expect(tester.getRect(composer), composerRect);
      expect(tester.getRect(header), headerRect);
      expect(position.pixels, offset);
      position.jumpTo(position.maxScrollExtent);
      await tester.pump();
      expect(thumb(12).hitTestable(), findsOneWidget);

      service.clarifiers.single.complete('The card adds a practical step.');
      await tester.pump();
      spread.dealNextCardOrClarifier();
      spread.flipSlot(13);
      await tester.pump();
      expect(service.clarifiers, hasLength(1));

      tester.view.viewInsets = const FakeViewPadding(bottom: 230);
      addTearDown(tester.view.resetViewInsets);
      await tester.pump();
      expect(
        tester.getRect(rail).bottom,
        lessThan(tester.getRect(composer).top),
      );
      await tester.enterText(
        find.byKey(const ValueKey('oracle-input')),
        'A follow-up',
      );
      await tester.tap(find.byKey(const ValueKey('oracle-send')));
      await tester.pump();
      expect(find.text('A follow-up'), findsOneWidget);
      tester.view.resetViewInsets();
      await tester.pump();
      await tester.tap(toggle);
      await pumpTransition(tester);
      expect(rail, findsNothing);
      expect(tester.getRect(header), headerRect);
      expect(tester.getRect(composer), composerRect);
    },
  );
}
