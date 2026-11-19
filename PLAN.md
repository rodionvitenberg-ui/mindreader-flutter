# MINDREADER.QUEST — ПЛАН РАСШИРЕНИЯ: PHYSICAL READING & LIVE ORACLE

> Master Implementation Specification v1.0 → пошаговый план для агентов.
> План атомарный: каждый шаг = отдельная сессия. После каждого шага — STOP.
> SSOT состояния = TASK_STATE.json (по .clinerules). PLAN.md — маршрут, не состояние.

## СТАТУС
- Phase 0 (Vision Engine): DEFERRED.
- Phase 1 (Camera & Session Architecture): DONE — 1.1 + 1.2 + 1.3 + 1.4 + 1.5 + 1.6 + 1.7 DONE
  (domain enums, stable sessionId/snapshot extension, OracleSessionController,
  Vision Engine contract, Camera UI redesign, CardOverlayPainter, Resource
  lifecycle). Acceptance criteria passed.
- Phase 2 (Quick Scan & Table): DONE — 2.1 + 2.2 + 2.3 + 2.4 DONE
  (SpreadInferenceService, Recognition Review sheet, generalized Camera→Table
  handoff, physical clarifier; PRO restrictions centrally disabled for
  pre-launch). Acceptance criteria passed.
- Phase 3 (Guided Physical Spread): DONE — 3.1 + 3.2 + 3.3 + 3.4 + 3.5 + 3.6 DONE.
  Acceptance criteria passed.
- Phase 4 (Live Oracle & Voice): IN PROGRESS — 4.1 DONE (Shared Oracle session
  VERIFIED: single OracleSessionController across all tabs; new
  test/oracle_shared_session_test.dart incl. Camera↔Table↔Oracle continuity).
  4.2 DONE (OracleVoiceService + flutter_tts ^4.2.5 research; TtsEngine seam;
  392/392 green).
- Phase 5 (Unification & QA): PENDING.

## РЕЗУЛЬТАТЫ АУДИТА РЕПОЗИТОРИЯ (фиксируются как исходная точка)
Git HEAD: 3c78343 (после 0a29878). PLAN.md был удалён в рабочем дереве — пересоздан.
Стек: Flutter/Dart + provider, camera 0.12.2, image_picker, image, http,
shared_preferences, google_fonts, speech_to_text 7.5.0, flutter_local_notifications.
Провайдеры (lib/main.dart): SpreadController, DeckPackController, AstralController,
AppSettingsController, SessionHistoryController(..load()), UserProfileController.

1. Диалог: SynthesisSession _synthesis — локальное состояние _TableWorkspaceState
   (lib/features/digital_table/table_workspace.dart:68). НЕ общий. → вынести.
2. ID сессии: _sessionTimestamp = DateTime.now().toIso8601String() (там же, :263);
   архивная идентичность = timestamp (SessionHistoryController.upsert).
3. Сохранение: _captureSession() → upsert(SpreadSessionSnapshot.capture(...)),
   только при hasSynthesis.
4. Восстановление: _restoreSession() → ctrl.restoreSpread + synthesis.restore →
   _goToPane(chatPane) (там же, :432).
5. Camera→Table: CameraScanScreen._scan() → loadScannedSpreadFaceUp (tarot, face-up)
   или completeClarifierScan → onHandoff() → shell _switchTo(1).
6. physicalCameraSync: TableSourceMode.physicalCameraSync (dealt_card_slot.dart:13);
   лента "PHYSICAL SYNC" (table_workspace.dart:590).
7. Доп. физ. карта: onOpenCameraClarifier → _switchTo(0); камера: clarifierScanRequested
   → completeClarifierScan (spread_controller.dart:541).
8. Переиспользуемое: SpreadController, DealtCardSlot/DivinationCard, SpreadType/
   LenormandSpread/RuneCast, SpreadSessionSnapshot, SessionHistoryController,
   OracleSynthesisService (synthesize/synthesizeStructured/synthesizeClarifier/
   answerChat/...), VisionScannerService.detectSpread(jpeg, cardCount),
   Step1 "Choose Spread" (digital_table_screen.dart + spread_blueprint_carousel.dart),
   AppColors, google_fonts, speech_to_text.
9. Необходимо: общий контроллер диалога; enums ReadingSource/ReadingMode/ReadingStatus;
   стабильный sessionId; Vision-контракт; spread inference; FSM Guided; voice-сервис.
   TTS отсутствует (нет flutter_tts) — research в Phase 4.

## ГЛОБАЛЬНЫЕ АРХИТЕКТУРНЫЕ РЕШЕНИЯ (инварианты для всех фаз)
- ЕДИНСТВЕННЫЙ источник истины карт: SpreadController.
- ЕДИНСТВЕННЫЙ источник истины диалога: новый OracleSessionController (см. 1.3),
  разделяется Camera/Table/Oracle. SynthesisSession остаётся моделью состояния.
- SpreadController НЕ дублируется; LiveReadingController (если нужен) управляет
  процессом физического взаимодействия, но не хранит копию расклада.
- Одна история (SessionHistoryController); никаких отдельных Camera/Live-Oracle историй.
- Один sessionId на всю сессию; переключение вкладок его не меняет.
- TableSourceMode сохраняем (slot/table-level источник); ReadingSource — session-level.
  Маппинг в ОДНОМ месте: digitalDeck→digital, physicalCameraSync→physical.
- Старые JSON-снимки загружаются без ошибок (паттерн _enumOr + optional keys).
- Hard cap 10 карт (SpreadController.maxTableCards) НЕ трогаем.
- Lenormand без реверсов, симметричные руны без merkstave — уже гарантировано
  dealCardAt; в физических потоках повторно применять те же правила.

---

# PHASE 1 — CAMERA & SESSION ARCHITECTURE

## 1.0 Pre-flight (1 сессия)
1. git status; зафиксировать baseline; PLAN.md (этот файл) — уже пересоздан.
2. Обновить TASK_STATE.json: status=IN_PROGRESS, active_feature_or_sprint="Phase 1".
3. Снимок счётчика тестов: `flutter test` до изменений (~254+ green).
STOP → отчёт.

## 1.1 Доменные enum + модели (1 сессия) — DONE
Создать (lib/core/models/):
- reading_source.dart: enum ReadingSource { digital, physical }
- reading_mode.dart: enum ReadingMode { standard, quickScan, guidedSpread, liveOracle }
- reading_status.dart: enum ReadingStatus { idle, preparing, active, paused, completed,
  cancelled, failed }
Тесты: test/reading_enums_test.dart — переходы статусов (idle→preparing→active→...),
сохранение source/mode. НЕ дублировать TableSourceMode (документировать маппинг в коде).
STOP.

## 1.2 Стабильный sessionId + расширение снимка (1 сессия) — DONE
1. SpreadSessionSnapshot: добавить optional поля readingSource/readingMode/
   readingStatus/completionStatus/voiceUsed + factory/JSON (backward-compatible:
   отсутствующие ключи → null/default, старые снимки грузятся).
2. Добавить sessionId (optional; fallback = timestamp). Archive-ключ остаётся timestamp.
3. Тесты: session_snapshot_test.dart расширить — legacy JSON грузится, новые поля
   round-trip.
STOP.

## 1.3 OracleSessionController — вынос диалога (КЛЮЧЕВОЙ шаг, 1-2 сессии)
1. Создать lib/state/oracle_session_controller.dart (ChangeNotifier):
   - оборачивает SynthesisSession (или поглощает её поля) + sessionId + readingSource/
     readingMode/readingStatus;
   - методы addUserMessage/addOracleMessage/beginAnswer/finishAnswer/restore/reset/
     markInitial/completeChapter + сохранение статуса сессии.
2. Зарегистрировать в main.dart MultiProvider.
3. Рефакторинг TableWorkspace: заменить _synthesis на provider-контроллер; поведение
   _runSynthesis/_askOracle/_captureSession/_restoreSession/_maybeExpandClarifiers
   сохранить 1:1 (код переносится, не переписывается).
4. GATE: flutter analyze + полный flutter test, без регрессий Table/History.
STOP.

## 1.4 Vision Engine contract (1 сессия)
Создать lib/core/services/vision/:
- vision_engine.dart: abstract VisionEngine (initialize/scanImage/startSession/
  processFrame/stopSession/dispose — async + cancellable + DI), VisionCapabilities,
  VisionFrame (normalized 0..1, source size, rotation, corners), VisionObservation,
  VisionCardCandidate (observationId/trackId/system/canonicalCardId?/deckId?/
  orientation/faceState/recognitionConfidence?/detectionConfidence?/boundingBox?/
  corners?/recognitionStatus/timestamp), VisionScanResult, VisionEvent;
  enums CardFaceState{faceUp,faceDown,unknown}, RecognitionStatus{detected,recognizing,
  recognized,ambiguous,unknown,lost}. Detection != Recognition.
- legacy_vision_adapter.dart: обёртка VisionScannerService; контракт detectSpread
  переработать так, чтобы cardCount был ОПЦИОНАЛЬНЫМ (количество из результата).
- unavailable_vision_engine.dart: честный fallback → ручной ввод через DivinationCard.
- test/fakes/fake_vision_engine.dart: детерминированный (появление/подтверждение/
  неизвестная/перевёрнутая/рубашкой вверх/окклюзия/исчезновение/повтор/много карт/
  неудача/задержка/отмена). Только для тестов и явного debug-режима.
Тесты: vision_contract_test.dart (координаты 0..1, отмена, stale-rejection).
STOP.

## 1.5 Camera UI redesign (1-2 сессии) — DONE
Файл: lib/features/camera_scan/camera_scan_screen.dart (+ widgets/).
1. УДАЛИТЬ ряд _CountChip (1|3|4|7|5|6|10) из build() (там :232-243).
2. widgets/camera_mode_selector.dart: segmented QUICK SCAN | GUIDED SPREAD | LIVE ORACLE;
   активный — лаванда, без layout shift; выбор persist (LocalStorageService ключ
   camera_mode). При активной Guided/Live сессии — подтверждение перед сменой.
3. widgets/camera_top_hud.dart: system selector + flash + gallery (+ optional engine
   status). Fallback для неподдерживаемых систем честный.
4. Контекстные инструкции по режиму (словарь из спеки: POINT AT YOUR SPREAD / …).
5. Сохранить композицию: preview, shutter, lock-on painter, dock.
Тесты: widget — camera_mode_selector_test.dart (3 режима, переключение, persist).
GATE: flutter analyze + flutter test + сборка apk --debug (если окружение доступно).
STOP.

## 1.6 CardOverlayPainter (1 сессия) — DONE
lib/features/camera_scan/widgets/card_overlay_painter.dart:
состояния detected/recognizing/recognized/ambiguous/faceDown/lost (цвета из AppColors:
lavender, conflictAmber), преобразование normalized→viewfinder, RepaintBoundary +
Listenable (не rebuild всего дерева). Debug-only fixtures для тестов. Не рисовать
вымышленные bbox при отсутствии провайдера.
Тесты: card_overlay_painter_test.dart.
STOP.

## 1.7 Resource lifecycle (1 сессия) — DONE
IndexedStack + isActiveTab уже корректны (camera_lifecycle_test 2 теста). Добавлено:
- микрофон выключается при уходе приложения в фон — GeminiInputCapsule теперь
  WidgetsBindingObserver: paused/inactive/hidden → _stopMic() (глушит SpeechToText,
  сохраняет текст; индикатор ОС гаснет). CameraController и так enableAudio:false.
- app-background приостанавливает камеру — CameraScanScreen теперь
  WidgetsBindingObserver: paused/inactive/hidden → _releaseCamera(); resumed →
  _initCamera() ТОЛЬКО если таб активен (green privacy indicator не горит в фоне).
- возврат не пересоздаёт расклад — IndexedStack + SpreadController (provider) уже
  держат состояние; подтверждено существующими tab-switch тестами.
- поздний async-ответ не меняет завершённую сессию — OracleSessionController
  получил монотонный epoch + isCurrentSession(epoch); TableWorkspace
  (_runSynthesis/_askOracle/_runAstralReading/_generateClarifier) захватывает epoch
  до await и отклоняет мутацию, если сессия была reset/перезапущена.
Тесты: camera_lifecycle_test.dart расширен до 4 (background→release, resume→re-acquire,
resume на не-камерном табе → не пересоздаётся); oracle_session_controller_test.dart +1
(epoch guard). GATE: flutter analyze = No issues found; full flutter test = 325/325 green.
STOP.

## Phase 1 acceptance criteria (единый чек-лист) — PASSED
- [x] 3 режима в Camera (QUICK SCAN | GUIDED SPREAD | LIVE ORACLE, 1.5);
- [x] выбор количества карт удалён (1.5);
- [x] Table/History без регрессий (full test 325/325);
- [x] Vision-контракт независим от ML (1.4, legacy_vision_adapter/unavailable_vision_engine);
- [x] FakeVision только тесты/debug (test/fakes/fake_vision_engine.dart);
- [x] отсутствие Vision не падает; ручной fallback (unavailable_vision_engine → manualFallbackRequired);
- [x] lifecycle корректен (1.7: mic off в фоне, camera pause на фоне, stale-response guard).

## Phase 1 → отчёт (шаблон §7 спеки) → STOP. НЕ начинать Phase 2 без команды.

---

# PHASE 2 — QUICK SCAN & TABLE INTEGRATION

## 2.1 SpreadInferenceService (1 сессия) — DONE
lib/core/services/spread_inference_service.dart: SpreadInferenceInput (system,
detectedCount, confirmedCount?, positions?/boxes? как NormalizedPoint/NormalizedRect
из VisionEngine — геометрия ОПЦИОНАЛЬНА, только флаг hasGeometry), SpreadCandidate
(tarot/lenormand/rune + cardCount/label/isPro/slotRoles/reason),
SpreadInferenceResult (candidates, top, isFreeform, needsConfirmation, detectedCount).
Количество ≠ назначение позиций; неоднозначность (Lenormand 9 = nine + grandPortrait)
→ needsConfirmation; нет схемы → Freeform (detectedCount сохраняется, карты не теряются).
Тесты: test/spread_inference_test.dart (8 тестов).
STOP.

## 2.2 Recognition Review (1-2 сессии) — DONE
lib/features/camera_scan/widgets/recognition_review_sheet.dart (bottom sheet):
счётчик распознанных, предложенный расклад (+ компактный выбор кандидатов при
неоднозначности), список карт с thumbnail (shortLabel), именем, переключением
ориентации (скрыто для Lenormand — supportsReversal), reorder (вверх/вниз = confirm
порядка), remove, CONFIRM → RecognitionReviewResult (cards + reversed + spread?).
Confidence не выдумывается. Тесты: test/recognition_review_test.dart (5 тестов).
STOP.

## 2.3 Camera→Table handoff (1 сессия) — DONE
SpreadController.loadScannedSpread (новый, обобщённый): system + List<DivinationCard>
+ reversed + опциональный spread (tarot/lenormand/rune enum). Freeform → все карты
сохраняются (generic "Card N" роли сверх шаблона), лишние не отбрасываются. Цифровой
ledger не трогается (reset+shuffle, без fake dealCardAt). loadScannedSpreadFaceUp
оставлен как legacy-обёртка. camera_scan_screen.dart: _scan → detect → lock-on →
RecognitionReviewSheet → loadScannedSpread → onHandoff. Amendment 4: recognizer
TAROT-only — для Lenormand/Runes честный manual fallback (SnackBar), никакой
конвертации tarot→lenormand/runes. Тесты: phase2_flow_test + app_smoke_test (обновлены
под review sheet), phase2_clarifier_test (freeform + идемпотентность).
STOP.

## 2.4 Physical clarifier (1 сессия) — DONE
+1 Clarifier уже был реализован (completeClarifierScan → Clarifier N с userContext =
вопросом, fromPhysicalCard, face-up; _maybeExpandClarifiers генерирует Clarifier
Expansion; _captureSession upsert той же сессии — новая сессия НЕ создаётся). Phase 2
закрепил: (а) amendment 4 — clarifier-скан для Lenormand/Runes → manual fallback,
(б) идемпотентность completeClarifierScan (повторный вызов без вооружения = no-op,
maxTableCards=10 соблюдается, hard cap не меняется). Тесты: phase2_clarifier_test
(round-trip + идемпотентность).
STOP.

## Phase 2 acceptance criteria — PASSED
- Quick Scan инферирует/подтверждает расклад; неоднозначность → выбор; Freeform
  сохраняет все карты; лишние не теряются (2.1 + 2.3).
- Recognition Review: полный набор действий, без выдуманного confidence, Lenormand
  без reversed (2.2).
- Handoff: физический источник, face-up, Focus/Spread + Oracle Chat + автосохранение,
  цифровой ledger нетронут (2.3).
- Physical clarifier в той же сессии, cap 10 соблюдён (2.4).
- PRO-ограничения централизованно отключены (lib/core/config/app_flags.dart:
  kProRestrictionsEnabled=false) при сохранении метаданных/инфраструктуры монетизации.
- Table/History/Astral без регрессий; flutter analyze clean; full flutter test зелёный.

---

# PHASE 3 — GUIDED PHYSICAL SPREAD

## 3.1 Переиспользование Choose Spread (1 сессия) — DONE
НЕ создавать новый каталог. Использовать Step 1 (digital_table_screen.dart
_SpreadSelectionView + spread_blueprint_carousel.dart). Только контекст запуска:
Digital → Active Digital Table; Physical guided → Active Camera Guided Session.
Опциональный заголовок "PHYSICAL SPREAD".
STOP.

## 3.2 Guided Session Controller / FSM (1-2 сессии) — DONE
lib/state/live_reading_controller.dart (ChangeNotifier): конечный автомат
preparing→awaitingIntention→awaitingCard→cardDetected→awaitingReveal→recognizingCard→
awaitingConfirmation→interpretingCard→awaitingUser→awaitingNextCard→spreadCompleted→
(paused|completed|cancelled|error). Переходы валидируются. Oracle не меняет карты и не
переходит на несуществующую позицию.
Тесты: guided_fsm_test.dart (все переходы, невалидные переходы).
STOP.

## 3.3 Guided lifecycle (1-2 сессии) — DONE
Реализовать сценарий Triad Flow: намерение → карта 1 (рубашкой вверх → обнаружение →
просьба открыть) → подтверждение → привязка к позиции → интерпретация → уточнение →
следующая. Завершение базового расклада → общий синтез → уместные уточнения →
clarifiers → продолжить в Oracle Chat. Незавершённый расклад не выдавать за завершённый.
STOP.

## 3.4 Guided Camera HUD (1 сессия) — DONE
lib/features/camera_scan/widgets/guided_spread_hud.dart: spread name, progress (2/3),
current slot role (HIDDEN SHADOW), flash, pause/exit. Снизу — инструкции + Confirm/Next
+ открыть полный чат. Не рисовать world-anchored AR (позиции = визуальные подсказки).
STOP.

## 3.5 Event-driven architecture (1 сессия) — DONE
lib/core/models/physical_reading_event.dart: CardObserved/CardRecognized/CardConfirmed/
CardRevealed/CardTemporarilyOccluded/CardMoved/CardRemoved/CardOrientationChanged/
ClarifierConfirmed/SpreadCompleted. eventId + trackId + sessionId против дублей.
Повторное появление подтверждённой карты НЕ дублирует; окклюзия ≠ удаление; исчезновение
из кадра ≠ отмена позиции; перемещение НЕ меняет роль автоматически.
Тесты: physical_event_test.dart (dedupe, occlusion, stale).
STOP.

## 3.6 Physical authenticity / Active vs Quiet Guidance (1 сессия) — DONE
Обеспечить естественную последовательность (намерение/перемешивание/вытягивание/
выкладывание/открытие/созерцание/интерпретация/уточнение/завершение). Два режима
сопровождения (Active/Quiet). Oracle не комментирует каждое движение.
STOP.

## Phase 3 acceptance criteria — PASSED (2026-11-19)
- 3.1 Choose Spread reused (no new catalog): SpreadLaunchContext digital →
  activateSpread, guided → onSpreadSelected(cardCount).
- 3.2 LiveReadingController FSM: validated transitions + position guard; no
  card-mutation API (cards stay in SpreadController).
- 3.3 Triad Flow: SpreadController.startGuidedSpread/bindGuidedCard +
  GuidedSessionCoordinator (start/confirmCard/nextCard/isComplete); incomplete
  spread never reported complete.
- 3.4 GuidedSpreadHud: name/progress/slot-role/instruction + flash/pause/exit +
  Confirm/Next/Resume + open-chat; no world-anchored AR.
- 3.5 PhysicalReadingEvent sealed model + physicalEventFromVision (lost =
  temporary occlusion, NOT removal) + dedupe ledger.
- 3.6 GuidanceMode active/quiet + guidanceShouldSpeak (quiet never narrates
  movement beats).
VERIFY: flutter analyze = No issues found; full flutter test green.
STOP → Phase 4 (Live Oracle & Voice) awaits command.

---

# PHASE 4 — LIVE ORACLE & VOICE EXPERIENCE

## 4.1 Shared Oracle session (подготовлено в 1.3; verify 1 сессия) — VERIFIED
Full Chat / Voice Overlay / Compact Oracle используют один sessionId, одни messages,
одни cards, один контекст, одни clarifiers, одну историю. Смена представления не
создаёт новую AI-сессию.
STOP.

## 4.2 OracleVoiceService (1-2 сессии; research обязателен) — DONE
1. RESEARCH: TTS-пакет (flutter_tts) — совместимость Android/iOS, лицензия, EN/RU,
   управление воспроизведением, background, версии Flutter/Dart. Зафиксировать в
   PLAN/ARCHITECTURE до добавления зависимости.
2. lib/core/services/oracle_voice_service.dart: start/stop listening, speak/stop,
   pause/resume, cancel, language, availability, permissions. Voice states: idle/
   listening/transcribing/thinking/speaking/muted/paused/unavailable/error.
   STT = существующий speech_to_text; TTS = выбранный пакет. Half-duplex; Interrupt.
   MVP: STT → Oracle text → TTS (без realtime speech-to-speech).
3. test/fakes/fake_oracle_voice_service.dart.
Тесты: oracle_voice_service_test.dart.
STOP.

## 4.3 Full Chat дополнения (1 сессия)
oracle_chat_pane.dart: source indicator (DIGITAL/PHYSICAL), mode indicator (QUICK/
GUIDED/LIVE), voice playback control, Resume Camera / Return to Physical Spread /
Continue Guided Session. Не перегружать метками.
STOP.

## 4.4 Voice Overlay + Compact Oracle (2 сессии)
lib/features/oracle/widgets/oracle_voice_overlay.dart, compact_oracle.dart,
oracle_voice_controls.dart, oracle_presence_indicator.dart, oracle_subtitles.dart:
presence (lavender glow, лёгкий pulse, subtle waveform, obsidian translucent surface),
субтитры, mic/mute/interrupt/pause/expand/end. Overlay не занимает видоискатель;
длинный ответ — компактные прокручиваемые субтитры. Compact = плавающая capsule.
Переходы Full↔Overlay↔Compact не сбрасывают голосовую сессию.
Тесты: widget — oracle_voice_overlay_test.dart, compact_oracle_test.dart.
STOP.

## 4.5 Live Oracle freeform (1-2 сессии)
Без обязательного выбора расклада: новая/продолжить сессия → намерение → свободное
выкладывание → Oracle интерпретирует в контексте → вопросы/доп. карта/символика/выбор
расклада/завершение. Выбор структурированного расклада → корректный переход в Guided;
существующие карты молча не перераспределять (запрос подтверждения ролей).
STOP.

## 4.6 Oracle structured actions (1-2 сессии)
lib/core/models/oracle_action.dart: respond/suggestSpread/requestNextCard/requestClarifier/
requestReveal/askQuestion/summarizeSpread/completeReading/none. LLM возвращает текст +
action (JSON). Строгая валидация; приложение — authoritative. LLM запрещено добавлять
вымышленные карты/менять canonicalCardId/orientation/обходить лимиты/PRO/history.
Некорректная команда → текст/уточнение.
Тесты: oracle_action_validation_test.dart.
STOP.

## 4.7 Oracle payload contract (1 сессия)
Компактный структурированный контекст (schemaVersion/sessionId/source/mode/system/
spreadId/currentPosition/cards[{cardId,position,role,orientation,source,confirmed}]/
expectedAction). Реальные canonical IDs. Raw кадры в Oracle НЕ передавать; обновление
bbox НЕ вызывает LLM-запрос.
STOP.

## 4.8 Oracle personality (без кода — промпт-правки в 1 сессию)
Спокойный, сдержанный, контекстный, символический тон; без категоричных медицинских/
финансовых/юридических предсказаний; голосовые ответы компактнее текстовых.
STOP.

## Phase 4 acceptance criteria → отчёт → STOP.

---

# PHASE 5 — UNIFICATION, QA & VISION INTEGRATION READINESS

## 5.1 Session continuity (1-2 сессии)
Реализовать/проверить сценарии A–H (Quick Scan→Oracle→Table→Oracle; Guided→Pause→Oracle→
Resume; Live→Compact→Full→Voice; Oracle→Physical Clarifier→Camera→Oracle; History→Restore
Physical; History→Restore Guided; History→Restore Live; Digital→Physical Clarifier→Same).
sessionId стабилен; повторная генерация не выполняется; переключение на старый разговор
сохраняет/подтверждает отмену текущей; stale async-ответ не попадает в новую сессию.
STOP.

## 5.2 History integration (1 сессия)
SpreadSessionSnapshot metadata: readingSource/readingMode/completionStatus/voiceUsed/
customSpread/pendingGuidedPosition. Обозначения DIGITAL/PHYSICAL/GUIDED/LIVE. Отдельного
Camera History НЕ делать. Restore: диалог+расклад+позиции+контекст; камера/микрофон НЕ
запускаются автоматически (явное действие). Старые JSON без миграционных ошибок; Astral
без изменений.
Тесты: history_restore_test.dart.
STOP.

## 5.3 Privacy & network (документация, 1 сессия)
Local-first: не хранить raw video/audio без согласия; не логировать PII/ключи; не слать
поток кадров в Oracle; изображения в remote Vision — только с уведомлением;
задокументировать передаваемые данные. Новые серверные зависимости и секреты в коде —
не добавлять.
STOP.

## 5.4 Performance (1 сессия)
Бюджетное Android (Redmi 12C): тяжёлая обработка не в UI thread; глобальный notifier не
обновляется на каждый кадр; backpressure + только актуальный кадр; throttling;
cancellation; RepaintBoundary; скрытые camera streams не запускать. Не заявлять точность
ML до Phase 0.
STOP.

## 5.5 Responsive UI (1 сессия)
Проверить compact/standard portrait, landscape, SafeArea, system nav, cutouts,
клавиатуру, длинные ответы, EN/RU, длинные имена карт, camera/mic permissions, text
scaling. Важные элементы не обрезаются и не перекрывают dock.
STOP.

## 5.6 Тесты (распределить по фазам, финальная консолидация)
Domain: ReadingMode transitions, ReadingSource preservation, sessionId stability,
snapshot serialization, legacy compatibility, spread inference, manual input, unknown
card, guided position validation, physical clarifier, duplicate event rejection,
occlusion, stale response rejection, session cancellation, orientation validation,
ledger isolation.
Widget: mode selector, Quick Scan, Recognition Review, guided selection/progress HUD,
Voice Overlay, Compact Oracle, Full Chat transition, permission denied (camera/mic),
vision unavailable, manual fallback, history restore, digital table regression, EN/RU.
Integration: Quick Scan→Oracle, guided complete flow, Live Oracle simulated, physical
clarifier round-trip, history restore+continuation, pause/resume, camera↔table navigation,
switching saved conversations, app background/resume.
Ограничения тестов: без RTX/CUDA/API-ключей/интернета/ML/платных сервисов.
STOP.

## 5.7 VISION_ENGINE_CONTRACT.md (1 сессия)
Создать документ: interface, capabilities, supported systems, frame format, orientation,
bbox/corner format, recognition schema, unknown card, event schema, session lifecycle,
cancellation, backpressure, adapter guide, debug fixtures, real-engine checklist.
Подключение реального движка = adapter + register provider + capabilities + validate +
existing integration tests (без копирования Oracle/Table/History).
STOP.

## Phase 5 acceptance criteria → финальный отчёт → STOP.

---

# QUALITY GATES (каждая фаза)
dart format && flutter analyze && flutter test && flutter build apk --debug
(адаптировать под окружение; недоступность сборки = limitation, не success).

# НЕОБСУЖДАЕМЫЕ ОГРАНИЧЕНИЯ
Чистый Flutter/Dart; без JS; сохранить существующую функциональность; физику цифровой
колоды; определения раскладов; PRO gate; History; Astral; Almanac; EN/RU; один Oracle;
одна история; без непрерывного LLM-видео; без фейкового production-распознавания;
без ML-обучения; без ненужного рефакторинга; без деструктивных миграций; без выдуманного
confidence; без несанкционированного запуска camera/mic; без пуша в remote; без Academy/
Journal; без молчаливых изменений hard-лимитов колоды/раскладов.

# ПОРЯДОК ИСПОЛНЕНИЯ
Phase 1 → STOP → (команда) Phase 2 → STOP → Phase 3 → STOP → Phase 4 → STOP → Phase 5.
Каждая фаза: 1) изучить код, 2) git status, 3) baseline, 4) обновить PLAN.md,
5) файлы, 6) реализация, 7) analyze, 8) тесты, 9) regression, 10) APK (если можно),
11) ARCHITECTURE.md, 12) TASK_STATE.json, 13) отчёт, 14) STOP.




