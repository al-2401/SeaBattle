import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../engine/entities.dart';
import '../engine/game_config.dart';
import '../engine/world.dart';
import 'painters/vessel_shapes.dart';
import 'palette.dart';
import 'strings.dart';

// Free-standing instruments around the eyepiece (docs/cockpit.md).
//
// Every one of them is a plate of olive enamel on dark steel with brass
// screws, and none of them carries a baked-in word or number: the lettering
// comes from strings.dart and every value is live. What they show is still
// deliberately provisional — the layout is decided, the contents are not.

// ------------------------------------------------------------------ plate

/// The enamelled plate every instrument is mounted on.
class InstrumentPlate extends StatelessWidget {
  const InstrumentPlate({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(14, 11, 14, 11),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _PlatePainter(),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _PlatePainter extends CustomPainter {
  const _PlatePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final outer = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(9),
    );
    // The plate stands proud of the compartment, so it throws a shadow.
    canvas.drawRRect(
      outer.shift(const Offset(0, 3)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawRRect(
      outer,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF454B48), Palette.plateSteel, Color(0xFF151817)],
        ).createShader(outer.outerRect),
    );
    final inner = outer.deflate(4);
    canvas.drawRRect(
      inner,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Palette.enamel, Palette.enamelDark],
        ).createShader(inner.outerRect),
    );
    canvas.drawRRect(
      inner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Palette.cream.withValues(alpha: 0.07),
    );

    // Worn enamel: a few fixed scratches, the same on every frame.
    final random = math.Random(size.width.round() * 31 + size.height.round());
    final scratch = Paint()
      ..strokeWidth = 0.6
      ..color = Palette.cream.withValues(alpha: 0.05);
    for (var i = 0; i < 16; i++) {
      final at = Offset(
        inner.left + random.nextDouble() * inner.width,
        inner.top + random.nextDouble() * inner.height,
      );
      final angle = random.nextDouble() * math.pi;
      final length = 3 + random.nextDouble() * 9;
      canvas.drawLine(
        at,
        at + Offset(math.cos(angle), math.sin(angle)) * length,
        scratch,
      );
    }

    const inset = 9.0;
    for (final corner in [
      const Offset(inset, inset),
      Offset(size.width - inset, inset),
      Offset(inset, size.height - inset),
      Offset(size.width - inset, size.height - inset),
    ]) {
      paintScrew(canvas, corner, 2.8);
    }
  }

  @override
  bool shouldRepaint(covariant _PlatePainter oldDelegate) => false;
}

/// A slotted brass screw head.
void paintScrew(Canvas canvas, Offset center, double radius) {
  canvas.drawCircle(
    center,
    radius,
    Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFFE6C781), Palette.brass, Palette.brassDark],
        stops: [0.0, 0.55, 1.0],
      ).createShader(
        Rect.fromCircle(
          center: center.translate(-radius * 0.3, -radius * 0.3),
          radius: radius * 1.4,
        ),
      ),
  );
  canvas.drawLine(
    center + Offset(-radius * 0.7, radius * 0.35),
    center + Offset(radius * 0.7, -radius * 0.35),
    Paint()
      ..strokeWidth = 0.9
      ..color = Palette.brassDark,
  );
}

TextStyle _plateLabel([double size = 8]) => kStencil.copyWith(
  fontSize: size,
  letterSpacing: 1.3,
  color: Palette.cream.withValues(alpha: 0.78),
);

// ------------------------------------------------------------ flap counter

/// A split-flap readout: one dark cell per character, cream figures.
class FlapCounter extends StatelessWidget {
  const FlapCounter(
    this.text, {
    super.key,
    this.fontSize = 13,
    this.color = Palette.cream,
  });

  final String text;
  final double fontSize;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Palette.readoutWindow,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: Palette.brassDark, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final char in text.split(''))
            Container(
              width: fontSize * 0.8,
              height: fontSize * 1.4,
              margin: const EdgeInsets.symmetric(horizontal: 0.5),
              alignment: Alignment.center,
              // The dark hairline across the middle is the flap's hinge.
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF242826),
                    Color(0xFF131514),
                    Color(0xFF000000),
                    Color(0xFF131514),
                    Color(0xFF242826),
                  ],
                  stops: [0.0, 0.48, 0.5, 0.52, 1.0],
                ),
              ),
              child: Text(
                char,
                style: kStencil.copyWith(
                  fontSize: fontSize,
                  letterSpacing: 0,
                  height: 1,
                  color: color,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A round indicator lamp.
class PanelLamp extends StatelessWidget {
  const PanelLamp({
    super.key,
    required this.on,
    required this.color,
    this.size = 12,
  });

  final bool on;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Palette.brassDark, width: size * 0.12),
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.35),
          colors: on
              ? [Color.lerp(color, Colors.white, 0.55)!, color]
              : [const Color(0xFF3A3F3C), const Color(0xFF141716)],
        ),
        boxShadow: on
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.7),
                  blurRadius: size * 0.9,
                ),
              ]
            : null,
      ),
    );
  }
}

// ------------------------------------------------------------------- radar

/// Seconds for one turn of the radar trace.
const double kRadarSweepPeriod = 2.6;

/// How bright a blip is, 0..1, given where the trace is now.
///
/// A plan-position display lights a contact as the trace passes over it and
/// lets it fade until the next pass. This works that out from the angles
/// alone, so the display needs no memory of its own.
double radarBlipGlow(double sweep, double bearing) {
  const twoPi = 2 * math.pi;
  final since = ((sweep - bearing) % twoPi + twoPi) % twoPi;
  return math.max(0.08, math.exp(-since / 2.2));
}

/// Where the radar trace points after [time] seconds, radians from the bow.
double radarSweepAt(double time) =>
    (time / kRadarSweepPeriod * 2 * math.pi) % (2 * math.pi);

/// Whether the alarm lamp should be lit: an escort close enough to be
/// dropping depth charges.
bool radarAlarm(List<Threat> threats, GameConfig config) {
  final bombing = 1 - config.depthChargeRange / config.threatRange;
  return threats.any(
    (t) => t.kind == ThreatKind.hunter && t.urgency >= bombing,
  );
}

/// The plan-position radar, top left.
///
/// It says where, never who: every contact is the same green dot, and it
/// only carries what the hydrophone already reports — escorts and mines
/// close enough to hurt. Finding targets stays the periscope's job.
class RadarScope extends StatelessWidget {
  const RadarScope({
    super.key,
    required this.size,
    required this.heading,
    required this.fieldOfView,
    required this.traverseLimit,
    required this.threats,
    required this.alarm,
    required this.time,
    this.soundLamp,
  });

  final double size;
  final double heading;
  final double fieldOfView;
  final double traverseLimit;
  final List<Threat> threats;
  final bool alarm;
  final double time;

  /// The sound switch rides on the radar's side tab: it needs a home, and
  /// the top-right corner is deliberately left empty for now.
  final Widget? soundLamp;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: InstrumentPlate(
            padding: EdgeInsets.all(size * 0.075),
            child: CustomPaint(
              size: Size.infinite,
              painter: _RadarPainter(
                heading: heading,
                fieldOfView: fieldOfView,
                traverseLimit: traverseLimit,
                threats: threats,
                sweep: radarSweepAt(time),
              ),
            ),
          ),
        ),
        const SizedBox(width: 3),
        InstrumentPlate(
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(Ru.alarm, style: _plateLabel(7.5)),
              const SizedBox(height: 5),
              PanelLamp(on: alarm, color: Palette.alarm, size: 16),
              if (soundLamp != null) ...[
                const SizedBox(height: 12),
                soundLamp!,
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({
    required this.heading,
    required this.fieldOfView,
    required this.traverseLimit,
    required this.threats,
    required this.sweep,
  });

  final double heading;
  final double fieldOfView;
  final double traverseLimit;
  final List<Threat> threats;
  final double sweep;

  /// Screen angle for a bearing: 0 is the bow, straight up; starboard is
  /// clockwise, which with y pointing down is simply `bearing - π/2`.
  static double _screen(double bearing) => bearing - math.pi / 2;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 2;
    if (radius < 8) return;
    final disc = Rect.fromCircle(center: center, radius: radius);

    // Brass bezel and the dark phosphor behind the glass.
    canvas.drawCircle(
      center,
      radius + 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Palette.brassDark,
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF113F22), Color(0xFF051409)],
        ).createShader(disc),
    );

    canvas.save();
    canvas.clipPath(Path()..addOval(disc));

    // Abaft the training stops the optics cannot look, so the display dims
    // there: the lit arc is the arc the periscope can actually search.
    canvas.drawPath(
      Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(disc, _screen(traverseLimit), 2 * math.pi - 2 * traverseLimit, false)
        ..close(),
      Paint()..color = Colors.black.withValues(alpha: 0.38),
    );

    final grid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = Palette.phosphor.withValues(alpha: 0.22);
    for (var ring = 1; ring <= 4; ring++) {
      canvas.drawCircle(center, radius * ring / 4, grid);
    }
    canvas.drawLine(
      Offset(center.dx - radius, center.dy),
      Offset(center.dx + radius, center.dy),
      grid,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - radius),
      Offset(center.dx, center.dy + radius),
      grid,
    );

    // The slice the periscope is looking at right now.
    canvas.drawArc(
      disc,
      _screen(heading - fieldOfView / 2),
      fieldOfView,
      true,
      Paint()..color = Palette.phosphor.withValues(alpha: 0.13),
    );
    final edge = Paint()
      ..strokeWidth = 1
      ..color = Palette.phosphor.withValues(alpha: 0.45);
    for (final side in const [-1.0, 1.0]) {
      final angle = _screen(heading + side * fieldOfView / 2);
      canvas.drawLine(
        center,
        center + Offset(math.cos(angle), math.sin(angle)) * radius,
        edge,
      );
    }

    // The trace and its afterglow, drawn as thin slices: a sweep gradient
    // would tear where it crosses its own start angle.
    const trail = 0.9;
    const slices = 18;
    for (var i = 0; i < slices; i++) {
      canvas.drawArc(
        disc,
        _screen(sweep - trail * (i + 1) / slices),
        trail / slices + 0.01,
        true,
        Paint()
          ..color = Palette.phosphor.withValues(
            alpha: 0.2 * (1 - i / slices),
          ),
      );
    }
    final traceAngle = _screen(sweep);
    canvas.drawLine(
      center,
      center + Offset(math.cos(traceAngle), math.sin(traceAngle)) * radius,
      Paint()
        ..strokeWidth = 1.4
        ..color = Palette.phosphor.withValues(alpha: 0.85),
    );

    // Contacts: same dot for everything — where, not who.
    for (final threat in threats) {
      final glow = radarBlipGlow(sweep, threat.bearing);
      final distance = (1 - threat.urgency) * radius;
      final angle = _screen(threat.bearing);
      final at = center + Offset(math.cos(angle), math.sin(angle)) * distance;
      canvas.drawCircle(
        at,
        5,
        Paint()
          ..color = Palette.phosphor.withValues(alpha: 0.4 * glow)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawCircle(
        at,
        2.2,
        Paint()..color = Palette.phosphor.withValues(alpha: glow),
      );
    }

    // Own boat in the middle.
    canvas.drawCircle(
      center,
      2,
      Paint()..color = Palette.phosphor.withValues(alpha: 0.9),
    );
    canvas.restore();

    // A glint across the glass.
    canvas.drawArc(
      disc.deflate(radius * 0.12),
      math.pi * 1.1,
      math.pi * 0.35,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.08),
    );
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) => true;
}

// ---------------------------------------------------------------- info panel

/// Characters the name flaps rattle through while a ship is being read.
const String _flapAlphabet = 'АБВГДЕЖЗИКЛМНОПРСТУФХЦЧШЭЮЯ';

/// Cells in the name readout: long enough for the longest class name.
const int kNameCells = 9;

/// What the name flaps show for [vessel] after [time] seconds.
///
/// Nothing is given away that the periscope has not earned: with no ship in
/// the sight the flaps say so; a ship that is not being read yet shows only
/// blank cells; while she is being read, the letters settle one by one in
/// step with [Vessel.recognition]; only an identified ship shows her class.
String targetNameFlaps(Vessel? vessel, double time) {
  if (vessel == null) return Ru.noTarget.padRight(kNameCells);
  final name = Ru.vessel(vessel.type).padRight(kNameCells);
  if (vessel.isIdentified) return name;
  if (vessel.recognition <= 0) return '·' * kNameCells;
  final settled = (vessel.recognition * name.trim().length).floor();
  final tick = (time * 14).floor();
  final buffer = StringBuffer();
  for (var i = 0; i < kNameCells; i++) {
    if (i < settled) {
      buffer.write(name[i]);
    } else if (i < name.trim().length) {
      final spin = (tick * 7 + i * 13 + vessel.id * 5) % _flapAlphabet.length;
      buffer.write(_flapAlphabet[spin]);
    } else {
      buffer.write(' ');
    }
  }
  return buffer.toString();
}

/// Target above, own boat below — in one plate, but kept apart, so a number
/// is never ambiguous about whose it is.
class InfoPanel extends StatelessWidget {
  const InfoPanel({
    super.key,
    required this.vessel,
    required this.time,
    required this.headingDegrees,
    required this.hits,
    required this.score,
    required this.gearDamage,
    this.width = 196,
  });

  final Vessel? vessel;
  final double time;
  final double headingDegrees;
  final int hits;
  final int score;
  final double gearDamage;
  final double width;

  @override
  Widget build(BuildContext context) {
    final target = vessel;
    final identified = target?.isIdentified ?? false;
    final reading = target != null && !identified && target.recognition > 0;
    // The lock lamp blinks while the flag is being read, burns once it is.
    final lockOn = identified || (reading && (time * 3).floor().isEven);

    return SizedBox(
      width: width,
      child: InstrumentPlate(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(Ru.target, style: _plateLabel(9)),
                const Spacer(),
                Text(Ru.lock, style: _plateLabel(7)),
                const SizedBox(width: 5),
                PanelLamp(on: lockOn, color: Palette.lamp, size: 11),
              ],
            ),
            const SizedBox(height: 5),
            Container(
              height: 30,
              decoration: BoxDecoration(
                color: Palette.readoutWindow,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: Palette.brassDark),
              ),
              child: CustomPaint(
                painter: _SilhouettePainter(
                  vessel: target,
                  lit: identified,
                ),
              ),
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                FlapCounter(
                  targetNameFlaps(target, time),
                  key: const ValueKey('target-name'),
                  fontSize: 9.5,
                  color: identified
                      ? Palette.cream
                      : Palette.cream.withValues(alpha: 0.55),
                ),
                const SizedBox(width: 6),
                // Right-aligned, and allowed to shrink: the name readout next
                // to it has a fixed number of cells and must never be cut.
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: _FlagChip(vessel: target),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(height: 1, color: Palette.cream.withValues(alpha: 0.18)),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _Labelled(
                  label: Ru.bearingLabel,
                  child: FlapCounter(
                    Ru.bearingCounter(headingDegrees),
                    key: const ValueKey('own-bearing'),
                    fontSize: 11,
                  ),
                ),
                const Spacer(),
                _Labelled(
                  label: Ru.score,
                  child: FlapCounter(
                    '$score'.padLeft(4, '0'),
                    key: const ValueKey('score'),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _GearPips(damage: gearDamage),
                const Spacer(),
                _Labelled(
                  label: Ru.hitsLabel,
                  child: FlapCounter(
                    '$hits'.padLeft(2, '0'),
                    key: const ValueKey('hits'),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Labelled extends StatelessWidget {
  const _Labelled({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: _plateLabel(7)),
        const SizedBox(height: 2),
        child,
      ],
    );
  }
}

/// Wear of the training gear, one lamp per knock the boat has taken.
class _GearPips extends StatelessWidget {
  const _GearPips({required this.damage});

  final double damage;

  @override
  Widget build(BuildContext context) {
    const steps = 4;
    final lit = (damage * steps).round().clamp(0, steps);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(Ru.gear, style: _plateLabel(7)),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < steps; i++) ...[
              if (i > 0) const SizedBox(width: 3),
              PanelLamp(on: i < lit, color: Palette.alarm, size: 10),
            ],
          ],
        ),
      ],
    );
  }
}

/// Whose flag the target flies — the thing identification is really about.
class _FlagChip extends StatelessWidget {
  const _FlagChip({required this.vessel});

  final Vessel? vessel;

  @override
  Widget build(BuildContext context) {
    final target = vessel;
    final known = target != null && target.isIdentified;
    final neutral = known && target.allegiance == Allegiance.neutral;
    final label = !known
        ? '?'
        : (neutral ? Ru.neutralFlag : Ru.enemyFlag);
    final color = !known
        ? Palette.cream.withValues(alpha: 0.35)
        : (neutral ? Palette.cream : Palette.alarm);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      decoration: BoxDecoration(
        color: Palette.readoutWindow,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        label,
        key: const ValueKey('target-flag'),
        style: kStencil.copyWith(fontSize: 7.5, letterSpacing: 1, color: color),
      ),
    );
  }
}

class _SilhouettePainter extends CustomPainter {
  _SilhouettePainter({required this.vessel, required this.lit});

  final Vessel? vessel;
  final bool lit;

  @override
  void paint(Canvas canvas, Size size) {
    final target = vessel;
    if (target == null) return;
    final shape = vesselShape(target.type, target.silhouetteSeed);
    // True proportions, fitted to the window.
    final scale = math.min(
      size.width * 0.86 / target.type.length,
      size.height * 0.82 / target.type.height,
    );
    final lengthPx = target.type.length * scale;
    final heightPx = target.type.height * scale;
    final origin = Offset(size.width / 2, size.height / 2 + heightPx / 2);
    Offset map(Offset n) =>
        origin + Offset(n.dx * lengthPx, n.dy * heightPx);

    // The periscope shows the silhouette anyway; the panel only brightens it
    // once the ship has been identified.
    final fill = Paint()
      ..color = Palette.cream.withValues(alpha: lit ? 0.88 : 0.3);
    for (final part in shape.parts) {
      final path = Path()..moveTo(map(part.first).dx, map(part.first).dy);
      for (final point in part.skip(1)) {
        final p = map(point);
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path..close(), fill);
    }
    final rigging = Paint()
      ..strokeWidth = 0.8
      ..color = fill.color;
    for (final line in shape.rigging) {
      canvas.drawLine(map(line.first), map(line.last), rigging);
    }
  }

  @override
  bool shouldRepaint(covariant _SilhouettePainter old) =>
      old.vessel != vessel || old.lit != lit;
}

// ------------------------------------------------------------- weapon drum

/// Weapon selection, right side.
///
/// A drum shows the weapon before, the one selected and the one after, so it
/// works the same for three weapons or seven. Only the torpedo exists for
/// now; the neighbouring slots are left blank rather than filled with
/// weapons that do not exist yet.
class WeaponDrum extends StatelessWidget {
  const WeaponDrum({super.key, required this.remaining, this.width = 176});

  final int remaining;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: InstrumentPlate(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: width * 0.62,
              child: const CustomPaint(painter: _DrumPainter()),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(Ru.torpedoes, style: _plateLabel(8)),
                const SizedBox(width: 8),
                FlapCounter(
                  '$remaining'.padLeft(2, '0'),
                  key: const ValueKey('torpedoes-left'),
                  fontSize: 14,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DrumPainter extends CustomPainter {
  const _DrumPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final band = size.height / 3;

    // The drum body: a cylinder, darker towards the top and bottom where it
    // turns away from the eye.
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(5)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF101310),
            Palette.enamel,
            Palette.enamel,
            Color(0xFF101310),
          ],
          stops: [0.0, 0.3, 0.7, 1.0],
        ).createShader(rect),
    );

    // Selected slot: a lit window in the middle band.
    final window = Rect.fromLTWH(3, band, size.width - 6, band);
    canvas.drawRRect(
      RRect.fromRectAndRadius(window, const Radius.circular(3)),
      Paint()..color = const Color(0xFF1A120A),
    );
    for (final y in [window.top, window.bottom]) {
      canvas.drawLine(
        Offset(window.left, y),
        Offset(window.right, y),
        Paint()
          ..strokeWidth = 2
          ..color = Palette.lamp.withValues(alpha: 0.75)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
      );
    }

    // Torpedo glyph and its name, painted rather than set as text so the
    // drum reads as a stencil on the slot and not as a label beside it.
    _paintTorpedo(
      canvas,
      Rect.fromCenter(
        center: window.center.translate(0, -window.height * 0.16),
        width: window.width * 0.62,
        height: window.height * 0.3,
      ),
    );
    final painter = TextPainter(
      text: TextSpan(
        text: Ru.fire,
        style: kStencil.copyWith(
          fontSize: window.height * 0.24,
          color: Palette.cream,
          letterSpacing: 2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(
        window.center.dx - painter.width / 2,
        window.bottom - painter.height - window.height * 0.08,
      ),
    );

    // Empty neighbours: just the slot seams.
    final seam = Paint()
      ..strokeWidth = 1
      ..color = Colors.black.withValues(alpha: 0.5);
    for (final y in [band * 0.5, band * 2.5]) {
      canvas.drawLine(Offset(12, y), Offset(size.width - 12, y), seam);
    }
  }

  void _paintTorpedo(Canvas canvas, Rect box) {
    final paint = Paint()..color = Palette.cream;
    final body = Rect.fromLTRB(
      box.left + box.width * 0.12,
      box.top + box.height * 0.2,
      box.right - box.height * 0.3,
      box.bottom - box.height * 0.2,
    );
    canvas.drawRect(body, paint);
    canvas.drawOval(
      Rect.fromLTRB(
        body.right - body.height * 0.6,
        body.top,
        body.right + body.height * 0.6,
        body.bottom,
      ),
      paint,
    );
    // Tail fins and screw.
    canvas.drawRect(
      Rect.fromLTRB(box.left + box.width * 0.04, box.top, body.left + 2, box.bottom),
      paint,
    );
    canvas.drawRect(
      Rect.fromLTRB(box.left, box.center.dy - 1.5, box.left + 4, box.center.dy + 1.5),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _DrumPainter oldDelegate) => false;
}

// ------------------------------------------------------------ launch lamps

/// How many countdown lamps are still lit, [count] of them in all.
///
/// [reloadFraction] is 1 when a reload begins and 0 when the tubes are
/// ready, so the lamps go out one by one as the reload runs down.
int countdownLampsLit(double reloadFraction, int count) {
  if (reloadFraction <= 0) return 0;
  return (reloadFraction * count).ceil().clamp(0, count);
}

/// Ready lamp and reload countdown beside the torpedo button.
///
/// A narrow upright strip: it stands between the button and the optic, and
/// every point of width it takes is width taken off the edge of the field.
class LaunchLamps extends StatelessWidget {
  const LaunchLamps({
    super.key,
    required this.reloadFraction,
    required this.ready,
    this.count = 5,
  });

  /// 1 at the start of a reload, 0 when done.
  final double reloadFraction;

  /// Whether a torpedo can go right now.
  final bool ready;
  final int count;

  @override
  Widget build(BuildContext context) {
    final lit = countdownLampsLit(reloadFraction, count);
    return InstrumentPlate(
      padding: const EdgeInsets.fromLTRB(9, 14, 9, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Counted from the bottom up, so the last lamp to go out is the
          // one next to the ready lamp.
          for (var i = count - 1; i >= 0; i--) ...[
            PanelLamp(on: i < lit, color: Palette.lamp, size: 9),
            const SizedBox(height: 4),
          ],
          const SizedBox(height: 4),
          PanelLamp(
            key: const ValueKey('ready-lamp'),
            on: ready,
            color: Palette.readyGreen,
            size: 20,
          ),
          const SizedBox(height: 5),
          Text(Ru.ready, style: _plateLabel(7)),
        ],
      ),
    );
  }
}
