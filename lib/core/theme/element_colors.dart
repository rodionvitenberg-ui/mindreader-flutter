import 'package:flutter/material.dart' hide Element;

import '../../design_system/taro_tokens.dart';
import '../models/tarot_card_model.dart';

/// Element → Tarot Tree accent color (badges, threads, labels, wheel glyphs).
extension ElementColorX on Element {
  Color get accent => switch (this) {
        Element.fire => TaroColors.amber,
        Element.water => TaroColors.cyan,
        Element.air => TaroColors.lavender,
        Element.earth => TaroColors.emerald,
      };
}
