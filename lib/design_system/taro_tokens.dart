import 'package:flutter/material.dart';

/// Tarot Tree — централизованные design tokens (Phase G1).
///
/// Отдельная система от [AppColors] (Dark Obsidian). Значения палитры задачи
/// живут здесь и НЕ подменяют существующую тему до визуального согласования.
/// Каждый параметр меняется в одном месте.
abstract final class TaroColors {
  static const background = Color(0xFF151725);
  static const surface = Color(0xFF282739);
  static const canvas = Color(0xFF625B75);
  static const mist = Color(0xFFA9A4BE);
  static const rose = Color(0xFFD4A8AC);
  static const dawn = Color(0xFFF0C7A4);
  static const textPrimary = Color(0xFFF2EBE4);
  static const textSecondary = Color(0xFFC5C0D0);

  /// Акценты подсветки для направления de-press.co + тёплый летний рассвет.
  static const lavender = Color(0xFFA78BFA);
  static const indigo = Color(0xFF6366F1);
  static const error = Color(0xFFE9A0A6);
}

/// Прозрачности поверхностей, бордеров и текста.
abstract final class TaroOpacity {
  static const surface = 0.55;
  static const surfaceStrong = 0.74;
  static const border = 0.18;
  static const borderStrong = 0.42;
  static const textMuted = 0.72;
  static const glow = 0.30;
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
