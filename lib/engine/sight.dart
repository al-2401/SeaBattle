import 'dart:math' as math;

import 'geometry.dart';
import 'vec2.dart';

/// Where a world point lands in the eyepiece.
class SightPoint {
  const SightPoint({
    required this.dx,
    required this.waterlineY,
    required this.metresToPixels,
    required this.relativeBearing,
    required this.range,
  });

  /// Horizontal position in the optic, in pixels from the left edge.
  final double dx;

  /// Vertical position of the object's waterline, in pixels from the top.
  final double waterlineY;

  /// Scale factor turning metres of the object into pixels on the glass.
  final double metresToPixels;

  final double relativeBearing;
  final double range;
}

/// A rectilinear pinhole projection of the sea onto the eyepiece.
///
/// One focal length ties everything together: how far apart two bearings look,
/// how far below the horizon a given range sits, and how large a ship of a
/// given length is drawn.
class Sight {
  Sight({
    required this.width,
    required this.height,
    required this.horizonY,
    required this.heading,
    required this.fieldOfView,
    required this.eyeHeight,
  });

  final double width;
  final double height;
  final double horizonY;

  /// Bearing the optics are trained on.
  final double heading;
  final double fieldOfView;

  /// Exaggerated height of the optics above the water, metres.
  final double eyeHeight;

  /// Pixels per radian at the centre of the field.
  late final double focalLength = (width / 2) / math.tan(fieldOfView / 2);

  double get centerX => width / 2;

  /// Screen x for an absolute [bearing], or null when it falls outside the
  /// half-plane in front of the optics.
  double? xForBearing(double bearing) {
    final relative = wrapAngle(bearing - heading);
    if (relative.abs() >= math.pi / 2 - 0.02) return null;
    return centerX + focalLength * math.tan(relative);
  }

  double yForRange(double range) =>
      horizonY + focalLength * eyeHeight / math.max(range, 1);

  double scaleForRange(double range) => focalLength / math.max(range, 1);

  /// Projects a world position, or returns null when it is behind the optics.
  SightPoint? project(Vec2 position) {
    final range = position.length;
    if (range < 1) return null;
    final relative = wrapAngle(position.bearing - heading);
    if (relative.abs() >= math.pi / 2 - 0.02) return null;
    return SightPoint(
      dx: centerX + focalLength * math.tan(relative),
      waterlineY: yForRange(range),
      metresToPixels: scaleForRange(range),
      relativeBearing: relative,
      range: range,
    );
  }
}
