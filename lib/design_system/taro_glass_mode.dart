/// Режим рендеринга стекла.
enum TaroGlassMode {
  /// Автовыбор по возможностям устройства ([TaroGlassMode.glass] где доступно,
  /// иначе [TaroGlassMode.fake]). Используется по умолчанию в [TaroGlassLayer].
  auto,

  /// Полный liquid glass (Impeller + Flutter GPU); без GPU сам падает в FakeGlass.
  glass,

  /// Принудительно FakeGlass — дешевле, но всё ещё сэмплит backdrop.
  fake,

  /// Простые полупрозрачные поверхности — без glass и без backdrop filter.
  simple,

  /// Непрозрачные поверхности — ноль backdrop sampling, минимальная нагрузка.
  opaque,
}
