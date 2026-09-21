import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../engine/entities.dart';
import '../../engine/sight.dart';
import '../palette.dart';
import 'vessel_shapes.dart';

/// Draws one target: reflection, bow wave, silhouette, and — once it is hit —
/// the list and the smoke.
void paintVessel(
  Canvas canvas,
  Rect rect,
  Sight sight,
  Vessel vessel,
  double time,
) {
  final point = sight.project(vessel.position);
  if (point == null) return;

  final scale = point.metresToPixels;
  // Bow-on ships show their beam, broadside ships their whole length.
  final apparentMetres =
      vessel.type.length * vessel.aspect +
      vessel.type.beam * (1 - vessel.aspect);
  final lengthPx = apparentMetres * scale;
  final heightPx = vessel.type.height * scale;
  if (lengthPx < 1.2 || heightPx < 0.8) return;
  if (point.dx + lengthPx < rect.left - 40 ||
      point.dx - lengthPx > rect.right + 40) {
    return;
  }

  final shape = vesselShape(vessel.type, vessel.silhouetteSeed);
  final facing = vessel.bearingRate >= 0 ? 1.0 : -1.0;
  final sinking = vessel.sinking;

  canvas.save();
  canvas.translate(point.dx, point.waterlineY);

  // A hit ship settles by the stern and rolls away from the torpedo track.
  if (sinking > 0) {
    canvas.translate(0, heightPx * sinking * 0.55);
    canvas.rotate(sinking * 0.30 * facing);
  }

  final fade = (1 - math.pow(sinking, 2.2)).toDouble().clamp(0.0, 1.0);

  Offset map(Offset n) => Offset(n.dx * lengthPx * facing, n.dy * heightPx);
  Offset mirror(Offset n) =>
      Offset(n.dx * lengthPx * facing, -n.dy * heightPx * 0.42);

  Path toPath(List<Offset> poly, Offset Function(Offset) fn) {
    final path = Path()..moveTo(fn(poly.first).dx, fn(poly.first).dy);
    for (final p in poly.skip(1)) {
      final o = fn(p);
      path.lineTo(o.dx, o.dy);
    }
    return path..close();
  }

  // --- reflection on the water -------------------------------------------
  if (heightPx > 3) {
    final reflection = Paint()
      ..color = Palette.hull.withValues(alpha: 0.35 * fade)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.4);
    for (final part in shape.parts) {
      canvas.drawPath(toPath(part, mirror), reflection);
    }
  }

  // --- wake and bow wave --------------------------------------------------
  if (!vessel.isHit && lengthPx > 6) {
    final wakeLength = lengthPx * (0.5 + vessel.speed / 140);
    final wake = Paint()
      ..color = Palette.foam.withValues(alpha: 0.22)
      ..style = PaintingStyle.fill;
    final sternX = -0.5 * lengthPx * facing;
    final wakePath = Path()
      ..moveTo(sternX, -heightPx * 0.02)
      ..lineTo(sternX - wakeLength * facing, math.max(1.2, heightPx * 0.10))
      ..lineTo(sternX - wakeLength * facing, math.max(2.4, heightPx * 0.18))
      ..lineTo(sternX, math.max(1.6, heightPx * 0.08))
      ..close();
    canvas.drawPath(wakePath, wake);

    final bowX = 0.5 * lengthPx * facing;
    final bowWave = Paint()..color = Palette.foam.withValues(alpha: 0.5);
    final swell = 1 + 0.15 * math.sin(time * 4 + vessel.id);
    canvas.drawPath(
      Path()
        ..moveTo(bowX, 0)
        ..lineTo(bowX - lengthPx * 0.12 * facing, math.max(1.0, heightPx * 0.07 * swell))
        ..lineTo(bowX + lengthPx * 0.06 * facing, math.max(1.0, heightPx * 0.05))
        ..close(),
      bowWave,
    );
  }

  // --- silhouette ---------------------------------------------------------
  final body = Paint()..color = Palette.hull.withValues(alpha: fade);
  for (final part in shape.parts) {
    canvas.drawPath(toPath(part, map), body);
  }

  // Cold rim light picked up from the sky behind.
  if (lengthPx > 18) {
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..color = Palette.hullRim.withValues(alpha: 0.35 * fade);
    for (final part in shape.parts) {
      canvas.drawPath(toPath(part, map), rim);
    }
  }

  // --- masts and rigging --------------------------------------------------
  if (lengthPx > 26) {
    final rigging = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.8, lengthPx * 0.006)
      ..color = Palette.hull.withValues(alpha: 0.9 * fade);
    for (final line in shape.rigging) {
      final a = map(line.first);
      final b = map(line.last);
      canvas.drawLine(a, b, rigging);
    }
  }

  // --- damage -------------------------------------------------------------
  if (sinking > 0) {
    final glow = Paint()
      ..color = Palette.fire.withValues(alpha: 0.55 * (1 - sinking))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, heightPx * 0.25 + 2);
    canvas.drawCircle(
      Offset(0, -heightPx * 0.35),
      heightPx * 0.42 + 2,
      glow,
    );

    final smoke = Paint()
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, heightPx * 0.2 + 3);
    for (var i = 0; i < 4; i++) {
      final t = (sinking * 1.4 + i * 0.22) % 1.0;
      smoke.color = Color.lerp(
        Palette.smoke,
        Palette.steel,
        0.35 + 0.3 * t,
      )!.withValues(alpha: 0.42 * (1 - t) * fade);
      canvas.drawCircle(
        Offset(
          math.sin(time * 0.9 + i) * heightPx * 0.4,
          -heightPx * (0.6 + t * 2.6),
        ),
        heightPx * (0.35 + t * 0.9) + 2,
        smoke,
      );
    }
  }

  canvas.restore();
}
