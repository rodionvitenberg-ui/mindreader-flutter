import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/models/natal_chart.dart';
import '../../core/services/natal_calculator_service.dart';
import '../../state/app_settings_controller.dart';

extension AstralCopy on BuildContext {
  bool get astralRussian =>
      watch<AppSettingsController?>()?.language == AppLanguage.ru;

  String astralRead(String key) => AppStrings.t(
    read<AppSettingsController?>()?.language ?? AppLanguage.en,
    'astral.$key',
  );

  String astralText(String key) => AppStrings.t(
    astralRussian ? AppLanguage.ru : AppLanguage.en,
    'astral.$key',
  );

  String astroPlanet(PlanetId planet) => astralRussian
      ? const [
          'Солнце',
          'Луна',
          'Меркурий',
          'Венера',
          'Марс',
          'Юпитер',
          'Сатурн',
          'Уран',
          'Нептун',
          'Плутон',
          'Асцендент',
          'Середина неба',
        ][planet.index]
      : planet.title;

  String astroSign(ZodiacSign sign) =>
      astralRussian ? sign.titleRu : sign.title;

  String astroHouseSystem(HouseSystem system) => astralRussian
      ? const ['ПЛАЦИДУС', 'КОХ', 'ЦЕЛЫЕ ЗНАКИ'][system.index]
      : system.label;

  String astroPhase(String name, String glyph) {
    final index = const [
      '🌑',
      '🌒',
      '🌓',
      '🌔',
      '🌕',
      '🌖',
      '🌗',
      '🌘',
    ].indexOf(glyph);
    if (!astralRussian || index < 0) return name;
    return const [
      'Новолуние',
      'Растущий серп',
      'Первая четверть',
      'Растущая Луна',
      'Полнолуние',
      'Убывающая Луна',
      'Последняя четверть',
      'Убывающий серп',
    ][index];
  }

  String astroPlacement(NatalPlanetPosition p) {
    if (!astralRussian) return p.interpretation;
    final theme = const [
      'самовыражение и энергия',
      'эмоциональные потребности',
      'мышление и общение',
      'симпатии и ценности',
      'инициатива и воля',
      'рост и поиск смысла',
      'границы и ответственность',
      'свобода и перемены',
      'воображение и сочувствие',
      'внутренние изменения',
      'первое впечатление',
      'призвание и репутация',
    ][p.planet.index];
    final house = p.house;
    return '${astroPlanet(p.planet)} в знаке «${astroSign(p.sign)}». Тема — $theme.'
        '${house == null ? '' : ' Дом $house связан с темами «${NatalCalculatorService.houseThemeRu(house)}».'}';
  }

  String astroAspect(AspectType type) => astralRussian
      ? const [
          'Соединение',
          'Секстиль',
          'Квадрат',
          'Тригон',
          'Оппозиция',
        ][type.index]
      : type.name;

  String astroAspectAdvice(AspectType type) => astralRussian
      ? const [
          'Темы этих планет проявляются вместе и усиливают друг друга.',
          'Темы этих планет могут дополнять друг друга при осознанном усилии.',
          'Потребности могут сталкиваться. Помогает договориться о границах.',
          'Эти темы легко поддерживают друг друга.',
          'Две разные потребности требуют внимания. Полезно искать баланс.',
        ][type.index]
      : type.dynamicLine;
}
