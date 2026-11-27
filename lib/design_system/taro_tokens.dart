import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// Dual dark atmospheric themes for Tarot Tree.
///
/// - [twilight]: existing twilight-plum & lavender glass aesthetic (default).
/// - [moonlit]: deep midnight obsidian (`#06070B`), nocturnal charcoal-obsidian
///   glass cards (`#0B0D14` @ `0.86`), moonlight lavender hairlines (`#A78BFA`
///   @ `0.22`), and subtle warm lantern-amber focus/glow accents (`#F59E0B` /
///   `#FBBF24`).
enum SanctuaryThemeMode {
  twilight,
  moonlit;

  static SanctuaryThemeMode fromName(String? raw) {
    if (raw == null || raw.isEmpty) return SanctuaryThemeMode.twilight;
    for (final mode in values) {
      if (mode.name == raw) return mode;
    }
    return SanctuaryThemeMode.twilight;
  }
}

/// Tarot Tree — централизованные design tokens (SSOT палитры и оптики).
///
/// Единая дизайн-система приложения `mindreader.quest`: каждый параметр цвета,
/// прозрачности, свечения, радиуса и оптики задаётся в одном месте.
abstract final class TaroColors {
  static const background = Color(0xFF151725);
  static const duskMid = Color(0xFF2A2338);
  static const duskHorizon = Color(0xFF3A2E3E);
  static const surface = Color(0xFF282739);
  static const canvas = Color(0xFF625B75);
  static const mist = Color(0xFFA9A4BE);
  static const border = Color(0x2EA9A4BE);
  static const rose = Color(0xFFD4A8AC);
  static const dawn = Color(0xFFF0C7A4);
  static const textPrimary = Color(0xFFF2EBE4);
  static const textSecondary = Color(0xFFC5C0D0);
  static const textDisabled = Color(0x8CC5C0D0);

  /// Moonlit Night palette tokens (`SanctuaryThemeMode.moonlit`).
  static const moonlitBackground = Color(0xFF06070B);
  static const moonlitDuskMid = Color(0xFF090B12);
  static const moonlitDuskHorizon = Color(0xFF0D101A);
  static const moonlitSurface = Color(0xFF0B0D14);
  static const moonlitCanvas = Color(0xFF161A28);
  static const moonlitScrim = Color(0xFF05060A);
  static const lanternAmber = Color(0xFFF59E0B);
  static const lanternAmberBright = Color(0xFFFBBF24);

  /// Акценты подсветки для направления de-press.co + тёплый летний рассвет.
  static const lavender = Color(0xFFA78BFA);
  static const indigo = Color(0xFF6366F1);
  static const cyan = Color(0xFF38BDF8);
  static const emerald = Color(0xFF34D399);
  static const amber = Color(0xFFF97316);
  static const conflictRose = Color(0xFFFB7185);
  static const error = Color(0xFFE9A0A6);

  /// Контрастные токены для Camera HUD и Oracle overlay поверх живого видео.
  static const hudScrim = Color(0xBD151725);
  static const hudFill = Color(0xD11E1D2D);
  static const hudBorder = Color(0x52A9A4BE);

  /// Сплошной тёмно-синий фон прелоадера (точный #0c101b из promo-tarottree).
  static const preloaderBackground = Color(0xFF0C101B);
}

/// Прозрачности поверхностей, бордеров и текста.
abstract final class TaroOpacity {
  static const surface = 0.55;
  static const surfaceStrong = 0.74;
  static const moonlitSurface = 0.86;
  static const moonlitBorder = 0.22;
  static const moonlitScrim = 0.45;
  static const border = 0.18;
  static const borderStrong = 0.42;
  static const textMuted = 0.72;
  static const glow = 0.30;
}

/// Reactive sanctuary palette exposed via [ThemeExtension] so switching between
/// [SanctuaryThemeMode.twilight] and [SanctuaryThemeMode.moonlit] updates the
/// entire app immediately without restart.
class TaroPalette extends ThemeExtension<TaroPalette> {
  const TaroPalette({
    required this.mode,
    required this.background,
    required this.duskMid,
    required this.duskHorizon,
    required this.surface,
    required this.surfaceAlpha,
    required this.canvas,
    required this.glassTint,
    required this.borderHairline,
    required this.borderStrong,
    required this.activeFill,
    required this.activeOutline,
    required this.lanternAccent,
    required this.lanternGlow,
    required this.lanternGlowAlpha,
    required this.scrim,
    required this.scrimAlpha,
  });

  final SanctuaryThemeMode mode;
  final Color background;
  final Color duskMid;
  final Color duskHorizon;
  final Color surface;
  final double surfaceAlpha;
  final Color canvas;
  final Color glassTint;
  final Color borderHairline;
  final Color borderStrong;
  final Color activeFill;
  final Color activeOutline;
  final Color lanternAccent;
  final Color lanternGlow;
  final double lanternGlowAlpha;
  final Color scrim;
  final double scrimAlpha;

  bool get isMoonlit => mode == SanctuaryThemeMode.moonlit;

  /// Option 1 — existing twilight-plum & lavender glass aesthetic (untouched).
  static const twilight = TaroPalette(
    mode: SanctuaryThemeMode.twilight,
    background: TaroColors.background,
    duskMid: TaroColors.duskMid,
    duskHorizon: TaroColors.duskHorizon,
    surface: TaroColors.surface,
    surfaceAlpha: TaroOpacity.surfaceStrong,
    canvas: TaroColors.canvas,
    glassTint: Color(0x24A78BFA), // lavender @ 0.14
    borderHairline: Color(0x2EA9A4BE), // mist @ 0.18
    borderStrong: Color(0x6BA9A4BE), // mist @ 0.42
    activeFill: Color(0x3DA78BFA), // lavender @ 0.24
    activeOutline: Color(0x6BA78BFA), // lavender @ 0.42
    lanternAccent: TaroColors.dawn,
    lanternGlow: TaroColors.lavender,
    lanternGlowAlpha: TaroOpacity.glow,
    scrim: TaroColors.background,
    scrimAlpha: 0.44,
  );

  /// Option 2 — deep midnight obsidian + charcoal-obsidian glass + moonlight
  /// hairlines & warm lantern-amber highlights.
  static const moonlit = TaroPalette(
    mode: SanctuaryThemeMode.moonlit,
    background: TaroColors.moonlitBackground,
    duskMid: TaroColors.moonlitDuskMid,
    duskHorizon: TaroColors.moonlitDuskHorizon,
    surface: TaroColors.moonlitSurface,
    surfaceAlpha: TaroOpacity.moonlitSurface,
    canvas: TaroColors.moonlitCanvas,
    glassTint: Color(0xDB0B0D14), // #0B0D14 @ 0.86
    borderHairline: Color(0x38A78BFA), // #A78BFA @ 0.22
    borderStrong: Color(0x5CA78BFA), // #A78BFA @ 0.36
    activeFill: Color(0x33F59E0B), // #F59E0B @ 0.20
    activeOutline: Color(0x57FBBF24), // #FBBF24 @ 0.34
    lanternAccent: TaroColors.lanternAmberBright,
    lanternGlow: TaroColors.lanternAmber,
    lanternGlowAlpha: 0.22,
    scrim: TaroColors.moonlitScrim,
    scrimAlpha: TaroOpacity.moonlitScrim,
  );

  static TaroPalette forMode(SanctuaryThemeMode mode) => switch (mode) {
    SanctuaryThemeMode.twilight => twilight,
    SanctuaryThemeMode.moonlit => moonlit,
  };

  static TaroPalette of(BuildContext context) =>
      Theme.of(context).extension<TaroPalette>() ?? twilight;

  @override
  TaroPalette copyWith({
    SanctuaryThemeMode? mode,
    Color? background,
    Color? duskMid,
    Color? duskHorizon,
    Color? surface,
    double? surfaceAlpha,
    Color? canvas,
    Color? glassTint,
    Color? borderHairline,
    Color? borderStrong,
    Color? activeFill,
    Color? activeOutline,
    Color? lanternAccent,
    Color? lanternGlow,
    double? lanternGlowAlpha,
    Color? scrim,
    double? scrimAlpha,
  }) => TaroPalette(
    mode: mode ?? this.mode,
    background: background ?? this.background,
    duskMid: duskMid ?? this.duskMid,
    duskHorizon: duskHorizon ?? this.duskHorizon,
    surface: surface ?? this.surface,
    surfaceAlpha: surfaceAlpha ?? this.surfaceAlpha,
    canvas: canvas ?? this.canvas,
    glassTint: glassTint ?? this.glassTint,
    borderHairline: borderHairline ?? this.borderHairline,
    borderStrong: borderStrong ?? this.borderStrong,
    activeFill: activeFill ?? this.activeFill,
    activeOutline: activeOutline ?? this.activeOutline,
    lanternAccent: lanternAccent ?? this.lanternAccent,
    lanternGlow: lanternGlow ?? this.lanternGlow,
    lanternGlowAlpha: lanternGlowAlpha ?? this.lanternGlowAlpha,
    scrim: scrim ?? this.scrim,
    scrimAlpha: scrimAlpha ?? this.scrimAlpha,
  );

  @override
  TaroPalette lerp(covariant TaroPalette? other, double t) {
    if (other == null) return this;
    return TaroPalette(
      mode: t < 0.5 ? mode : other.mode,
      background: Color.lerp(background, other.background, t)!,
      duskMid: Color.lerp(duskMid, other.duskMid, t)!,
      duskHorizon: Color.lerp(duskHorizon, other.duskHorizon, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlpha: lerpDouble(surfaceAlpha, other.surfaceAlpha, t)!,
      canvas: Color.lerp(canvas, other.canvas, t)!,
      glassTint: Color.lerp(glassTint, other.glassTint, t)!,
      borderHairline: Color.lerp(borderHairline, other.borderHairline, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      activeFill: Color.lerp(activeFill, other.activeFill, t)!,
      activeOutline: Color.lerp(activeOutline, other.activeOutline, t)!,
      lanternAccent: Color.lerp(lanternAccent, other.lanternAccent, t)!,
      lanternGlow: Color.lerp(lanternGlow, other.lanternGlow, t)!,
      lanternGlowAlpha: lerpDouble(
        lanternGlowAlpha,
        other.lanternGlowAlpha,
        t,
      )!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
      scrimAlpha: lerpDouble(scrimAlpha, other.scrimAlpha, t)!,
    );
  }
}

/// Подсветка / мягкое свечение.
abstract final class TaroGlow {
  /// Мягкая тень-свечение для панелей и карточек.
  static List<BoxShadow> soft(
    Color color, {
    double alpha = TaroOpacity.glow,
    double blur = 26,
    Offset offset = Offset.zero,
  }) => [
    BoxShadow(
      color: color.withValues(alpha: alpha),
      blurRadius: blur,
      offset: offset,
    ),
  ];
}

/// Радиусы скруглений (один радиус на форму — ограничение рендерера).
abstract final class TaroRadii {
  static const button = 16.0;
  static const panel = 24.0;
  static const dock = 22.0;
  static const pill = 28.0;
  static const segment = 14.0;
  static const input = 14.0;
  static const chip = 12.0;
}

/// Анимации и движение (spring — по соглашению проекта).
abstract final class TaroMotion {
  static const spring = SpringDescription(
    mass: 1.0,
    stiffness: 320.0,
    damping: 24.0,
  );
  static const fast = Duration(milliseconds: 180);
  static const normal = Duration(milliseconds: 260);
  static const slow = Duration(milliseconds: 420);
}

/// Оптические эффекты liquid glass: преломление, frost, подсветка.
abstract final class TaroOptics {
  static const refractionHeight = 16.0;
  static const refractionAmount = 32.0; // «умеренное преломление»
  static const frost = 12.0; // умеренное размытие
  static const highlight = 0.5;
  static const contourStrength = 0.36;
  static const tintAmount = 0.15;
}
