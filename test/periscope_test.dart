import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sea_battle/engine/game_config.dart';
import 'package:sea_battle/engine/periscope.dart';

void main() {
  void run(Periscope periscope, double seconds, {double step = 1 / 120}) {
    for (var t = 0.0; t < seconds; t += step) {
      periscope.update(step);
    }
  }

  group('Periscope', () {
    test('a sound gear is up to speed almost as fast as the handle moves', () {
      const config = GameConfig();
      final periscope = Periscope(config: config)..control = 1;
      run(periscope, 0.25);

      // A quarter of a second gets it nearly all the way to full rate.
      expect(
        periscope.angularVelocity,
        greaterThan(config.maxAngularSpeed * 0.85),
      );
    });

    test('a wrecked gear takes its time winding up', () {
      final sound = Periscope()..control = 1;
      final wrecked = Periscope()
        ..wear(1)
        ..control = 1;
      run(sound, 0.25);
      run(wrecked, 0.25);

      expect(wrecked.angularVelocity, lessThan(sound.angularVelocity * 0.5));
    });

    test('damage accumulates and never runs past the wrecked gear', () {
      final periscope = Periscope();
      const config = GameConfig();

      periscope.wear(config.gearDamagePerHit);
      final onceHit = periscope.drag;
      expect(periscope.damage, closeTo(config.gearDamagePerHit, 1e-9));
      expect(onceHit, lessThan(config.angularDrag));

      for (var i = 0; i < 20; i++) {
        periscope.wear(config.gearDamagePerHit);
      }
      expect(periscope.damage, 1.0);
      expect(periscope.drag, closeTo(config.wreckedAngularDrag, 1e-9));
      expect(
        periscope.acceleration,
        closeTo(config.wreckedAngularAcceleration, 1e-9),
      );

      periscope.reset();
      expect(periscope.damage, 0);
    });

    test('a wrecked gear still tops out at the same rate', () {
      const config = GameConfig();
      // Start hard over to port so there is a full sweep to wind up in
      // before the far stop comes round.
      Periscope trained({required double damage}) {
        final periscope = Periscope(config: config)
          ..wear(damage)
          ..heading = -config.traverseLimit
          ..control = 1;
        run(periscope, 2.0, step: 1 / 240);
        return periscope;
      }

      final sound = trained(damage: 0);
      final wrecked = trained(damage: 1);

      // Both are held to maxAngularSpeed; only the time to get there differs.
      expect(sound.angularVelocity, closeTo(config.maxAngularSpeed, 0.01));
      expect(wrecked.angularVelocity, closeTo(sound.angularVelocity, 0.02));
    });

    test('keeps coasting after the handle is released', () {
      final periscope = Periscope()..control = 1;
      run(periscope, 1.0); // short of the training stop
      final headingAtRelease = periscope.heading;

      periscope.control = 0;
      run(periscope, 0.5);

      expect(periscope.heading, greaterThan(headingAtRelease + 0.05));
      expect(periscope.angularVelocity, greaterThan(0));
    });

    test('settles to a stop once the drag has bled the rate off', () {
      final periscope = Periscope()..control = -1;
      run(periscope, 1.0);
      periscope.control = 0;
      run(periscope, 6.0);

      expect(periscope.angularVelocity, 0);
    });

    test('never trains past the stops, and bounces off them', () {
      const config = GameConfig();
      final periscope = Periscope(config: config)..control = 1;
      run(periscope, 12.0);

      expect(periscope.heading, closeTo(config.traverseLimit, 1e-9));
      expect(periscope.isAtStop, isTrue);
      expect(periscope.stopContact, greaterThan(0));

      periscope.control = 0;
      periscope.update(1 / 60);
      expect(periscope.angularVelocity, lessThanOrEqualTo(0));
    });

    test('rate saturates at the geared maximum', () {
      const config = GameConfig();
      final periscope = Periscope(config: config)..control = 1;
      run(periscope, 30.0);
      expect(
        periscope.angularVelocity.abs(),
        lessThanOrEqualTo(config.maxAngularSpeed + 1e-9),
      );
    });

    test('trainFraction reports where the optics sit in the arc', () {
      const config = GameConfig();
      final periscope = Periscope(config: config);
      expect(periscope.trainFraction, 0);

      periscope.heading = config.traverseLimit / 2;
      expect(periscope.trainFraction, closeTo(0.5, 1e-9));
    });

    test('ignores a NaN handle demand', () {
      final periscope = Periscope()..control = 0.4;
      periscope.control = double.nan;
      expect(periscope.control, 0.4);
    });

    test('a zero-length step changes nothing', () {
      final periscope = Periscope()
        ..control = 1
        ..angularVelocity = 0.3;
      final heading = periscope.heading;
      periscope.update(0);
      expect(periscope.heading, heading);
      expect(periscope.angularVelocity, 0.3);
    });

    test('symmetric handling to port and starboard', () {
      final port = Periscope()..control = -1;
      final starboard = Periscope()..control = 1;
      run(port, 1.5);
      run(starboard, 1.5);
      expect(port.heading, closeTo(-starboard.heading, 1e-12));
    });

    test('a full sweep of the arc takes a few seconds of handle', () {
      const config = GameConfig();
      final periscope = Periscope(config: config)
        ..heading = -config.traverseLimit
        ..control = 1;
      var seconds = 0.0;
      while (periscope.heading < config.traverseLimit - 0.01 && seconds < 20) {
        periscope.update(1 / 120);
        seconds += 1 / 120;
      }
      expect(seconds, greaterThan(2.0));
      expect(seconds, lessThan(8.0));
    });

    test('reset returns the optics to the bow', () {
      final periscope = Periscope()..control = 1;
      run(periscope, 3.0);
      periscope.reset();
      expect(periscope.heading, 0);
      expect(periscope.angularVelocity, 0);
      expect(periscope.control, 0);
    });

    test('heading stays inside the arc under an absurd step', () {
      const config = GameConfig();
      final periscope = Periscope(config: config)
        ..control = 1
        ..angularVelocity = 50;
      periscope.update(1.0);
      expect(periscope.heading.abs(), lessThanOrEqualTo(config.traverseLimit));
      expect(periscope.heading.abs(), lessThan(math.pi));
    });
  });
}
