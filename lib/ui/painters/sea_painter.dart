import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../engine/geometry.dart';
import '../../engine/sight.dart';
import '../../engine/vec2.dart';
import '../palette.dart';

/// One crest of the standing wave field, fixed in world space.
class WaveCrest {
  const WaveCrest(this.bearing, this.range, this.phase, this.width);
  final double bearing;
  final double range;
  final double phase;
  final double width;
}

/// A bank of cloud, fixed in world space like everything else out there.
class CloudBank {
  const CloudBank(this.bearing, this.height, this.width, this.thickness,
      this.shade, this.seed);

  /// Where it stands, and how high above the horizon it sits — as a fraction
  /// of the window, because clouds are too far away for range to mean much.
  final double bearing;
  final double height;

  /// Angular width, radians, and how deep the bank is drawn.
  final double width;
  final double thickness;

  /// 0 the palest scud, 1 the heavy stuff low down.
  final double shade;
  final int seed;
}

/// A distant headland, there to give the eye a fixed bearing to steer by.
class Landmass {
  const Landmass(this.bearing, this.range, this.width, this.height, this.seed);
  final double bearing;
  final double range;
  final double width;
  final double height;
  final int seed;
}

/// A fixed field of wave crests and distant land.
///
/// The crests live in world coordinates, so they are projected through the
/// same optics as the ships. That is what sells the rotation: near swell
/// sweeps past quickly while the far horizon barely moves.
class SeaSurface {
  SeaSurface({int seed = 20250921}) {
    final random = math.Random(seed);
    for (var i = 0; i < 520; i++) {
      final bearing = (random.nextDouble() * 2 - 1) * 1.75;
      // Log-uniform ranges: evenly spaced once projected, so the crests thin
      // out towards the horizon the way real swell does.
      final range = 520 * math.pow(26000 / 520, random.nextDouble()).toDouble();
      waves.add(
        WaveCrest(
          bearing,
          range,
          random.nextDouble() * math.pi * 2,
          9 + random.nextDouble() * 46,
        ),
      );
    }
    waves.sort((a, b) => b.range.compareTo(a.range));

    landmarks.addAll(const [
      Landmass(-1.02, 9400, 2600, 190, 7),
      Landmass(0.62, 11800, 3400, 150, 19),
      Landmass(1.34, 8600, 1500, 120, 31),
    ]);

    // A dozen banks spread right round the arc, low and heavy near the
    // horizon, thinner and paler higher up.
    for (var i = 0; i < 14; i++) {
      final high = random.nextDouble();
      clouds.add(
        CloudBank(
          (random.nextDouble() * 2 - 1) * 1.8,
          0.05 + high * 0.30,
          0.10 + random.nextDouble() * 0.26,
          0.02 + random.nextDouble() * 0.05,
          1 - high * 0.8,
          random.nextInt(1 << 20),
        ),
      );
    }
    clouds.sort((a, b) => b.height.compareTo(a.height));
  }

  final List<WaveCrest> waves = [];
  final List<Landmass> landmarks = [];
  final List<CloudBank> clouds = [];
}

void paintSkyAndSea(Canvas canvas, Rect rect, Sight sight) {
  final horizon = sight.horizonY.clamp(rect.top, rect.bottom);

  canvas.drawRect(
    Rect.fromLTRB(rect.left, rect.top, rect.right, horizon),
    Paint()
      ..shader = ui.Gradient.linear(
        Offset(rect.center.dx, rect.top),
        Offset(rect.center.dx, horizon),
        const [Palette.skyHigh, Palette.skyMid, Palette.skyLow],
        const [0.0, 0.62, 1.0],
      ),
  );

  canvas.drawRect(
    Rect.fromLTRB(rect.left, horizon, rect.right, rect.bottom),
    Paint()
      ..shader = ui.Gradient.linear(
        Offset(rect.center.dx, horizon),
        Offset(rect.center.dx, rect.bottom),
        const [Palette.seaFar, Palette.seaMid, Palette.seaNear],
        const [0.0, 0.46, 0.98],
      ),
  );

  // Haze sitting on the horizon line, brightest where the low sun is.
  canvas.drawRect(
    Rect.fromLTRB(rect.left, horizon - 26, rect.right, horizon + 10),
    Paint()
      ..shader = ui.Gradient.linear(
        Offset(rect.center.dx, horizon - 26),
        Offset(rect.center.dx, horizon + 10),
        [Palette.haze.withValues(alpha: 0), Palette.haze.withValues(alpha: 0.30), Palette.haze.withValues(alpha: 0)],
        const [0.0, 0.62, 1.0],
      ),
  );
}

/// Cloud over the horizon: banks of blurred lozenges, standing on bearings of
/// their own so they slide past as the optics are trained, only far slower
/// than the swell. They drift on the wind too, a few minutes to cross the arc.
void paintClouds(
  Canvas canvas,
  Rect rect,
  Sight sight,
  SeaSurface surface,
  double time,
) {
  for (final cloud in surface.clouds) {
    // Windage: the higher the bank, the harder it runs.
    final drift = time * 0.0016 * (0.4 + cloud.height);
    final centerX = sight.xForBearing(
      wrapAngle(cloud.bearing + drift),
    );
    if (centerX == null) continue;

    final spread = sight.focalLength * math.tan(cloud.width / 2);
    if (centerX + spread < rect.left || centerX - spread > rect.right) continue;

    final baseY = sight.horizonY - rect.height * cloud.height;
    final random = math.Random(cloud.seed);
    final puffs = 5 + random.nextInt(5);
    final paint = Paint()
      ..maskFilter = MaskFilter.blur(
        BlurStyle.normal,
        rect.height * cloud.thickness * 0.9 + 2,
      );

    for (var i = 0; i < puffs; i++) {
      final along = (random.nextDouble() * 2 - 1);
      final lift = random.nextDouble() * cloud.thickness * rect.height;
      // Paler and bluer the higher it sits: distance eats the contrast.
      paint.color = Color.lerp(
        Palette.skyLow,
        Palette.haze,
        0.25 + 0.5 * cloud.shade,
      )!.withValues(alpha: 0.10 + 0.16 * cloud.shade);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(centerX + along * spread, baseY - lift),
          width: spread * (0.5 + random.nextDouble() * 0.9),
          height: rect.height * cloud.thickness * (0.8 + random.nextDouble()),
        ),
        paint,
      );
    }
  }
}

/// The low sun: a fixed bearing that gives the eye something to steer by.
void paintSunGlow(Canvas canvas, Rect rect, Sight sight) {
  const sunBearing = -0.44;
  final x = sight.xForBearing(sunBearing);
  if (x == null) return;
  final y = sight.horizonY - 14;
  canvas.drawCircle(
    Offset(x, y),
    rect.width * 0.34,
    Paint()
      ..shader = ui.Gradient.radial(Offset(x, y), rect.width * 0.34, [
        const Color(0xFFFFD9A0).withValues(alpha: 0.30),
        const Color(0xFFFFB86B).withValues(alpha: 0.10),
        const Color(0x00000000),
      ], const [0.0, 0.45, 1.0]),
  );
  canvas.drawCircle(
    Offset(x, y),
    13,
    Paint()
      ..color = const Color(0xFFFFE2B8).withValues(alpha: 0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
  );
}

void paintLandmarks(Canvas canvas, Rect rect, Sight sight, SeaSurface surface) {
  final paint = Paint()..color = const Color(0xFF12262B).withValues(alpha: 0.85);
  for (final land in surface.landmarks) {
    final point = sight.project(Vec2.fromBearing(land.bearing, land.range));
    if (point == null) continue;
    final halfWidth = land.width * point.metresToPixels / 2;
    if (point.dx + halfWidth < rect.left - 20 ||
        point.dx - halfWidth > rect.right + 20) {
      continue;
    }
    final height = land.height * point.metresToPixels;
    final base = point.waterlineY;
    final random = math.Random(land.seed);
    final path = Path()..moveTo(point.dx - halfWidth, base);
    const steps = 9;
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final ridge =
          math.sin(t * math.pi) * (0.55 + random.nextDouble() * 0.45);
      path.lineTo(
        point.dx - halfWidth + land.width * point.metresToPixels * t,
        base - height * ridge,
      );
    }
    path
      ..lineTo(point.dx + halfWidth, base)
      ..close();
    canvas.drawPath(path, paint);
  }
}

/// Draws the crests whose range falls in `[rangeFrom, rangeTo)`, so the
/// foreground swell can be laid over the ships while the far crests stay
/// behind them.
void paintWaves(
  Canvas canvas,
  Rect rect,
  Sight sight,
  SeaSurface surface,
  double time, {
  double rangeFrom = 0,
  double rangeTo = double.infinity,
}) {
  final crest = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  for (final wave in surface.waves) {
    if (wave.range < rangeFrom || wave.range >= rangeTo) continue;
    final point = sight.project(Vec2.fromBearing(wave.bearing, wave.range));
    if (point == null) continue;
    final scale = point.metresToPixels;
    final halfWidth = wave.width * scale * 0.5;
    if (point.dx + halfWidth < rect.left || point.dx - halfWidth > rect.right) {
      continue;
    }

    final bob = math.sin(time * 1.7 + wave.phase) * 1.8 * scale;
    final y = point.waterlineY + bob;
    if (y < sight.horizonY - 1 || y > rect.bottom + 6) continue;

    final depth = ((y - sight.horizonY) / (rect.bottom - sight.horizonY))
        .clamp(0.0, 1.0);
    final glint = 0.45 + 0.55 * (0.5 + 0.5 * math.sin(time * 1.1 + wave.phase * 2));
    final alpha = (0.07 + 0.50 * depth * depth) * glint;
    crest
      ..color = Palette.foam.withValues(alpha: alpha.clamp(0.0, 0.62))
      ..strokeWidth = math.max(0.8, 0.9 * scale);
    canvas.drawLine(
      Offset(point.dx - halfWidth, y),
      Offset(point.dx + halfWidth, y),
      crest,
    );
  }
}
