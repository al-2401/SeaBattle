import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../engine/entities.dart';
import '../../engine/sight.dart';
import '../palette.dart';
import 'vessel_shapes.dart';

/// The flag at the masthead, and the neutrality markings down the hull.
///
/// Both come up out of the murk as the identification runs: at first there is
/// only a rag on the mast, no more readable than a shape, and by the time the
/// ship has been held in the sight long enough the colours are plain. A
/// neutral flies a pale flag with a cross and carries painted bands on her
/// side, the way Swedish ore carriers did; anything hostile flies dark.
void _paintColours(
  Canvas canvas,
  Vessel vessel, {
  required Offset Function(Offset) map,
  required List<List<Offset>> rigging,
  required double lengthPx,
  required double heightPx,
  required double facing,
  required double time,
  required double fade,
}) {
  // Fly it from the highest thing the ship has.
  Offset? masthead;
  for (final line in rigging) {
    for (final point in line) {
      if (masthead == null || point.dy < masthead.dy) masthead = point;
    }
  }
  if (masthead == null) return;

  final top = map(masthead);
  // Oversized on purpose: at two kilometres an honest ensign would be half a
  // pixel, and the whole mechanic is reading it. This is the same lie as the
  // exaggerated height of the optics.
  final flagLength = math.max(4.0, heightPx * 0.52);
  final flagHeight = math.max(3.0, flagLength * 0.6);
  // Flies aft, and stirs.
  final fly = -facing * flagLength;
  final wave = math.sin(time * 2.6 + vessel.id) * flagHeight * 0.12;

  final read = vessel.recognition;
  final neutral = vessel.allegiance == Allegiance.neutral;
  final rect = Rect.fromLTRB(
    math.min(top.dx, top.dx + fly),
    top.dy + wave,
    math.max(top.dx, top.dx + fly),
    top.dy + flagHeight + wave,
  );

  // Unread, the flag is the same dark rag whoever it belongs to.
  final cloth = Color.lerp(
    Palette.hull,
    neutral ? Palette.foam : const Color(0xFF241014),
    read,
  )!;
  canvas.drawRect(rect, Paint()..color = cloth.withValues(alpha: 0.95 * fade));
  // A rim off the sky behind, so the flag is still a flag when it happens to
  // hang against the ship's own superstructure.
  canvas.drawRect(
    rect,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = Palette.hullRim.withValues(alpha: 0.5 * fade),
  );

  if (neutral && read > 0.55 && flagLength > 5) {
    // The cross, once there is enough of it to see.
    final ink = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.8, flagHeight * 0.16)
      ..color = Palette.alarm.withValues(alpha: (read - 0.55) / 0.45 * fade);
    canvas.drawLine(
      Offset(rect.left, rect.center.dy),
      Offset(rect.right, rect.center.dy),
      ink,
    );
    canvas.drawLine(
      Offset(rect.left + rect.width * 0.42, rect.top),
      Offset(rect.left + rect.width * 0.42, rect.bottom),
      ink,
    );
  }

  // Neutrality bands painted on the side, the way they were in life: big,
  // and meant to be read from exactly this distance.
  if (neutral && read > 0.35 && lengthPx > 40) {
    final band = Paint()
      ..color = Palette.foam.withValues(
        alpha: 0.55 * ((read - 0.35) / 0.65) * fade,
      );
    for (final at in const [-0.22, 0.12]) {
      canvas.drawRect(
        Rect.fromLTWH(
          at * lengthPx * facing,
          -heightPx * 0.16,
          lengthPx * 0.06 * facing,
          heightPx * 0.16,
        ),
        band,
      );
    }
  }
}

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

  // --- flag and neutrality markings ---------------------------------------
  if (lengthPx > 26 && !vessel.isHit) {
    _paintColours(
      canvas,
      vessel,
      map: map,
      rigging: shape.rigging,
      lengthPx: lengthPx,
      heightPx: heightPx,
      facing: facing,
      time: time,
      fade: fade,
    );
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
