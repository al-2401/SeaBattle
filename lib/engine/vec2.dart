import 'dart:math' as math;

/// Immutable 2D vector in world space.
///
/// World coordinates are metres, seen from above: `+y` points along the
/// submarine's bow (bearing 0), `+x` points to starboard (bearing +90°).
class Vec2 {
  const Vec2(this.x, this.y);

  final double x;
  final double y;

  static const Vec2 zero = Vec2(0, 0);

  /// Unit vector for a compass-style [bearing] in radians (0 = bow).
  factory Vec2.fromBearing(double bearing, [double length = 1]) =>
      Vec2(math.sin(bearing) * length, math.cos(bearing) * length);

  Vec2 operator +(Vec2 other) => Vec2(x + other.x, y + other.y);
  Vec2 operator -(Vec2 other) => Vec2(x - other.x, y - other.y);
  Vec2 operator *(double scalar) => Vec2(x * scalar, y * scalar);
  Vec2 operator /(double scalar) => Vec2(x / scalar, y / scalar);
  Vec2 operator -() => Vec2(-x, -y);

  double get length => math.sqrt(x * x + y * y);
  double get lengthSquared => x * x + y * y;

  /// Bearing of this vector, radians, 0 = bow, positive to starboard.
  double get bearing => math.atan2(x, y);

  double dot(Vec2 other) => x * other.x + y * other.y;

  /// 2D cross product (z component of the 3D cross product).
  double cross(Vec2 other) => x * other.y - y * other.x;

  Vec2 normalized() {
    final len = length;
    if (len == 0) return Vec2.zero;
    return Vec2(x / len, y / len);
  }

  double distanceTo(Vec2 other) => (this - other).length;

  @override
  String toString() => 'Vec2(${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)})';

  @override
  bool operator ==(Object other) =>
      other is Vec2 && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}
