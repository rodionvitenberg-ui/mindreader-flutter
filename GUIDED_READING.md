# GUIDED_READING.md — Guided Reading: наставник-компаньон Tarot Tree

> Статус: **v0.5 (22.11)** — архитектура и этапы G1–G4; **G1, G2.0–G2.1, G3, G4.0–G4.4 и локализация на 6 языков реализованы**.
> Сверхзадача: превратить сам процесс работы с картами в обучение — **не** превращая приложение в учебник.
>
> **Где мы сейчас:** весь пользовательский текст (включая уроки, назначения и опцию Оракула) живёт в `l10n/*.tsv` на 6 языках (§15.2). G4 закрыт полностью (G4.0–G4.4). Дальше: образ/позы маскота и облачко (G2.2+).
> Прежние решения: G1 (образовательная логика) делаем без маскота; образ маскота решаем отдельно.

---

## 1. Два «guided» — не путать (критично)

В кодовой базе уже есть два разных понятия со словом «guided». Документ — только про второе.

| Понятие | Файлы | Что это | Статус |
|---|---|---|---|
| **Guided Physical Spread** | `state/live_reading_controller.dart` (`GuidePhase` FSM), `state/guided_session_coordinator.dart`, `features/camera_scan/widgets/guided_spread_hud.dart` | Пошаговый ритуал **физического** расклада через камеру (preparing → awaitingCard → recognizingCard → …) | Есть, работает. **НЕ трогаем.** |
| **Reading Guide / Guided Reading** | `features/digital_table/widgets/reading_guide.dart`, `ReadingAid.guide` | Образовательный наставник **на цифровом столе** | Реализован: G1, G2.0–G2.1, G3, G4.0–G4.1 (статус — §15). **Предмет этого плана.** |

Термином «Guided Reading» далее называется только второй пункт.

## 2. Точка отсчёта — что уже реализовано

> Раздел фиксирует состояние **до G1** (историческая база плана). Актуальный статус реализации — §15.

- **Три независимые настройки Reading Experience** — `enum ReadingAid { positions, guide, relationships }` в `state/app_settings_controller.dart`:
  - `enabled(ReadingAid)` / `setAid(...)`, персистентность через `LocalStorageService` (`reading_aid.$aid`).
  - Дефолты: `positions = true`, `guide = false`, `relationships = false`.
  - UI: `features/profile/profile_screen.dart` → карточка «Reading experience» (3 × `TaroGlassToggle`).
  - Лейблы уже в `core/l10n/app_strings.dart`: `reading.title/positions/guide/relationships` + `.hint`.
- **`features/digital_table/widgets/reading_guide.dart`** — текущий минимальный наставник:
  - `recommendedPosition(SpreadController)` — рекомендательный порядок: при раздаче → следующий пустой слот; для Трёх карт (tarot) → сначала центр (slot 1); иначе первая закрытая карта.
  - `GuideHighlight` — лавандовая рамка на рекомендуемом слоте/колоде (используется в `spread_board.dart`, `board_pillar_view.dart`, `digital_table_screen.dart`).
  - `ReadingGuide` — `TextButton.icon` (`menu_book`) с одной строкой; тап открывает `TaroGlassSheet` с объяснением (фокус расклада, вопрос позиции, стихии, Золотая Заря, подсказка раздачи/раскрытия, кнопка «выключить»). Тексты сейчас **захардкожены** RU/EN-тернарниками.
- **`core/services/reading_relationships.dart`** — `readingRelationships()` + `influenceOf()` (Golden Dawn dignities: reinforcing/supportive/opposing/neutral). Работает только для tarot; схемы: Three-card, Celtic Cross, Four/Love Bridge, custom five-card-line, custom compareNeighbors. `explanation` пока только EN и лаконичное.
- **`state/spread_controller.dart`** — SSOT стола: `slots`, `nextEmptySlotIndex`, `spreadCardCount`, `relationships` (живой геттер), `spreadFocusLine`, `spreadSlotRoles`, `readingRevision`, `dealCardAt`/`dealNextCard`/`flipSlot`.
- **Тесты уже есть:** `guided_reading_test`, `guided_fsm_test`, `guided_lifecycle_test`, `guided_quiet_mode_test`, `guided_spread_hud_test`.

**Вывод:** событийная «печка» частично готова. Не хватает: (а) событийной модели подсказок, (б) дедупликации/памяти «усвоенного», (в) маскота + стеклянных облачков, (г) онбординга, (д) контентной базы объяснений.

## 3. Принципы-инварианты

1. Guided Reading **только читает** `SpreadController`; никогда не мутирует карты и порядок.
2. Работает и в Focus View, и в Spread View, адаптируя положение подсказки.
3. Spread Definition и Relationship Engine работают **всегда**; выключается только Reading Guide.
4. Свобода пользователя: рекомендация ≠ запрет. Открыл «не ту» карту — не ругаем, не ломаем расклад.
5. **Одна подсказка за раз**; не повторяем уже усвоенное.
6. Базовые тексты локальны (offline), RU/EN, учитывают reduce-motion, без обязательных AI-запросов.
7. Не мешает раздаче/перетаскиванию/раскрытию; маскот не перекрывает карты, док и элементы управления.

## 4. Три разных «порядка»

- **Порядок раздачи** — структурный (`dealCardAt` заполняет следующий пустой слот).
- **Порядок раскрытия** — свободный, с рекомендацией (`recommendedPosition`).
- **Порядок интерпретации** — зависит от методики и конкретного расклада.

## 5. Событийная модель (ядро G1)

### 5.1 Типы событий
`GuideEventType`: `spreadSelected`, `dealingStarted`, `cardDealt`, `cardPlaced`, `revealingStarted`, `cardRevealed`, `relationshipTapped`, `spreadCompleted`.

### 5.2 Контекст
`GuideContext` — производный снапшот: фаза (`dealing` / `revealing` / `interpreting` / `complete`), `recommendedSlot`, `currentSlot`, активная связь (`relationship`), `system`, `spreadType`, `customSpread`, язык, уровень подробности.

### 5.3 Подсказка
`GuideHint { id, type, priority, title, body, anchor, action }`, где `anchor ∈ { deck, slot:index, relationship:id, whole }`.

### 5.4 Арбитр «одна подсказка»
Приоритет (убывание): `spreadCompleted` > `relationshipTapped` > `cardRevealed` > `cardPlaced` > `revealingStarted` > `dealingStarted` > `spreadSelected`.

### 5.5 Память / дедупликация
- **Процедурная** инструкция («выложите карту в позицию 2») — раз за сессию/расклад.
- **Концептуальный** урок («что значит центральная позиция») — раз за тип расклада, персистентно (`guided_seen_v1`), сброс в настройках.

**Реализовано (G1.3).** Урок живёт на подсказке (`GuideHint.lessonId` + `.lesson`), прикрепляется только в режиме `GuideDetail.thorough` и только пока не прочитан (`slot:<system>:<spread>:<n>`). Урок считается усвоенным при **открытии листа подсказки** (`learnCurrentLesson`), а не при показе строки: читатель учится чтением. Память — `guided_seen_v1` (отсортированный строковый список), сброс — `resetLearned()` из «Reading experience».

## 6. Карта событий → действие наставника

| Событие | Действие наставника | anchor |
|---|---|---|
| Пользователь выбрал расклад | Объясняет назначение, число позиций, как читается | whole |
| Началась раздача | Подсвечивает колоду и следующую позицию | deck + slot |
| Карта вытащена из колоды | Показывает место размещения | slot:index |
| Карта размещена | Коротко объясняет роль позиции | slot:index |
| Началось раскрытие | Рекомендует следующую карту | slot:index |
| Карта раскрыта | Предлагает прочесть значение в контексте позиции | slot:index |
| Появилась/коснулись стихийная связь | Объясняет взаимодействие стихий (тап по строке связи в инспекторе карты) | relationship:id |
| Расклад завершён | Предлагает проанализировать историю целиком | whole |

## 7. Архитектура G1 — образовательная логика

### 7.1 Новый контроллер (главное решение)
`state/guided_reading_controller.dart` — `ChangeNotifier`:
- слушает `SpreadController` (через `addListener`) и `AppSettingsController`;
- вычисляет **одну** наиболее уместную `GuideHint` (арбитр §5.4);
- ведёт дедупликацию (§5.5), причём **никогда не мутирует** карты/порядок;
- отдаёт наружу: `GuideHint? currentHint`, `int? recommendedSlot`, `bool shouldHighlightDeck`.
- Жизненный цикл: сбрасывается на `readingRevision` (новый расклад) и при `exitSpread`.

### 7.2 Файлы G1
| Файл | Назначение |
|---|---|
| `core/models/guide_event.dart` | `GuideEventType`, `GuidePhase` (dealing/revealing/interpreting/complete), `GuideContext` |
| `core/models/guide_hint.dart` | `GuideHint`, `GuideHintAnchor`, `GuideHintPriority` |
| `core/data/guide_copy.dart` | локальные тексты RU/EN (вынос из inline `reading_guide.dart`) |
| `state/guided_reading_controller.dart` | вычисление + арбитр + дедупликация |
| `features/digital_table/widgets/reading_guide.dart` | рефактор: рендер из контроллера вместо собственной логики |
| `core/services/reading_relationships.dart` | развёрнутые `explanation` (EN+RU) + method id |
| spread-модели (`spread_type.dart`, `lenormand_spread.dart`, `rune_cast.dart`, `custom_spread.dart`) | добавить `slotRoleExplanation`, `spreadPurpose`, `dealingOrder` |
| `core/l10n/app_strings.dart` | перенести тексты guide в словарь |
| `state/app_settings_controller.dart` | + уровень подробности `GuideDetail { concise, thorough }` |
| `core/services/local_storage_service.dart` | + `guided_seen_v1`, + `guide_detail` |
| `test/guided_reading_controller_test.dart` | юнит-тесты арбитра и дедупликации |

> **Фактически (G4):** контент уроков/назначений живёт не в spread-моделях, а в
> `core/data/guide_lessons_{tarot,lenormand,runes}.dart` за фасадом
> `core/data/guide_content.dart`; `spreadSlotExplanation()`
> удалён. `dealingOrder` так и не понадобился — порядок раздачи структурный.
> L10n (§15.2): `GuideLine` стал «ключом + словарь» (`GuideLine(key)`), тексты —
> в `l10n/*.tsv`; G4.2 добавил туда уроки `content.lesson.tarot.conflict/school`.

### 7.3 Порядок работ G1
1. **G1.0** — модели + контроллер + тесты (без изменения UI).
2. **G1.1** — рефактор `ReadingGuide` на контроллер, вынос текстов в `guide_copy.dart`/`AppStrings`.
3. **G1.2** — развёрнутые объяснения связей и позиций (расширение `reading_relationships.dart` + spread-моделей).
4. **G1.3** — память уроков (`guided_seen_v1`) + уровень подробности (`guide_detail`) + сброс прогресса. **Сделано** (маскот по-прежнему отложен).

## 8. G2 — Маскот (образ по-прежнему отложен, но заглушка работает)

По решению от 22.11 маскот не блокирует G1. Здесь фиксируем критерии и направления для будущего выбора.

### 8.0 Сделано: звезда-заглушка (G2.0–G2.1)

Образ/имя/характер пока НЕ решаются — сделан технический каркас, чтобы проверить функционал.

- `features/digital_table/widgets/guide_mascot.dart` — процедурная четырёхлучевая звезда (`CustomPainter`, лаванда → индиго, мягкое гало без тяжёлых спрайтов), `RepaintBoundary`, `const`-конструктор.
- Настроение — чистая функция `guideMascotMoodFor(GuideHint?)`: `idle` (подсказки нет) / `hint` (любая подсказка) / `celebrate` (расклад собран). Отдельно тестируется без виджетов.
- Движение: idle-breathing (2.6 с, `AnimationController`) + spring-pop на смену настроения (`TaroMotion.spring`, mass 1 / 320 / 24). Reduce-motion (`MediaQuery.disableAnimationsOf`) выключает и дыхание, и pop — кадры не планируются.
- Haptics: ровно один `mediumImpact` на переход в `celebrate`; на обычные подсказки — без вибрации (чтобы не спамить при каждой раздаче).
- Место: **внутри строки-подсказки** `ReadingGuide` (она же выполняет роль «стеклянного облачка» до макетов). Маскот не перекрывает карты, док и органы управления и не меняет высоту строки.
- Открытый вопрос «где живёт маскот» смягчён: текущая позиция — safe-by-construction; угловое/плавающее размещение появится вместе с макетами.

### Критерии
- узнаваем, но не конкурирует с картами;
- дёшев в 120 FPS (процедурный `CustomPainter`, не тяжёлые спрайты);
- 2–3 позы/эмоции + spring-анимации, haptics на порогах;
- вписан в Obsidian-эстетику (свечение + стекло, без «милоты ради милоты»).

### Направления (не утверждены)
| Направление | Узнаваемость | Стоимость | Связь с брендом | Риск |
|---|---|---|---|---|
| A. Лесной дух-светлячок (wisp) | средняя | низкая | высокая | риск излишней «милоты» |
| B. Стихийный хранитель (окраска под стихию) | высокая | средняя | очень высокая | сложнее анимации, геймификация |
| C. Абстрактная звезда-компаньон | низкая | очень низкая | средняя | слабо запоминается |
| D. Антропоморфный мини-персонаж | высокая | высокая | средняя | дорого, спорит с картами |

### Компоненты
Есть: `guide_mascot.dart` (звезда + `_StarMascotPainter` + `GuideMascotMood`, всё в одном файле < 200 строк). Роль «облачка» временно выполняет строка `ReadingGuide` + `TaroGlassSheet`; отдельная тайп-анимация не нужна до появления образа.
Осталось (после решения по образу): `guide_bubble.dart` (стеклянное облачко + «подробнее/закрыть»), отдельный `mascot_animation_controller.dart` (idle/hint/celebrate/hide как самостоятельный контроллер, если поз станет больше двух), угловое/плавающее позиционирование по макетам.

### Открытые вопросы
облик, имя, характер, набор эмоций/анимаций (сейчас: idle-breathing + hint + celebrate), точное расположение на экранах (сейчас: строка подсказки, без перекрытия карт), стиль облачков.

## 9. G3 — Онбординг (сделано)

- `features/onboarding/onboarding_flow.dart` + `features/onboarding/widgets/onboarding_step_body.dart` — три шага в стеклянной панели поверх шелла: знакомство (звезда-компаньон) → вопрос «Вы уже работали с Таро?» → «Всё готово». `AnimatedSwitcher` (нулевая длительность при reduce-motion), точки прогресса, «Пропустить» на первых шагах, `ModalBarrier` — под оверлеем ничего не нажимается.
- Показ: тем же правилом, что и прелоадер, — `showOnboarding ?? (WidgetsBinding.instance is WidgetsFlutterBinding)`. В реальном приложении оверлей поднимается сам, в `testWidgets` — только по явному `showOnboarding: true`, поэтому 580+ существующих тестов не получили внезапный экран.
- `state/onboarding_controller.dart` — `completed`, `loaded`, `initialLoad`, `complete({bool? tarotFamiliar})`, `restart()`; персист `onboarding_completed_v1` (`LocalStorageService`), guard от notify-after-dispose.
- Seed уровня подробности: **новичок** → `GuideDetail.thorough` + `ReadingAid.guide = true`; **уже знаком(а)** → `concise`, переключатели не трогаем; **пропустить** → ни одна настройка чтения не меняется. Функции не блокируются.
- Профиль → «Reading experience» → «Повторить знакомство» (`restart`). Полное отключение обучения — существующий мастер-тумблер Guided reading.
- Тесты: `test/onboarding_test.dart` (5 контроллерных + 5 widget, включая «the overlay lives under a Material ancestor»).
- **Проверка на устройстве (22.11)**: интро отрисовывалось с жёлтым двойным подчёркиванием — оверлей в `MaterialApp.builder` живёт выше Navigator, и без `Material` Flutter отдаёт error-style текста. Исправлено обёрткой `Material(type: MaterialType.transparency)`, закрыто регрессионным тестом. Вывод на будущее: **builder-level оверлеи всегда требуют `Material`-предка**, а такие дефекты видны только на устройстве — проверять скриншотом.

## 10. G4 — Содержательная полировка

### 10.1 Сделано (G4.0 — контентное ядро)

- **Урок на каждую позицию каждого пресета, RU + EN**: 36 слотов Tarot, 27 Lenormand, 25 рун — всего 88 уроков. Файлы: `core/data/guide_lessons_tarot.dart`, `guide_lessons_lenormand.dart`, `guide_lessons_runes.dart`; `core/models/guide_line.dart` (`GuideLine(en, ru)`); фасад `core/data/guide_content.dart` (`guideSlotLesson`, `guidePurposeLine`). Английские тексты Tarot перенесены без изменений из `spread_type.dart` (сам `spreadSlotExplanation` удалён — один источник правды).
- **Назначение расклада, RU + EN**: 17 пресетов (`*PurposeLines`) — «зачем этот расклад и как его читают».
- **Уроки теперь есть у всех систем**: `SpreadController.slotLesson(index, lang)` и `guidePurpose(lang)`; `GuidedReadingController` в режиме `thorough` прикрепляет урок для Tarot, Lenormand и рун (раньше — только Tarot). Custom-расклады остаются без уроков: вопросы пишет сам читатель.
- **Маркировка метода**: лист подсказки показывает локальную пометку системы — `GuideCopy.methodNote(lang, system)`: Золотая Заря и стихийные достоинства (Tarot), чтение парами и отсутствие перевёрнутых карт (Lenormand), силы/действия и меркставе у восьми несимметричных знаков (руны).
- **Тесты**: `test/guide_content_test.dart` (10) — полнота (каждый слот, оба языка, нет «непереведённых» строк), отсутствие урока за пределами расклада, локализация в контроллере, переключение языка, пометки метода.

### 10.2 Сделано (G4.1 — связи Lenormand и перевёрнутые)

- **Lenormand-пары в движке связей**: `readingRelationships` для Lenormand даёт соседние пары (0-1, 1-2, …) с `ReadingLinkKind.lenormandPair`, БЕЗ стихийных достоинств (`influence == null`) и без меркставе. Авторская традиционная строка пары берётся из `LenormandCard.combinations` через единый `lenormandCombination(a, b)` — тот же лукап теперь использует и Focus-view пилюля (было дублирование).
- **Локализованное объяснение пары**: «Rider + Scythe — первая карта называет предмет, вторая его уточняет» (RU/EN) через `ReadingRelationship.localizedExplanation`.
- **`ReadingLinkKind`** (`elementalDignity` / `positional` / `lenormandPair`) — движок больше не притворяется, что любая связь стихийная; вид попадает в `toJson` для промптов.
- **Инспектор карты**: строки связей теперь локализованы (было `method. explanation` по-английски), а для пар дополнительно показывается традиционная строка; у перевёрнутых карт и меркставе — короткая методическая пометка `GuideCopy.reversalNote` («не «плохая» карта»).
- **Тесты**: `reading_relationships_test` +4 (пары Lenormand, охрана от пар на одной карте, лукап авторской строки, руны без связей, вид tarot-связей), `guide_content_test` +1 (пометка о перевёрнутых/меркставе).

### 10.3 Сделано (G4.2 — противоречивые сочетания и «традиция vs школа»)

- **Движок связей знает о противоречии**: `ReadingRelationship.isContradictory` — истинно только для `elementalDignity` + `opposing` (огонь↔вода, воздух↔земля). Позиционные связи и пары Lenormand противоречивыми не считаются.
- **Урок «две карты тянут в разные стороны»** (`content.lesson.tarot.conflict`, 6 языков): назвать требование каждой карты, читать натяжение, а не «отмену». Прикрепляется наставником в режиме `GuideDetail.thorough`, когда расклад собран и среди связей есть противоположная, либо когда читатель открыл такую связь (`explainRelationship`).
- **Урок «традиция vs современная школа»** (`content.lesson.tarot.school`, 6 языков) — отдельный, следующий сценарий: если конфликтный урок уже прочитан (или его нет), наставник объясняет, что стихийные достоинства — одна из традиций (Золотая Заря), а современное чтение каждой карты отдельно не «неправильно».
- **Память**: id уроков — `conflict:<system>` / `school:<system>`, от языка не зависят, хранятся в `guided_seen_v1` вместе с уроками позиций, сбрасываются `resetLearned()`. Каждый урок выдаётся один раз на систему.
- **Где видно**: строка-подсказка собранного расклада → лист `ReadingGuide` (урок в `GuideHint.lesson`); новой UI не потребовалось.
- **Охрана от лишнего**: уроки связей не появляются, если в раскладе нет ни одной стихийной связи (одна карта, Celtic Cross с позиционными парами) и в режиме `concise`. Lenormand и руны остаются без уроков связей — у них нет достоинств.
- **Тесты**: `guide_link_lessons_test` (12) — приоритет конфликт→школа, одноразовость и перенос между раскладами, `concise`, одиночная карта, позиционные связи, локализация на 6 языках; `reading_relationships_test` +1 (`isContradictory` только для opposing).

### 10.4 Сделано (G4.3 — тап по связи в инспекторе карты)

- Строки связей в инспекторе (`reading_bottom_sheet.dart`) стали тапабельными, пока включено Guided Reading: лавандовая иконка `menu_book` подсказывает жест, тап даёт `HapticFeedback.selectionClick()`, передаёт `ReadingRelationship` в `GuidedReadingController.explainRelationship` и закрывает лист.
- Наставник берёт связь на себя: строка-подсказка показывает «Elemental link / Positional link», а её лист содержит объяснение связи и (в режиме `thorough`) урок `conflict` / `school`.
- Возврат: в листе явной связи появилась кнопка «Back to the spread» (`guide.backToSpread`, 6 языков) → `clearRelationship()`, и наставник снова ведёт по раскладу. Без неё объяснение связи «залипало» бы до конца расклада — это была бы регрессия UX.
- Границы: пока выключен `ReadingAid.relationships`, строк нет; пока выключен `ReadingAid.guide`, строки остаются обычным текстом (без жеста и иконки).
- Тест: `guided_reading_test` +1 widget-тест — полная цепочка «тап по связи → подсказка связи → урок о натяжении → Back to the spread → снова подсказка расклада».

### 10.5 Сделано (G4.4 — опция Оракула по явному запросу)

- **Только по тапу**: в листе подсказки появилась кнопка «Ask the Oracle» (`guide.askOracle`, 6 языков). Открытие листа Оракула не вызывает — тест это фиксирует. Кнопка показывается, когда на столе есть хотя бы одна открытая карта, и после ответа гаснет (один запрос на момент).
- **Сервис**: `OracleSynthesisService.explainGuideMoment(moment, focus, slots, link, focusSlot)` — тот же двухступенчатый конвейер (worker → cloud), модель получает момент наставника, фокус расклада, открытые карты и коснутую связь. Принимает `ctrl.slots` целиком и сам отбирает открытые карты.
- **Офлайн-ответ локализован** и собран из ключей: фокус расклада → «На столе: …» (роль · карта (ориентация)) → коснутая связь (`ReadingRelationship.explanation`) → сократический вопрос фокус-карты (`DivinationCard.reflection`). Пустой стол отвечает честно (`guide.oracle.empty`), а не выдумывает карты. Промптовый текст модели остаётся вне словарей (не показывается читателю).
- **UI**: `_GuideDetailSheet` стал stateful — `_asking` показывает `guide.oracle.thinking`, ответ рендерится под меткой `guide.oracle.label` (monospace, lavender) и не теряется при прокрутке; `mounted`-guard не даёт setState после закрытия листа.
- **Тесты**: `guide_oracle_option_test` (7) — офлайн-ответ называет карты/роли и заканчивается вопросом карты, пустой стол, связь в ответе, смена языка, копирайт на 6 языках, «сам не спрашивает», локализованный ответ.

### 10.6 G4 закрыт

Все пункты контентной полировки выполнены: G4.0 (контентное ядро), G4.1 (связи Lenormand/перевёрнутые), G4.2 (конфликтующие сочетания и «традиция vs школа»), G4.3 (тап по связи в инспекторе), G4.4 (опция Оракула). Новых пунктов в G4 не осталось.

## 11. Итоговая модель настроек

| Настройка | Где | Статус |
|---|---|---|
| Show Spread Positions | `ReadingAid.positions` | есть |
| Guided Reading | `ReadingAid.guide` | есть (мастер-переключатель) |
| Show Card Relationships | `ReadingAid.relationships` | есть |
| Уровень подробности `GuideDetail` | `app_settings_controller` | G1 — есть (`guide_detail`) |
| Сбросить прогресс подсказок | настройки | G1 — есть (`resetLearned`) |
| Повторить онбординг / отключить обучение | настройки | G3 — есть (`restart`; отключение — тумблер Guided reading) |

## 12. Roadmap (порядок внедрения)

1. **G1.0** модели + `GuidedReadingController` + тесты (без UI).
2. **G1.1** рефактор `ReadingGuide` на контроллер + `guide_copy.dart`/`AppStrings`.
3. **G1.2** развёрнутые объяснения связей/позиций.
4. **G2** маскот: **G2.0–G2.1 звезда-заглушка в строке подсказки — сделано**; образ/позы/облачко/угловое размещение — после решения по образу.
5. **G3** онбординг — **сделано** (интро, seed `GuideDetail`, повтор из Профиля).
6. **G4** контентная полировка — **закрыт**: G4.0 контентное ядро, G4.1 связи Lenormand/перевёрнутые, G4.2 противоречивые сочетания/«традиция vs школа», G4.3 тап по связи, G4.4 опция Оракула по явному запросу (§10.6).
7. **L10n — сделано:** 6 языков (`en/ru/es/pt/de/fr`), весь текст → ключи + словари, контент Guided Reading на ключах (§15.2).
8. **Дальше:** образ/позы маскота и облачко (G2.2+) — единственный незакрытый блок плана.

## 13. Тестирование

- `guided_reading_controller_test.dart` — арбитр (одна подсказка, приоритеты), дедупликация (процедурная vs концептуальная), сброс на `readingRevision`, выключение при `ReadingAid.guide=false`.
- `guide_mascot_test.dart` — маппинг настроений (`idle`/`hint`/`celebrate`), звезда в строке подсказки, celebrate на собранном раскладе, исчезновение при выключенном обучении, reduce-motion не планирует кадры.
- `onboarding_test.dart` — персист `onboarding_completed_v1`, seed уровня (новичок/знакомый/пропуск), `restart`, весь поток интро + повтор из Профиля, отсутствие оверлея без флага.
- `guide_content_test.dart` — полнота G4-контента: назначение и урок на каждый слот всех пресетов в RU и EN, отсутствие «непереведённых» строк, уроки в контроллере для Lenormand/рун, смена языка на лету, пометки метода и перевёрнутых.
- `reading_relationships_test.dart` — связи Lenormand (соседние пары, без достоинств, авторская строка пары), руны без связей, вид tarot-связей (dignities vs positional), `isContradictory` только для противоположных стихий.
- `guide_link_lessons_test.dart` — G4.2: конфликтный урок на собранном раскладе и на явной связи, порядок «конфликт → школа», одноразовость и перенос между раскладами, отсутствие уроков в `concise`, у одиночной карты и у позиционных связей, локализация на 6 языках.
- `guide_oracle_option_test.dart` — G4.4: офлайн-ответ Оракула называет карты, роли и вопрос фокус-карты; пустой стол; коснутая связь в ответе; язык ответа; копирайт на 6 языках; лист сам Оракула не спрашивает, ответ появляется только по тапу.
- `guided_reading_test.dart` — подсказки следуют за out-of-order раскрытием в обеих view; открытие листа учит урок ровно один раз; тап по строке связи в инспекторе карты передаёт объяснение наставнику, а «Back to the spread» возвращает подсказку расклада.
- Регресс: `guided_fsm_test`, `guided_lifecycle_test`, `guided_quiet_mode_test`, `guided_spread_hud_test` (Guided Physical Spread не затронут).
- `flutter analyze` чисто; widget-тесты не блокируются на `SharedPreferences` (паттерн UI-first уже принят).

## 14. Риски и открытые решения

| Вопрос | Статус |
|---|---|
| Внешность, имя, характер маскота | Временно звезда-заглушка (G2.1); финальный образ открыт |
| Анимации и эмоции | Каркас есть (idle-breathing, spring-pop, celebrate); расширение — с образом |
| Точное расположение на экранах | Пока строка подсказки; угловое — по макетам |
| Стиль стеклянных облачков | Нужны макеты (`TaroGlassSheet` временно закрывает) |
| Полный набор текстов раскладов | G4.0 — есть (88 уроков + 17 назначений, RU/EN) |
| Степень подробности | G1 (`GuideDetail`) — есть |
| Условия повторного показа | G1 (дедупликация `guided_seen_v1`) — есть |
| Подключение помощи Оракула | G4.4 — сделано: только по тапу «Ask the Oracle», офлайн-ответ на ключах |
| Языков в интерфейсе | 6 (`en/ru/es/pt/de/fr`) — сделано, §15.2 |

## 15. Статус на 22.11: локализация на 6 языков и что осталось

### 15.1 Что сделано и проверено

| Этап | Итог | Ключевые файлы |
|---|---|---|
| G1.0–G1.3 | модели подсказок, read-only контроллер, память уроков (`guided_seen_v1`), уровень подробности (`guide_detail`), сброс прогресса | `core/models/guide_{event,hint}.dart`, `state/guided_reading_controller.dart`, `state/app_settings_controller.dart`, `core/services/local_storage_service.dart` |
| G2.0–G2.1 | звезда-заглушка в строке подсказки: idle-breathing, spring-pop, celebrate, reduce-motion, haptics | `features/digital_table/widgets/guide_mascot.dart` |
| G3 | онбординг из 3 шагов, seed `GuideDetail`, повтор из Профиля (`onboarding_completed_v1`) | `features/onboarding/*`, `state/onboarding_controller.dart` |
| G4.0 | 88 уроков + 17 назначений для всех пресетов в RU/EN, пометки метода, локализованное назначение в листе | `core/data/guide_lessons_*.dart`, `core/data/guide_content.dart`, `core/models/guide_line.dart` |
| G4.1 | Lenormand-пары в движке связей (`ReadingLinkKind`), авторская строка пары из одного лукапа, локализованные строки в инспекторе, пометка о перевёрнутых/меркставе | `core/services/reading_relationships.dart`, `reading_bottom_sheet.dart`, `core/data/guide_copy.dart` |
| G4.2 | урок о противоположных стихиях (`conflict:<system>`) и отдельный урок «традиция vs современная школа» (`school:<system>`) в памяти `guided_seen_v1`; `ReadingRelationship.isContradictory` | `state/guided_reading_controller.dart`, `core/services/reading_relationships.dart`, `core/data/guide_content.dart`, `core/data/guide_lessons_tarot.dart`, `l10n/*.tsv` |
| G4.3 | тап по строке связи в инспекторе карты → `explainRelationship` (иконка `menu_book`, haptics, лист закрывается), кнопка «Back to the spread» → `clearRelationship` | `features/digital_table/widgets/reading_bottom_sheet.dart`, `features/digital_table/widgets/reading_guide.dart`, `core/data/guide_copy.dart`, `l10n/*.tsv` |
| G4.4 | опция «Ask the Oracle» по явному тапу (лист не спрашивает сам), `explainGuideMoment` с локализованным офлайн-ответом (карты · роли · связь · вопрос), пустой стол отвечает честно | `features/digital_table/widgets/reading_guide.dart`, `core/services/oracle_synthesis_service.dart`, `core/data/guide_copy.dart`, `l10n/*.tsv` |
| L10n | 6 языков, `l10n/*.tsv` — единственный источник копирайта (2485 ключей × 6), контент уроков/назначений на ключах | `l10n/*.tsv`, `tool/gen_l10n_dart.py`, `lib/core/l10n/strings/*.dart` |

**Проверка (22.11):** `flutter analyze` — 0 issues. Целевые наборы: `guided_reading_controller` 14, `guided_reading` 2, `guide_mascot` 5, `onboarding` 10, `guide_content` 11, `reading_relationships` 8 — зелёные. Полный `flutter test`: **611 passed / 4 failed**, все 4 — предсуществующие WIP-падения worktree (§15.4). Release-APK собран и установлен на устройство (`versionName 0.1.0`, `versionCode 1`), холодный старт чистый; проверено скриншотом, по нему же пойман и исправлен дефект стиля текста в онбординге (§9).

**Проверка G4.2–G4.4 (22.11):** `flutter analyze` — 0 issues. Новые наборы: `guide_link_lessons` 12, `reading_relationships` 12 (+1), `guided_reading` 3 widget-теста (тап по связи и возврат), `guide_oracle_option` 7 — зелёные; guided-наборы (`guided_reading_controller`, `guide_mascot`, `guide_content`, `onboarding`, `l10n_coverage`, `oracle_synthesis_service`) — зелёные; в словарях 2494 ключа на язык. Полный `flutter test`: **638 passed / 4 failed** — те же известные WIP-падения (§15.4), ничего нового.

### 15.2 Локализация на 6 языков — сделано (эпик закрыт)

План от 22.11 выполнен: весь пользовательский текст переведён на **ключи + словари**, языков **6** (`AppLanguage {en, ru, es, pt, de, fr}`). Источник копирайта — `l10n/<code>.tsv` (`key<TAB>text`), Dart-словари генерируются `tool/gen_l10n_dart.py`; `test/l10n_coverage_test.dart` требует каждый ключ во всех 6 языках, непустое значение и одинаковый набор `{placeholders}`.

Что это дало Guided Reading:
- `core/models/guide_line.dart` → ключ + словарь: 88 уроков и 17 назначений сохранили смысл; `.en/.ru` остались совместимыми геттерами для старых тестов.
- `core/data/guide_copy.dart` — только выбор ключа и подстановка плейсхолдеров (RU/EN-тернарников больше нет).
- `ReadingRelationship.localizedExplanation`, `GuideCopy.methodNote` / `reversalNote`, уроки G4.2 — на ключах.
- «Усвоенные» уроки от языка не зависят: id — `slot:<system>:<spread>:<n>`, `conflict:<system>`, `school:<system>`.
- Смена языка перерисовывает строку-подсказку, лист подсказки, инспектор карты, онбординг и Профиль; фолбэк — EN, затем сам ключ.

### 15.3 Критерии приёмки локализации (для Guided Reading)

- Ни одного пользовательского текста вне словарей (в `guide_mascot.dart` текста нет вообще — только настроение).
- Каждый ключ есть во всех 6 языках (тест покрытия); фолбэк EN не «молчит» в интерфейсе.
- Смена языка перерисовывает: строку-подсказку, лист подсказки, инспектор карты, онбординг, Профиль.
- «Усвоенные» уроки не сбрасываются при смене языка (id уроков от языка не зависят).
- Проверка на устройстве скриншотом: длинные строки не ломают строку-подсказку и лист.

### 15.4 Известные падения полного прогона (НЕ наши, WIP worktree)

`astral_horoscope_and_zodiac_almanac_test` (×2 — бейдж `✦ HOROSCOPE`, которого нет в `lib`), `workspace_swipe_test` (панель истории после переписывания `spread_history_pane.dart`), `interactive_spread_test` (tooltip `Fit whole spread` после переписывания `spread_board.dart`). Не связаны с Guided Reading; не «зеленить» их в рамках этого плана.

Отдельно замечен **флейк**: `rune_volumetric_and_spread_test` («horizontal swipe on SPREAD VIEW rune heap shuffles without dealing») один раз упал в полном прогоне под параллельной нагрузкой и зелёный в изоляции и в повторном полном прогоне. К Guided Reading не относится.

---

### Чек-лист приёмки G1
- [x] `GuidedReadingController` не мутирует `SpreadController`.
- [x] Одна подсказка за раз; приоритеты соблюдены.
- [x] Усвоенное не повторяется; сброс работает (G1.3).
- [x] Все пользовательские тексты через ключи + словари — **сделано эпиком L10n (6 языков, §15.2)**: `guide_copy.dart`, `GuideLine(key)` и контент G4.2 живут в `l10n/*.tsv`.
- [x] Offline-тексты; reduce-motion; Focus/Spread view.
- [x] `flutter analyze` чисто; guided-тесты зелёные.
