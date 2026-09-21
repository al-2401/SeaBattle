import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../engine/sight.dart';
import '../engine/world.dart';
import 'painters/effects_painter.dart';
import 'painters/optics_painter.dart';
import 'painters/sea_painter.dart';
import 'painters/vessel_painter.dart';

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
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 16;
    if (radius <= 20) return;

    // Work in a square box around the optic so the field of view always maps
    // to the width of the circle, whatever the window shape.
    canvas.save();
    canvas.translate(center.dx - radius, center.dy - radius);

    final diameter = radius * 2;
    final localCenter = Offset(radius, radius);
    final rect = Rect.fromLTWH(0, 0, diameter, diameter);
    final sight = Sight(
      width: diameter,
      height: diameter,
      horizonY: diameter * 0.40,
      heading: world.periscope.heading,
      fieldOfView: world.config.fieldOfView,
      eyeHeight: world.config.eyeHeight,
    );

    canvas.save();
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: localCenter, radius: radius)),
    );

    // The sea rolls with the swell; the graticule does not.
    canvas.save();
    canvas.translate(localCenter.dx, localCenter.dy);
    canvas.rotate(world.swellRoll);
    canvas.translate(
      -localCenter.dx,
      -localCenter.dy + world.swellHeave * diameter,
    );

    final scene = rect.inflate(radius * 0.25);
    paintSkyAndSea(canvas, scene, sight);
    paintSunGlow(canvas, scene, sight);
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
    paintReticle(canvas, rect, sight);
    paintNotices(canvas, rect, sight, world.notices);
    paintGlass(canvas, rect, localCenter, radius, time);

    canvas.restore(); // circular clip
    canvas.restore(); // local box

    paintBezel(
      canvas,
      size,
      center,
      radius,
      stopContact: world.periscope.stopContact,
      trainFraction: world.periscope.trainFraction,
    );
  }

  @override
  bool shouldRepaint(covariant _PeriscopePainter oldDelegate) => true;
}
