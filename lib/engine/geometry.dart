import 'dart:math' as math;

import 'vec2.dart';

/// Wraps [angle] (radians) into the range `(-pi, pi]`.
double wrapAngle(double angle) {
  var a = angle % (2 * math.pi);
  if (a > math.pi) a -= 2 * math.pi;
  if (a <= -math.pi) a += 2 * math.pi;
  return a;
}

/// Shortest signed rotation that takes [from] to [to].
double angleDelta(double from, double to) => wrapAngle(to - from);

double lerpDouble(double a, double b, double t) => a + (b - a) * t;

/// Closest point to [p] on the segment `a..b`.
Vec2 closestPointOnSegment(Vec2 p, Vec2 a, Vec2 b) {
  final ab = b - a;
  final lengthSquared = ab.lengthSquared;
  if (lengthSquared == 0) return a;
  final t = ((p - a).dot(ab) / lengthSquared).clamp(0.0, 1.0);
  return a + ab * t;
}

double pointSegmentDistance(Vec2 p, Vec2 a, Vec2 b) =>
    p.distanceTo(closestPointOnSegment(p, a, b));

/// Minimum distance between the segments `a1..a2` and `b1..b2`.
///
/// Used for torpedo/hull collisions: both the torpedo's travel during a tick
/// and the ship's hull are modelled as segments, so a fast torpedo cannot
/// tunnel through a ship between two frames.
double segmentSegmentDistance(Vec2 a1, Vec2 a2, Vec2 b1, Vec2 b2) {
  final r = a2 - a1;
  final s = b2 - b1;
  final denominator = r.cross(s);
  if (denominator.abs() > 1e-9) {
    final qp = b1 - a1;
    final t = qp.cross(s) / denominator;
    final u = qp.cross(r) / denominator;
    if (t >= 0 && t <= 1 && u >= 0 && u <= 1) return 0; // segments intersect
  }
  return math.min(
    math.min(pointSegmentDistance(a1, b1, b2), pointSegmentDistance(a2, b1, b2)),
    math.min(pointSegmentDistance(b1, a1, a2), pointSegmentDistance(b2, a1, a2)),
  );
}
