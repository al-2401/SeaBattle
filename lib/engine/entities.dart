import 'dart:math' as math;

import 'vec2.dart';

/// A class of target, with the silhouette and score value that go with it.
enum VesselClass {
  patrolBoat(
    label: 'КАТЕР',
    length: 46,
    beam: 9,
    height: 8,
    speedFactor: 1.45,
    points: 200,
    weight: 1.1,
    hunts: true,
  ),
  submarine(
    label: 'ПОДЛОДКА',
    length: 82,
    beam: 10,
    height: 9,
    speedFactor: 1.15,
    points: 250,
    weight: 0.7,
  ),
  destroyer(
    label: 'ЭСМИНЕЦ',
    length: 112,
    beam: 13,
    height: 17,
    speedFactor: 1.2,
    points: 120,
    weight: 1.6,
    hunts: true,
  ),
  cruiser(
    label: 'КРЕЙСЕР',
    length: 176,
    beam: 21,
    height: 26,
    speedFactor: 0.95,
    points: 80,
    weight: 1.3,
  ),
  freighter(
    label: 'ТРАНСПОРТ',
    length: 152,
    beam: 20,
    height: 21,
    speedFactor: 0.8,
    points: 60,
    weight: 1.7,
  ),
  tanker(
    label: 'ТАНКЕР',
    length: 214,
    beam: 27,
    height: 19,
    speedFactor: 0.7,
    points: 50,
    weight: 1.2,
  );

  const VesselClass({
    required this.label,
    required this.length,
    required this.beam,
    required this.height,
    required this.speedFactor,
    required this.points,
    required this.weight,
    this.hunts = false,
  });

  /// Russian name, shown when the target is hit.
  final String label;

  /// Hull length in metres — also the width of the silhouette.
  final double length;

  /// Hull width in metres, used as the collision radius broadside on.
  final double beam;

  /// Height of the superstructure above the waterline, in metres.
  final double height;

  /// Multiplier on the randomly drawn transit speed.
  final double speedFactor;

  /// Base score for a hit, before the range bonus.
  final int points;

  /// Relative spawn frequency.
  final double weight;

  /// Whether this class hunts submarines. Escorts work the boat over with
  /// depth charges once they are close enough; merchants never do.
  final bool hunts;
}

/// A surface target crossing the searched arc.
class Vessel {
  Vessel({
    required this.id,
    required this.type,
    required this.position,
    required this.course,
    required this.speed,
    this.silhouetteSeed = 0,
  });

  final int id;
  final VesselClass type;
  Vec2 position;

  /// Direction of travel, radians, 0 = away from the submarine.
  final double course;
  final double speed;

  /// Stable per-ship randomness for the silhouette (funnels, masts).
  final int silhouetteSeed;

  /// Seconds until this escort drops its next pattern of depth charges.
  /// Only counts down while it is close enough to be a threat.
  double attackTimer = 0;

  /// Whether this ship has already run over the boat: the hull is overhead
  /// for several ticks running, but it only costs the gear once.
  bool hasRammed = false;

  /// 0 while afloat, grows to 1 once hit and settling under.
  double sinking = 0;
  bool get isHit => sinking > 0;
  bool get isGone => sinking >= 1;

  double get range => position.length;
  double get bearing => position.bearing;

  Vec2 get heading => Vec2.fromBearing(course);

  /// Bow and stern in world space; the hull is treated as the segment between
  /// them for collision.
  Vec2 get bow => position + heading * (type.length / 2);
  Vec2 get stern => position - heading * (type.length / 2);

  /// Rate of change of the ship's bearing, rad/s. Positive means it is
  /// crossing to starboard, i.e. moving right across the eyepiece.
  double get bearingRate {
    final velocity = heading * speed;
    final squared = math.max(position.lengthSquared, 1.0);
    return (position.y * velocity.x - position.x * velocity.y) / squared;
  }

  /// How broadside the ship is to the line of sight, 0 (bow/stern on) .. 1.
  double get aspect {
    final toShip = position.normalized();
    return (heading.cross(toShip)).abs().clamp(0.0, 1.0);
  }

  void update(double dt) {
    if (isHit) {
      // A hit ship keeps its way on for a moment, then settles.
      sinking = math.min(1.0, sinking + dt / 4.2);
      position = position + heading * (speed * dt * (1 - sinking) * 0.35);
      return;
    }
    position = position + heading * (speed * dt);
  }
}

/// How a torpedo's run ended.
enum TorpedoOutcome { running, hitVessel, hitMine, expired }

/// A torpedo running on its gyro, straight out from the boat.
class Torpedo {
  Torpedo({
    required this.id,
    required this.origin,
    required this.bearing,
    required this.speed,
    required this.maxRange,
  }) : position = origin,
       previousPosition = origin;

  final int id;
  final Vec2 origin;

  /// Bearing set by the periscope at the moment of firing — it never changes.
  final double bearing;
  final double speed;
  final double maxRange;

  Vec2 position;
  Vec2 previousPosition;
  TorpedoOutcome outcome = TorpedoOutcome.running;

  bool get spent => outcome != TorpedoOutcome.running;

  double get distanceRun => (position - origin).length;
  Vec2 get direction => Vec2.fromBearing(bearing);

  void update(double dt) {
    previousPosition = position;
    position = position + direction * (speed * dt);
    if (distanceRun >= maxRange) outcome = TorpedoOutcome.expired;
  }
}

/// A drifting contact mine. Blocks torpedoes; costs you the shot.
class Mine {
  Mine({
    required this.id,
    required this.position,
    required this.drift,
    required this.bobPhase,
  });

  final int id;
  Vec2 position;
  final Vec2 drift;
  final double bobPhase;
  bool destroyed = false;

  double get range => position.length;
  double get bearing => position.bearing;

  void update(double dt) => position = position + drift * dt;
}

enum BlastKind { hit, mine, splash }

/// A short-lived visual event: a torpedo hit, a mine going up, or the plume
/// of a torpedo that ran out of fuel.
class Blast {
  Blast({
    required this.position,
    required this.kind,
    required this.duration,
    this.scale = 1,
  });

  final Vec2 position;
  final BlastKind kind;
  final double duration;
  final double scale;

  double age = 0;
  double get progress => (age / duration).clamp(0.0, 1.0);
  bool get isDone => age >= duration;

  void update(double dt) => age += dt;
}
