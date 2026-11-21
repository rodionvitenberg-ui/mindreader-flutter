# GLASS.md — План перевода интерфейса на дизайн-систему Tarot Tree

Статус: **G4 завершён** (фундамент G1 + тема/фон G2 + Shell G3 + Digital Table: `TaroGlassChip`/`Pill`, `TaroGlassProgress`, input capsule, subject toggle, sheets, CTA, chat & history).
Этот документ — полный план поэтапного перевода всего UI приложения на новый
«стеклянный» дизайн **без поломки существующей логики**.

---

## 1. Цель

Перевести весь интерфейс `mindreader.quest` с текущей темы **Dark Obsidian**
(`AppColors`, холодная тёмная палитра) на **Tarot Tree** — тёплую стеклянную
дизайн-систему на `liquid_glass_renderer` (направление de-press.co + тёплый
летний рассвет после дождя). Бизнес-логика, модели, сервисы и контроллеры
**не меняются** — это чисто визуальная миграция.

---

## 2. Текущее состояние (Phase G1 — сделано)

- `lib/design_system/taro_tokens.dart` — токены (цвета/прозрачность/свечение/
  радиусы/анимации/оптика).
- `lib/design_system/taro_glass.dart` — `TaroGlassLayer` (один общий
  `LiquidGlassLayer` на экран) + `TaroGlassSurface` + 4 режима рендера.
- `lib/design_system/taro_glass_mode.dart` — `TaroGlassMode` (`auto`/`glass`/
  `fake`/`simple`/`opaque`).
- `lib/design_system/taro_glass_capability.dart` — автовыбор режима: shader-gate
  + Metal (Apple) + Vulkan (Android, через `MainActivity`) + **render-самопроверка**
  (чёрный кадр → `fake`). Проверено на Redmi (Impeller GLES): `auto` → `fake`.
- 6 компонентов (`lib/design_system/components/`):
  `TaroGlassButton`, `TaroGlassSegmentedControl`, `TaroGlassPanel`,
  `TaroGlassDock`, `TaroGlassInput`, `TaroGlassSelect`.
- `lib/design_system/playground/` — изолированный `GlassPlayground` +
  `playground_main.dart` (отдельная точка входа, не трогает `main.dart`).
- Тесты: `test/taro_glass_design_system_test.dart`,
  `test/taro_glass_capability_test.dart`.

Основные экраны пока **не изменены** (по условию STOP до визуального
согласования).

---

## 3. Принципы миграции

1. **Инкрементально, за флагом.** Ни одна смена не должна оставлять приложение
   в сломанном состоянии; каждый экран переключается отдельно.
2. **Логика не трогается.** Меняем только виджеты/декорации, обработчики и
   семантика сохраняются.
3. **Один `TaroGlassLayer` на экран.** Не создаём backdrop-слой на каждую кнопку.
4. **`auto` по умолчанию.** Слабые GPU/GLES сами уходят в `fake`/`simple`.
5. **Доступность.** Touch-target ≥ 44 px, контраст по токенам, `Semantics`.
6. **Никакого Material-kitsch** (золото, дефолтные фиолетовые pill, эмодзи в
   подписях).

---

## 4. Целевая архитектура

```
lib/design_system/
  taro.dart                    barrel
  taro_tokens.dart             токены (SSOT палитры/оптики)
  taro_glass.dart              TaroGlassLayer + TaroGlassSurface
  taro_glass_mode.dart         режимы рендера
  taro_glass_capability.dart   автовыбор режима + self-test
  components/                  6 базовых + растущий набор (см. §7)
  theme/taro_theme.dart        (G2) ThemeData на Tarot Tree вместо buildAppTheme
lib/core/theme/
  app_colors.dart              → со временем становится thin alias на TaroColors
  app_theme.dart               → buildAppTheme() → buildTaroTheme()
  app_typography.dart          остаётся (шрифт Allo), цвета из TaroTokens
```

**Стратегия темы:** Tarot Tree становится основной палитрой приложения.
`AppColors` (Dark Obsidian) сохраняется как legacy-алиас на время миграции,
чтобы не ломать экраны, которые ещё не переведены, затем удаляется.


---

## 5. Этапность (фазы G2–G7)

| Фаза | Содержание | Критерий готовности |
|------|-----------|---------------------|
| **G1** | Фундамент: токены + 6 компонентов + playground + capability | ✅ сделано |
| **G2** | Тема: `buildTaroTheme()`, подключение в `main.dart`, фон-подложка, шрифт | ✅ сделано (513/513 тестов, проверено на Redmi Impeller GLES) |
| **G3** | Shell + навигация: док `TaroGlassDock`, sheet-обёртки, безопасные области | ✅ сделано (523/523 тестов, `flutter analyze` 0 issues, debug APK собран) |
| **G4** | Digital Table (главный экран): панели, input, select, сегменты, bottom-sheet | ✅ сделано (530/530 тестов, `flutter analyze` 0 issues, APK установлен на Redmi GLES) |
| **G5** | Almanac + Astral + Profile | три раздела переведены |
| **G6** | Camera HUD + Oracle overlay | оверлеи/HUD переведены, читаемость сохранена |
| **G7** | Зачистка legacy (`AppColors`/Dark Obsidian), скриншот-ревью, профиль-perf | `flutter analyze` чист, legacy удалён |

Каждая фаза — отдельный коммит + скриншот + `flutter test`.

---

## 6. Матрица миграции по экранам

### Shell / навигация — `lib/features/shell/`
| Сейчас | Станет |
|--------|--------|
| `_GlassNavBar` + `_NavItem` (`main_navigation_shell.dart`) | `TaroGlassDock` (items/index/onTap уже есть) |
| `AppSettingsSheet` | `TaroGlassPanel` + `TaroGlassSelect`/segmented для настроек |
| `ProSubscriptionSheet` | `TaroGlassPanel` + `TaroGlassButton(primary)` |

### Digital Table — `lib/features/digital_table/`
| Сейчас | Станет |
|--------|--------|
| `GeminiInputCapsule` (TextField) | `TaroGlassInput` (оставить mic/`+`/send-кнопки) |
| `ReadingSubjectToggle` (2 pill) | `TaroGlassSegmentedControl` |
| `DeckPickerSheet` / `SpreadSelectorSheet` | `TaroGlassSelect` + стеклянный bottom-sheet |
| `ReadingBottomSheet`, `CustomSpreadSheet`, `RitualSettingsSheet` | стеклянные sheet-обёртки (`TaroGlassPanel`) |
| `SynthesizeCta`, `SynthesisPanel`, `IntentionPromptBar` | `TaroGlassButton`/`TaroGlassPanel` + токены |
| card 3D / shuffle / threads (CustomPainter) | **оставить**, перекрасить в токены (не стекло) |

### Almanac — `lib/features/almanac/`
| Сейчас | Станет |
|--------|--------|
| `CardDetailSheet`, `ZodiacDetailSheet` | стеклянные sheet + `TaroGlassPanel` |
| `DeckCoverPicker`, `DeckShopScreen` (кнопки/карточки) | `TaroGlassButton`/`TaroGlassPanel` |
| фильтры элементов | `TaroGlassSegmentedControl` |

### Astral — `lib/features/astral/`
| Сейчас | Станет |
|--------|--------|
| `AstralGradientButton` | `TaroGlassButton(primary)` |
| `AstralHouseSelector` (сегменты домов) | `TaroGlassSegmentedControl` |
| `BirthDataFormSheet` (поля) | `TaroGlassInput` |
| `AstralProPaywallSheet` | `TaroGlassPanel` + `TaroGlassButton` |
| `NatalWheelPainter` и пр. CustomPainter | **оставить**, перекрасить |

### Profile — `lib/features/profile/`
| Сейчас | Станет |
|--------|--------|
| `ProfileHeader`, `ProfileIdentityCard`, `ProfileCard` | `TaroGlassPanel` |
| `ProfileMigrationCard`, `ProfileSigninCard` | `TaroGlassPanel` + `TaroGlassButton` |

### Camera / Oracle — `lib/features/camera_scan/`, `lib/features/oracle/`
| Сейчас | Станет |
|--------|--------|
| `CameraModeSelector` (3 режима) | `TaroGlassSegmentedControl` |
| `CameraTopHud`, `GuidedSpreadHud`, `RecognitionReviewSheet` | стеклянные HUD/sheet (аккуратно: контраст поверх камеры) |

---

## 7. Компоненты, которых ещё не хватает (достроить по мере фаз)

| Компонент | Для чего | Фаза |
|-----------|---------|------|
| `TaroGlassSheet` | универсальный стеклянный bottom-sheet (drag-handle + контент) | G3 |
| `TaroGlassChip` / `TaroGlassPill` | интеншн-промпты, фильтры, бейджи | G4 |
| `TaroGlassToggle` / `Switch` | настройки, тихий режим | G3 |
| `TaroGlassSlider` | настройки (аналог iOS 27 slider) | G3 |
| `TaroGlassSnackbar`/`Toast` | уведомления | G5 |
| `TaroGlassProgress` | загрузка/синтез | G4 |
| `TaroGlassIconButton` | mic / `+` / send / back | G3 |
| `TaroGlassEmptyState` | пустые состояния | G5 |

Каждый — по тем же правилам: реальные обработчики, `Semantics`, touch ≥ 44 px.

---

## 8. Тема и токены (G2)

- Создать `lib/design_system/theme/taro_theme.dart`:
  - `ThemeData buildTaroTheme()` на базе `TaroColors`/`TaroOptics`/`AppTypography`;
  - `scaffoldBackgroundColor = TaroColors.background`;
  - `colorScheme.dark(primary: lavender, secondary: indigo, ...)`;
  - дефолтные `TextTheme` из `AppTypography` с цветами `TaroColors.textPrimary/Secondary`.
- В `main.dart` заменить `buildAppTheme()` → `buildTaroTheme()` (за флагом
  `kTarotTreeThemeEnabled`, чтобы можно было откатить).
- Фон: `TaroGlassLayer` на верхнем уровне `MainNavigationShell` (обёртка вокруг
  `IndexedStack`), плюс общий фон-подложка (градиент сумерек) как в playground.
- `AppColors` временно оставить; экраны, не переведённые, продолжают на нём
  работать (удалить в G7).

---

## 9. Производительность и доступность

- **Один** `TaroGlassLayer` на экран; все поверхности внутри делят один backdrop
  sample (лимит пакета — 16 форм на слой; при превышении — дробить на слои).
- Фон и тяжёлые `CustomPainter` (карты, колесо натал, threads) **не** оборачивать
  в стекло — только перекрасить в токены.
- Анимировать только `Transform`/`Matrix4`/`Opacity`/`AnimatedAlign` (уже
  заложено), не layout-свойства.
- `auto`-режим гарантирует: на Vulkan/Metal — настоящее стекло, на GLES — FakeGlass.
- Touch-target ≥ 44 px, контраст по токенам, проверять `Semantics` на каждом экране.
- Профиль-perf на физическом устройстве после каждой фазы (DevTools / overlay `P`).

---

## 10. Тестирование и приёмка (на фазу)

- `flutter analyze` — 0 issues.
- `flutter test` — полный набор зелёный (сейчас 507).
- Скриншот экрана до/после (коммит в репо).
- Проверка на устройстве: Impeller Vulkan (glass) и Impeller GLES (fake) — оба без
  чёрных экранов.
- Коммит фазы с описанием «что / зачем / как проверено».

---

## 11. Риски

| Риск | Митигация |
|------|-----------|
| `liquid_glass_renderer 1.0.0-dev` — пре-релиз, API может меняться | доступ спрятан за `taro_glass.dart`; обновление пакета не трогает компоненты |
| Настоящий glass чёрен на Impeller GLES (часть MediaTek) | `auto` + render-самопроверка → `fake`; проверено на Redmi |
| >16 форм на слой | дробить на несколько `TaroGlassLayer` (правило в §9) |
| Потеря контраста на камере/HUD | отдельные токены контраста, ручная проверка |
| Регрессия при массовой замене виджетов | флаг-гейт темы + поэкранные коммиты + полный тест-сьют |
| Пробы шейдеров на старте (jank) | самопроверка один раз, не блокирует первый кадр |

| `OracleVoiceControls`, `OracleVoiceOverlay` | `TaroGlassPanel`/pill на токенах |
