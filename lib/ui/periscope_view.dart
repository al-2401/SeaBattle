import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../engine/sight.dart';
import '../engine/world.dart';
import 'painters/effects_painter.dart';
import 'painters/optics_painter.dart';
import 'painters/sea_painter.dart';
import 'painters/vessel_painter.dart';

/// Shapes the field of view can be masked to.
///
/// A real periscope gives a circle and nothing else — the field is round
/// because the optics are. Everything else here is a liberty taken for a
/// phone held on its side, where a circle throws away most of the screen.
enum EyepieceShape {
  /// A circle with the sides pulled apart: straight top and bottom, round
  /// ends. Reads as optics stretched to fit the panel.
  capsule,

  /// A plain ellipse. Softer, less mechanical — no straight runs anywhere.
  ellipse,

  /// A circle cropped top and bottom, like a viewing slit: the round edge is
  /// kept at the sides, where the eye looks for it, and the sky and the
  /// foreground swell are cut away.
  letterbox,

  /// A rounded window with real corners — an instrument panel rather than an
  /// eyepiece, but it uses every pixel it is given.
  panel,

  /// Two overlapping circles, the way binoculars are drawn. Wide, and still
  /// unmistakably an optic.
  binocular,
}

/// The mask the field of view wears. One constant, because the whole cabinet
/// is built around it — change it here and the housing, the tape and the
/// touch handling all follow.
const EyepieceShape kEyepieceShape = EyepieceShape.binocular;

/// The box the field of view is fitted into.
///
/// Narrower than the space it is given: the optics are the instrument, not
/// the whole cabinet, and the rest is the housing around it. The vertical
/// margin is the wider one — that is where the collar and the eyecup go, and
/// on a cropped circle they sit along a straight edge where there is nowhere
/// to hide them.
Rect eyepieceBox(Size size) {
  const margin = 12.0;
  const collar = 30.0;
  final available = Size(
    math.max(48.0, (size.width - margin * 2) * 0.85),
    math.max(40.0, size.height - collar * 2),
  );
  // Never wider than three of its own heights, never taller than it is wide.
  final width = math.min(available.width, available.height * 3.0);
  final height = math.min(available.height, width);
  return Rect.fromCenter(
    center: size.center(Offset.zero),
    width: width,
    height: height,
  );
}

/// The outline of the field of view inside [rect].
Path eyepieceOutline(Rect rect, EyepieceShape shape) {
  switch (shape) {
    case EyepieceShape.capsule:
      return Path()
        ..addRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(rect.height / 2)),
        );
    case EyepieceShape.ellipse:
      return Path()..addOval(rect);
    case EyepieceShape.letterbox:
      // A circle as wide as the window, with the top and bottom cut off by
      // the window's own height.
      final radius = rect.width / 2;
      return Path.combine(
        PathOperation.intersect,
        Path()..addOval(Rect.fromCircle(center: rect.center, radius: radius)),
        Path()..addRect(rect),
      );
    case EyepieceShape.panel:
      return Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            rect,
            Radius.circular(rect.height * 0.26),
          ),
        );
    case EyepieceShape.binocular:
      // Two barrels, deliberately overlapped far more than they need to be.
      // Drawn tangent to the height they would have, the circles leave a
      // notch right in the middle of the field — exactly where the target
      // is. Oversizing them and cropping to the box pushes that notch out to
      // a shallow dip at the top and bottom, which is how every convincing
      // binocular mask is drawn.
      // Just over half the height: the barrels are cropped flat at the top
      // and bottom, and the dip between them stays a tenth of the field —
      // enough to read as two barrels, too little to sit on the target.
      final radius = math.min(rect.height * 0.52, rect.width / 2);
      final reach = math.max(0.0, rect.width / 2 - radius);
      final barrels = Path.combine(
        PathOperation.union,
        Path()
          ..addOval(
            Rect.fromCircle(
              center: rect.center.translate(-reach, 0),
              radius: radius,
            ),
          ),
        Path()
          ..addOval(
            Rect.fromCircle(
              center: rect.center.translate(reach, 0),
              radius: radius,
            ),
          ),
      );
      return Path.combine(
        PathOperation.intersect,
        barrels,
        Path()..addRect(rect),
      );
  }
}

/// Whether [position] (local to a box of [size]) falls on the glass.
bool onEyepiece(
  Size size,
  Offset position, [
  EyepieceShape shape = kEyepieceShape,
]) => eyepieceOutline(eyepieceBox(size), shape).contains(position);

/// The ellipse the vignette falls off along: for a cropped circle it stays
/// round, for the stretched shapes it follows the window.
Rect eyepieceFalloff(Rect rect, EyepieceShape shape) => switch (shape) {
  EyepieceShape.letterbox => Rect.fromCircle(
    center: rect.center,
    radius: rect.width / 2,
  ),
  // Binoculars darken towards each barrel, but one soft pool across the
  // pair reads better than two competing ones.
  EyepieceShape.binocular => rect.inflate(rect.height * 0.12),
  _ => rect,
};

/// Everything you see through the eyepiece.
class PeriscopeView extends StatelessWidget {
  const PeriscopeView({
    super.key,
    required this.world,
    required this.surface,
    required this.time,
    this.shape = kEyepieceShape,
  });

  final SeaBattleWorld world;
  final SeaSurface surface;
  final double time;
  final EyepieceShape shape;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PeriscopePainter(
        world: world,
        surface: surface,
        time: time,
        shape: shape,
      ),
      size: Size.infinite,
      isComplex: true,
      willChange: true,
    );
  }
}

class _PeriscopePainter extends CustomPainter {
  _PeriscopePainter({
    required this.world,
    required this.surface,
    required this.time,
    required this.shape,
  });

  final SeaBattleWorld world;
  final SeaSurface surface;
  final double time;
  final EyepieceShape shape;

  /// Crests closer than this are drawn over the ships as foreground swell.
  static const double _foregroundSwell = 900;

  @override
  void paint(Canvas canvas, Size size) {
    final outer = eyepieceBox(size);
    if (outer.width <= 40 || outer.height <= 32) return;

    // Work in the window's own coordinates: everything the optics show is
    // laid out against this box, and the field of view maps to its width.
    canvas.save();
    canvas.translate(outer.left, outer.top);

    final rect = Rect.fromLTWH(0, 0, outer.width, outer.height);
    final localCenter = rect.center;
    final glass = eyepieceOutline(rect, shape);
    final sight = Sight(
      width: rect.width,
      height: rect.height,
      horizonY: rect.height * 0.42,
      heading: world.periscope.heading,
      fieldOfView: world.config.fieldOfView,
      eyeHeight: world.config.eyeHeight,
    );

    canvas.save();
    canvas.clipPath(glass);

    // The sea rolls with the swell; the graticule does not. A blow on the
    // hull throws the whole picture about on top of that, and dies away.
    final shock = world.shock;
    canvas.save();
    canvas.translate(localCenter.dx, localCenter.dy);
    canvas.rotate(world.swellRoll + math.sin(time * 37) * 0.055 * shock);
    canvas.translate(
      -localCenter.dx + math.sin(time * 61) * rect.height * 0.04 * shock,
      -localCenter.dy +
          world.swellHeave * rect.height +
          math.cos(time * 47) * rect.height * 0.04 * shock,
    );

    final scene = rect.inflate(rect.height * 0.3);
    paintSkyAndSea(canvas, scene, sight);
    paintSunGlow(canvas, scene, sight);
    paintClouds(canvas, scene, sight, surface, time);
    paintLandmarks(canvas, scene, sight, surface);
    paintWaves(
      canvas,
      scene,
      sight,
      surface,
      time,
      rangeFrom: _foregroundSwell,
    );

    final vessels = world.vessels.toList()
      ..sort((a, b) => b.range.compareTo(a.range));
    for (final vessel in vessels) {
      paintVessel(canvas, scene, sight, vessel, time);
    }

    final mines = world.mines.toList()
      ..sort((a, b) => b.range.compareTo(a.range));
    for (final mine in mines) {
      paintMine(canvas, scene, sight, mine, time);
    }

    for (final torpedo in world.torpedoes) {
      paintTorpedo(canvas, scene, sight, torpedo, time);
    }

    for (final blast in world.blasts) {
      paintBlast(canvas, scene, sight, blast);
    }

    paintWaves(canvas, scene, sight, surface, time, rangeTo: _foregroundSwell);
    canvas.restore();

    paintBearingTape(canvas, rect, glass, sight, world.config.traverseLimit);
    paintThreatStrip(
      canvas,
      rect,
      glass,
      sight,
      world.config.traverseLimit,
      world.config.fieldOfView,
      world.threats,
    );
    paintReticle(canvas, rect, sight);
    paintNotices(canvas, rect, sight, world.notices);
    paintGlass(canvas, rect, glass, eyepieceFalloff(rect, shape), time);

    canvas.restore(); // window clip
    canvas.restore(); // window origin

    paintBezel(
      canvas,
      size,
      outer,
      eyepieceOutline(outer, shape),
      stopContact: world.periscope.stopContact,
      trainFraction: world.periscope.trainFraction,
    );
  }

  @override
  bool shouldRepaint(covariant _PeriscopePainter oldDelegate) => true;
}
