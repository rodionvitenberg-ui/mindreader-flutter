import 'package:flutter/material.dart' hide Element;
import '../models/tarot_card_model.dart';

/// Dark Obsidian Sanctuary tokens. No gold. No kitsch.
class AppColors {
  static const canvas = Color(0xFF09090D);
  static const surface = Color(0xFF13131A);
  static const border = Color(0x29A78BFA); // rgba(167,139,250,0.16)
  static const lavender = Color(0xFFA78BFA);
  static const indigo = Color(0xFF6366F1);
  static const harmonyCyan = Color(0xFF38BDF8);
  static const harmonyEmerald = Color(0xFF34D399);
  static const conflictRose = Color(0xFFFB7185);
  static const conflictAmber = Color(0xFFF97316);
  static const textPrimary = Color(0xFFE4E4E7);
  static const textMuted = Color(0xFF94A3B8);
}

/// Element → accent color (badges, threads, labels).
extension ElementColorX on Element {
  Color get accent => switch (this) {
        Element.fire => const Color(0xFFF97316),
        Element.water => const Color(0xFF38BDF8),
        Element.air => const Color(0xFFA78BFA),
        Element.earth => const Color(0xFF34D399),
      };
}

/// Standard game-feel spring shared across all card motion.
const spring = SpringDescription(mass: 1.0, stiffness: 320.0, damping: 24.0);

/// Perspective entry for 2.5D card transforms.
const perspectiveEntry = 0.0012;

/// Isometric tilt of board slots (~8 degrees).
const slotTiltRadians = -0.14;
