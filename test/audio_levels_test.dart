import 'package:flutter_test/flutter_test.dart';
import 'package:sea_battle/audio/game_audio.dart';

/// Runs a loop's level towards [target] the way the player does, frame by
/// frame, and returns the last value it actually sent.
({double sent, int frames}) glideTo(double from, double target) {
  var level = from;
  var sent = from;
  for (var frame = 1; frame <= 600; frame++) {
    level = glideLevel(level, target);
    if (levelWorthSending(level, sent, target)) sent = level;
    if (level == target && sent == target) return (sent: sent, frames: frame);
  }
  return (sent: sent, frames: -1);
}

void main() {
  test('a loop told to fall silent really reaches silence', () {
    final result = glideTo(0.38, 0);
    expect(result.sent, 0, reason: 'no hiss left at a fraction of a percent');
    expect(result.frames, greaterThan(10), reason: 'it still fades, not cuts');
    expect(result.frames, lessThan(90), reason: 'and within a second or so');
  });

  test('coming up, it settles exactly on the level asked for', () {
    final result = glideTo(0, 0.38);
    expect(result.sent, 0.38);
    expect(result.frames, greaterThan(0));
  });

  test('small wobbles are not sent every frame', () {
    expect(levelWorthSending(0.300, 0.295, 0.31), isFalse);
    expect(levelWorthSending(0.33, 0.30, 0.4), isTrue);
  });

  test('the last step to the target is always sent', () {
    expect(levelWorthSending(0, 0.01, 0), isTrue);
    expect(levelWorthSending(0, 0, 0), isFalse, reason: 'but only once');
  });
}
