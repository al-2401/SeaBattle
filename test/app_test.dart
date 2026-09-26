import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sea_battle/audio/game_audio.dart';
import 'package:sea_battle/engine/sound_cue.dart';
import 'package:sea_battle/main.dart';
import 'package:sea_battle/ui/control_panel.dart';
import 'package:sea_battle/ui/game_page.dart';
import 'package:sea_battle/ui/instruments.dart';
import 'package:sea_battle/ui/periscope_view.dart';

/// Torpedoes left, read off whichever instrument carries the count in the
/// current layout — the rack in portrait, the weapon counter on its side.
int torpedoesLeft(WidgetTester tester) {
  final texts = tester.widgetList<Text>(
    find.descendant(
      of: find.byKey(const ValueKey('torpedoes-left')),
      matching: find.byType(Text),
      matchRoot: true,
    ),
  );
  final digits = texts.map((t) => t.data ?? '').join().replaceAll(
    RegExp(r'[^0-9]'),
    '',
  );
  return int.parse(digits);
}

/// Stands in for the audio device: records what the cabinet asked for
/// without going near a real one.
class FakeAudio implements GameAudio {
  @override
  bool enabled = true;

  final List<SoundCue> played = [];
  int unlocks = 0;
  int loopUpdates = 0;
  double lastTrainEffort = 0;
  int lastTorpedoesRunning = 0;
  bool prepared = false;
  bool disposed = false;

  @override
  Future<void> prepare() async => prepared = true;

  @override
  void unlock() => unlocks++;

  @override
  void fire(SoundCue cue) => played.add(cue);

  @override
  void updateLoops({
    required double trainEffort,
    required int torpedoesRunning,
    required bool patrolRunning,
  }) {
    loopUpdates++;
    lastTrainEffort = trainEffort;
    lastTorpedoesRunning = torpedoesRunning;
  }

  @override
  Future<void> dispose() async => disposed = true;
}

void main() {
  testWidgets('the cabinet starts on its attract screen', (tester) async {
    await tester.pumpWidget(SeaBattleApp(audio: FakeAudio()));
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.text('ПОГРУЖЕНИЕ'), findsOneWidget);
    expect(torpedoesLeft(tester), 12);
  });

  testWidgets('pressing the start button clears the overlay', (tester) async {
    await tester.pumpWidget(SeaBattleApp(audio: FakeAudio()));
    await tester.pump(const Duration(milliseconds: 16));

    await tester.tap(find.text('ПОГРУЖЕНИЕ'));
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.text('ПОГРУЖЕНИЕ'), findsNothing);
  });

  testWidgets('the torpedo button spends a torpedo', (tester) async {
    await tester.pumpWidget(SeaBattleApp(audio: FakeAudio()));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.tap(find.text('ПОГРУЖЕНИЕ'));
    await tester.pump(const Duration(milliseconds: 16));

    await tester.tap(find.text('ТОРПЕДА'));
    await tester.pump(const Duration(milliseconds: 16));

    expect(torpedoesLeft(tester), 11);
  });

  testWidgets('the picture keeps running frame after frame', (tester) async {
    await tester.pumpWidget(SeaBattleApp(audio: FakeAudio()));
    for (var i = 0; i < 90; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('it lays out on a phone-sized screen', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(SeaBattleApp(audio: FakeAudio()));
    await tester.pump(const Duration(milliseconds: 16));

    expect(tester.takeException(), isNull);
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('it lays out on a phone held on its side', (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(SeaBattleApp(audio: FakeAudio()));
    await tester.pump(const Duration(milliseconds: 16));

    expect(tester.takeException(), isNull);
    // Wheel on the left wing, button on the right, optic between them.
    final wheel = tester.getCenter(find.byType(HelmWheel));
    final optic = tester.getCenter(find.byType(PeriscopeView));
    final button = tester.getCenter(find.byType(FireButton));
    expect(wheel.dx, lessThan(optic.dx));
    expect(button.dx, greaterThan(optic.dx));
  });

  testWidgets('a touch in the corner beside the torpedo button does not fire', (
    tester,
  ) async {
    await tester.pumpWidget(SeaBattleApp(audio: FakeAudio()));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.tap(find.text('ПОГРУЖЕНИЕ'));
    await tester.pump(const Duration(milliseconds: 16));

    final box = tester.getRect(find.byType(FireButton));
    await tester.tapAt(box.topLeft + const Offset(3, 3));
    await tester.tapAt(box.bottomRight - const Offset(3, 3));
    await tester.pump(const Duration(milliseconds: 16));
    expect(torpedoesLeft(tester), 12);

    await tester.tapAt(box.center);
    await tester.pump(const Duration(milliseconds: 16));
    expect(torpedoesLeft(tester), 11);
  });

  testWidgets('a tap fires on the eyepiece glass but not on the cabinet', (
    tester,
  ) async {
    // Tall window: plenty of dark cabinet above and below the round optic.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(SeaBattleApp(audio: FakeAudio()));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.tap(find.text('ПОГРУЖЕНИЕ'));
    await tester.pump(const Duration(milliseconds: 16));

    final optic = tester.getRect(find.byType(PeriscopeView));
    await tester.tapAt(Offset(optic.center.dx, optic.top + 6));
    await tester.tapAt(Offset(optic.center.dx, optic.bottom - 6));
    await tester.pump(const Duration(milliseconds: 16));
    expect(torpedoesLeft(tester), 12);

    await tester.tapAt(optic.center);
    await tester.pump(const Duration(milliseconds: 16));
    expect(torpedoesLeft(tester), 11);
  });

  testWidgets('firing reaches the audio device', (tester) async {
    final audio = FakeAudio();
    await tester.pumpWidget(SeaBattleApp(audio: audio));
    await tester.pump(const Duration(milliseconds: 16));
    expect(audio.prepared, isTrue);

    await tester.tap(find.text('ПОГРУЖЕНИЕ'));
    await tester.pump(const Duration(milliseconds: 16));
    expect(audio.unlocks, greaterThan(0));

    await tester.tap(find.text('ТОРПЕДА'));
    await tester.pump(const Duration(milliseconds: 16));

    expect(audio.played, contains(SoundCue.launch));
    expect(audio.loopUpdates, greaterThan(0));
    expect(audio.lastTorpedoesRunning, 1);
  });

  testWidgets('the training effort handed to the loops tracks the gear', (
    tester,
  ) async {
    final audio = FakeAudio();
    await tester.pumpWidget(SeaBattleApp(audio: audio));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.tap(find.text('ПОГРУЖЕНИЕ'));
    await tester.pump(const Duration(milliseconds: 16));
    expect(audio.lastTrainEffort, 0);

    // Hold the handle hard over and let the gear wind up.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final windingUp = audio.lastTrainEffort;
    expect(windingUp, greaterThan(0.2));

    // Let go: the gear coasts, so the motor is still turning over.
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump(const Duration(milliseconds: 16));
    expect(audio.lastTrainEffort, greaterThan(0));

    for (var i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(audio.lastTrainEffort, lessThan(windingUp));
  });

  testWidgets('the sound lamp switches the audio off and on', (tester) async {
    final audio = FakeAudio();
    await tester.pumpWidget(SeaBattleApp(audio: audio));
    await tester.pump(const Duration(milliseconds: 16));
    expect(audio.enabled, isTrue);

    await tester.tap(find.text('ЗВУК'));
    await tester.pump(const Duration(milliseconds: 16));
    expect(audio.enabled, isFalse);

    await tester.tap(find.text('ЗВУК'));
    await tester.pump(const Duration(milliseconds: 16));
    expect(audio.enabled, isTrue);
  });

  testWidgets('leaving the cabinet shuts the audio down', (tester) async {
    final audio = FakeAudio();
    await tester.pumpWidget(SeaBattleApp(audio: audio));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(audio.disposed, isTrue);
  });

  group('corner layout on a phone held on its side', () {
    Future<Size> pumpAt(WidgetTester tester, Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(SeaBattleApp(audio: FakeAudio()));
      await tester.pump(const Duration(milliseconds: 16));
      return size;
    }

    testWidgets('it is the layout in use', (tester) async {
      expect(kCockpitLayout, CockpitLayout.corners);
      await pumpAt(tester, const Size(915, 412));
      expect(find.byType(RadarScope), findsOneWidget);
      expect(find.byType(InfoPanel), findsOneWidget);
      expect(find.byType(WeaponDrum), findsOneWidget);
      expect(find.byType(LaunchLamps), findsOneWidget);
      // One fact, one place: the rack's count now lives on the weapon drum.
      expect(find.byType(TorpedoRack), findsNothing);
    });

    for (final size in const [
      Size(915, 412),
      Size(844, 390),
      Size(780, 360),
      Size(700, 320),
      Size(1280, 600),
    ]) {
      testWidgets('lays out without overflow at ${size.width.round()}×'
          '${size.height.round()}', (tester) async {
        await pumpAt(tester, size);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('each instrument stands in the place it was given', (
      tester,
    ) async {
      final size = await pumpAt(tester, const Size(915, 412));
      final mid = size.center(Offset.zero);
      final radar = tester.getRect(find.byType(RadarScope));
      final info = tester.getRect(find.byType(InfoPanel));
      final drum = tester.getRect(find.byType(WeaponDrum));
      final button = tester.getRect(find.byType(FireButton));
      final lamps = tester.getRect(find.byType(LaunchLamps));
      final optic = tester.getCenter(find.byType(PeriscopeView));

      expect(optic.dx, closeTo(mid.dx, 1), reason: 'optic in the middle');

      expect(radar.center.dx, lessThan(mid.dx), reason: 'radar on the left');
      expect(radar.top, lessThan(20), reason: 'radar at the top');

      expect(info.center.dx, lessThan(mid.dx), reason: 'info on the left');
      expect(info.top, greaterThanOrEqualTo(radar.bottom), reason: 'below radar');
      expect(info.center.dy, closeTo(mid.dy, size.height * 0.12));

      expect(drum.center.dx, greaterThan(mid.dx), reason: 'weapons right');
      expect(drum.center.dy, closeTo(mid.dy, size.height * 0.2));

      expect(button.center.dx, greaterThan(mid.dx));
      expect(button.bottom, greaterThan(size.height * 0.9));
      expect(button.right, greaterThan(size.width * 0.9));
      expect(lamps.right, lessThanOrEqualTo(button.left),
          reason: 'lamps stand beside the button');
      expect(drum.bottom, lessThanOrEqualTo(button.top + 1),
          reason: 'weapons do not sit on the button');
    });

    testWidgets('the wheel is sunk into the bottom edge', (tester) async {
      final size = await pumpAt(tester, const Size(915, 412));
      final wheel = tester.getRect(find.byType(HelmWheel));
      expect(wheel.center.dx, lessThan(size.width / 2));
      expect(wheel.bottom, greaterThan(size.height), reason: 'partly hidden');
      final showing = (size.height - wheel.top) / wheel.height;
      expect(showing, closeTo(kWheelShowing, 0.01));
      expect(showing, inInclusiveRange(1 / 3, 0.5));
    });

    testWidgets('the top-right corner is left empty', (tester) async {
      final size = await pumpAt(tester, const Size(915, 412));
      final corner = Rect.fromLTRB(
        size.width * 0.8,
        0,
        size.width,
        size.height * 0.25,
      );
      for (final type in const [
        RadarScope,
        InfoPanel,
        WeaponDrum,
        LaunchLamps,
        FireButton,
        HelmWheel,
      ]) {
        expect(
          tester.getRect(find.byType(type)).overlaps(corner),
          isFalse,
          reason: '$type strays into the top-right corner',
        );
      }
    });

    testWidgets('a tap on the glass fires, the instruments do not', (
      tester,
    ) async {
      await pumpAt(tester, const Size(915, 412));
      await tester.tap(find.text('ПОГРУЖЕНИЕ'));
      await tester.pump(const Duration(milliseconds: 16));

      await tester.tapAt(tester.getCenter(find.byType(InfoPanel)));
      await tester.tapAt(tester.getCenter(find.byType(WeaponDrum)));
      await tester.pump(const Duration(milliseconds: 16));
      expect(torpedoesLeft(tester), 12);

      await tester.tapAt(tester.getCenter(find.byType(PeriscopeView)));
      await tester.pump(const Duration(milliseconds: 16));
      expect(torpedoesLeft(tester), 11);
    });

    testWidgets('emptying the tubes lights the countdown, then ready', (
      tester,
    ) async {
      await pumpAt(tester, const Size(915, 412));
      await tester.tap(find.text('ПОГРУЖЕНИЕ'));
      await tester.pump(const Duration(milliseconds: 16));

      PanelLamp ready() =>
          tester.widget<PanelLamp>(find.byKey(const ValueKey('ready-lamp')));
      expect(ready().on, isTrue);

      await tester.tap(find.text('ТОРПЕДА'));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.tap(find.text('ТОРПЕДА'));
      await tester.pump(const Duration(milliseconds: 16));

      final lamps = tester.widget<LaunchLamps>(find.byType(LaunchLamps));
      expect(ready().on, isFalse);
      expect(countdownLampsLit(lamps.reloadFraction, lamps.count), lamps.count);

      for (var i = 0; i < 300; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(ready().on, isTrue);
    });

    testWidgets('the old column layout still lays out', (tester) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GamePage(audio: FakeAudio(), layout: CockpitLayout.columns),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.takeException(), isNull);
      expect(find.byType(TorpedoRack), findsOneWidget);
      expect(find.byType(RadarScope), findsNothing);
    });
  });
}
