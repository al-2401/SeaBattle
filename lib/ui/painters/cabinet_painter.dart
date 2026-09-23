import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../palette.dart';

/// How much of the boat is drawn around the optic.
///
/// Everything here lives *behind* the panels: the eyepiece housing covers the
/// middle, the instruments sit on top, and this is the compartment they are
/// all bolted to. It never moves and never reacts — it is the room, not the
/// game.
enum CabinetDecor {
  /// Bare metal, near enough to what was there before.
  plain,

  /// Riveted plating: seams, rivet rows, scuffed paint, a welded doubler.
  riveted,

  /// Plating plus the brass: pipe runs along the top and bottom, unions and
  /// straps where they are carried, a valve handwheel in the corner.
  brass,

  /// All of it, and the small instruments a control room is covered in —
  /// depth gauge, trim bubble, an engraved builder's plate.
  instruments,
}

const _steelHigh = Color(0xFF141A1E);
const _steelLow = Color(0xFF070B0D);
const _seam = Color(0xFF05080A);
const _brass = Color(0xFFB4894A);
const _brassDark = Color(0xFF6A4E27);
const _brassLit = Color(0xFFE6C48B);

/// Paints the compartment the cabinet is built into.
void paintCabinet(Canvas canvas, Size size, CabinetDecor decor, double time) {
  _plating(canvas, size);
  if (decor == CabinetDecor.plain) return;

  _rivetsAndSeams(canvas, size);

  // Everything below is placed in the dark corners the round window leaves
  // in the middle of the screen — the one place nothing is bolted already.
  final corner = math.min(size.width, size.height);
  if (decor == CabinetDecor.brass || decor == CabinetDecor.instruments) {
    _pipeRun(canvas, size, y: size.height * 0.055, thickness: 13);
    _pipeRun(canvas, size, y: size.height * 0.95, thickness: 9);
    _handwheel(
      canvas,
      Offset(size.width * 0.245, size.height * 0.845),
      corner * 0.085,
    );
  }
  if (decor == CabinetDecor.instruments) {
    _dial(
      canvas,
      Offset(size.width * 0.245, size.height * 0.16),
      corner * 0.075,
      needle: -2.2,
      ticks: 12,
    );
    _dial(
      canvas,
      Offset(size.width * 0.757, size.height * 0.16),
      corner * 0.06,
      needle: 0.6,
      ticks: 8,
    );
    _plate(canvas, Offset(size.width * 0.757, size.height * 0.86), size);
  }

  // A hanging lamp somewhere above and to port: the whole compartment is lit
  // by it, so every highlight in here leans the same way.
  canvas.drawCircle(
    Offset(size.width * 0.22, -size.height * 0.25),
    size.height * 0.85,
    Paint()
      ..shader = ui.Gradient.radial(
        Offset(size.width * 0.22, -size.height * 0.25),
        size.height * 0.85,
        [
          const Color(0xFFFFCB8A).withValues(alpha: 0.055),
          const Color(0x00000000),
        ],
      ),
  );
}

void _plating(Canvas canvas, Size size) {
  canvas.drawRect(
    Offset.zero & size,
    Paint()
      ..shader = ui.Gradient.linear(
        Offset(size.width * 0.3, 0),
        Offset(size.width * 0.7, size.height),
        [_steelHigh, _steelLow],
      ),
  );
}

void _rivetsAndSeams(Canvas canvas, Size size) {
  final seam = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2
    ..color = _seam;
  final lit = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1
    ..color = Palette.steel.withValues(alpha: 0.10);

  // Plates run fore and aft, so the seams are vertical and evenly spaced.
  final pitch = math.max(120.0, size.width / 7);
  for (var x = pitch; x < size.width; x += pitch) {
    canvas.drawLine(Offset(x, 0), Offset(x, size.height), seam);
    canvas.drawLine(Offset(x + 1.5, 0), Offset(x + 1.5, size.height), lit);
  }

  // Rivet rows along the top and bottom edges, and down every seam.
  final rivet = Paint()..color = Palette.steel.withValues(alpha: 0.22);
  final rivetShade = Paint()..color = Colors.black.withValues(alpha: 0.45);
  void rivetAt(Offset at, double r) {
    canvas.drawCircle(at.translate(0, 0.8), r, rivetShade);
    canvas.drawCircle(at, r, rivet);
  }

  for (final y in [size.height * 0.035, size.height * 0.975]) {
    for (var x = 18.0; x < size.width; x += 26) {
      rivetAt(Offset(x, y), 2.2);
    }
  }
  for (var x = pitch; x < size.width; x += pitch) {
    for (var y = 26.0; y < size.height - 10; y += 30) {
      rivetAt(Offset(x - 7, y), 1.9);
    }
  }

  // A welded doubler plate low down on the starboard side: the compartment
  // has been patched, like everything else aboard.
  final patch = Rect.fromLTWH(
    size.width * 0.74,
    size.height * 0.56,
    size.width * 0.17,
    size.height * 0.3,
  );
  canvas.drawRect(
    patch,
    Paint()..color = Palette.steel.withValues(alpha: 0.045),
  );
  canvas.drawRect(
    patch,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = Colors.black.withValues(alpha: 0.5),
  );
  for (var x = patch.left + 10; x < patch.right; x += 22) {
    rivetAt(Offset(x, patch.top + 8), 1.9);
    rivetAt(Offset(x, patch.bottom - 8), 1.9);
  }
}

/// A pipe carried across the compartment, with unions and straps.
void _pipeRun(
  Canvas canvas,
  Size size, {
  required double y,
  required double thickness,
}) {
  final body = Rect.fromLTWH(-4, y - thickness / 2, size.width + 8, thickness);
  canvas.drawRRect(
    RRect.fromRectAndRadius(body, Radius.circular(thickness / 2)),
    Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, body.top),
        Offset(0, body.bottom),
        [_brassDark, _brass, _brassLit, _brassDark],
        const [0.0, 0.35, 0.55, 1.0],
      ),
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(body, Radius.circular(thickness / 2)),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.black.withValues(alpha: 0.55),
  );

  // Unions every so often, and a strap holding the run to the frames.
  final pitch = math.max(150.0, size.width / 5);
  for (var x = pitch * 0.6; x < size.width; x += pitch) {
    final union = Rect.fromCenter(
      center: Offset(x, y),
      width: thickness * 0.9,
      height: thickness * 1.5,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(union, const Radius.circular(2)),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, union.top),
          Offset(0, union.bottom),
          [_brass, _brassLit, _brassDark],
          const [0.0, 0.45, 1.0],
        ),
    );

    final strap = Rect.fromCenter(
      center: Offset(x + pitch * 0.45, y),
      width: thickness * 0.5,
      height: thickness * 1.9,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(strap, const Radius.circular(1.5)),
      Paint()..color = Palette.steel.withValues(alpha: 0.35),
    );
  }
}

/// A valve handwheel on the bulkhead.
void _handwheel(Canvas canvas, Offset center, double radius) {
  final rim = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = radius * 0.16
    ..shader = ui.Gradient.linear(
      Offset(center.dx, center.dy - radius),
      Offset(center.dx, center.dy + radius),
      [_brassLit, _brass, _brassDark],
      const [0.0, 0.5, 1.0],
    );
  canvas.drawCircle(
    center.translate(2, 3),
    radius,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.18
      ..color = Colors.black.withValues(alpha: 0.45),
  );
  canvas.drawCircle(center, radius, rim);

  final spoke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = radius * 0.11
    ..strokeCap = StrokeCap.round
    ..color = _brass.withValues(alpha: 0.9);
  for (var i = 0; i < 5; i++) {
    final a = i * math.pi * 2 / 5 - 0.4;
    canvas.drawLine(
      center,
      center + Offset(math.cos(a), math.sin(a)) * radius * 0.92,
      spoke,
    );
  }
  canvas.drawCircle(center, radius * 0.19, Paint()..color = _brassDark);
  canvas.drawCircle(
    center.translate(-radius * 0.05, -radius * 0.05),
    radius * 0.13,
    Paint()..color = _brass,
  );
}

/// A small brass-rimmed instrument: dark face, ticks, one needle.
void _dial(
  Canvas canvas,
  Offset center,
  double radius, {
  required double needle,
  required int ticks,
}) {
  canvas.drawCircle(
    center.translate(2, 3),
    radius,
    Paint()..color = Colors.black.withValues(alpha: 0.5),
  );
  canvas.drawCircle(
    center,
    radius,
    Paint()
      ..shader = ui.Gradient.linear(
        Offset(center.dx, center.dy - radius),
        Offset(center.dx, center.dy + radius),
        [_brassLit, _brass, _brassDark],
        const [0.0, 0.45, 1.0],
      ),
  );
  canvas.drawCircle(
    center,
    radius * 0.84,
    Paint()..color = const Color(0xFF0B1113),
  );

  final tick = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2
    ..color = Palette.steel.withValues(alpha: 0.55);
  for (var i = 0; i < ticks; i++) {
    final a = i * math.pi * 2 / ticks - math.pi / 2;
    final direction = Offset(math.cos(a), math.sin(a));
    canvas.drawLine(
      center + direction * radius * 0.78,
      center + direction * radius * (i.isEven ? 0.62 : 0.70),
      tick,
    );
  }

  canvas.drawLine(
    center,
    center + Offset(math.cos(needle), math.sin(needle)) * radius * 0.66,
    Paint()
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..color = Palette.lamp.withValues(alpha: 0.75),
  );
  canvas.drawCircle(center, radius * 0.09, Paint()..color = _brass);
  // A blink of light off the cover glass.
  canvas.drawCircle(
    center.translate(-radius * 0.3, -radius * 0.34),
    radius * 0.30,
    Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
  );
}

/// The builder's plate, screwed to the bulkhead and long since dulled.
void _plate(Canvas canvas, Offset center, Size size) {
  final rect = Rect.fromCenter(
    center: center,
    width: math.min(size.width * 0.1, 96),
    height: math.min(size.height * 0.1, 36),
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(rect, const Radius.circular(2)),
    Paint()
      ..shader = ui.Gradient.linear(
        Offset(rect.left, rect.top),
        Offset(rect.right, rect.bottom),
        [_brass.withValues(alpha: 0.55), _brassDark.withValues(alpha: 0.75)],
      ),
  );
  final engraved = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1
    ..color = Colors.black.withValues(alpha: 0.45);
  for (var i = 1; i <= 3; i++) {
    final y = rect.top + rect.height * i / 4;
    canvas.drawLine(
      Offset(rect.left + 7, y),
      Offset(rect.right - (i == 3 ? 24 : 7), y),
      engraved,
    );
  }
  for (final at in [rect.topLeft, rect.topRight, rect.bottomLeft, rect.bottomRight]) {
    canvas.drawCircle(
      at.translate(at.dx == rect.left ? 4 : -4, at.dy == rect.top ? 4 : -4),
      1.6,
      Paint()..color = Palette.steel.withValues(alpha: 0.4),
    );
  }
}
