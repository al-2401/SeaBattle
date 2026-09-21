import 'dart:math' as math;

import 'game_config.dart';

/// The training gear of the periscope.
///
/// The handle does not set the bearing directly: it feeds a torque into a
/// heavy, damped rotor. Let go and the optics keep drifting; slam into the
/// training stops and they bounce back a little. That lag is what makes
/// leading a target feel like work.
class Periscope {
  Periscope({this.config = const GameConfig()});

  final GameConfig config;

  /// Bearing the optics are trained on, radians, 0 = dead ahead.
  double heading = 0;

  /// Current rate of train, rad/s.
  double angularVelocity = 0;

  double _control = 0;

  /// Seconds the handle has been held hard against a stop.
  double _stopContact = 0;

  /// Rate the gear was doing when it last struck a stop, rad/s. The presenter
  /// reads this to decide how hard the clunk should sound, then clears it.
  double stopImpact = 0;

  /// Handle deflection, -1 (port) .. +1 (starboard).
  double get control => _control;

  set control(double value) {
    if (value.isNaN) return;
    _control = value.clamp(-1.0, 1.0);
  }

  bool get isAtStop => heading.abs() >= config.traverseLimit - 1e-6;

  /// Non-zero while the gear is grinding against a stop; used by the view to
  /// shake the optics and light the warning lamp.
  double get stopContact => _stopContact;

  /// 0 at the bow, ±1 at the training limits.
  double get trainFraction => (heading / config.traverseLimit).clamp(-1.0, 1.0);

  void update(double dt) {
    if (dt <= 0) return;
    final torque = _control * config.angularAcceleration;
    angularVelocity += (torque - config.angularDrag * angularVelocity) * dt;
    angularVelocity = angularVelocity.clamp(
      -config.maxAngularSpeed,
      config.maxAngularSpeed,
    );

    heading += angularVelocity * dt;

    final limit = config.traverseLimit;
    if (heading.abs() > limit) {
      heading = heading.sign * limit;
      stopImpact = math.max(stopImpact, angularVelocity.abs());
      angularVelocity = -angularVelocity * config.limitRestitution;
      _stopContact = math.min(1.0, _stopContact + dt * 6);
    } else {
      _stopContact = math.max(0.0, _stopContact - dt * 3);
    }

    // Kill the last sliver of drift so the sight settles instead of creeping.
    if (_control == 0 && angularVelocity.abs() < 0.0015) angularVelocity = 0;
  }

  void reset() {
    heading = 0;
    angularVelocity = 0;
    _control = 0;
    _stopContact = 0;
    stopImpact = 0;
  }
}
