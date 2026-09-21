import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sea_battle/engine/entities.dart';
import 'package:sea_battle/engine/game_config.dart';
import 'package:sea_battle/engine/vec2.dart';
import 'package:sea_battle/engine/world.dart';

const _config = GameConfig();

/// Same rules as the real game, but nothing ever sails in by itself — the
/// test decides exactly what is out there.
const _quiet = GameConfig(maxVessels: 0, maxMines: 0);

SeaBattleWorld freshWorld() =>
    SeaBattleWorld(config: _config, random: math.Random(7));

SeaBattleWorld quietSea() {
  final world = SeaBattleWorld(config: _quiet, random: math.Random(7));
  world.start();
  return world;
}

Vessel target({
  required VesselClass type,
  double range = 1200,
  double bearing = 0,
  double course = math.pi / 2,
  double speed = 0,
}) => Vessel(
  id: 1,
  type: type,
  position: Vec2.fromBearing(bearing, range),
  course: course,
  speed: speed,
);

void advance(SeaBattleWorld world, double seconds, {double step = 1 / 60}) {
  for (var t = 0.0; t < seconds; t += step) {
    world.update(step);
  }
}

void main() {
  group('firing', () {
    test('the first shot starts the patrol', () {
      final world = freshWorld();
      expect(world.phase, GamePhase.ready);
      expect(world.fire(), isTrue);
      expect(world.phase, GamePhase.running);
      expect(world.torpedoes, hasLength(1));
    });

    test('a shot leaves on the bearing the optics are trained on', () {
      final world = quietSea();
      world.periscope.heading = -0.4;
      world.fire();
      expect(world.torpedoes.single.bearing, -0.4);
    });

    test('emptying the tubes starts a reload that blocks further shots', () {
      final world = quietSea();
      for (var i = 0; i < _config.torpedoSalvoSize; i++) {
        expect(world.fire(), isTrue);
      }
      expect(world.canFire, isFalse);
      expect(world.fire(), isFalse);
      expect(world.isReloading, isTrue);

      advance(world, _config.reloadTime + 0.2);
      expect(world.isReloading, isFalse);
      expect(world.canFire, isTrue);
    });

    test('every shot costs a torpedo', () {
      final world = quietSea();
      final before = world.torpedoesRemaining;
      world.fire();
      expect(world.torpedoesRemaining, before - 1);
      expect(world.shotsFired, 1);
    });
  });

  group('torpedo runs', () {
    test('a ship dead ahead is hit and starts to sink', () {
      final world = quietSea();
      world.vessels.add(target(type: VesselClass.destroyer, range: 1200));
      world.fire();

      advance(world, 1200 / _config.torpedoSpeed + 0.3);

      expect(world.hits, 1);
      expect(world.score, greaterThan(0));
      expect(world.vessels.single.isHit, isTrue);
      expect(world.torpedoes, isEmpty);
      expect(world.blasts.any((b) => b.kind == BlastKind.hit), isTrue);
    });

    test('a ship well off the track is missed', () {
      final world = quietSea();
      world.vessels.add(
        target(type: VesselClass.destroyer, range: 1200, bearing: 0.35),
      );
      world.fire();

      advance(world, _config.torpedoRange / _config.torpedoSpeed + 0.5);

      expect(world.hits, 0);
      expect(world.score, 0);
      expect(world.torpedoes, isEmpty);
      expect(
        world.notices.any((n) => n.kind == NoticeKind.miss),
        isTrue,
      );
    });

    test('a torpedo cannot tunnel through a small boat between frames', () {
      final world = quietSea();
      world.vessels.add(target(type: VesselClass.patrolBoat, range: 1500));
      world.fire();

      // The coarsest step the simulation will ever integrate.
      advance(world, 5, step: 0.05);

      expect(world.hits, 1);
    });

    test('a torpedo that runs out of fuel makes a splash, not a hit', () {
      final world = quietSea();
      world.fire();
      advance(world, _config.torpedoRange / _config.torpedoSpeed + 0.2);

      expect(world.hits, 0);
      expect(world.blasts.any((b) => b.kind == BlastKind.splash), isTrue);
    });

    test('a mine in the way stops the torpedo short of the ship', () {
      final world = quietSea();
      world.vessels.add(target(type: VesselClass.cruiser, range: 1800));
      world.mines.add(
        Mine(id: 9, position: const Vec2(0, 900), drift: Vec2.zero, bobPhase: 0),
      );
      world.fire();

      advance(world, 900 / _config.torpedoSpeed + 0.2);
      expect(world.mines, isEmpty);
      expect(world.torpedoes, isEmpty);
      expect(world.blasts.any((b) => b.kind == BlastKind.mine), isTrue);

      advance(world, 1800 / _config.torpedoSpeed + 0.5);
      expect(world.hits, 0);
      expect(world.vessels.single.isHit, isFalse);
    });

    test('only the nearest target is struck', () {
      final world = quietSea();
      final near = target(type: VesselClass.destroyer, range: 1000);
      final far = Vessel(
        id: 2,
        type: VesselClass.tanker,
        position: const Vec2(0, 2200),
        course: math.pi / 2,
        speed: 0,
      );
      world.vessels.addAll([near, far]);
      world.fire();

      advance(world, 2400 / _config.torpedoSpeed + 0.3);

      expect(near.isHit, isTrue);
      expect(far.isHit, isFalse);
      expect(world.hits, 1);
    });
  });

  group('scoring', () {
    test('a distant target is worth more than a close one', () {
      final world = quietSea();
      final close = target(type: VesselClass.cruiser, range: _config.minRange);
      final distant = target(
        type: VesselClass.cruiser,
        range: _config.maxRange,
      );
      expect(world.scoreFor(distant), greaterThan(world.scoreFor(close)));
      expect(world.scoreFor(close), VesselClass.cruiser.points);
    });

    test('a hit puts a torpedo back in the rack', () {
      final world = quietSea();
      world.vessels.add(target(type: VesselClass.freighter, range: 1000));
      world.fire();
      final afterFiring = world.torpedoesRemaining;

      advance(world, 1000 / _config.torpedoSpeed + 0.3);

      expect(world.hits, 1);
      expect(
        world.torpedoesRemaining,
        afterFiring + _config.torpedoesPerHit,
      );
    });

    test('the best score survives a restart', () {
      final world = quietSea();
      world.vessels.add(target(type: VesselClass.destroyer, range: 1500));
      world.fire();
      advance(world, 1500 / _config.torpedoSpeed + 0.3);

      final best = world.bestScore;
      expect(best, greaterThan(0));

      world.reset();
      expect(world.score, 0);
      expect(world.bestScore, best);
    });
  });

  group('patrol', () {
    test('ends once the last torpedo has run', () {
      final world = quietSea();
      while (world.torpedoesRemaining > 0) {
        if (!world.fire()) advance(world, 0.1);
      }
      expect(world.phase, GamePhase.running, reason: 'shots still running');

      advance(world, _config.torpedoRange / _config.torpedoSpeed + 1);

      expect(world.phase, GamePhase.over);
      expect(world.torpedoes, isEmpty);
    });

    test('traffic keeps appearing while the patrol runs', () {
      final world = freshWorld()..start();
      advance(world, 25);
      expect(world.vessels, isNotEmpty);
      expect(world.vessels.length, lessThanOrEqualTo(_config.maxVessels));
    });

    test('ships that have crossed the arc are cleared away', () {
      final world = quietSea();
      world.vessels.add(
        target(
          type: VesselClass.freighter,
          range: 2000,
          bearing: -1.75, // already abaft the port beam
          course: -1.9, // and drawing further aft
          speed: 80,
        ),
      );
      advance(world, 30);
      expect(world.vessels, isEmpty);
    });

    test('traffic cycles: ships come in, cross, and are cleared', () {
      final world = freshWorld()..start();
      final seen = <int>{};
      for (var t = 0.0; t < 240; t += 0.05) {
        world.update(0.05);
        seen.addAll(world.vessels.map((v) => v.id));
        expect(world.vessels.length, lessThanOrEqualTo(_config.maxVessels));
      }
      // Far more ships than the arc can hold at once must have passed through.
      expect(seen.length, greaterThan(_config.maxVessels * 3));
    });

    test('spawned ships cross the bow instead of sailing away', () {
      final world = freshWorld()..start();
      advance(world, 3);
      expect(world.vessels, isNotEmpty);
      for (final vessel in world.vessels) {
        // Closing, not opening: a crossing track starts by drawing nearer.
        final approaching =
            vessel.heading.dot(vessel.position.normalized()) < 0;
        expect(approaching, isTrue, reason: 'ship ${vessel.id} is outbound');
      }
    });

    test('a hit ship settles and disappears', () {
      final world = quietSea();
      final ship = target(type: VesselClass.destroyer, range: 1000);
      world.vessels.add(ship);
      world.fire();
      advance(world, 1000 / _config.torpedoSpeed + 0.5);
      expect(ship.isHit, isTrue);

      advance(world, 6);
      expect(world.vessels, isEmpty);
    });

    test('difficulty ramps up but stays bounded', () {
      final world = freshWorld()..start();
      expect(world.difficulty, 0);
      advance(world, 60, step: 0.05);
      expect(world.difficulty, greaterThan(0.2));
      advance(world, 200, step: 0.05);
      expect(world.difficulty, 1.0);
    });

    test('the swell stays gentle', () {
      final world = freshWorld()..start();
      for (var t = 0.0; t < 20; t += 0.05) {
        world.update(0.05);
        expect(world.swellRoll.abs(), lessThanOrEqualTo(_config.swellRollAmplitude));
        expect(
          world.swellHeave.abs(),
          lessThanOrEqualTo(_config.swellHeaveAmplitude),
        );
      }
    });

    test('a long frozen frame cannot skip the simulation forward', () {
      final world = quietSea();
      world.fire();
      world.update(10);
      expect(
        world.torpedoes.single.distanceRun,
        lessThanOrEqualTo(_config.torpedoSpeed * 0.05 + 1e-6),
      );
    });
  });

  group('vessels', () {
    test('a broadside ship shows its whole length, bow-on very little', () {
      final broadside = target(
        type: VesselClass.cruiser,
        range: 1000,
        course: math.pi / 2,
      );
      final bowOn = target(
        type: VesselClass.cruiser,
        range: 1000,
        course: math.pi,
      );
      expect(broadside.aspect, closeTo(1, 1e-9));
      expect(bowOn.aspect, closeTo(0, 1e-9));
    });

    test('bearingRate tells which way the ship crosses the field', () {
      final toStarboard = target(
        type: VesselClass.destroyer,
        course: math.pi / 2,
        speed: 40,
      );
      final toPort = target(
        type: VesselClass.destroyer,
        course: -math.pi / 2,
        speed: 40,
      );
      expect(toStarboard.bearingRate, greaterThan(0));
      expect(toPort.bearingRate, lessThan(0));
    });
  });
}
