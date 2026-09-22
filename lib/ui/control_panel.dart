import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'palette.dart';

/// The training handle. Dragging it sideways feeds torque into the periscope;
/// let go and it springs back while the optics keep coasting.
class HelmWheel extends StatefulWidget {
  const HelmWheel({
    super.key,
    required this.heading,
    required this.control,
    required this.onControl,
    this.diameter = 132,
  });

  /// Size of the handle; shrinks on small screens.
  final double diameter;

  /// Bearing the optics are trained on, radians — drives the wheel's rotation.
  final double heading;

  /// Current handle deflection, -1..1.
  final double control;
  final ValueChanged<double> onControl;

  @override
  State<HelmWheel> createState() => _HelmWheelState();
}

class _HelmWheelState extends State<HelmWheel> {
  double _origin = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (d) => _origin = d.localPosition.dx,
      onHorizontalDragUpdate: (d) {
        final deflection = (d.localPosition.dx - _origin) / 54;
        widget.onControl(deflection.clamp(-1.0, 1.0));
      },
      onHorizontalDragEnd: (_) => widget.onControl(0),
      onHorizontalDragCancel: () => widget.onControl(0),
      child: CustomPaint(
        size: Size(widget.diameter, widget.diameter),
        painter: _WheelPainter(
          // Gearing: several turns of the handle per sweep of the arc.
          angle: widget.heading * 3.2 + widget.control * 0.18,
          control: widget.control,
        ),
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  _WheelPainter({required this.angle, required this.control});

  final double angle;
  final double control;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 6;

    canvas.drawCircle(
      center,
      radius + 4,
      Paint()..color = Colors.black.withValues(alpha: 0.5),
    );

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);

    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.22
      ..shader = ui.Gradient.linear(
        Offset(0, -radius),
        Offset(0, radius),
        [Palette.steel.withValues(alpha: 0.75), const Color(0xFF232A2D)],
      );
    canvas.drawCircle(Offset.zero, radius * 0.84, rim);

    final spoke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.11
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF39464B);
    for (var i = 0; i < 4; i++) {
      final a = i * math.pi / 2;
      canvas.drawLine(
        Offset.zero,
        Offset(math.cos(a), math.sin(a)) * radius * 0.84,
        spoke,
      );
    }

    // Grip handles around the rim.
    final grip = Paint()..color = const Color(0xFF14181A);
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4 + math.pi / 8;
      canvas.drawCircle(
        Offset(math.cos(a), math.sin(a)) * radius * 0.84,
        radius * 0.10,
        grip,
      );
    }

    canvas.drawCircle(Offset.zero, radius * 0.26, Paint()..color = const Color(0xFF1B2226));
    canvas.drawCircle(
      Offset.zero,
      radius * 0.26,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Palette.steel.withValues(alpha: 0.4),
    );
    // Index stripe so the rotation is readable.
    canvas.drawRect(
      Rect.fromLTWH(-radius * 0.035, -radius * 0.84, radius * 0.07, radius * 0.30),
      Paint()..color = Palette.lamp.withValues(alpha: 0.85),
    );
    canvas.restore();

    if (control.abs() > 0.01) {
      final sweep = control * 1.1;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius + 2),
        -math.pi / 2,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..color = Palette.lamp.withValues(alpha: 0.8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WheelPainter old) =>
      old.angle != angle || old.control != control;
}

/// The red torpedo button, with the reload timer running round its rim.
class FireButton extends StatefulWidget {
  const FireButton({
    super.key,
    required this.onFire,
    required this.enabled,
    required this.reloadProgress,
    this.diameter = 118,
  });

  final VoidCallback onFire;
  final bool enabled;

  /// 0 when ready, 1 at the start of a reload.
  final double reloadProgress;

  /// Size of the button; shrinks on small screens.
  final double diameter;

  @override
  State<FireButton> createState() => _FireButtonState();
}

class _FireButtonState extends State<FireButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    // Only the round button itself answers: touches in the corners of the
    // square it sits in are turned away, so a thumb landing beside it does
    // not launch.
    return _RoundHitArea(
      center: _FireButtonPainter.centerIn,
      // The red cap or its steel collar, nowhere else.
      radius: (size) => _FireButtonPainter.radiusIn(size) + 8,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) {
          setState(() => _down = true);
          widget.onFire();
        },
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        child: _face(),
      ),
    );
  }

  Widget _face() {
    return SizedBox(
      width: widget.diameter,
      height: widget.diameter,
      child: CustomPaint(
        painter: _FireButtonPainter(
          pressed: _down,
          enabled: widget.enabled,
          reloadProgress: widget.reloadProgress,
        ),
        child: Center(
          child: Padding(
            padding: EdgeInsets.only(top: widget.diameter * 0.39),
            child: Text(
              'ТОРПЕДА',
              style: kStencil.copyWith(
                fontSize: widget.diameter * 0.085,
                color: Colors.white.withValues(
                  alpha: widget.enabled ? 0.85 : 0.35,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Lets touches through to [child] only inside a circle, so a round control
/// drawn in a square box does not answer in the box's corners.
class _RoundHitArea extends SingleChildRenderObjectWidget {
  const _RoundHitArea({
    required this.center,
    required this.radius,
    super.child,
  });

  final Offset Function(Size size) center;
  final double Function(Size size) radius;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderRoundHitArea(center, radius);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderRoundHitArea renderObject,
  ) {
    renderObject
      ..center = center
      ..radius = radius;
  }
}

class _RenderRoundHitArea extends RenderProxyBox {
  _RenderRoundHitArea(this.center, this.radius);

  Offset Function(Size size) center;
  double Function(Size size) radius;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if ((position - center(size)).distance > radius(size)) return false;
    return super.hitTest(result, position: position);
  }
}

class _FireButtonPainter extends CustomPainter {
  _FireButtonPainter({
    required this.pressed,
    required this.enabled,
    required this.reloadProgress,
  });

  final bool pressed;
  final bool enabled;
  final double reloadProgress;

  static Offset centerIn(Size size) => Offset(size.width / 2, size.height / 2 - 6);
  static double radiusIn(Size size) => size.width / 2 - 12;

  @override
  void paint(Canvas canvas, Size size) {
    final center = centerIn(size);
    final radius = radiusIn(size);

    canvas.drawCircle(
      center,
      radius + 8,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..color = const Color(0xFF1C2427),
    );

    if (reloadProgress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius + 8),
        -math.pi / 2,
        2 * math.pi * (1 - reloadProgress),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..color = Palette.lamp.withValues(alpha: 0.75),
      );
    }

    final top = pressed ? radius * 0.06 : radius * 0.16;
    final base = enabled ? const Color(0xFFB4301F) : const Color(0xFF4A2A25);
    final light = enabled ? const Color(0xFFF2604A) : const Color(0xFF6B3A32);

    canvas.drawCircle(
      center + Offset(0, top),
      radius,
      Paint()..color = const Color(0xFF200E0B),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = ui.Gradient.radial(
          center + Offset(-radius * 0.3, -radius * 0.35),
          radius * 1.4,
          [light, base, const Color(0xFF5A190F)],
          const [0.0, 0.55, 1.0],
        ),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.black.withValues(alpha: 0.6),
    );
    if (enabled) {
      canvas.drawCircle(
        center + Offset(-radius * 0.28, -radius * 0.32),
        radius * 0.30,
        Paint()
          ..color = Colors.white.withValues(alpha: pressed ? 0.10 : 0.22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FireButtonPainter old) =>
      old.pressed != pressed ||
      old.enabled != enabled ||
      old.reloadProgress != reloadProgress;
}

/// Torpedoes left, drawn as rounds in the rack.
class TorpedoRack extends StatelessWidget {
  const TorpedoRack({
    super.key,
    required this.remaining,
    required this.loaded,
    required this.capacity,
  });

  final int remaining;
  final int loaded;
  final int capacity;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'ТОРПЕДЫ  $remaining',
          style: kStencil.copyWith(fontSize: 11, color: Palette.lamp),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: List.generate(capacity, (i) {
            final present = i < remaining;
            final inTube = i < loaded;
            return Container(
              width: 9,
              height: 20,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: present
                    ? (inTube ? Palette.lamp : Palette.lamp.withValues(alpha: 0.35))
                    : Palette.lampOff,
                boxShadow: inTube
                    ? [
                        BoxShadow(
                          color: Palette.lamp.withValues(alpha: 0.5),
                          blurRadius: 6,
                        ),
                      ]
                    : null,
              ),
            );
          }),
        ),
      ],
    );
  }
}

/// A stencilled readout on the cabinet front.
class CabinetGauge extends StatelessWidget {
  const CabinetGauge({
    super.key,
    required this.label,
    required this.value,
    this.color = Palette.lamp,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: kStencil.copyWith(
            fontSize: 9,
            color: Palette.steel.withValues(alpha: 0.75),
          ),
        ),
        const SizedBox(height: 3),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF07090A),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: Colors.black, width: 1),
          ),
          child: Text(
            value,
            style: kStencil.copyWith(
              fontSize: 20,
              color: color,
              shadows: [Shadow(color: color.withValues(alpha: 0.6), blurRadius: 10)],
            ),
          ),
        ),
      ],
    );
  }
}
