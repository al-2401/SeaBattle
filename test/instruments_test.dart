import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sea_battle/engine/entities.dart';
import 'package:sea_battle/engine/game_config.dart';
import 'package:sea_battle/engine/vec2.dart';
import 'package:sea_battle/engine/world.dart';
import 'package:sea_battle/ui/instruments.dart';
import 'package:sea_battle/ui/strings.dart';

Vessel ship({
  VesselClass type = VesselClass.destroyer,
  double recognition = 0,
  Allegiance allegiance = Allegiance.enemy,
}) => Vessel(
  id: 3,
  type: type,
  position: const Vec2(0, 1500),
  course: math.pi / 2,
  speed: 20,
  allegiance: allegiance,
)..recognition = recognition;

String readout(WidgetTester tester, String key) => tester
    .widgetList<Text>(
      find.descendant(
        of: find.byKey(ValueKey(key)),
        matching: find.byType(Text),
        matchRoot: true,
      ),
    )
    .map((t) => t.data ?? '')
    .join();

void main() {
  group('countdown lamps', () {
    test('all lit when a reload begins, none once it is done', () {
      expect(countdownLampsLit(1.0, 5), 5);
      expect(countdownLampsLit(0.0, 5), 0);
    });

    test('they go out one by one as the reload runs down', () {
      var previous = 5;
      for (var f = 1.0; f > 0; f -= 0.01) {
        final lit = countdownLampsLit(f, 5);
        expect(lit, lessThanOrEqualTo(previous));
        expect(previous - lit, lessThanOrEqualTo(1));
        previous = lit;
      }
    });

    test('the last lamp stays lit until the very end', () {
      expect(countdownLampsLit(0.01, 5), 1);
    });
  });

  group('radar', () {
    test('a contact is brightest just after the trace passes over it', () {
      const bearing = 0.4;
      final justPassed = radarBlipGlow(bearing + 0.05, bearing);
      final longAgo = radarBlipGlow(bearing + 5.5, bearing);
      expect(justPassed, greaterThan(0.9));
      expect(longAgo, lessThan(justPassed / 4));
    });

    test('a contact never quite vanishes between sweeps', () {
      for (var s = 0.0; s < 2 * math.pi; s += 0.1) {
        expect(radarBlipGlow(s, 1.0), greaterThan(0));
      }
    });

    test('the trace goes round once per period', () {
      expect(radarSweepAt(0), closeTo(0, 1e-9));
      expect(radarSweepAt(kRadarSweepPeriod / 2), closeTo(math.pi, 1e-9));
      expect(radarSweepAt(kRadarSweepPeriod), closeTo(0, 1e-9));
    });

    test('the alarm is for escorts close enough to bomb, not for mines', () {
      const config = GameConfig();
      final bombing = 1 - config.depthChargeRange / config.threatRange;
      expect(radarAlarm(const [], config), isFalse);
      expect(
        radarAlarm([
          Threat(bearing: 0, kind: ThreatKind.hunter, urgency: bombing - 0.05),
        ], config),
        isFalse,
      );
      expect(
        radarAlarm([
          Threat(bearing: 0, kind: ThreatKind.hunter, urgency: bombing + 0.05),
        ], config),
        isTrue,
      );
      expect(
        radarAlarm(const [
          Threat(bearing: 0, kind: ThreatKind.mine, urgency: 0.99),
        ], config),
        isFalse,
      );
    });
  });

  group('target name flaps', () {
    test('with nothing in the sight they say so', () {
      expect(targetNameFlaps(null, 0).trim(), Ru.noTarget);
    });

    test('a ship that is not being read gives nothing away', () {
      final flaps = targetNameFlaps(ship(), 0);
      expect(flaps.contains(Ru.vessel(VesselClass.destroyer)), isFalse);
      expect(flaps.length, kNameCells);
    });

    test('letters settle in step with recognition', () {
      final name = Ru.vessel(VesselClass.destroyer);
      final half = targetNameFlaps(ship(recognition: 0.5), 0);
      final settled = (0.5 * name.length).floor();
      expect(half.substring(0, settled), name.substring(0, settled));
      expect(half.substring(0, name.length) == name, isFalse);
    });

    test('an identified ship shows her class', () {
      expect(
        targetNameFlaps(ship(recognition: 1), 0).trim(),
        Ru.vessel(VesselClass.destroyer),
      );
    });

    test('every class name fits the readout', () {
      for (final type in VesselClass.values) {
        expect(Ru.vessel(type).length, lessThanOrEqualTo(kNameCells));
      }
    });
  });

  group('info panel', () {
    Future<void> pumpPanel(WidgetTester tester, Vessel? vessel) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: InfoPanel(
                vessel: vessel,
                time: 0,
                headingDegrees: -15.4,
                hits: 3,
                score: 240,
                gearDamage: 0.5,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('the flag stays unknown until the ship is identified', (
      tester,
    ) async {
      await pumpPanel(tester, ship(recognition: 0.6));
      expect(readout(tester, 'target-flag'), '?');

      await pumpPanel(tester, ship(recognition: 1));
      expect(readout(tester, 'target-flag'), Ru.enemyFlag);

      await pumpPanel(
        tester,
        ship(
          type: VesselClass.freighter,
          recognition: 1,
          allegiance: Allegiance.neutral,
        ),
      );
      expect(readout(tester, 'target-flag'), Ru.neutralFlag);
      expect(
        readout(tester, 'target-name').trim(),
        Ru.vessel(VesselClass.freighter),
      );
    });

    testWidgets('own-boat readouts are live values', (tester) async {
      await pumpPanel(tester, null);
      expect(readout(tester, 'own-bearing'), 'Л015');
      expect(readout(tester, 'score'), '0240');
      expect(readout(tester, 'hits'), '03');
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('the weapon counter shows the torpedoes left', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: WeaponDrum(remaining: 7))),
      ),
    );
    expect(readout(tester, 'torpedoes-left'), '07');
  });

  test('bearing counter reads port and starboard', () {
    expect(Ru.bearingCounter(-15.4), 'Л015');
    expect(Ru.bearingCounter(72), 'П072');
    expect(Ru.bearingCounter(0.2), ' 000');
  });

  group('weapon drum positions', () {
    test('positions wrap round in both directions', () {
      expect(weaponSlotAt(0), WeaponSlot.torpedo);
      expect(weaponSlotAt(kWeaponSlots.length.toDouble()), WeaponSlot.torpedo);
      expect(weaponSlotAt(-kWeaponSlots.length.toDouble()), WeaponSlot.torpedo);
      expect(weaponSlotAt(1), WeaponSlot.empty);
      expect(weaponSlotAt(-1), kWeaponSlots.last);
    });

    test('a half-turned drum reads as the nearer position', () {
      expect(weaponSlotAt(0.4), WeaponSlot.torpedo);
      expect(weaponSlotAt(0.6), WeaponSlot.empty);
    });

    test('only the torpedo is real; the rest are honest blanks', () {
      expect(kWeaponSlots.where((s) => s == WeaponSlot.torpedo), hasLength(1));
    });
  });

  testWidgets('the drum paints mid-turn without trouble', (tester) async {
    for (final position in const [0.0, 0.5, 1.0, -1.3, 7.8]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: WeaponDrum(remaining: 4, position: position)),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    }
  });

  group('alarm lamp', () {
    test('dark when nothing is happening', () {
      for (var t = 0.0; t < 3; t += 0.05) {
        expect(alarmLampLit(sounding: false, bombing: false, time: t), isFalse);
      }
    });

    test('flashes while the alarm sounds', () {
      final states = {
        for (var t = 0.0; t < 3; t += 0.05)
          alarmLampLit(sounding: true, bombing: false, time: t),
      };
      expect(states, {true, false});
    });

    test('burns steady while an escort is bombing', () {
      for (var t = 0.0; t < 3; t += 0.05) {
        expect(alarmLampLit(sounding: false, bombing: true, time: t), isTrue);
      }
    });
  });
}
