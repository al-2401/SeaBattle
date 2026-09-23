import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../audio/game_audio.dart';
import '../engine/world.dart';
import 'control_panel.dart';
import 'painters/cabinet_painter.dart';
import 'painters/sea_painter.dart';
import 'palette.dart';
import 'strings.dart';
import 'periscope_view.dart';

class GamePage extends StatefulWidget {
  const GamePage({super.key, this.audio, this.decor = CabinetDecor.instruments});

  /// Sound engine; null means build the real one.
  final GameAudio? audio;

  /// How much of the boat is drawn behind the instruments.
  final CabinetDecor decor;

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage>
    with SingleTickerProviderStateMixin {
  final SeaBattleWorld _world = SeaBattleWorld();
  final SeaSurface _surface = SeaSurface();
  final FocusNode _focusNode = FocusNode();
  final Set<LogicalKeyboardKey> _heldKeys = {};

  late final GameAudio _audio;
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
    _audio = widget.audio ?? ArcadeAudio();
    _audio.prepare();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _focusNode.dispose();
    _audio.dispose();
    super.dispose();
  }

  /// Every way of firing goes through here, so the audio layer always gets
  /// its gesture before it tries to make a sound.
  void _fire() {
    _audio.unlock();
    _world.fire();
  }

  void _startPatrol() {
    _audio.unlock();
    _world.start();
    _focusNode.requestFocus();
  }

  void _toggleSound() {
    _audio.unlock();
    setState(() => _audio.enabled = !_audio.enabled);
  }

  void _onTick(Duration elapsed) {
    final dt = ((elapsed - _lastTick).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _lastTick = elapsed;
    _time += dt;
    _world.periscope.control = _handleDemand();
    _world.update(dt);

    for (final cue in _world.drainCues()) {
      _audio.fire(cue);
    }
    _audio.updateLoops(
      trainEffort:
          _world.periscope.angularVelocity.abs() /
          _world.config.maxAngularSpeed,
      torpedoesRunning: _world.torpedoes.length,
      patrolRunning: _world.phase == GamePhase.running,
    );

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
    if (event is KeyDownEvent) _audio.unlock();
    if (event is KeyUpEvent) {
      _heldKeys.remove(key);
      return KeyEventResult.handled;
    }
    if (event is KeyDownEvent) {
      if (key == LogicalKeyboardKey.space) {
        _fire();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyM) {
        _toggleSound();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.numpadEnter) {
        _startPatrol();
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
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _onKey,
      child: CustomPaint(
        painter: _CabinetBackdrop(decor: widget.decor, time: _time),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) =>
                constraints.maxWidth > constraints.maxHeight
                ? _landscapeCabinet(constraints.biggest)
                : _portraitCabinet(constraints.biggest),
          ),
        ),
      ),
    );
  }

  Widget _scope() {
    return Stack(
      fit: StackFit.expand,
      children: [
        _PeriscopeSurface(
          world: _world,
          surface: _surface,
          time: _time,
          onControl: _setDragControl,
          onFire: _fire,
        ),
        if (_world.phase != GamePhase.running)
          _PhaseOverlay(world: _world, onStart: _startPatrol),
      ],
    );
  }

  /// Status strip on top, controls along the bottom: a tall window.
  Widget _portraitCabinet(Size size) {
    final compact = size.height < 720 || size.width < 560;
    return Column(
      children: [
        _StatusBar(
          world: _world,
          soundOn: _audio.enabled,
          onToggleSound: _toggleSound,
        ),
        Expanded(child: _scope()),
        _ControlDeck(
          world: _world,
          compact: compact,
          width: size.width,
          onControl: _setDragControl,
          onFire: _fire,
        ),
      ],
    );
  }

  /// The eyepiece takes the full height in the middle, with the training
  /// wheel under the left thumb and the torpedo button under the right —
  /// the way a phone is held on its side.
  Widget _landscapeCabinet(Size size) {
    // The wings are only as wide as the controls on them need; everything
    // left over goes to the optic, which is what lets the window stretch
    // into a capsule instead of sitting in a square.
    final side = (size.width * 0.17).clamp(140.0, 220.0);
    final control = math
        .min(side * 0.72, size.height * 0.36)
        .clamp(80.0, 150.0);
    return Row(
      children: [
        _SidePanel(
          width: side,
          border: const Border(
            right: BorderSide(color: Color(0xFF1E262A), width: 2),
          ),
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                CabinetGauge(
                  label: Ru.score,
                  value: '${_world.score}'.padLeft(4, '0'),
                ),
                CabinetGauge(
                  label: Ru.best,
                  value: '${_world.bestScore}'.padLeft(4, '0'),
                  color: Palette.steel,
                ),
              ],
            ),
            const Spacer(),
            Center(
              child: HelmWheel(
                heading: _world.periscope.heading,
                control: _world.periscope.control,
                onControl: _setDragControl,
                diameter: control,
              ),
            ),
          ],
        ),
        Expanded(child: _scope()),
        _SidePanel(
          width: side,
          border: const Border(
            left: BorderSide(color: Color(0xFF1E262A), width: 2),
          ),
          children: [
            _TitlePlate(world: _world, alignEnd: false),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: GearDamageLamp(damage: _world.periscope.damage),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: _SoundLamp(on: _audio.enabled, onTap: _toggleSound),
            ),
            const Spacer(),
            // On a narrow wing the rack wraps onto more rows than the panel
            // has height for; let it shrink rather than spill.
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: TorpedoRack(
                  remaining: _world.torpedoesRemaining,
                  loaded: _world.tubesLoaded,
                  capacity: _world.config.maxTorpedoes,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: FireButton(
                enabled: _world.canFire,
                reloadProgress: _reloadProgress,
                onFire: _fire,
                diameter: control,
              ),
            ),
          ],
        ),
      ],
    );
  }

  double get _reloadProgress => _world.reloadTimer <= 0
      ? 0.0
      : _world.reloadTimer / _world.config.reloadTime;
}

/// The compartment the whole cabinet is bolted into: plating, rivets, pipe
/// runs and the odd instrument. Painted once, behind everything.
class _CabinetBackdrop extends CustomPainter {
  const _CabinetBackdrop({required this.decor, required this.time});

  final CabinetDecor decor;
  final double time;

  @override
  void paint(Canvas canvas, Size size) =>
      paintCabinet(canvas, size, decor, time);

  @override
  bool shouldRepaint(covariant _CabinetBackdrop old) => old.decor != decor;
}

/// One wing of the cabinet front in the landscape layout.
class _SidePanel extends StatelessWidget {
  const _SidePanel({
    required this.width,
    required this.border,
    required this.children,
  });

  final double width;
  final Border border;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      // Only a scrim: the plating, the pipes and the brass behind have to
      // stay visible, or the compartment might as well not be there.
      decoration: BoxDecoration(
        color: const Color(0xFF0C1013).withValues(alpha: 0.55),
        border: border,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

/// The cabinet's name plate with the bearing readout under it.
class _TitlePlate extends StatelessWidget {
  const _TitlePlate({required this.world, this.alignEnd = true});

  final SeaBattleWorld world;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final bearingDeg = world.periscope.heading * 180 / math.pi;
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: alignEnd
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Text(
            Ru.title,
            style: kStencil.copyWith(
              fontSize: 15,
              color: Palette.reticle.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            Ru.bearing(bearingDeg),
            style: kStencil.copyWith(
              fontSize: 11,
              color: Palette.steel.withValues(alpha: 0.8),
            ),
          ),
        ],
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
      // A tap on the glass fires; the dark cabinet around the optic does
      // not, or a thumb reaching for the controls would launch by mistake.
      onTapUp: (d) {
        final size = context.size;
        if (size != null && onEyepiece(size, d.localPosition)) widget.onFire();
      },
      child: PeriscopeView(
        world: widget.world,
        surface: widget.surface,
        time: widget.time,
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.world,
    required this.soundOn,
    required this.onToggleSound,
  });

  final SeaBattleWorld world;
  final bool soundOn;
  final VoidCallback onToggleSound;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final roomForRecord = constraints.maxWidth > 430;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              CabinetGauge(
                label: Ru.score,
                value: '${world.score}'.padLeft(4, '0'),
              ),
              if (roomForRecord) ...[
                const SizedBox(width: 14),
                CabinetGauge(
                  label: Ru.best,
                  value: '${world.bestScore}'.padLeft(4, '0'),
                  color: Palette.steel,
                ),
              ],
              const Spacer(),
              if (constraints.maxWidth > 360) ...[
                GearDamageLamp(damage: world.periscope.damage),
                const SizedBox(width: 12),
              ],
              _SoundLamp(on: soundOn, onTap: onToggleSound),
              const SizedBox(width: 12),
              Flexible(child: _TitlePlate(world: world)),
            ],
          );
        },
      ),
    );
  }
}

/// The sound switch on the cabinet front, with its little indicator lamp.
class _SoundLamp extends StatelessWidget {
  const _SoundLamp({required this.on, required this.onTap});

  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: on ? Palette.lamp : Palette.lampOff,
                boxShadow: on
                    ? [
                        BoxShadow(
                          color: Palette.lamp.withValues(alpha: 0.6),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              Ru.sound,
              style: kStencil.copyWith(
                fontSize: 9,
                color: (on ? Palette.lamp : Palette.steel).withValues(
                  alpha: on ? 0.9 : 0.5,
                ),
              ),
            ),
          ],
        ),
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
    required this.onFire,
  });

  final SeaBattleWorld world;
  final bool compact;
  final double width;
  final ValueChanged<double> onControl;
  final VoidCallback onFire;

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
                    Ru.keyHints,
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
            onFire: onFire,
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
      // The briefing is long enough to outgrow a phone lying on its side, so
      // the whole card scales down rather than spilling over the edge.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                over ? Ru.patrolOver : Ru.title,
                style: kStencil.copyWith(
                  fontSize: 30,
                  color: Palette.lamp,
                  shadows: [const Shadow(color: Palette.lamp, blurRadius: 24)],
                ),
              ),
              const SizedBox(height: 14),
              if (over) ...[
                _statLine(Ru.points, '${world.score}'),
                _statLine(
                  Ru.hitsOfShots,
                  '${world.hits} / ${world.shotsFired}',
                ),
                _statLine(Ru.accuracy, '${(world.accuracy * 100).round()}%'),
                _statLine(Ru.hullHits, '${world.hullHits}'),
                if (world.neutralsSunk > 0)
                  _statLine(Ru.neutralsSunk, '${world.neutralsSunk}'),
                _statLine(Ru.best, '${world.bestScore}'),
              ] else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    Ru.briefing,
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
                label: over ? Ru.again : Ru.dive,
                onPressed: onStart,
              ),
            ],
          ),
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
