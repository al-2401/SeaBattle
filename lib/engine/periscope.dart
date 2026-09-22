import 'dart:math' as math;

import 'game_config.dart';
import 'geometry.dart';

/// The training gear of the periscope.
///
/// The handle does not set the bearing directly: it feeds a torque into a
/// damped rotor. Fresh out of the yard the gear answers almost at once; every
/// knock the boat takes bends it further, until it is the heavy drive that
/// keeps coasting after you let go and makes leading a target real work.
/// Slam into the training stops and the optics bounce back a little.
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

  /// Wear of the training gear, 0 (straight out of the yard) .. 1 (the drive
  /// is bent and swings like a pendulum). Only damage to the boat moves it.
  double damage = 0;

  /// Acceleration and damping the gear is actually running with.
  double get acceleration => lerpDouble(
    config.angularAcceleration,
    config.wreckedAngularAcceleration,
    damage,
  );

  double get drag =>
      lerpDouble(config.angularDrag, config.wreckedAngularDrag, damage);

  /// Takes a knock: the gear gets heavier and stays that way.
  void wear(double amount) {
    if (amount <= 0 || amount.isNaN) return;
    damage = (damage + amount).clamp(0.0, 1.0);
  }

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
    final torque = _control * acceleration;
    angularVelocity += (torque - drag * angularVelocity) * dt;
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
    damage = 0;
  }
}
