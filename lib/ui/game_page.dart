import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../engine/world.dart';
import 'control_panel.dart';
import 'painters/sea_painter.dart';
import 'palette.dart';
import 'periscope_view.dart';

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage>
    with SingleTickerProviderStateMixin {
  final SeaBattleWorld _world = SeaBattleWorld();
  final SeaSurface _surface = SeaSurface();
  final FocusNode _focusNode = FocusNode();
  final Set<LogicalKeyboardKey> _heldKeys = {};

  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  double _time = 0;
  double _dragControl = 0;

  static final Set<LogicalKeyboardKey> _portKeys = {
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.keyA,
  };
  static final Set<LogicalKeyboardKey> _starboardKeys = {
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.keyD,
  };

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final dt = ((elapsed - _lastTick).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _lastTick = elapsed;
    _time += dt;
    _world.periscope.control = _handleDemand();
    _world.update(dt);
    setState(() {});
  }

  /// Keyboard and drag both push the same handle; whichever is further over
  /// wins, so a key press does not fight a thumb on the wheel.
  double _handleDemand() {
    var keyboard = 0.0;
    if (_heldKeys.any(_portKeys.contains)) keyboard -= 1;
    if (_heldKeys.any(_starboardKeys.contains)) keyboard += 1;
    return keyboard.abs() >= _dragControl.abs() ? keyboard : _dragControl;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    if (event is KeyUpEvent) {
      _heldKeys.remove(key);
      return KeyEventResult.handled;
    }
    if (event is KeyDownEvent) {
      if (key == LogicalKeyboardKey.space) {
        _world.fire();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.numpadEnter) {
        _world.start();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyR) {
        _world.reset();
        _world.start();
        return KeyEventResult.handled;
      }
      _heldKeys.add(key);
    }
    return KeyEventResult.ignored;
  }

  void _setDragControl(double value) => _dragControl = value;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.height < 720 || size.width < 560;
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF10161A), Color(0xFF05080A)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _StatusBar(world: _world),
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _PeriscopeSurface(
                      world: _world,
                      surface: _surface,
                      time: _time,
                      onControl: _setDragControl,
                      onFire: () => _world.fire(),
                    ),
                    if (_world.phase != GamePhase.running)
                      _PhaseOverlay(
                        world: _world,
                        onStart: () {
                          _world.start();
                          _focusNode.requestFocus();
                        },
                      ),
                  ],
                ),
              ),
              LayoutBuilder(
                builder: (context, constraints) => _ControlDeck(
                  world: _world,
                  compact: compact,
                  width: constraints.maxWidth,
                  onControl: _setDragControl,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PeriscopeSurface extends StatefulWidget {
  const _PeriscopeSurface({
    required this.world,
    required this.surface,
    required this.time,
    required this.onControl,
    required this.onFire,
  });

  final SeaBattleWorld world;
  final SeaSurface surface;
  final double time;
  final ValueChanged<double> onControl;
  final VoidCallback onFire;

  @override
  State<_PeriscopeSurface> createState() => _PeriscopeSurfaceState();
}

class _PeriscopeSurfaceState extends State<_PeriscopeSurface> {
  double _origin = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (d) => _origin = d.localPosition.dx,
      onHorizontalDragUpdate: (d) => widget.onControl(
        ((d.localPosition.dx - _origin) / 90).clamp(-1.0, 1.0),
      ),
      onHorizontalDragEnd: (_) => widget.onControl(0),
      onHorizontalDragCancel: () => widget.onControl(0),
      onTap: widget.onFire,
      child: PeriscopeView(
        world: widget.world,
        surface: widget.surface,
        time: widget.time,
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.world});

  final SeaBattleWorld world;

  @override
  Widget build(BuildContext context) {
    final bearingDeg = world.periscope.heading * 180 / math.pi;
    final side = bearingDeg < -0.5 ? 'Л' : (bearingDeg > 0.5 ? 'П' : '');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final roomForRecord = constraints.maxWidth > 430;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              CabinetGauge(
                label: 'СЧЁТ',
                value: '${world.score}'.padLeft(4, '0'),
              ),
              if (roomForRecord) ...[
                const SizedBox(width: 14),
                CabinetGauge(
                  label: 'РЕКОРД',
                  value: '${world.bestScore}'.padLeft(4, '0'),
                  color: Palette.steel,
                ),
              ],
              const Spacer(),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'МОРСКОЙ БОЙ',
                        style: kStencil.copyWith(
                          fontSize: 15,
                          color: Palette.reticle.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ПЕЛЕНГ $side${bearingDeg.abs().round()}°',
                        style: kStencil.copyWith(
                          fontSize: 11,
                          color: Palette.steel.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ControlDeck extends StatelessWidget {
  const _ControlDeck({
    required this.world,
    required this.compact,
    required this.width,
    required this.onControl,
  });

  final SeaBattleWorld world;
  final bool compact;
  final double width;
  final ValueChanged<double> onControl;

  @override
  Widget build(BuildContext context) {
    final reload = world.reloadTimer <= 0
        ? 0.0
        : world.reloadTimer / world.config.reloadTime;
    // Leave the controls big enough for a thumb, but never wider than the
    // cabinet front.
    final wheel = (width * 0.26).clamp(84.0, 132.0);
    final button = (width * 0.24).clamp(76.0, 118.0);
    final showKeyHints = width > 620;
    return Container(
      padding: EdgeInsets.fromLTRB(18, compact ? 6 : 12, 18, compact ? 8 : 16),
      decoration: const BoxDecoration(
        color: Color(0xFF0C1013),
        border: Border(top: BorderSide(color: Color(0xFF1E262A), width: 2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                TorpedoRack(
                  remaining: world.torpedoesRemaining,
                  loaded: world.tubesLoaded,
                  capacity: world.config.maxTorpedoes,
                ),
                if (showKeyHints) ...[
                  const SizedBox(height: 8),
                  Text(
                    '← → ПОВОРОТ    ПРОБЕЛ ЗАЛП    R ЗАНОВО',
                    style: kStencil.copyWith(
                      fontSize: 9,
                      color: Palette.steel.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ],
            ),
          ),
          HelmWheel(
            heading: world.periscope.heading,
            control: world.periscope.control,
            onControl: onControl,
            diameter: wheel,
          ),
          SizedBox(width: compact ? 8 : 18),
          FireButton(
            enabled: world.canFire,
            reloadProgress: reload,
            onFire: () => world.fire(),
            diameter: button,
          ),
        ],
      ),
    );
  }
}

class _PhaseOverlay extends StatelessWidget {
  const _PhaseOverlay({required this.world, required this.onStart});

  final SeaBattleWorld world;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final over = world.phase == GamePhase.over;
    return Container(
      color: Colors.black.withValues(alpha: 0.72),
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              over ? 'ОТБОЙ' : 'МОРСКОЙ БОЙ',
              style: kStencil.copyWith(
                fontSize: 30,
                color: Palette.lamp,
                shadows: [
                  const Shadow(color: Palette.lamp, blurRadius: 24),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (over) ...[
              _statLine('ОЧКИ', '${world.score}'),
              _statLine('ПОПАДАНИЙ', '${world.hits} / ${world.shotsFired}'),
              _statLine(
                'ТОЧНОСТЬ',
                '${(world.accuracy * 100).round()}%',
              ),
              _statLine('РЕКОРД', '${world.bestScore}'),
            ] else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Наводи перископ штурвалом или стрелками. '
                  'Оптика тяжёлая — она продолжает идти по инерции, '
                  'поэтому упреждение бери заранее. Торпеда идёт долго: '
                  'стреляй туда, где цель будет, а не туда, где она есть.',
                  textAlign: TextAlign.center,
                  style: kStencil.copyWith(
                    fontSize: 12,
                    height: 1.6,
                    letterSpacing: 0.6,
                    color: Palette.reticle.withValues(alpha: 0.78),
                  ),
                ),
              ),
            const SizedBox(height: 22),
            _StartButton(
              label: over ? 'ЕЩЁ РАЗ' : 'ПОГРУЖЕНИЕ',
              onPressed: onStart,
            ),
          ],
        ),
      ),
    );
  }

  Widget _statLine(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            textAlign: TextAlign.right,
            style: kStencil.copyWith(fontSize: 12, color: Palette.steel),
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 120,
          child: Text(
            value,
            style: kStencil.copyWith(fontSize: 14, color: Palette.reticle),
          ),
        ),
      ],
    ),
  );
}

class _StartButton extends StatelessWidget {
  const _StartButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF14201F),
          border: Border.all(color: Palette.reticle.withValues(alpha: 0.6)),
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: Palette.reticle.withValues(alpha: 0.18),
              blurRadius: 18,
            ),
          ],
        ),
        child: Text(
          label,
          style: kStencil.copyWith(fontSize: 15, color: Palette.reticle),
        ),
      ),
    );
  }
}
