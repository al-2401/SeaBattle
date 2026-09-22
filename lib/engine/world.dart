import 'dart:math' as math;

import 'entities.dart';
import 'game_config.dart';
import 'geometry.dart';
import 'periscope.dart';
import 'sound_cue.dart';
import 'vec2.dart';

enum GamePhase { ready, running, over }

enum ThreatKind { hunter, mine }

/// Something close enough to hurt the boat, as the hydrophone reports it:
/// a bearing and how pressing it is. Targets are not in here — finding those
/// is still the player's job, and the whole game is the narrow field of view.
class Threat {
  const Threat({
    required this.bearing,
    required this.kind,
    required this.urgency,
  });

  final double bearing;
  final ThreatKind kind;

  /// 0 at the edge of hearing, 1 right on top of the boat.
  final double urgency;
}

enum NoticeKind { hit, miss, mine, info }

/// A short message shown across the optics ("ПОПАДАНИЕ!", "МИМО").
class Notice {
  Notice(this.text, this.kind, this.ttl);

  final String text;
  final NoticeKind kind;
  double ttl;
}

/// The whole simulation: periscope, traffic, torpedoes, score.
///
/// Deliberately free of any Flutter import so the rules can be unit-tested
/// without a widget tree.
class SeaBattleWorld {
  SeaBattleWorld({GameConfig? config, math.Random? random})
    : config = config ?? const GameConfig(),
      _random = random ?? math.Random() {
    periscope = Periscope(config: this.config);
    reset();
  }

  final GameConfig config;
  final math.Random _random;

  late final Periscope periscope;

  final List<Vessel> vessels = [];
  final List<Torpedo> torpedoes = [];
  final List<Mine> mines = [];
  final List<Blast> blasts = [];
  final List<Notice> notices = [];

  /// Noises that happened since the presenter last looked.
  final List<SoundCue> _cues = [];

  GamePhase phase = GamePhase.ready;
  int score = 0;
  int bestScore = 0;
  int torpedoesRemaining = 0;
  int tubesLoaded = 0;
  int shotsFired = 0;
  int hits = 0;
  double reloadTimer = 0;
  double elapsed = 0;

  /// Times the boat has been hit this patrol.
  int hullHits = 0;

  /// Fades from 1 to 0 after a blow lands; the view shakes the optics by it.
  double shock = 0;

  double _spawnTimer = 0;
  double _mineTimer = 0;
  double _hornTimer = 0;
  int _nextId = 1;

  /// Ramps from 0 to 1 over the first three minutes of a patrol.
  double get difficulty => (elapsed / 180).clamp(0.0, 1.0);

  bool get isReloading => reloadTimer > 0;
  bool get canFire =>
      phase == GamePhase.running && tubesLoaded > 0 && !isReloading;

  double get accuracy => shotsFired == 0 ? 0 : hits / shotsFired;

  /// Everything within earshot that can hurt the boat: escorts hunting us and
  /// mines drifting down on us, wherever they are in the arc.
  List<Threat> get threats {
    final found = <Threat>[];
    double urgencyAt(double range) =>
        (1 - range / config.threatRange).clamp(0.0, 1.0);

    for (final vessel in vessels) {
      if (!vessel.type.hunts || vessel.isHit) continue;
      if (vessel.range > config.threatRange) continue;
      found.add(
        Threat(
          bearing: vessel.bearing,
          kind: ThreatKind.hunter,
          urgency: urgencyAt(vessel.range),
        ),
      );
    }

    for (final mine in mines) {
      if (mine.destroyed || mine.range > config.threatRange) continue;
      found.add(
        Threat(
          bearing: mine.bearing,
          kind: ThreatKind.mine,
          urgency: urgencyAt(mine.range),
        ),
      );
    }

    return found;
  }

  /// Roll of the horizon from the swell, radians.
  double get swellRoll =>
      math.sin(elapsed * 2 * math.pi / config.swellPeriod) *
      config.swellRollAmplitude;

  /// Vertical heave of the horizon, as a fraction of the optic radius.
  double get swellHeave =>
      math.sin(elapsed * 2 * math.pi / (config.swellPeriod * 0.63) + 1.1) *
      config.swellHeaveAmplitude;

  void reset() {
    vessels.clear();
    torpedoes.clear();
    mines.clear();
    blasts.clear();
    notices.clear();
    periscope.reset();
    phase = GamePhase.ready;
    score = 0;
    shotsFired = 0;
    hits = 0;
    hullHits = 0;
    shock = 0;
    elapsed = 0;
    reloadTimer = 0;
    torpedoesRemaining = config.initialTorpedoes;
    tubesLoaded = math.min(config.torpedoSalvoSize, torpedoesRemaining);
    _spawnTimer = 0.8;
    _mineTimer = _randomBetween(config.mineSpawnInterval);
    _hornTimer = 6 + _random.nextDouble() * 12;
    _cues.clear();
    // Start with a little traffic already in the arc.
    for (var i = 0; i < math.min(3, config.maxVessels); i++) {
      _spawnVessel();
    }
  }

  void start() {
    if (phase == GamePhase.running) return;
    if (phase == GamePhase.over) reset();
    phase = GamePhase.running;
    _notify('ПОИСК ЦЕЛИ', NoticeKind.info, 1.6);
  }

  /// Hands over the noises queued since the last call and empties the queue.
  List<SoundCue> drainCues() {
    if (_cues.isEmpty) return const [];
    final drained = List<SoundCue>.of(_cues);
    _cues.clear();
    return drained;
  }

  void update(double dt) {
    if (dt <= 0) return;
    // Never integrate a huge step: a backgrounded tab must not teleport
    // torpedoes past their targets.
    dt = math.min(dt, 0.05);

    periscope.update(dt);
    if (periscope.stopImpact > 0.12) _cues.add(SoundCue.clunk);
    periscope.stopImpact = 0;
    shock = math.max(0, shock - dt * 0.8);
    _updateNotices(dt);
    _updateBlasts(dt);

    if (phase != GamePhase.running) return;

    elapsed += dt;

    if (reloadTimer > 0) {
      reloadTimer = math.max(0, reloadTimer - dt);
      if (reloadTimer == 0 && torpedoesRemaining > 0) {
        tubesLoaded = math.min(config.torpedoSalvoSize, torpedoesRemaining);
        _notify('ТОРПЕДЫ ГОТОВЫ', NoticeKind.info, 1.0);
        _cues.add(SoundCue.reload);
      }
    }

    _updateTraffic(dt);
    _updateTorpedoes(dt);
    _checkGameOver();
  }

  /// Fires a torpedo on the bearing the optics are trained on.
  ///
  /// The torpedo takes the mechanical bearing of the periscope, not the
  /// swell-shaken picture, so the sight picture is honest.
  bool fire() {
    if (phase == GamePhase.ready) {
      start();
    }
    if (!canFire) {
      if (isReloading) _notify('ПЕРЕЗАРЯДКА', NoticeKind.info, 0.8);
      return false;
    }

    torpedoes.add(
      Torpedo(
        id: _nextId++,
        origin: Vec2.zero,
        bearing: periscope.heading,
        speed: config.torpedoSpeed,
        maxRange: config.torpedoRange,
      ),
    );
    _cues.add(SoundCue.launch);
    shotsFired++;
    torpedoesRemaining--;
    tubesLoaded--;
    if (tubesLoaded == 0 && torpedoesRemaining > 0) {
      reloadTimer = config.reloadTime;
    }
    return true;
  }

  // ---------------------------------------------------------------- traffic

  void _updateTraffic(double dt) {
    for (final vessel in vessels) {
      vessel.update(dt);
      _workOverTheBoat(vessel, dt);
    }
    vessels.removeWhere((v) => v.isGone || _shouldRetire(v));

    for (final mine in mines) {
      mine.update(dt);
      if (!mine.destroyed && mine.range <= config.hullRadius + config.mineRadius) {
        mine.destroyed = true;
        blasts.add(
          Blast(position: mine.position, kind: BlastKind.mine, duration: 1.3),
        );
        _takeHit('МИНА У БОРТА', SoundCue.mine);
      }
    }
    mines.removeWhere((m) => m.destroyed || m.range > config.maxRange * 1.8);

    _spawnTimer -= dt;
    if (_spawnTimer <= 0 && vessels.length < config.maxVessels) {
      _spawnVessel();
      final interval = config.spawnInterval;
      _spawnTimer = lerpDouble(
        _randomBetween(interval),
        interval.min * 0.7,
        difficulty,
      );
    }

    _hornTimer -= dt;
    if (_hornTimer <= 0) {
      _hornTimer = _soundOffIfAnyoneIsAbout()
          ? 16 + _random.nextDouble() * 22
          : 4;
    }

    _mineTimer -= dt;
    if (_mineTimer <= 0) {
      if (mines.length < config.maxMines) _spawnMine();
      _mineTimer = _randomBetween(config.mineSpawnInterval) *
          (1 - 0.45 * difficulty);
    }
  }

  /// Everything a ship can do to the boat.
  ///
  /// An escort that has come inside its attack range keeps dropping patterns
  /// of depth charges until it is sunk or drawing away again; the closer it
  /// is, the more of the pattern lands on the hull. Any ship at all — even a
  /// merchant — wrecks the gear if its hull passes right over us.
  void _workOverTheBoat(Vessel vessel, double dt) {
    if (vessel.isHit) return;

    final overhead =
        pointSegmentDistance(Vec2.zero, vessel.stern, vessel.bow) <=
        config.hullRadius;
    if (overhead) {
      // Only once per ship: it is over us for several ticks running.
      if (!vessel.hasRammed) {
        vessel.hasRammed = true;
        _takeHit('УДАР ПО КОРПУСУ', SoundCue.hit);
      }
      return;
    }

    if (!vessel.type.hunts || vessel.range > config.depthChargeRange) {
      vessel.attackTimer = 0;
      return;
    }

    if (vessel.attackTimer == 0) {
      // A first pass takes a moment to line up; after that, pattern on
      // pattern until it loses us.
      vessel.attackTimer = _randomBetween(config.depthChargeInterval);
      return;
    }

    vessel.attackTimer -= dt;
    if (vessel.attackTimer > 0) return;
    vessel.attackTimer = _randomBetween(config.depthChargeInterval) *
        (1 - 0.35 * difficulty);

    // Near misses shake the boat; only a pattern straight overhead bends the
    // training gear. Closeness is measured across the band an escort can
    // actually occupy — from the closest any ship comes out to the range it
    // starts dropping at — because measuring it from zero would make every
    // pattern a near miss: nothing ever gets closer than `closestApproach`.
    final band = math.max(1.0, config.depthChargeRange - config.closestApproach);
    final closeness =
        ((config.depthChargeRange - vessel.range) / band).clamp(0.0, 1.0);
    if (closeness > 0.45 || _random.nextDouble() < closeness) {
      _takeHit('ГЛУБИННАЯ БОМБА', SoundCue.depthCharge);
    } else {
      shock = math.max(shock, 0.45);
      _notify('БОМБЁЖКА', NoticeKind.mine, 1.2);
      _cues.add(SoundCue.depthCharge);
    }
  }

  /// The boat takes a blow: the training gear is bent a little further, and
  /// it stays bent for the rest of the patrol.
  void _takeHit(String text, SoundCue cue) {
    hullHits++;
    periscope.wear(config.gearDamagePerHit);
    shock = 1;
    _notify(text, NoticeKind.mine, 2.0);
    _cues.add(cue);
  }

  /// Sounds a merchant's horn if one is close enough and roughly where the
  /// optics are looking. Returns whether anybody was there to sound off.
  bool _soundOffIfAnyoneIsAbout() {
    for (final vessel in vessels) {
      if (vessel.isHit) continue;
      if (vessel.range > 2600) continue;
      final offAxis = angleDelta(periscope.heading, vessel.bearing).abs();
      if (offAxis > config.fieldOfView * 0.7) continue;
      _cues.add(SoundCue.horn);
      return true;
    }
    return false;
  }

  /// A ship is retired once it has finished its transit: either hull down in
  /// the haze, or well outside the searched arc — and in both cases only
  /// while it is still drawing away, never on the tick it spawns.
  bool _shouldRetire(Vessel vessel) {
    final opening = vessel.heading.dot(vessel.position.normalized()) > 0;
    if (opening && vessel.range > config.maxRange * 1.15) return true;
    if (vessel.bearing.abs() <= config.spawnBearing + 0.1) return false;
    return vessel.bearing * vessel.bearingRate > 0;
  }

  /// Picks a bearing for new traffic that is well clear of where the optics
  /// are pointed, so nothing ever materialises inside the field of view.
  double _pickSpawnBearing() {
    final clear = config.fieldOfView * 0.85;
    for (var attempt = 0; attempt < 8; attempt++) {
      final bearing =
          (_random.nextDouble() * 2 - 1) * config.spawnBearing;
      if (angleDelta(periscope.heading, bearing).abs() > clear) return bearing;
    }
    // Fall back to the far side of the arc from the periscope.
    return -periscope.heading.sign * config.spawnBearing;
  }

  void _spawnVessel() {
    // Weighted towards the near half of the arc: out at the horizon a ship is
    // a couple of pixels of smoke, and a patrol made only of those is empty
    // to look at. There is still traffic all the way out there.
    final draw = math.pow(_random.nextDouble(), 1.6).toDouble();
    final range = lerpDouble(config.minRange, config.maxRange, draw);
    final bearing = _pickSpawnBearing();
    final side = bearing >= 0 ? 1.0 : -1.0;
    final position = Vec2.fromBearing(bearing, range);

    final type = _pickVesselClass();
    final speed =
        _randomBetween(config.vesselSpeed) *
        type.speedFactor *
        (1 + 0.35 * difficulty);

    // Put the ship on a track that crosses the bow at a chosen closest point
    // of approach, so it sweeps the whole arc and grows as it comes on.
    // With the closest approach at `cpa` and the target `range` away, the
    // track has to leave the line of sight by asin(cpa / range).
    // Nothing is allowed to come inside `closestApproach`: closer than that
    // a ship fills the eyepiece and the periscope scale stops meaning
    // anything.
    final cpa = (range * lerpDouble(0.35, 0.85, _random.nextDouble())).clamp(
      config.closestApproach,
      2600.0,
    );
    final offset = math.asin((cpa / range).clamp(0.15, 0.95));
    final course = wrapAngle(bearing - side * (math.pi - offset));

    vessels.add(
      Vessel(
        id: _nextId++,
        type: type,
        position: position,
        course: course,
        speed: speed,
        silhouetteSeed: _random.nextInt(1 << 30),
      ),
    );
  }

  VesselClass _pickVesselClass() {
    final total = VesselClass.values.fold<double>(
      0,
      (sum, type) => sum + type.weight,
    );
    var pick = _random.nextDouble() * total;
    for (final type in VesselClass.values) {
      pick -= type.weight;
      if (pick <= 0) return type;
    }
    return VesselClass.freighter;
  }

  void _spawnMine() {
    final bearing = (_random.nextDouble() * 2 - 1) * config.traverseLimit;
    final range = _randomBetween(config.mineRange);
    final position = Vec2.fromBearing(bearing, range);
    // The set drifts down on the boat rather than past it, so a mine left
    // alone eventually arrives — which is the reason to spend a torpedo on
    // one instead of steering the sight around it.
    final towards = position.normalized() * -(3 + _random.nextDouble() * 6);
    mines.add(
      Mine(
        id: _nextId++,
        position: position,
        drift: Vec2(
          towards.x + (_random.nextDouble() - 0.5) * 4,
          towards.y + (_random.nextDouble() - 0.5) * 4,
        ),
        bobPhase: _random.nextDouble() * math.pi * 2,
      ),
    );
  }

  // --------------------------------------------------------------- torpedoes

  void _updateTorpedoes(double dt) {
    for (final torpedo in torpedoes) {
      torpedo.update(dt);
      _resolveTorpedo(torpedo);
      if (torpedo.outcome == TorpedoOutcome.expired) {
        blasts.add(
          Blast(
            position: torpedo.position,
            kind: BlastKind.splash,
            duration: 1.1,
          ),
        );
        _notify('МИМО', NoticeKind.miss, 1.1);
        _cues.add(SoundCue.splash);
      }
    }
    torpedoes.removeWhere((t) => t.spent);
  }

  /// Finds the first thing the torpedo's travel this tick ran into.
  void _resolveTorpedo(Torpedo torpedo) {
    if (torpedo.spent) return;

    Vessel? struckVessel;
    Mine? struckMine;
    var bestDistance = double.infinity;

    for (final vessel in vessels) {
      if (vessel.isHit) continue;
      final clearance = segmentSegmentDistance(
        torpedo.previousPosition,
        torpedo.position,
        vessel.stern,
        vessel.bow,
      );
      if (clearance > vessel.type.beam / 2 + config.torpedoRadius) continue;
      final along = (vessel.position - torpedo.previousPosition).length;
      if (along < bestDistance) {
        bestDistance = along;
        struckVessel = vessel;
        struckMine = null;
      }
    }

    for (final mine in mines) {
      if (mine.destroyed) continue;
      final clearance = pointSegmentDistance(
        mine.position,
        torpedo.previousPosition,
        torpedo.position,
      );
      if (clearance > config.mineRadius + config.torpedoRadius) continue;
      final along = (mine.position - torpedo.previousPosition).length;
      if (along < bestDistance) {
        bestDistance = along;
        struckMine = mine;
        struckVessel = null;
      }
    }

    if (struckVessel != null) {
      _registerHit(torpedo, struckVessel);
    } else if (struckMine != null) {
      struckMine.destroyed = true;
      torpedo.outcome = TorpedoOutcome.hitMine;
      blasts.add(
        Blast(
          position: struckMine.position,
          kind: BlastKind.mine,
          duration: 1.3,
        ),
      );
      _notify('МИНА!', NoticeKind.mine, 1.4);
      _cues.add(SoundCue.mine);
    }
  }

  void _registerHit(Torpedo torpedo, Vessel vessel) {
    torpedo.outcome = TorpedoOutcome.hitVessel;
    vessel.sinking = 0.0001;
    hits++;

    final points = scoreFor(vessel);
    score += points;
    if (score > bestScore) bestScore = score;

    if (torpedoesRemaining < config.maxTorpedoes) {
      torpedoesRemaining = math.min(
        config.maxTorpedoes,
        torpedoesRemaining + config.torpedoesPerHit,
      );
      if (!isReloading && tubesLoaded < config.torpedoSalvoSize) {
        tubesLoaded++;
      }
    }

    blasts.add(
      Blast(
        position: vessel.position,
        kind: BlastKind.hit,
        duration: 1.6,
        scale: vessel.type.height / 18,
      ),
    );
    _notify('${vessel.type.label} +$points', NoticeKind.hit, 1.8);
    _cues.add(SoundCue.hit);
  }

  /// Score for sinking [vessel]: the farther the target, the better the shot.
  int scoreFor(Vessel vessel) {
    final span = config.maxRange - config.minRange;
    final rangeFactor = span <= 0
        ? 0.0
        : ((vessel.range - config.minRange) / span).clamp(0.0, 1.0);
    final raw = vessel.type.points * (1 + rangeFactor);
    return (raw / 10).round() * 10;
  }

  // ------------------------------------------------------------------ misc

  void _updateBlasts(double dt) {
    for (final blast in blasts) {
      blast.update(dt);
    }
    blasts.removeWhere((b) => b.isDone);
  }

  void _updateNotices(double dt) {
    for (final notice in notices) {
      notice.ttl -= dt;
    }
    notices.removeWhere((n) => n.ttl <= 0);
  }

  void _notify(String text, NoticeKind kind, double ttl) {
    notices.removeWhere((n) => n.kind == kind);
    notices.add(Notice(text, kind, ttl));
    while (notices.length > 3) {
      notices.removeAt(0);
    }
  }

  void _checkGameOver() {
    if (torpedoesRemaining > 0 || torpedoes.isNotEmpty) return;
    phase = GamePhase.over;
    if (score > bestScore) bestScore = score;
    _notify('БОЕЗАПАС ИЗРАСХОДОВАН', NoticeKind.info, 4);
    _cues.add(SoundCue.gameOver);
  }

  double _randomBetween(({double min, double max}) range) =>
      lerpDouble(range.min, range.max, _random.nextDouble());
}
