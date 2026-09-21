import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../engine/entities.dart';

/// A ship silhouette in normalised space.
///
/// `x` runs -0.5 (stern) to +0.5 (bow) across the apparent length, `y` runs
/// 0 (waterline) to -1 (masthead). The painter maps that box onto the
/// projected size, so one shape serves every range.
class VesselShape {
  VesselShape(this.parts, this.rigging);

  final List<List<Offset>> parts;
  final List<List<Offset>> rigging;
}

final Map<String, VesselShape> _cache = {};

VesselShape vesselShape(VesselClass type, int seed) {
  final variant = seed % 4;
  return _cache.putIfAbsent(
    '${type.name}-$variant',
    () => _build(type, math.Random(variant * 7919 + type.index * 104729)),
  );
}

List<Offset> _box(double x0, double x1, double top, double bottom) => [
  Offset(x0, bottom),
  Offset(x0, top),
  Offset(x1, top),
  Offset(x1, bottom),
];

/// Hull with a square transom and a raked, sheered bow.
List<Offset> _hull(double deck, {double bowRise = 1.25, double flare = 0.0}) => [
  const Offset(-0.5, 0),
  Offset(-0.5, -deck),
  Offset(-0.46 - flare, -deck * 1.02),
  Offset(0.26, -deck * 1.04),
  Offset(0.42, -deck * bowRise),
  Offset(0.5, -deck * (bowRise - 0.12)),
  const Offset(0.5, 0),
];

VesselShape _build(VesselClass type, math.Random rng) {
  double jitter(double amount) => (rng.nextDouble() - 0.5) * amount;

  switch (type) {
    case VesselClass.destroyer:
      const deck = 0.24;
      return VesselShape(
        [
          _hull(deck),
          _box(0.20, 0.32, -0.44, -deck), // A turret
          _box(-0.40, -0.30, -0.40, -deck), // Y turret
          _box(-0.26, 0.18, -0.46, -deck), // deckhouse
          _box(-0.02, 0.16, -0.68, -deck), // bridge
          _box(0.03, 0.11, -0.82 + jitter(0.04), -deck), // pilot house
          _box(-0.09, -0.02, -0.74 + jitter(0.05), -deck), // fore funnel
          _box(-0.30, -0.23, -0.70 + jitter(0.05), -deck), // aft funnel
        ],
        [
          [const Offset(0.09, -0.80), const Offset(0.07, -1.0)],
          [const Offset(0.07, -0.98), const Offset(-0.06, -0.80)],
          [const Offset(0.07, -0.98), const Offset(0.20, -0.72)],
          [const Offset(-0.34, -0.42), const Offset(-0.33, -0.86)],
        ],
      );

    case VesselClass.cruiser:
      const deck = 0.26;
      return VesselShape(
        [
          _hull(deck, flare: 0.02),
          _box(0.16, 0.30, -0.46, -deck),
          _box(0.30, 0.40, -0.40, -deck),
          _box(-0.44, -0.30, -0.46, -deck),
          _box(-0.30, 0.16, -0.50, -deck),
          _box(-0.04, 0.14, -0.74, -deck),
          _box(0.01, 0.09, -0.92 + jitter(0.05), -deck),
          _box(-0.14, -0.06, -0.76 + jitter(0.04), -deck),
          _box(-0.28, -0.20, -0.72 + jitter(0.04), -deck),
        ],
        [
          [const Offset(0.05, -0.90), const Offset(0.04, -1.0)],
          [const Offset(0.04, -1.0), const Offset(-0.12, -0.78)],
          [const Offset(0.04, -1.0), const Offset(0.22, -0.66)],
          [const Offset(-0.32, -0.48), const Offset(-0.31, -0.92)],
          [const Offset(-0.31, -0.92), const Offset(-0.18, -0.70)],
        ],
      );

    case VesselClass.freighter:
      const deck = 0.30;
      return VesselShape(
        [
          _hull(deck, bowRise: 1.18),
          _box(-0.34, -0.08, -0.62, -deck), // midships bridge block
          _box(-0.28, -0.14, -0.74, -deck),
          _box(-0.24, -0.17, -0.88 + jitter(0.05), -deck), // funnel
          _box(0.04, 0.34, -0.40, -deck), // forward hatches
          _box(-0.46, -0.36, -0.40, -deck), // aft hatch
        ],
        [
          [const Offset(-0.02, -0.38), const Offset(-0.02, -0.92)],
          [const Offset(-0.02, -0.92), const Offset(0.18, -0.44)],
          [const Offset(0.38, -0.38), const Offset(0.38, -0.84)],
          [const Offset(0.38, -0.84), const Offset(0.20, -0.44)],
        ],
      );

    case VesselClass.tanker:
      const deck = 0.32;
      return VesselShape(
        [
          _hull(deck, bowRise: 1.12),
          _box(-0.48, -0.28, -0.64, -deck), // accommodation aft
          _box(-0.44, -0.33, -0.80, -deck),
          _box(-0.41, -0.36, -0.94 + jitter(0.06), -deck), // funnel
          _box(-0.06, 0.06, -0.48, -deck), // manifold
          _box(0.28, 0.40, -0.40, -deck), // forecastle
        ],
        [
          [const Offset(0.0, -0.46), const Offset(0.0, -0.74)],
          [const Offset(-0.20, -0.34), const Offset(-0.20, -0.52)],
          [const Offset(0.20, -0.34), const Offset(0.20, -0.52)],
        ],
      );

    case VesselClass.patrolBoat:
      const deck = 0.34;
      return VesselShape(
        [
          _hull(deck, bowRise: 1.5),
          _box(-0.16, 0.12, -0.66, -deck),
          _box(-0.08, 0.06, -0.80 + jitter(0.06), -deck),
          _box(0.20, 0.32, -0.48, -deck),
        ],
        [
          [const Offset(-0.01, -0.78), const Offset(-0.01, -1.0)],
          [const Offset(-0.01, -1.0), const Offset(-0.18, -0.70)],
        ],
      );

    case VesselClass.submarine:
      const deck = 0.30;
      return VesselShape(
        [
          [
            const Offset(-0.5, 0),
            const Offset(-0.46, -deck * 0.8),
            const Offset(0.30, -deck),
            const Offset(0.46, -deck * 0.75),
            const Offset(0.5, 0),
          ],
          _box(-0.10, 0.12, -0.76, -deck * 0.9),
          _box(-0.04, 0.06, -0.86 + jitter(0.04), -deck),
        ],
        [
          [const Offset(0.02, -0.84), const Offset(0.02, -1.0)],
          [const Offset(-0.06, -0.80), const Offset(-0.06, -0.96)],
        ],
      );
  }
}
