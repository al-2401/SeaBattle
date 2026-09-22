import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../engine/sight.dart';
import '../engine/world.dart';
import 'painters/effects_painter.dart';
import 'painters/optics_painter.dart';
import 'painters/sea_painter.dart';
import 'painters/vessel_painter.dart';

/// The window the sea is seen through.
///
/// Not the round hole a real periscope gives you: a wide capsule, because a
/// phone on its side is a letterbox and a circle throws away two thirds of
/// it. The optics still show the same 30° of arc — the slice is simply drawn
/// bigger, which is what makes a flag at two kilometres readable at all. In a
/// tall window the capsule collapses back to the circle it came from.
RRect eyepieceWindow(Size size) {
  const margin = 12.0;
  final available = Size(
    math.max(48.0, size.width - margin * 2),
    math.max(40.0, size.height - margin * 2),
  );
  // Never wider than three of its own heights, never taller than it is wide.
  final width = math.min(available.width, available.height * 3.0);
  final height = math.min(available.height, width);
  final rect = Rect.fromCenter(
    center: size.center(Offset.zero),
    width: width,
    height: height,
  );
  return RRect.fromRectAndRadius(rect, Radius.circular(height / 2));
}

/// Whether [position] (local to a box of [size]) falls on the glass.
bool onEyepiece(Size size, Offset position) =>
    (Path()..addRRect(eyepieceWindow(size))).contains(position);

/// Everything you see through the eyepiece.
class PeriscopeView extends StatelessWidget {
  const PeriscopeView({
    super.key,
    required this.world,
    required this.surface,
    required this.time,
  });

  final SeaBattleWorld world;
  final SeaSurface surface;
  final double time;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PeriscopePainter(world: world, surface: surface, time: time),
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
  });

  final SeaBattleWorld world;
  final SeaSurface surface;
  final double time;

  /// Crests closer than this are drawn over the ships as foreground swell.
  static const double _foregroundSwell = 900;

  @override
  void paint(Canvas canvas, Size size) {
    final window = eyepieceWindow(size);
    final outer = window.outerRect;
    if (outer.width <= 40 || outer.height <= 32) return;

    // Work in the window's own coordinates: everything the optics show is
    // laid out against this box, and the field of view maps to its width.
    canvas.save();
    canvas.translate(outer.left, outer.top);

    final rect = Rect.fromLTWH(0, 0, outer.width, outer.height);
    final localCenter = rect.center;
    final glass = RRect.fromRectAndRadius(
      rect,
      Radius.circular(rect.height / 2),
    );
    final sight = Sight(
      width: rect.width,
      height: rect.height,
      horizonY: rect.height * 0.42,
      heading: world.periscope.heading,
      fieldOfView: world.config.fieldOfView,
      eyeHeight: world.config.eyeHeight,
    );

    canvas.save();
    canvas.clipPath(Path()..addRRect(glass));

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

    paintBearingTape(canvas, rect, sight, world.config.traverseLimit);
    paintThreatStrip(
      canvas,
      rect,
      sight,
      world.config.traverseLimit,
      world.config.fieldOfView,
      world.threats,
    );
    paintReticle(canvas, rect, sight);
    paintNotices(canvas, rect, sight, world.notices);
    paintGlass(canvas, glass, time);

    canvas.restore(); // window clip
    canvas.restore(); // window origin

    paintBezel(
      canvas,
      size,
      window,
      stopContact: world.periscope.stopContact,
      trainFraction: world.periscope.trainFraction,
    );
  }

  @override
  bool shouldRepaint(covariant _PeriscopePainter oldDelegate) => true;
}
