import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sea_battle/engine/sight.dart';
import 'package:sea_battle/engine/vec2.dart';

Sight sightAt(double heading) => Sight(
  width: 600,
  height: 600,
  horizonY: 240,
  heading: heading,
  fieldOfView: 30 * math.pi / 180,
  eyeHeight: 34,
);

void main() {
  group('Sight', () {
    test('the trained bearing lands in the middle of the glass', () {
      for (final heading in const [-0.9, -0.2, 0.0, 0.5, 1.1]) {
        final sight = sightAt(heading);
        expect(sight.xForBearing(heading), closeTo(sight.centerX, 1e-9));
      }
    });

    test('the edges of the field sit at the edges of the optic', () {
      final sight = sightAt(0);
      expect(sight.xForBearing(sight.fieldOfView / 2), closeTo(600, 1e-6));
      expect(sight.xForBearing(-sight.fieldOfView / 2), closeTo(0, 1e-6));
    });

    test('anything abeam or behind is not projected', () {
      final sight = sightAt(0);
      expect(sight.xForBearing(math.pi / 2), isNull);
      expect(sight.project(const Vec2(0, -1000)), isNull);
    });

    test('closer targets sit lower down the glass and look bigger', () {
      final sight = sightAt(0);
      final near = sight.project(const Vec2(0, 900))!;
      final far = sight.project(const Vec2(0, 2800))!;

      expect(near.waterlineY, greaterThan(far.waterlineY));
      expect(near.metresToPixels, greaterThan(far.metresToPixels));
      expect(far.waterlineY, greaterThan(sight.horizonY));
    });

    test('training the optics slides the picture the other way', () {
      const contact = Vec2(0, 1500);
      final centred = sightAt(0).project(contact)!;
      final trained = sightAt(0.1).project(contact)!;

      expect(centred.dx, closeTo(300, 1e-9));
      expect(trained.dx, lessThan(centred.dx));
      expect(trained.waterlineY, closeTo(centred.waterlineY, 1e-9));
    });

    test('range scale is inverse in range', () {
      final sight = sightAt(0);
      expect(
        sight.scaleForRange(1000) / sight.scaleForRange(2000),
        closeTo(2, 1e-9),
      );
    });

    test('a narrower field magnifies the picture', () {
      final wide = Sight(
        width: 600,
        height: 600,
        horizonY: 240,
        heading: 0,
        fieldOfView: 60 * math.pi / 180,
        eyeHeight: 34,
      );
      final narrow = sightAt(0);
      expect(narrow.focalLength, greaterThan(wide.focalLength));
      expect(
        narrow.scaleForRange(1500),
        greaterThan(wide.scaleForRange(1500)),
      );
    });

    test('relative bearing comes back with the projected point', () {
      final sight = sightAt(0.3);
      final point = sight.project(Vec2.fromBearing(0.2, 2000))!;
      expect(point.relativeBearing, closeTo(-0.1, 1e-9));
      expect(point.range, closeTo(2000, 1e-9));
    });
  });
}
