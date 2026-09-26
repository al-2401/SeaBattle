import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sea_battle/engine/entities.dart';
import 'package:sea_battle/engine/game_config.dart';
import 'package:sea_battle/engine/vec2.dart';
import 'package:sea_battle/engine/world.dart';
import 'package:sea_battle/ui/painters/sea_painter.dart';
import 'package:sea_battle/ui/periscope_view.dart';

/// Renders the eyepiece over a world the test builds by hand, to be sure the
/// painters survive every state the game can reach: ships of every class at
/// every aspect, torpedoes running, mines, blasts and sinking wrecks.
void main() {
  final surface = SeaSurface();

  Future<void> renderWorld(
    WidgetTester tester,
    SeaBattleWorld world, {
    double time = 3.2,
    Size size = const Size(760, 760),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: PeriscopeView(world: world, surface: surface, time: time),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  }

  SeaBattleWorld staged() {
    final world = SeaBattleWorld(
      config: const GameConfig(maxVessels: 0, maxMines: 0),
      random: math.Random(3),
    )..start();
    world.vessels.clear();
    return world;
  }

  testWidgets('a quiet sea renders', (tester) async {
    await renderWorld(tester, staged());
  });

  testWidgets('every class of target renders at every aspect', (tester) async {
    final world = staged();
    var id = 100;
    for (final type in VesselClass.values) {
      for (final aspect in const [0.0, math.pi / 4, math.pi / 2]) {
        world.vessels.add(
          Vessel(
            id: id++,
            type: type,
            position: Vec2.fromBearing(
              (id % 7 - 3) * 0.06,
              900 + (id % 5) * 480,
            ),
            course: aspect,
            speed: 50,
            silhouetteSeed: id * 13,
          ),
        );
      }
    }
    await renderWorld(tester, world);
  });

  testWidgets('torpedoes, mines, blasts and wrecks render', (tester) async {
    final world = staged();
    world.vessels.add(
      Vessel(
        id: 1,
        type: VesselClass.destroyer,
        position: const Vec2(-140, 1400),
        course: math.pi / 2,
        speed: 60,
      )..sinking = 0.45,
    );
    world.mines.add(
      Mine(id: 2, position: const Vec2(320, 1100), drift: Vec2.zero, bobPhase: 1),
    );
    world.torpedoes.add(
      Torpedo(
        id: 3,
        origin: Vec2.zero,
        bearing: 0.05,
        speed: 430,
        maxRange: 3400,
      )..position = const Vec2(60, 1200),
    );
    world.blasts.addAll([
      Blast(
        position: const Vec2(-140, 1400),
        kind: BlastKind.hit,
        duration: 1.6,
        scale: 1.2,
      )..age = 0.35,
      Blast(position: const Vec2(520, 1800), kind: BlastKind.mine, duration: 1.3)
        ..age = 0.5,
      Blast(
        position: const Vec2(-620, 2400),
        kind: BlastKind.splash,
        duration: 1.1,
      )..age = 0.6,
    ]);
    await renderWorld(tester, world);
  });

  testWidgets('renders hard over against the training stop', (tester) async {
    final world = staged();
    world.periscope.heading = world.config.traverseLimit;
    world.vessels.add(
      Vessel(
        id: 1,
        type: VesselClass.cruiser,
        position: Vec2.fromBearing(world.config.traverseLimit - 0.05, 1600),
        course: 0.4,
        speed: 70,
      ),
    );
    await renderWorld(tester, world);
  });

  testWidgets('flags and neutrality markings render as they are read', (
    tester,
  ) async {
    for (final read in const [0.0, 0.5, 1.0]) {
      final world = staged();
      for (final allegiance in Allegiance.values) {
        world.vessels.add(
          Vessel(
            id: allegiance.index + 1,
            type: VesselClass.tanker,
            position: Vec2.fromBearing(allegiance.index * 0.16 - 0.08, 1400),
            course: math.pi / 2,
            speed: 30,
            allegiance: allegiance,
          )..recognition = read,
        );
      }
      await renderWorld(tester, world);
    }
  });

  testWidgets('the threat strip renders, marks and all', (tester) async {
    final world = staged();
    world.vessels.add(
      Vessel(
        id: 1,
        type: VesselClass.destroyer,
        position: Vec2.fromBearing(-1.1, 900),
        course: 0,
        speed: 40,
      ),
    );
    world.mines.add(
      Mine(
        id: 2,
        position: Vec2.fromBearing(0.9, 1500),
        drift: Vec2.zero,
        bobPhase: 0,
      ),
    );
    expect(world.threats, hasLength(2));

    // Both are well outside the 30° in the eyepiece: the strip is the only
    // place they show up at all.
    await renderWorld(tester, world);
    await renderWorld(tester, world, size: const Size(220, 220));
  });

  testWidgets('renders in a tiny and a very wide optic', (tester) async {
    await renderWorld(tester, staged(), size: const Size(220, 220));
    await renderWorld(tester, staged(), size: const Size(1600, 500));
  });
}
