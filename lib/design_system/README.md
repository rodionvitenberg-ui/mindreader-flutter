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
| `glass`  | полный liquid glass | да (1 слой на экран) |
| `fake`   | FakeGlass | да |
| `simple` | полупрозрачные поверхности | нет |
| `opaque` | непрозрачные поверхности | нет |

Все поверхности внутри одного `TaroGlassLayer` делят один backdrop sample
(не по слою на кнопку).

## Производительность (profile)

```bash
flutter run --profile -t lib/design_system/playground/playground_main.dart
```

FPS замеряется на физическом устройстве (DevTools / `flutter run --profile`).
На эмуляторе Flutter GPU недоступен → стекло падает в FakeGlass.
