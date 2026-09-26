import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../engine/entities.dart';
import '../../engine/sight.dart';
import '../palette.dart';

/// The torpedo's track.
///
/// Every point of the run shares one bearing, so in a rectilinear projection
/// the wake is a vertical wedge — wide and close at the bottom of the glass,
/// tapering to the running torpedo. Train the periscope away and the track
/// slides across the field like it should.
void paintTorpedo(
  Canvas canvas,
  Rect rect,
  Sight sight,
  Torpedo torpedo,
  double time,
) {
  final x = sight.xForBearing(torpedo.bearing);
  if (x == null || x < rect.left - 60 || x > rect.right + 60) return;

  // Start the drawn track at a range that is still on the glass; anything
  // closer projects far below the bottom of the optic.
  const nearRange = 460.0;
  final run = math.max(torpedo.distanceRun, nearRange + 1);

  final yNear = sight.yForRange(nearRange);
  final yHead = sight.yForRange(run);
  // A torpedo wake is narrow; cap it in pixels so a close-in shot does not
  // smear a cone across half the field.
  final halfNear = math.min(11.0, 3.0 * sight.scaleForRange(nearRange));
  final halfHead = math.max(0.5, 3.0 * sight.scaleForRange(run));

  // The disturbed water fades as it falls astern of the running torpedo.
  canvas.drawPath(
    Path()
      ..moveTo(x - halfNear, yNear)
      ..lineTo(x - halfHead, yHead)
      ..lineTo(x + halfHead, yHead)
      ..lineTo(x + halfNear, yNear)
      ..close(),
    Paint()
      ..shader = ui.Gradient.linear(Offset(x, yHead), Offset(x, yNear), [
        Palette.foam.withValues(alpha: 0.30),
        Palette.foam.withValues(alpha: 0.04),
      ]),
  );

  // Bubbles boiling up along the track.
  final bubble = Paint()..color = Palette.foam.withValues(alpha: 0.5);
  const samples = 22;
  for (var i = 0; i <= samples; i++) {
    final t = i / samples;
    final range = nearRange + (run - nearRange) * t;
    final y = sight.yForRange(range);
    final scale = sight.scaleForRange(range);
    final wobble = math.sin(time * 9 + i * 1.7) * math.min(6.0, 2.0 * scale);
    final radius = math.max(0.5, math.min(3.0, 0.9 * scale));
    bubble.color = Palette.foam.withValues(alpha: 0.12 + 0.48 * t);
    canvas.drawCircle(Offset(x + wobble, y), radius, bubble);
  }

  // The torpedo itself, just under the surface.
  final headScale = sight.scaleForRange(run);
  canvas.drawCircle(
    Offset(x, yHead),
    math.max(1.2, math.min(5.0, 2.5 * headScale)),
    Paint()..color = Palette.foam.withValues(alpha: 0.85),
  );
}

void paintMine(Canvas canvas, Rect rect, Sight sight, Mine mine, double time) {
  final point = sight.project(mine.position);
  if (point == null) return;
  final scale = point.metresToPixels;
  final radius = math.max(1.6, 4.5 * scale);
  if (point.dx < rect.left - 20 || point.dx > rect.right + 20) return;

  final bob = math.sin(time * 1.4 + mine.bobPhase) * 1.2 * scale;
  final center = Offset(point.dx, point.waterlineY - radius * 0.55 + bob);

  final horn = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(0.7, radius * 0.16)
    ..color = Palette.hull;
  for (var i = -2; i <= 2; i++) {
    final angle = -math.pi / 2 + i * 0.44;
    canvas.drawLine(
      center + Offset(math.cos(angle), math.sin(angle)) * radius,
      center + Offset(math.cos(angle), math.sin(angle)) * (radius * 1.45),
      horn,
    );
  }

  canvas.drawCircle(center, radius, Paint()..color = Palette.hull);
  canvas.drawCircle(
    center + Offset(-radius * 0.3, -radius * 0.3),
    radius * 0.3,
    Paint()..color = Palette.hullRim.withValues(alpha: 0.35),
  );

  // Ripple where it sits in the water.
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(point.dx, point.waterlineY),
      width: radius * 3.4,
      height: radius * 0.9,
    ),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.6, radius * 0.12)
      ..color = Palette.foam.withValues(alpha: 0.30),
  );
}

void paintBlast(Canvas canvas, Rect rect, Sight sight, Blast blast) {
  final point = sight.project(blast.position);
  if (point == null) return;
  final scale = point.metresToPixels;
  final t = blast.progress;
  final fade = (1 - t * t).clamp(0.0, 1.0);
  final base = Offset(point.dx, point.waterlineY);

  final metres = switch (blast.kind) {
    BlastKind.hit => 58.0 * blast.scale,
    BlastKind.mine => 44.0,
    BlastKind.splash => 24.0,
  };
  final height = metres * scale * (0.45 + 1.85 * math.sqrt(t));
  final width = metres * scale * (0.42 + 0.75 * t);
  if (height < 1) return;

  final random = math.Random(blast.kind.index * 977 + 13);
  final water = Paint()
    ..color = Palette.foam.withValues(alpha: 0.50 * fade)
    ..maskFilter = MaskFilter.blur(
      BlurStyle.normal,
      math.max(0.6, width * 0.035),
    );

  // The column is built from overlapping puffs rather than one outline, so it
  // boils like thrown water instead of standing there like a tent.
  const puffs = 9;
  for (var i = 0; i < puffs; i++) {
    final u = i / (puffs - 1);
    final lean = (random.nextDouble() - 0.5) * width * 0.55;
    final radius =
        width * 0.30 * (1.05 - 0.5 * u) * (0.75 + random.nextDouble() * 0.6);
    canvas.drawCircle(
      Offset(base.dx + lean * u, base.dy - height * u),
      math.max(0.8, radius),
      water,
    );
  }
  // Foam spreading at the foot of the column.
  canvas.drawOval(
    Rect.fromCenter(
      center: base,
      width: width * (1.1 + 0.9 * t),
      height: width * (0.22 + 0.16 * t),
    ),
    Paint()..color = Palette.foam.withValues(alpha: 0.26 * fade),
  );

  // Spray thrown clear of the column.
  final spray = Paint()..color = Palette.foam.withValues(alpha: 0.55 * fade);
  for (var i = 0; i < 18; i++) {
    final angle = -math.pi / 2 + (random.nextDouble() - 0.5) * 2.4;
    final reach = height * (0.7 + random.nextDouble() * 1.1) * t;
    canvas.drawCircle(
      base + Offset(math.cos(angle) * reach, math.sin(angle) * reach * 0.9),
      math.max(0.6, math.min(3.5, 0.9 * scale)),
      spray,
    );
  }

  if (blast.kind != BlastKind.splash) {
    // Flash at the moment of detonation.
    final flash = (1 - t * 3.2).clamp(0.0, 1.0);
    if (flash > 0) {
      canvas.drawCircle(
        base + Offset(0, -height * 0.30),
        width * (0.55 + t * 2.2),
        Paint()
          ..color = Palette.fire.withValues(alpha: 0.80 * flash)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 + width * 0.25),
      );
    }
    // Shock ring running out across the surface.
    canvas.drawOval(
      Rect.fromCenter(
        center: base,
        width: width * (1.2 + 3.0 * t),
        height: width * (1.2 + 3.0 * t) * 0.18,
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.8, math.min(2.0, 0.6 * scale))
        ..color = Palette.foam.withValues(alpha: 0.22 * fade),
    );
  }
}
