import 'dart:math' as math;

/// Every tunable number of the simulation, in one place.
///
/// The defaults are chosen for the feel of the Soviet arcade cabinet: a heavy
/// periscope that keeps swinging after you let go, a narrow slice of horizon,
/// and torpedoes slow enough that you have to lead the target.
class GameConfig {
  const GameConfig({
    this.fieldOfView = 30 * math.pi / 180,
    this.traverseLimit = 72 * math.pi / 180,
    this.angularAcceleration = 1.45,
    this.angularDrag = 1.25,
    this.maxAngularSpeed = 0.80,
    this.limitRestitution = 0.22,
    this.eyeHeight = 132.0,
    this.torpedoSpeed = 430.0,
    this.torpedoRange = 3400.0,
    this.torpedoRadius = 9.0,
    this.torpedoSalvoSize = 2,
    this.reloadTime = 1.9,
    this.initialTorpedoes = 12,
    this.maxTorpedoes = 18,
    this.torpedoesPerHit = 1,
    this.minRange = 850.0,
    this.maxRange = 3000.0,
    this.spawnInterval = const (min: 3.4, max: 7.0),
    this.maxVessels = 5,
    this.vesselSpeed = const (min: 42.0, max: 88.0),
    this.mineSpawnInterval = const (min: 11.0, max: 22.0),
    this.maxMines = 3,
    this.mineRange = const (min: 900.0, max: 2000.0),
    this.mineRadius = 26.0,
    this.swellPeriod = 7.3,
    this.swellRollAmplitude = 0.026,
    this.swellHeaveAmplitude = 0.012,
  });

  /// Angular width of the slice of horizon visible through the optics.
  final double fieldOfView;

  /// How far the periscope can be trained either side of the bow.
  final double traverseLimit;

  /// Angular acceleration applied at full handle deflection (rad/s^2).
  final double angularAcceleration;

  /// Viscous damping of the training gear (1/s). Low values coast for longer.
  final double angularDrag;

  final double maxAngularSpeed;

  /// How much of the angular speed survives a knock against the stops.
  final double limitRestitution;

  /// Height of the optics above the water, in metres. Wildly exaggerated on
  /// purpose: a real periscope squeezes every range into a few pixels under
  /// the horizon, whereas the cabinet spread its targets up the backdrop.
  /// This is the number that gives back that layered depth.
  final double eyeHeight;

  final double torpedoSpeed;
  final double torpedoRange;
  final double torpedoRadius;

  /// Torpedoes ready in the tubes before a reload is needed.
  final int torpedoSalvoSize;
  final double reloadTime;

  final int initialTorpedoes;
  final int maxTorpedoes;
  final int torpedoesPerHit;

  final double minRange;
  final double maxRange;

  final ({double min, double max}) spawnInterval;
  final int maxVessels;
  final ({double min, double max}) vesselSpeed;

  final ({double min, double max}) mineSpawnInterval;
  final int maxMines;
  final ({double min, double max}) mineRange;
  final double mineRadius;

  final double swellPeriod;
  final double swellRollAmplitude;
  final double swellHeaveAmplitude;

  /// Bearing at which traffic appears, just outside the training limits so
  /// ships sail into the searched arc rather than popping up inside it.
  double get spawnBearing => traverseLimit + fieldOfView * 0.9;
}
