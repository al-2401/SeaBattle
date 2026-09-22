import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sea_battle/audio/game_audio.dart';
import 'package:sea_battle/engine/sound_cue.dart';
import 'package:sea_battle/main.dart';
import 'package:sea_battle/ui/control_panel.dart';
import 'package:sea_battle/ui/periscope_view.dart';

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
    expect(find.text('ТОРПЕДЫ  12'), findsOneWidget);
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

    expect(find.text('ТОРПЕДЫ  11'), findsOneWidget);
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
    expect(find.text('ТОРПЕДЫ  12'), findsOneWidget);

    await tester.tapAt(box.center);
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('ТОРПЕДЫ  11'), findsOneWidget);
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
    expect(find.text('ТОРПЕДЫ  12'), findsOneWidget);

    await tester.tapAt(optic.center);
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('ТОРПЕДЫ  11'), findsOneWidget);
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
}
