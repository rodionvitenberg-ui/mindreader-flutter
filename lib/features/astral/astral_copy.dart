import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/models/natal_chart.dart';
import '../../state/app_settings_controller.dart';

/// Locale-aware helpers for the ASTRAL surface. Every string they return is
/// resolved from the shared dictionaries, so the screen has no Russian/English
/// branch of its own.
extension AstralCopy on BuildContext {
  AppLanguage get astralLanguage =>
      watch<AppSettingsController?>()?.language ?? AppLanguage.en;

  bool get astralRussian => astralLanguage == AppLanguage.ru;

  String astralRead(String key) => AppStrings.t(
    read<AppSettingsController?>()?.language ?? AppLanguage.en,
    'astral.$key',
  );

  String astralText(String key) =>
      AppStrings.t(astralLanguage, 'astral.$key');

  String astroPlanet(PlanetId planet) => planet.title;

  String astroSign(ZodiacSign sign) => sign.title;

  String astroHouseSystem(HouseSystem system) => system.label;

  String astroPhase(String name, String glyph) => name;

  String astroPlacement(NatalPlanetPosition p) => p.interpretation;

  String astroAspect(AspectType type) => AppStrings.g('content.aspect.${type.name}.name');

  String astroAspectAdvice(AspectType type) => type.dynamicLine;
}
