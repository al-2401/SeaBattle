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
    this.angularAcceleration = 7.2,
    this.angularDrag = 9.0,
    this.wreckedAngularAcceleration = 1.45,
    this.wreckedAngularDrag = 1.25,
    this.gearDamagePerHit = 0.25,
    this.maxAngularSpeed = 0.80,
    this.limitRestitution = 0.22,
    this.eyeHeight = 132.0,
    this.torpedoSpeed = 430.0,
    this.torpedoRange = 6000.0,
    this.torpedoRadius = 9.0,
    this.torpedoSalvoSize = 2,
    this.reloadTime = 3.4,
    this.initialTorpedoes = 12,
    this.maxTorpedoes = 18,
    this.torpedoesPerHit = 1,
    this.minRange = 1100.0,
    this.maxRange = 6000.0,
    this.closestApproach = 1000.0,
    this.hullRadius = 60.0,
    this.depthChargeRange = 1200.0,
    this.depthChargeInterval = const (min: 9.0, max: 16.0),
    this.threatRange = 2400.0,
    this.neutralShare = 0.3,
    this.flagRange = 2200.0,
    this.identifyTime = 1.3,
    this.neutralPenalty = 300,
    this.spawnInterval = const (min: 9.0, max: 18.0),
    this.maxVessels = 6,
    this.vesselSpeed = const (min: 16.0, max: 34.0),
    this.mineSpawnInterval = const (min: 20.0, max: 38.0),
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
  ///
  /// Together with [angularDrag] this is a gear that answers the handle almost
  /// at once: the two numbers settle at the same top speed as the wrecked gear
  /// below, but they get there in a tenth of a second instead of a second.
  final double angularAcceleration;

  /// Viscous damping of the training gear (1/s). Low values coast for longer.
  final double angularDrag;

  /// What the gear turns into once the boat has taken a beating: the heavy,
  /// coasting drive the cabinet had, where the lead has to be taken early.
  final double wreckedAngularAcceleration;
  final double wreckedAngularDrag;

  /// How much of that wear one hit on the boat adds, 0..1.
  final double gearDamagePerHit;

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

  /// Traffic keeps its distance: nothing spawns closer than this, and
  /// [maxRange] reaches all the way out to the haze on the horizon. It sits a
  /// little above [closestApproach] on purpose — a crossing track can only be
  /// held off to about 0.95 of the range a ship appeared at.
  final double minRange;
  final double maxRange;

  /// Closest point of approach a ship's track is allowed to have.
  final double closestApproach;

  /// Radius of the boat itself: anything drifting inside it is touching us.
  final double hullRadius;

  /// A hunter this close starts working the boat over with depth charges.
  final double depthChargeRange;
  final ({double min, double max}) depthChargeInterval;

  /// How far out the boat can tell that something means it harm. Inside this
  /// the hydrophone has it and the threat strip marks its bearing; beyond it
  /// there is nothing to hear yet, wherever the optics happen to point.
  final double threatRange;

  /// Share of the merchant traffic sailing under a neutral flag. Warships are
  /// never neutral — nobody was fooled by an escort.
  final double neutralShare;

  /// Beyond this the flag at the masthead is a smudge, however long you look.
  final double flagRange;

  /// Seconds of holding a ship in the field of view, alongside, to read it.
  final double identifyTime;

  /// What sinking a neutral costs off the score.
  final int neutralPenalty;

  /// How often new traffic comes over the horizon, and how much of it is in
  /// the arc at once. Deliberately unhurried: this is a patrol, not a
  /// shooting gallery — the long waits are what make a contact matter.
  final ({double min, double max}) spawnInterval;
  final int maxVessels;

  /// Transit speed, m/s. Still well above anything that floated — 16 m/s is
  /// 31 knots — but slow enough that a ship takes the better part of a minute
  /// to cross the sector, which is what leaves room to identify her, take the
  /// lead, and watch the torpedo run.
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
