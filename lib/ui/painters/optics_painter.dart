import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../engine/sight.dart';
import '../../engine/world.dart';
import '../palette.dart';
import '../strings.dart';

void drawLabel(
  Canvas canvas,
  String text,
  Offset at, {
  double size = 9,
  Color color = Palette.reticle,
  double opacity = 1,
  TextAlign align = TextAlign.center,
  double letterSpacing = 1.2,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: kStencil.copyWith(
        fontSize: size,
        color: color.withValues(alpha: opacity),
      ).copyWith(letterSpacing: letterSpacing),
    ),
    textAlign: align,
    textDirection: TextDirection.ltr,
  )..layout();
  final dx = switch (align) {
    TextAlign.left => 0.0,
    TextAlign.right => -painter.width,
    _ => -painter.width / 2,
  };
  painter.paint(canvas, at + Offset(dx, -painter.height / 2));
}

/// Etched graticule: the part of the picture that belongs to the optics and
/// therefore never rolls with the swell.
void paintReticle(Canvas canvas, Rect rect, Sight sight) {
  final line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1
    ..color = Palette.reticle.withValues(alpha: 0.55);
  final faint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1
    ..color = Palette.reticleDim.withValues(alpha: 0.55);

  final cx = sight.centerX;
  final hy = sight.horizonY;

  // Horizontal graticule along the nominal horizon, graduated in degrees.
  canvas.drawLine(Offset(rect.left, hy), Offset(cx - 26, hy), line);
  canvas.drawLine(Offset(cx + 26, hy), Offset(rect.right, hy), line);

  for (var deg = 1; deg <= 18; deg++) {
    final offset = sight.focalLength * math.tan(deg * math.pi / 180);
    final major = deg % 5 == 0;
    final tick = major ? 9.0 : 4.5;
    for (final sign in const [-1.0, 1.0]) {
      final x = cx + offset * sign;
      if (x < rect.left || x > rect.right) continue;
      canvas.drawLine(
        Offset(x, hy - tick),
        Offset(x, hy + tick),
        major ? line : faint,
      );
      if (major) {
        drawLabel(
          canvas,
          '$deg',
          Offset(x, hy - tick - 8),
          size: 8,
          opacity: 0.6,
        );
      }
    }
  }

  // Vertical stadimeter with range marks.
  canvas.drawLine(Offset(cx, hy + 22), Offset(cx, rect.bottom), faint);
  for (final range in const [3000.0, 2000.0, 1500.0, 1000.0]) {
    final y = sight.yForRange(range);
    if (y > rect.bottom - 4 || y < hy + 6) continue;
    canvas.drawLine(Offset(cx - 7, y), Offset(cx + 7, y), faint);
    drawLabel(
      canvas,
      '${(range / 100).round()}',
      Offset(cx + 20, y),
      size: 8,
      color: Palette.reticleDim,
      opacity: 0.85,
    );
  }

  // Aiming pip and lead chevrons: hold one of these ahead of a crossing ship.
  canvas.drawCircle(Offset(cx, hy), 3.2, line);
  for (final sign in const [-1.0, 1.0]) {
    for (final deg in const [3.0, 6.0]) {
      final x = cx + sign * sight.focalLength * math.tan(deg * math.pi / 180);
      canvas.drawPath(
        Path()
          ..moveTo(x - 4 * sign, hy - 6)
          ..lineTo(x, hy)
          ..lineTo(x - 4 * sign, hy + 6),
        faint,
      );
    }
  }
}

/// Half the width the field still has at height [y], found by feeling along
/// the outline rather than assuming its shape.
///
/// Anything laid out across the field — the bearing tape, the threat strip —
/// has to stop short of wherever the glass curves away, and that is a
/// different place for every mask the window can wear.
double fieldHalfWidth(Rect rect, Path field, double y) {
  if (!field.contains(Offset(rect.center.dx, y))) return 0;
  var inside = 0.0;
  var outside = rect.width / 2;
  for (var i = 0; i < 12; i++) {
    final middle = (inside + outside) / 2;
    if (field.contains(Offset(rect.center.dx + middle, y))) {
      inside = middle;
    } else {
      outside = middle;
    }
  }
  return inside;
}

/// Bearing tape across the top of the field: absolute bearings, so it slides
/// as the periscope is trained and tells you where you are looking.
void paintBearingTape(
  Canvas canvas,
  Rect rect,
  Path field,
  Sight sight,
  double traverseLimit,
) {
  final tapeY = rect.top + rect.height * 0.16;
  // Labels sit above the tape, so the run is measured where they are.
  final reach = math.min(
    fieldHalfWidth(rect, field, tapeY),
    fieldHalfWidth(rect, field, tapeY - 17),
  ) - 10;
  if (reach <= 20) return;
  final left = rect.center.dx - reach;
  final right = rect.center.dx + reach;

  final line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1
    ..color = Palette.reticle.withValues(alpha: 0.35);

  canvas.drawLine(Offset(left, tapeY), Offset(right, tapeY), line);

  final limitDeg = traverseLimit * 180 / math.pi;
  for (var deg = -95; deg <= 95; deg += 5) {
    final x = sight.xForBearing(deg * math.pi / 180);
    if (x == null || x < left || x > right) continue;
    final major = deg % 15 == 0;
    final beyond = deg.abs() > limitDeg;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = major ? 1.4 : 1
      ..color = (beyond ? Palette.alarm : Palette.reticle).withValues(
        alpha: beyond ? 0.55 : (major ? 0.75 : 0.35),
      );
    canvas.drawLine(
      Offset(x, tapeY - (major ? 8 : 4)),
      Offset(x, tapeY + (major ? 8 : 4)),
      paint,
    );
    if (major) {
      final label = Ru.bearingMark(deg);
      drawLabel(
        canvas,
        label,
        Offset(x, tapeY - 17),
        size: 8.5,
        color: beyond ? Palette.alarm : Palette.reticle,
        opacity: 0.8,
      );
    }
  }

  // Index mark showing the trained bearing.
  canvas.drawPath(
    Path()
      ..moveTo(sight.centerX, tapeY + 12)
      ..lineTo(sight.centerX - 5, tapeY + 21)
      ..lineTo(sight.centerX + 5, tapeY + 21)
      ..close(),
    Paint()..color = Palette.lamp.withValues(alpha: 0.9),
  );
}

/// The threat strip: the whole trained arc squeezed into one short scale,
/// sitting under the bearing tape.
///
/// The tape above it shows the 30° actually in the eyepiece; this shows all
/// ±72° at once, so something creeping up on the far side of the arc can be
/// seen coming. Only threats are marked — hunters and mines. Targets are
/// deliberately absent: hunting them down in a narrow field of view is the
/// game, and a repeater that showed them would play it for you.
void paintThreatStrip(
  Canvas canvas,
  Rect rect,
  Path field,
  Sight sight,
  double traverseLimit,
  double fieldOfView,
  List<Threat> threats,
) {
  final y = rect.top + rect.height * 0.16 + 34;
  final width = math.min(
    rect.width * 0.54,
    (fieldHalfWidth(rect, field, y + 15) - 12) * 2,
  );
  if (width <= 40) return;
  final left = rect.center.dx - width / 2;

  /// Bearing to a position along the strip.
  double xFor(double bearing) =>
      left + width * (bearing.clamp(-traverseLimit, traverseLimit) / traverseLimit + 1) / 2;

  // The slice of arc the optics are actually looking at.
  final windowRect = Rect.fromLTRB(
    xFor(sight.heading - fieldOfView / 2),
    y - 6,
    xFor(sight.heading + fieldOfView / 2),
    y + 6,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(windowRect, const Radius.circular(2)),
    Paint()..color = Palette.reticle.withValues(alpha: 0.10),
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(windowRect, const Radius.circular(2)),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Palette.reticle.withValues(alpha: 0.45),
  );

  // The rail, with a tick at the bow and one at each training stop.
  canvas.drawLine(
    Offset(left, y),
    Offset(left + width, y),
    Paint()
      ..strokeWidth = 1
      ..color = Palette.reticle.withValues(alpha: 0.28),
  );
  for (final bearing in [-traverseLimit, 0.0, traverseLimit]) {
    final x = xFor(bearing);
    canvas.drawLine(
      Offset(x, y - 4),
      Offset(x, y + 4),
      Paint()
        ..strokeWidth = 1
        ..color = (bearing == 0 ? Palette.reticle : Palette.alarm).withValues(
          alpha: 0.5,
        ),
    );
  }

  for (final threat in threats) {
    final x = xFor(threat.bearing);
    final alpha = 0.45 + 0.55 * threat.urgency;
    final paint = Paint()..color = Palette.alarm.withValues(alpha: alpha);
    switch (threat.kind) {
      // An escort: a wedge pointing down at its bearing, growing as it closes.
      case ThreatKind.hunter:
        final size = 4.5 + 3 * threat.urgency;
        canvas.drawPath(
          Path()
            ..moveTo(x, y - 1)
            ..lineTo(x - size, y - size - 4)
            ..lineTo(x + size, y - size - 4)
            ..close(),
          paint,
        );
      // A mine: a round contact under the rail.
      case ThreatKind.mine:
        canvas.drawCircle(Offset(x, y + 8), 2.5 + 1.5 * threat.urgency, paint);
    }
  }

  if (threats.isNotEmpty) {
    final worst = threats.fold<double>(
      0,
      (worst, t) => math.max(worst, t.urgency),
    );
    drawLabel(
      canvas,
      Ru.threat,
      Offset(rect.center.dx, y + 15),
      size: 8,
      color: Palette.alarm,
      opacity: 0.45 + 0.5 * worst,
    );
  }
}

/// Coated glass: tint, vignette, dirt and a chromatic fringe at the edge.
///
/// [glass] is the outline of the field, whatever shape it has been masked to,
/// [rect] is the box it sits in, and [falloff] is the ellipse the vignette
/// darkens along — which is not the same thing once the field is cropped.
void paintGlass(
  Canvas canvas,
  Rect rect,
  Path glass,
  Rect falloff,
  double time,
) {
  final center = rect.center;
  final reach = rect.longestSide / 2;

  canvas.drawPath(
    glass,
    Paint()..color = Palette.glassTint.withValues(alpha: 0.055),
  );

  // Vignette. Drawn in a squashed space so the falloff follows the glass
  // instead of bulging out past it.
  canvas.save();
  canvas.translate(falloff.center.dx, falloff.center.dy);
  canvas.scale(1.0, falloff.height / falloff.width);
  canvas.drawCircle(
    Offset.zero,
    falloff.width / 2,
    Paint()
      ..shader = ui.Gradient.radial(Offset.zero, falloff.width / 2, [
        const Color(0x00000000),
        Colors.black.withValues(alpha: 0.16),
        Colors.black.withValues(alpha: 0.80),
      ], const [0.52, 0.80, 1.0]),
  );
  canvas.restore();

  // Two soft reflections off the prism stack.
  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.rotate(-0.7);
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(-reach * 0.22, -reach * 0.18),
      width: reach * 0.30,
      height: rect.height * 1.1,
    ),
    Paint()
      ..color = Colors.white.withValues(alpha: 0.035)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26),
  );
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(reach * 0.45, rect.height * 0.06),
      width: reach * 0.12,
      height: rect.height * 0.7,
    ),
    Paint()
      ..color = Colors.white.withValues(alpha: 0.025)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
  );
  canvas.restore();

  // Dust and salt on the outer lens — fixed to the glass, never moving.
  final random = math.Random(4242);
  final dirt = Paint();
  for (var i = 0; i < 34; i++) {
    dirt.color = Colors.black.withValues(
      alpha: 0.05 + random.nextDouble() * 0.12,
    );
    canvas.drawCircle(
      Offset(
        rect.left + random.nextDouble() * rect.width,
        rect.top + random.nextDouble() * rect.height,
      ),
      0.6 + random.nextDouble() * 1.8,
      dirt,
    );
  }

  // Chromatic fringe around the rim of the field.
  canvas.drawPath(
    scalePath(glass, rect, -1.5),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFF4FC3F7).withValues(alpha: 0.10),
  );
  canvas.drawPath(
    scalePath(glass, rect, -3.5),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFFFF7043).withValues(alpha: 0.07),
  );

  // The edge of the field is rubber and shadow, not a cut: a blurred band
  // laid just inside the outline, so the picture dies into the housing
  // instead of ending at a line.
  canvas.drawPath(
    scalePath(glass, rect, -6),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..color = Colors.black.withValues(alpha: 0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
  );

  // Faint breathing of the illumination.
  final pulse = 0.012 + 0.008 * math.sin(time * 1.3);
  canvas.drawPath(
    glass,
    Paint()..color = Palette.glassTint.withValues(alpha: pulse),
  );
}

/// [path] grown by [outset] pixels all round, by scaling it about the centre
/// of [rect]. Good enough for the rings of a housing, which are all convex.
Path scalePath(Path path, Rect rect, double outset) {
  final sx = (rect.width + outset * 2) / rect.width;
  final sy = (rect.height + outset * 2) / rect.height;
  final matrix = Matrix4.identity()
    ..translateByDouble(rect.center.dx, rect.center.dy, 0, 1)
    ..scaleByDouble(sx, sy, 1, 1)
    ..translateByDouble(-rect.center.dx, -rect.center.dy, 0, 1);
  return path.transform(matrix.storage);
}

/// The eyepiece housing around the optic: cast collar, rubber eyecup, the
/// retaining screws that hold the glass in, and the training-stop lamps.
void paintBezel(
  Canvas canvas,
  Size size,
  Rect rect,
  Path window, {
  required double stopContact,
  required double trainFraction,
}) {
  // Outside the glass is the compartment, painted underneath — so this is
  // only the shadow the housing throws on it, not a lid over it.
  canvas.drawPath(
    Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      window,
    ),
    Paint()..color = Palette.bezel.withValues(alpha: 0.55),
  );

  // Rubber eyecup: thick, and darker at the bottom where the light dies.
  canvas.drawPath(
    scalePath(window, rect, 9),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..shader = ui.Gradient.linear(
        Offset(rect.center.dx, rect.top),
        Offset(rect.center.dx, rect.bottom),
        [Palette.bezelEdge, Palette.rubber, const Color(0xFF05080A)],
        const [0.0, 0.45, 1.0],
      ),
  );
  // Cast collar outside it, with a lit top edge.
  canvas.drawPath(
    scalePath(window, rect, 20),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..shader = ui.Gradient.linear(
        Offset(rect.center.dx, rect.top - 24),
        Offset(rect.center.dx, rect.bottom + 24),
        [Palette.steel.withValues(alpha: 0.45), const Color(0xFF10161A)],
        const [0.0, 1.0],
      ),
  );
  canvas.drawPath(
    scalePath(window, rect, 1),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Palette.steel.withValues(alpha: 0.25),
  );

  // Retaining screws, walked around the housing at a fixed spacing rather
  // than at fixed angles — on a long window a dozen evenly spread screws
  // would bunch up at the ends and leave the straight runs bare.
  final screw = Paint()..color = Palette.steel.withValues(alpha: 0.35);
  final rim = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.7
    ..color = Colors.black.withValues(alpha: 0.6);
  for (final metric in scalePath(window, rect, 18).computeMetrics()) {
    final count = math.max(10, (metric.length / 52).round());
    for (var i = 0; i < count; i++) {
      final at = metric.getTangentForOffset(metric.length * i / count)?.position;
      if (at == null) continue;
      canvas.drawCircle(at, 2.4, screw);
      canvas.drawCircle(at, 2.4, rim);
    }
  }

  // Training-stop lamps, one either side of the housing.
  for (final sign in const [-1.0, 1.0]) {
    final lit = stopContact > 0.02 && trainFraction.sign == sign;
    final at = Offset(
      rect.center.dx + sign * (rect.width / 2 + 26),
      rect.center.dy + rect.height * 0.26,
    );
    canvas.drawCircle(
      at,
      5,
      Paint()
        ..color = lit
            ? Palette.alarm.withValues(alpha: 0.5 + 0.5 * stopContact)
            : Palette.lampOff,
    );
    if (lit) {
      canvas.drawCircle(
        at,
        11,
        Paint()
          ..color = Palette.alarm.withValues(alpha: 0.35 * stopContact)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      drawLabel(
        canvas,
        Ru.stop,
        at + Offset(0, 16),
        size: 8,
        color: Palette.alarm,
        opacity: 0.9,
      );
    }
  }
}

/// Messages flashed across the lower half of the field.
void paintNotices(
  Canvas canvas,
  Rect rect,
  Sight sight,
  List<Notice> notices,
) {
  var index = 0;
  for (final notice in notices) {
    final color = switch (notice.kind) {
      NoticeKind.hit => Palette.lamp,
      NoticeKind.miss => Palette.reticleDim,
      NoticeKind.mine => Palette.alarm,
      NoticeKind.info => Palette.reticle,
    };
    final fade = notice.ttl.clamp(0.0, 1.0);
    final y = sight.horizonY + rect.height * 0.20 + index * 22;
    drawLabel(
      canvas,
      Ru.notice(notice),
      Offset(sight.centerX, y),
      size: notice.kind == NoticeKind.hit ? 17 : 13,
      color: color,
      opacity: 0.35 + 0.65 * fade,
      letterSpacing: 3,
    );
    index++;
  }
}
