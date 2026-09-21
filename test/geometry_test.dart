import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sea_battle/engine/geometry.dart';
import 'package:sea_battle/engine/vec2.dart';

void main() {
  group('angles', () {
    test('wraps into (-pi, pi]', () {
      expect(wrapAngle(0), 0);
      expect(wrapAngle(3 * math.pi), closeTo(math.pi, 1e-12));
      expect(wrapAngle(-3 * math.pi), closeTo(math.pi, 1e-12));
      expect(wrapAngle(math.pi * 1.5), closeTo(-math.pi * 0.5, 1e-12));
    });

    test('delta takes the short way round', () {
      expect(angleDelta(0.1, -0.1), closeTo(-0.2, 1e-12));
      expect(
        angleDelta(math.pi - 0.1, -math.pi + 0.1),
        closeTo(0.2, 1e-12),
      );
    });
  });

  group('Vec2', () {
    test('bearing is measured from the bow, positive to starboard', () {
      expect(const Vec2(0, 100).bearing, 0);
      expect(const Vec2(100, 0).bearing, closeTo(math.pi / 2, 1e-12));
      expect(const Vec2(-100, 0).bearing, closeTo(-math.pi / 2, 1e-12));
    });

    test('fromBearing round-trips', () {
      for (final bearing in const [-1.2, -0.3, 0.0, 0.45, 1.1]) {
        final v = Vec2.fromBearing(bearing, 1700);
        expect(v.bearing, closeTo(bearing, 1e-12));
        expect(v.length, closeTo(1700, 1e-9));
      }
    });
  });

  group('segment distance', () {
    test('zero when the segments cross', () {
      expect(
        segmentSegmentDistance(
          const Vec2(-10, 0),
          const Vec2(10, 0),
          const Vec2(0, -10),
          const Vec2(0, 10),
        ),
        0,
      );
    });

    test('parallel segments keep their separation', () {
      expect(
        segmentSegmentDistance(
          const Vec2(0, 0),
          const Vec2(10, 0),
          const Vec2(0, 4),
          const Vec2(10, 4),
        ),
        closeTo(4, 1e-12),
      );
    });

    test('falls back to the nearest endpoint when they do not overlap', () {
      expect(
        segmentSegmentDistance(
          const Vec2(0, 0),
          const Vec2(1, 0),
          const Vec2(5, 0),
          const Vec2(6, 0),
        ),
        closeTo(4, 1e-12),
      );
    });

    test('point-to-segment clamps to the ends', () {
      expect(
        pointSegmentDistance(const Vec2(-5, 0), Vec2.zero, const Vec2(10, 0)),
        closeTo(5, 1e-12),
      );
      expect(
        pointSegmentDistance(const Vec2(5, 3), Vec2.zero, const Vec2(10, 0)),
        closeTo(3, 1e-12),
      );
    });
  });
}
