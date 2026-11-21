import 'package:flutter/physics.dart';

/// Standard game-feel spring shared across all card motion.
const spring = SpringDescription(mass: 1.0, stiffness: 320.0, damping: 24.0);

/// Heavier deck spring — squares the riffle packets back into a tight,
/// aligned 78-layer stack after the finger lifts (mass 1, 380/26).
const deckSpring = SpringDescription(mass: 1.0, stiffness: 380.0, damping: 26.0);

/// Perspective entry for 2.5D card transforms.
const perspectiveEntry = 0.0012;

/// Stronger perspective for the 3D riffle/weave packet arcs.
const deckPerspectiveEntry = 0.0016;

/// Isometric tilt of board slots (~8 degrees).
const slotTiltRadians = -0.14;
