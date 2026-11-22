import '../l10n/app_strings.dart';
import 'tarot_card_model.dart' show Element;

/// ASTRAL Phase 1 — astrological domain models. Pure Dart, immutable,
/// JSON-serializable. No Flutter imports.

/// The three house systems offered by the ASTRAL engine.
enum HouseSystem { placidus, koch, wholeSign }

extension HouseSystemX on HouseSystem {
  /// Uppercase display label, e.g. 'PLACIDUS'.
  String get label => AppStrings.g('content.houseSystem.$name.label');

  /// Localized subtitle shown under the display label.
  String get ruSubtitle => AppStrings.g('content.houseSystem.$name.subtitle');
}

/// Zodiac modality: how a sign initiates, holds, or transforms energy.
enum ZodiacModality { cardinal, fixed, mutable }

extension ZodiacModalityX on ZodiacModality {
  String get label => AppStrings.g('content.modality.$name');
}

/// The twelve zodiac signs in canonical Aries-first order.
enum ZodiacSign {
  aries,
  taurus,
  gemini,
  cancer,
  leo,
  virgo,
  libra,
  scorpio,
  sagittarius,
  capricorn,
  aquarius,
  pisces,
}

extension ZodiacSignX on ZodiacSign {
  static const List<String> _glyphs = [
    '♈',
    '♉',
    '♊',
    '♋',
    '♌',
    '♍',
    '♎',
    '♏',
    '♐',
    '♑',
    '♒',
    '♓',
  ];

  static const List<String> _titleKeys = [
    'content.sign.aries.title',
    'content.sign.taurus.title',
    'content.sign.gemini.title',
    'content.sign.cancer.title',
    'content.sign.leo.title',
    'content.sign.virgo.title',
    'content.sign.libra.title',
    'content.sign.scorpio.title',
    'content.sign.sagittarius.title',
    'content.sign.capricorn.title',
    'content.sign.aquarius.title',
    'content.sign.pisces.title',
  ];

  /// One grounded psychological trait line (used in interpretations).
  static const List<String> _traitKeys = [
    'content.sign.aries.trait',
    'content.sign.taurus.trait',
    'content.sign.gemini.trait',
    'content.sign.cancer.trait',
    'content.sign.leo.trait',
    'content.sign.virgo.trait',
    'content.sign.libra.trait',
    'content.sign.scorpio.trait',
    'content.sign.sagittarius.trait',
    'content.sign.capricorn.trait',
    'content.sign.aquarius.trait',
    'content.sign.pisces.trait',
  ];

  String get glyph => _glyphs[index];
  String get title => AppStrings.g(_titleKeys[index]);
  String get trait => AppStrings.g(_traitKeys[index]);

  Element get element => switch (this) {
    ZodiacSign.aries ||
    ZodiacSign.leo ||
    ZodiacSign.sagittarius => Element.fire,
    ZodiacSign.taurus ||
    ZodiacSign.virgo ||
    ZodiacSign.capricorn => Element.earth,
    ZodiacSign.gemini || ZodiacSign.libra || ZodiacSign.aquarius => Element.air,
    ZodiacSign.cancer ||
    ZodiacSign.scorpio ||
    ZodiacSign.pisces => Element.water,
  };

  ZodiacModality get modality => switch (this) {
    ZodiacSign.aries ||
    ZodiacSign.cancer ||
    ZodiacSign.libra ||
    ZodiacSign.capricorn => ZodiacModality.cardinal,
    ZodiacSign.taurus ||
    ZodiacSign.leo ||
    ZodiacSign.scorpio ||
    ZodiacSign.aquarius => ZodiacModality.fixed,
    ZodiacSign.gemini ||
    ZodiacSign.virgo ||
    ZodiacSign.sagittarius ||
    ZodiacSign.pisces => ZodiacModality.mutable,
  };

  /// Modern ruling planet of the sign.
  PlanetId get ruler => switch (this) {
    ZodiacSign.aries => PlanetId.mars,
    ZodiacSign.taurus => PlanetId.venus,
    ZodiacSign.gemini => PlanetId.mercury,
    ZodiacSign.cancer => PlanetId.moon,
    ZodiacSign.leo => PlanetId.sun,
    ZodiacSign.virgo => PlanetId.mercury,
    ZodiacSign.libra => PlanetId.venus,
    ZodiacSign.scorpio => PlanetId.pluto,
    ZodiacSign.sagittarius => PlanetId.jupiter,
    ZodiacSign.capricorn => PlanetId.saturn,
    ZodiacSign.aquarius => PlanetId.uranus,
    ZodiacSign.pisces => PlanetId.neptune,
  };

  /// The sign containing an ecliptic longitude in degrees (0..360).
  String get titleRu => AppStrings.t(AppLanguage.ru, _titleKeys[index]);

  static ZodiacSign fromLongitude(double longitude) {
    final idx = ((longitude % 360.0) / 30.0).floor();
    return ZodiacSign.values[idx < 0 ? 0 : (idx > 11 ? 11 : idx)];
  }
}

/// Ten celestial bodies plus the two chart angles ASC/MC.
enum PlanetId {
  sun,
  moon,
  mercury,
  venus,
  mars,
  jupiter,
  saturn,
  uranus,
  neptune,
  pluto,
  ascendant,
  midheaven,
}

extension PlanetIdX on PlanetId {
  static const List<String> _glyphs = [
    '☉',
    '☽',
    '☿',
    '♀',
    '♂',
    '♃',
    '♄',
    '♅',
    '♆',
    '♇',
    'ASC',
    'MC',
  ];

  static const List<String> _titleKeys = [
    'content.planet.sun.title',
    'content.planet.moon.title',
    'content.planet.mercury.title',
    'content.planet.venus.title',
    'content.planet.mars.title',
    'content.planet.jupiter.title',
    'content.planet.saturn.title',
    'content.planet.uranus.title',
    'content.planet.neptune.title',
    'content.planet.pluto.title',
    'content.planet.ascendant.title',
    'content.planet.midheaven.title',
  ];

  /// Archetype theme used in interpretations and transit advice.
  static const List<String> _archetypeKeys = [
    'content.planet.sun.archetype',
    'content.planet.moon.archetype',
    'content.planet.mercury.archetype',
    'content.planet.venus.archetype',
    'content.planet.mars.archetype',
    'content.planet.jupiter.archetype',
    'content.planet.saturn.archetype',
    'content.planet.uranus.archetype',
    'content.planet.neptune.archetype',
    'content.planet.pluto.archetype',
    'content.planet.ascendant.archetype',
    'content.planet.midheaven.archetype',
  ];

  String get glyph => _glyphs[index];
  String get title => AppStrings.g(_titleKeys[index]);
  String get archetype => AppStrings.g(_archetypeKeys[index]);

  bool get isAngle => this == PlanetId.ascendant || this == PlanetId.midheaven;

  /// The ten moving celestial bodies (excluding the angles).
  bool get isBody => !isAngle;
}

/// Emotional register of an aspect.
enum AspectHarmony { harmonious, tense, intense }

/// The five Ptolemaic aspects with their orbs.
enum AspectType { conjunction, sextile, square, trine, opposition }

extension AspectTypeX on AspectType {
  /// Exact angular separation the aspect is centered on.
  double get baseAngle => switch (this) {
    AspectType.conjunction => 0.0,
    AspectType.sextile => 60.0,
    AspectType.square => 90.0,
    AspectType.trine => 120.0,
    AspectType.opposition => 180.0,
  };

  /// Maximum allowed deviation from [baseAngle] in degrees.
  double get maxOrb => switch (this) {
    AspectType.conjunction => 8.0,
    AspectType.sextile => 5.0,
    AspectType.square => 7.0,
    AspectType.trine => 7.0,
    AspectType.opposition => 8.0,
  };

  String get glyph => switch (this) {
    AspectType.conjunction => '☌',
    AspectType.sextile => '⚹',
    AspectType.square => '□',
    AspectType.trine => '△',
    AspectType.opposition => '☍',
  };

  AspectHarmony get harmony => switch (this) {
    AspectType.conjunction => AspectHarmony.intense,
    AspectType.sextile => AspectHarmony.harmonious,
    AspectType.square => AspectHarmony.tense,
    AspectType.trine => AspectHarmony.harmonious,
    AspectType.opposition => AspectHarmony.tense,
  };

  /// One-line dynamic description of the aspect (for synthesis text).
  String get dynamicLine => AppStrings.g('content.aspect.$name.line');
}

/// One computed natal position: a planet or an angle placed in the zodiac
/// and in the chart's houses.
class NatalPlanetPosition {
  const NatalPlanetPosition({
    required this.planet,
    required this.longitude,
    required this.sign,
    required this.degreeInSign,
    required this.house,
    required this.isRetrograde,
    required this.interpretation,
  });

  final PlanetId planet;

  /// Ecliptic longitude in degrees, 0..360.
  final double longitude;

  final ZodiacSign sign;

  /// Position inside the sign, 0..29.99°.
  final double degreeInSign;

  /// Natal house, 1..12 (ASC = 1, MC = 10).
  final int? house;

  final bool isRetrograde;

  /// Grounded psychological interpretation (sign + house).
  final String interpretation;

  /// Human-readable degree inside the sign, e.g. `18°24′`.
  String get formattedDegree {
    final whole = degreeInSign.floor();
    final minutes = ((degreeInSign - whole) * 60).floor();
    return '$whole°${minutes.toString().padLeft(2, '0')}′';
  }

  Map<String, dynamic> toJson() => {
    'planet': planet.name,
    'longitude': longitude,
    'sign': sign.name,
    'degreeInSign': degreeInSign,
    'house': house,
    'isRetrograde': isRetrograde,
    'interpretation': interpretation,
  };

  static NatalPlanetPosition fromJson(Map<String, dynamic> json) =>
      NatalPlanetPosition(
        planet: PlanetId.values.byName(json['planet'] as String),
        longitude: (json['longitude'] as num).toDouble(),
        sign: ZodiacSign.values.byName(json['sign'] as String),
        degreeInSign: (json['degreeInSign'] as num).toDouble(),
        house: json['house'] as int?,
        isRetrograde: json['isRetrograde'] as bool,
        interpretation: json['interpretation'] as String,
      );
}

/// One natal aspect between two chart points.
class NatalAspect {
  const NatalAspect({
    required this.bodyA,
    required this.bodyB,
    required this.type,
    required this.exactAngle,
    required this.orb,
    required this.strength,
    required this.synthesis,
  });

  final PlanetId bodyA;
  final PlanetId bodyB;
  final AspectType type;

  /// The actual angular separation in degrees.
  final double exactAngle;

  /// Deviation from the aspect's exact angle, in degrees.
  final double orb;

  /// 0..1 — tighter orb means stronger aspect.
  final double strength;

  /// Psychological synthesis text.
  final String synthesis;

  Map<String, dynamic> toJson() => {
    'bodyA': bodyA.name,
    'bodyB': bodyB.name,
    'type': type.name,
    'exactAngle': exactAngle,
    'orb': orb,
    'strength': strength,
    'synthesis': synthesis,
  };

  static NatalAspect fromJson(Map<String, dynamic> json) => NatalAspect(
    bodyA: PlanetId.values.byName(json['bodyA'] as String),
    bodyB: PlanetId.values.byName(json['bodyB'] as String),
    type: AspectType.values.byName(json['type'] as String),
    exactAngle: (json['exactAngle'] as num).toDouble(),
    orb: (json['orb'] as num).toDouble(),
    strength: (json['strength'] as num).toDouble(),
    synthesis: json['synthesis'] as String,
  );
}

/// Moon phase snapshot for an instant: name, glyph, illumination.
class MoonPhase {
  const MoonPhase({
    required this.name,
    required this.glyph,
    required this.illumination,
    required this.elongationDegrees,
    required this.ageDays,
  });

  /// E.g. 'Waxing Gibbous'.
  final String name;

  /// E.g. '🌔'.
  final String glyph;

  /// Illuminated fraction of the lunar disk, 0..1.
  final double illumination;

  /// Sun–Moon geocentric elongation in degrees, 0..360.
  final double elongationDegrees;

  /// Approximate age of the Moon in days since the last new moon.
  final double ageDays;
}

/// One grounded daily focus sphere: a domain of life with one sentence of
/// psychological guidance (relationships, career, inner state).
class FocusSphere {
  const FocusSphere({
    required this.title,
    required this.text,
    this.titleRu,
    this.textRu,
  });

  final String title;
  final String text;
  final String? titleRu;
  final String? textRu;

  Map<String, dynamic> toJson() => {
    'title': title,
    'text': text,
    if (titleRu != null) 'titleRu': titleRu,
    if (textRu != null) 'textRu': textRu,
  };

  static FocusSphere fromJson(Map<String, dynamic> json) =>
      FocusSphere(title: json['title'] as String, text: json['text'] as String);
}

/// One active live transit of today's sky against the natal chart.
class DailyTransitItem {
  const DailyTransitItem({
    required this.title,
    required this.transitLabel,
    required this.orb,
    required this.advice,
    required this.harmony,
    this.transitingBody,
    this.natalBody,
    this.aspectType,
    this.closestAt,
    this.activeFrom,
    this.activeUntil,
  });

  /// Short headline, e.g. 'Mars stirs your Moon'.
  final String title;

  /// Canonical pair label, e.g. 'Transit Mars □ Natal Moon'.
  final String transitLabel;

  /// Deviation from the exact aspect angle, in degrees.
  final double orb;

  /// Grounded psychological advice for today.
  final String advice;

  /// Emotional register (Harmony cyan / Tension rose / Intense lavender).
  final AspectHarmony harmony;

  final PlanetId? transitingBody;
  final PlanetId? natalBody;
  final AspectType? aspectType;
  final DateTime? closestAt;
  final DateTime? activeFrom;
  final DateTime? activeUntil;

  bool get reachesExact => closestAt != null && orb < 0.0001;

  Map<String, dynamic> toJson() => {
    'title': title,
    'transitLabel': transitLabel,
    'orb': orb,
    'advice': advice,
    'harmony': harmony.name,
    if (transitingBody != null) 'transitingBody': transitingBody!.name,
    if (natalBody != null) 'natalBody': natalBody!.name,
    if (aspectType != null) 'aspectType': aspectType!.name,
    if (closestAt != null) 'closestAt': closestAt!.toIso8601String(),
    if (activeFrom != null) 'activeFrom': activeFrom!.toIso8601String(),
    if (activeUntil != null) 'activeUntil': activeUntil!.toIso8601String(),
  };

  static DailyTransitItem fromJson(Map<String, dynamic> json) =>
      DailyTransitItem(
        title: json['title'] as String,
        transitLabel: json['transitLabel'] as String,
        orb: (json['orb'] as num).toDouble(),
        advice: json['advice'] as String,
        harmony: AspectHarmony.values.byName(json['harmony'] as String),
        transitingBody: json['transitingBody'] == null
            ? null
            : PlanetId.values.byName(json['transitingBody'] as String),
        natalBody: json['natalBody'] == null
            ? null
            : PlanetId.values.byName(json['natalBody'] as String),
        aspectType: json['aspectType'] == null
            ? null
            : AspectType.values.byName(json['aspectType'] as String),
        closestAt: DateTime.tryParse(json['closestAt'] as String? ?? ''),
        activeFrom: DateTime.tryParse(json['activeFrom'] as String? ?? ''),
        activeUntil: DateTime.tryParse(json['activeUntil'] as String? ?? ''),
      );
}

/// The deterministic, non-fatalistic daily horoscope for one profile.
class DailyHoroscopeReport {
  const DailyHoroscopeReport({
    required this.date,
    required this.moonPhaseName,
    required this.moonPhaseGlyph,
    required this.moonIllumination,
    required this.transitingMoonSign,
    required this.transitingMoonHouse,
    required this.overallTheme,
    this.overallThemeRu,
    required this.energyScore,
    required this.transits,
    this.focusSpheres = const [],
  });

  final DateTime date;
  final String moonPhaseName;
  final String moonPhaseGlyph;
  final double moonIllumination;
  final ZodiacSign transitingMoonSign;

  /// Which natal house today's Moon is passing through, 1..12.
  final int? transitingMoonHouse;

  final String overallTheme;
  final String? overallThemeRu;

  /// Deterministic daily energy indicator, 1..100.
  final int energyScore;

  /// Top 3–5 active transits, tightest orb first.
  final List<DailyTransitItem> transits;

  /// Three grounded focus spheres (relationships, career, inner state).
  final List<FocusSphere> focusSpheres;

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'moonPhaseName': moonPhaseName,
    'moonPhaseGlyph': moonPhaseGlyph,
    'moonIllumination': moonIllumination,
    'transitingMoonSign': transitingMoonSign.name,
    'transitingMoonHouse': transitingMoonHouse,
    'overallTheme': overallTheme,
    if (overallThemeRu != null) 'overallThemeRu': overallThemeRu,
    'energyScore': energyScore,
    'transits': [for (final t in transits) t.toJson()],
    'focusSpheres': [for (final f in focusSpheres) f.toJson()],
  };

  static DailyHoroscopeReport fromJson(Map<String, dynamic> json) =>
      DailyHoroscopeReport(
        date: DateTime.parse(json['date'] as String),
        moonPhaseName: json['moonPhaseName'] as String,
        moonPhaseGlyph: json['moonPhaseGlyph'] as String,
        moonIllumination: (json['moonIllumination'] as num).toDouble(),
        transitingMoonSign: ZodiacSign.values.byName(
          json['transitingMoonSign'] as String,
        ),
        transitingMoonHouse: json['transitingMoonHouse'] as int?,
        overallTheme: json['overallTheme'] as String,
        overallThemeRu: json['overallThemeRu'] as String?,
        energyScore: json['energyScore'] as int,
        transits: [
          for (final t in json['transits'] as List<dynamic>)
            DailyTransitItem.fromJson(t as Map<String, dynamic>),
        ],
        focusSpheres: [
          for (final f in (json['focusSpheres'] as List? ?? const []))
            FocusSphere.fromJson(f as Map<String, dynamic>),
        ],
      );
}

/// One full natal chart: birth data, house cusps, positions and aspects.
class NatalChart {
  const NatalChart({
    required this.id,
    required this.profileName,
    required this.createdAt,
    required this.birthDateUtc,
    required this.birthLocalYear,
    required this.birthLocalMonth,
    required this.birthLocalDay,
    required this.birthLocalHour,
    required this.birthLocalMinute,
    required this.timeKnown,
    required this.cityName,
    required this.country,
    required this.latitude,
    required this.longitude,
    required this.timezoneOffsetHours,
    this.timezoneId,
    this.moonSignUncertain = false,
    required this.houseSystem,
    required this.houseCusps,
    required this.planets,
    required this.aspects,
  });

  final String id;
  final String profileName;
  final DateTime createdAt;
  final DateTime birthDateUtc;
  final int birthLocalYear;
  final int birthLocalMonth;
  final int birthLocalDay;
  final int birthLocalHour;
  final int birthLocalMinute;

  /// False when the birth time is unknown (noon convention used).
  final bool timeKnown;

  final String cityName;
  final String country;
  final double latitude;
  final double longitude;
  final double timezoneOffsetHours;
  final String? timezoneId;
  final bool moonSignUncertain;
  final HouseSystem houseSystem;

  /// 12 cusp longitudes, 0..360°, starting at the Ascendant.
  final List<double> houseCusps;

  final List<NatalPlanetPosition> planets;
  final List<NatalAspect> aspects;

  Map<String, dynamic> toJson() => {
    'id': id,
    'profileName': profileName,
    'createdAt': createdAt.toIso8601String(),
    'birthDateUtc': birthDateUtc.toIso8601String(),
    'birthLocalYear': birthLocalYear,
    'birthLocalMonth': birthLocalMonth,
    'birthLocalDay': birthLocalDay,
    'birthLocalHour': birthLocalHour,
    'birthLocalMinute': birthLocalMinute,
    'timeKnown': timeKnown,
    'cityName': cityName,
    'country': country,
    'latitude': latitude,
    'longitude': longitude,
    'timezoneOffsetHours': timezoneOffsetHours,
    if (timezoneId != null) 'timezoneId': timezoneId,
    'moonSignUncertain': moonSignUncertain,
    'houseSystem': houseSystem.name,
    'houseCusps': houseCusps,
    'planets': [for (final p in planets) p.toJson()],
    'aspects': [for (final a in aspects) a.toJson()],
  };

  static NatalChart fromJson(Map<String, dynamic> json) {
    final timeKnown = json['timeKnown'] as bool;
    final moonUncertain = json['moonSignUncertain'] as bool? ?? !timeKnown;
    final planets = (json['planets'] as List).cast<Map<String, dynamic>>().map(
      NatalPlanetPosition.fromJson,
    );
    final aspects = (json['aspects'] as List).cast<Map<String, dynamic>>().map(
      NatalAspect.fromJson,
    );
    bool usable(PlanetId planet) =>
        (timeKnown || !planet.isAngle) &&
        (timeKnown || planet != PlanetId.moon);
    return NatalChart(
      id: json['id'] as String,
      profileName: json['profileName'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      birthDateUtc: DateTime.parse(json['birthDateUtc'] as String),
      birthLocalYear: json['birthLocalYear'] as int,
      birthLocalMonth: json['birthLocalMonth'] as int,
      birthLocalDay: json['birthLocalDay'] as int,
      birthLocalHour: json['birthLocalHour'] as int,
      birthLocalMinute: json['birthLocalMinute'] as int,
      timeKnown: timeKnown,
      timezoneId: json['timezoneId'] as String?,
      moonSignUncertain: moonUncertain,
      cityName: json['cityName'] as String,
      country: json['country'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      timezoneOffsetHours: (json['timezoneOffsetHours'] as num).toDouble(),
      houseSystem: HouseSystem.values.byName(json['houseSystem'] as String),
      houseCusps: timeKnown
          ? (json['houseCusps'] as List)
                .map((c) => (c as num).toDouble())
                .toList()
          : const [],
      planets: [
        for (final p in planets)
          if (timeKnown || !p.planet.isAngle)
            if (!timeKnown && p.house != null)
              NatalPlanetPosition(
                planet: p.planet,
                longitude: p.longitude,
                sign: p.sign,
                degreeInSign: p.degreeInSign,
                house: null,
                isRetrograde: p.isRetrograde,
                interpretation: AppStrings.g('astral.placement.shortNoHouse', {
                  'planet': p.planet.title,
                  'sign': p.sign.title,
                  'archetype': p.planet.archetype,
                }),
              )
            else
              p,
      ],
      aspects: [
        for (final a in aspects)
          if (usable(a.bodyA) && usable(a.bodyB)) a,
      ],
    );
  }
}

/// One axis of the four-axis synastry compatibility read.
class SynastryAxis {
  const SynastryAxis({
    required this.titleKey,
    required this.score,
    required this.textKey,
  });

  /// Dictionary key of the axis title, e.g. `content.synastry.emotional.title`.
  final String titleKey;

  /// Deterministic 0..100 axis score.
  final int score;

  /// Dictionary key of the grounded, non-fatalistic interpretation line.
  final String textKey;

  String get title => AppStrings.g(titleKey);
  String get text => AppStrings.g(textKey);

  Map<String, dynamic> toJson() => {
    'titleKey': titleKey,
    'score': score,
    'textKey': textKey,
  };

  /// Legacy English titles/texts saved before the localization migration.
  static const Map<String, String> _legacyKeys = {
    'Emotional Bond': 'emotional',
    'Attraction & Spark': 'attraction',
    'Mental & Communication': 'mental',
    'Growth & Friction': 'growth',
    'Moon–Moon and Moon–Venus contact: how needs are felt, held and mirrored.':
        'emotional',
    'Venus–Mars and Sun contact: the charge that pulls two people together.':
        'attraction',
    'Mercury links: how the two minds trade, question and understand.':
        'mental',
    'Saturn and the squares: where the bond is built through resistance.':
        'growth',
  };

  static String _legacy(String? value, String field) {
    final slug = _legacyKeys[value] ?? 'emotional';
    return 'content.synastry.$slug.$field';
  }

  static SynastryAxis fromJson(Map<String, dynamic> json) => SynastryAxis(
    titleKey:
        json['titleKey'] as String? ??
        _legacy(json['title'] as String?, 'title'),
    score: json['score'] as int,
    textKey:
        json['textKey'] as String? ?? _legacy(json['text'] as String?, 'text'),
  );
}

/// The deterministic 2-profile synastry summary: an overall 0..100 resonance
/// score plus the four core compatibility axes.
class SynastryReport {
  const SynastryReport({required this.overallScore, required this.axes});

  final int overallScore;
  final List<SynastryAxis> axes;

  Map<String, dynamic> toJson() => {
    'overallScore': overallScore,
    'axes': [for (final a in axes) a.toJson()],
  };

  static SynastryReport fromJson(Map<String, dynamic> json) => SynastryReport(
    overallScore: json['overallScore'] as int,
    axes: [
      for (final a in json['axes'] as List<dynamic>)
        SynastryAxis.fromJson(a as Map<String, dynamic>),
    ],
  );
}

/// One day of the 7-day power/tension forecast: the strongest single transit
/// peak for that day, or null when the day is calm.
class DailyTransitPeak {
  const DailyTransitPeak({required this.date, this.transit});

  final DateTime date;
  final DailyTransitItem? transit;

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    if (transit != null) 'transit': transit!.toJson(),
  };

  static DailyTransitPeak fromJson(Map<String, dynamic> json) =>
      DailyTransitPeak(
        date: DateTime.parse(json['date'] as String),
        transit: json['transit'] == null
            ? null
            : DailyTransitItem.fromJson(
                json['transit'] as Map<String, dynamic>,
              ),
      );
}
