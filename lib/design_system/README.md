# Tarot Tree — Glass Design System (Phase G1)

Изолированная дизайн-система на `liquid_glass_renderer` 1.0.x. Не подменяет
существующую тему (Dark Obsidian `AppColors`) и основные экраны до визуального
согласования.

## Файлы

```
lib/design_system/
  taro.dart                                  barrel-экспорт
  taro_tokens.dart                           цвета/прозрачности/свечение/радиусы/анимации/оптика
  taro_glass.dart                            TaroGlassLayer + TaroGlassSurface + 4 режима
  components/
    taro_glass_button.dart                   primary/secondary/ghost × normal/pressed/disabled/loading
    taro_glass_segmented_control.dart        плавный индикатор активного сегмента
    taro_glass_panel.dart                    панель с мягкой глубиной + section label
    taro_glass_dock.dart                     4 раздела (Camera/Table/Almanac/Astral)
    taro_glass_input.dart                    normal/focus/error
    taro_glass_select.dart                   выбор колоды/расклада (bottom-sheet)
  playground/
    glass_playground.dart                    изолированный GlassPlayground
    playground_main.dart                     отдельная точка входа
test/taro_glass_design_system_test.dart     7 тестов (логика в simple-режиме)
```

## Запуск playground

```bash
flutter run -t lib/design_system/playground/playground_main.dart \
  --enable-impeller --enable-flutter-gpu
```

Полное стекло требует Impeller + Flutter GPU (включено в
`android/app/src/main/AndroidManifest.xml` мета-данными
`io.flutter.embedding.android.EnableFlutterGPU`). Без GPU рендерер
автоматически падает в `FakeGlass`; на web — только `FakeGlass`.

## Режимы рендеринга (TaroGlassMode)

| Режим | Что рисует | Backdrop sampling |
|-------|-----------|-------------------|
| `auto`   | выбор по устройству (см. ниже) | как у выбранного |
| `glass`  | полный liquid glass | да (1 слой на экран) |
| `fake`   | FakeGlass | да |
| `simple` | полупрозрачные поверхности | нет |
| `opaque` | непрозрачные поверхности | нет |

Все поверхности внутри одного `TaroGlassLayer` делят один backdrop sample
(не по слою на кнопку).

### Автовыбор (`auto`) — [`TaroGlassCapability`](taro_glass_capability.dart)

`TaroGlassLayer` по умолчанию работает в `auto`: после первого кадра резолвит
режим один раз и кеширует (`TaroGlassCapability.mode`, `ValueNotifier`):

- нет shader-фильтров (`ImageFilter.isShaderFilterSupported == false`) → `fake`;
- iOS/macOS (Impeller Metal + Flutter GPU) → `glass`;
- Android → `glass` только если нативный провайдер `taro/glass_capability`
  сообщает поддержку **Vulkan** (`FEATURE_VULKAN_HARDWARE_LEVEL`), иначе `fake`;
- остальные платформы → `fake`.

Пока идёт проба — безопасный `fake`, поэтому первый кадр не чёрный.
Логика решения (`TaroGlassCapability.decide`) покрыта тестами
`test/taro_glass_capability_test.dart`. Переопределение — передать `mode`
в `TaroGlassLayer` явно (`glass`/`fake`/`simple`/`opaque`).

**Render-самопроверка.** Некоторые устройства (часть MediaTek) рапортуют Vulkan,
но Impeller у них на GLES и настоящий glass рисуется чёрным. Чтобы не полагаться
на эвристику, после первого кадра рисуется крошечный (64×64, практически
невидимый) настоящий glass над белым фоном в `Overlay`, читаются пиксели через
`RepaintBoundary.toImage()`; если кадр чёрный — `auto` уходит в `fake`.
Если `Overlay` недоступен — остаётся эвристика по Vulkan.


## Производительность (profile)

```bash
flutter run --profile -t lib/design_system/playground/playground_main.dart
```

FPS замеряется на физическом устройстве (DevTools / `flutter run --profile`).

## Проверено на устройстве (Android 13, Impeller OpenGLES)

Скриншоты: `screenshot_auto.png` (auto → fake) и `screenshot_fake.png`.

Важный вывод по рендереру:

| Режим | На Impeller GLES (без Flutter GPU/Vulkan) |
|-------|-------------------------------------------|
| `auto`  | **работает** — самопроверка выбирает `fake`, чёрного кадра нет |
| `glass` | **чёрный кадр** — настоящий glass требует Impeller Vulkan + Flutter GPU |
| `fake`  | **работает** — FakeGlass даёт стеклянный вид (blur + tint + rim) |
| `simple`| работает |
| `opaque`| работает |

Дефолт playground — `auto`: на этом Redmi (Impeller GLES) самопроверка
определила чёрный кадр и выбрала `fake`; на устройстве с Impeller Vulkan/Metal
она выберет `glass`. Режимы `simple`/`opaque` — для слабых GPU и замеров без
backdrop sampling.
