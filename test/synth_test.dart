import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sea_battle/audio/sound_bank.dart';
import 'package:sea_battle/audio/synth.dart';
import 'package:sea_battle/engine/sound_cue.dart';

/// Reads back a 16-bit mono WAV the way a player would.
({int sampleRate, int frames, List<double> samples}) decodeWav(Uint8List wav) {
  final data = ByteData.sublistView(wav);
  String tag(int offset) => String.fromCharCodes(wav.sublist(offset, offset + 4));
  expect(tag(0), 'RIFF');
  expect(tag(8), 'WAVE');
  expect(tag(12), 'fmt ');
  expect(data.getUint16(20, Endian.little), 1, reason: 'PCM');
  expect(tag(36), 'data');

  final channels = data.getUint16(22, Endian.little);
  final bits = data.getUint16(34, Endian.little);
  final bytes = data.getUint32(40, Endian.little);
  expect(channels, 1);
  expect(bits, 16);
  expect(bytes, wav.length - 44);

  final frames = bytes ~/ 2;
  return (
    sampleRate: data.getUint32(24, Endian.little),
    frames: frames,
    samples: [
      for (var i = 0; i < frames; i++)
        data.getInt16(44 + i * 2, Endian.little) / 32767,
    ],
  );
}

double rmsOf(List<double> samples, int from, int to) {
  final first = from.clamp(0, samples.length);
  final last = to.clamp(0, samples.length);
  if (last <= first) return 0;
  var total = 0.0;
  for (var i = first; i < last; i++) {
    total += samples[i] * samples[i];
  }
  return math.sqrt(total / (last - first));
}

void main() {
  group('Wave', () {
    test('an oscillator really does oscillate at the asked frequency', () {
      final wave = Wave.seconds(8000, 1.0)..addOscillator(from: 100);
      // A 100 Hz sine crosses zero 200 times a second.
      var crossings = 0;
      for (var i = 1; i < wave.length; i++) {
        if ((wave.samples[i - 1] < 0) != (wave.samples[i] < 0)) crossings++;
      }
      expect(crossings, closeTo(200, 2));
      expect(wave.peak, closeTo(1, 0.01));
    });

    test('a sweep passes through the frequencies between its ends', () {
      final wave = Wave.seconds(8000, 1.0)..addOscillator(from: 50, to: 400);
      int crossingsIn(int from, int to) {
        var count = 0;
        for (var i = from + 1; i < to; i++) {
          if ((wave.samples[i - 1] < 0) != (wave.samples[i] < 0)) count++;
        }
        return count;
      }

      expect(crossingsIn(0, 800), lessThan(crossingsIn(7200, 8000)));
    });

    test('a percussive envelope starts at nothing and decays away', () {
      final wave = Wave.seconds(8000, 1.0)
        ..addOscillator(from: 200)
        ..percussive(attack: 0.01, release: 0.1);

      expect(wave.samples.first.abs(), lessThan(0.01));
      expect(rmsOf(wave.samples, 0, 800), greaterThan(0.2));
      expect(rmsOf(wave.samples, 7000, 8000), lessThan(0.01));
    });

    test('the low pass takes the top off and the high pass the bottom', () {
      Wave tone(double frequency) =>
          Wave.seconds(8000, 0.5)..addOscillator(from: frequency);

      final lowThroughLowPass = tone(80)..lowPass(300);
      final highThroughLowPass = tone(2000)..lowPass(300);
      expect(lowThroughLowPass.rms, greaterThan(highThroughLowPass.rms * 5));

      final lowThroughHighPass = tone(80)..highPass(600);
      final highThroughHighPass = tone(2000)..highPass(600);
      expect(highThroughHighPass.rms, greaterThan(lowThroughHighPass.rms * 5));
    });

    test('normalize hits the requested peak exactly', () {
      final wave = Wave.seconds(8000, 0.2)
        ..addOscillator(from: 200, amplitude: 0.03)
        ..normalize(0.8);
      expect(wave.peak, closeTo(0.8, 1e-9));
    });

    test('normalize leaves silence alone instead of dividing by zero', () {
      final wave = Wave.seconds(8000, 0.1)..normalize();
      expect(wave.peak, 0);
      expect(wave.samples.every((s) => s == 0), isTrue);
    });

    test('mixIn can lay a sound down later in the buffer', () {
      final blip = Wave.seconds(8000, 0.05)..addOscillator(from: 400);
      final track = Wave.seconds(8000, 0.5)..mixIn(blip, at: 0.25);

      expect(rmsOf(track.samples, 0, 1000), 0);
      expect(rmsOf(track.samples, 2000, 2400), greaterThan(0.5));
    });

    test('mixIn clips anything that falls off the end', () {
      final blip = Wave.seconds(8000, 0.1)..addOscillator(from: 400);
      final track = Wave.seconds(8000, 0.1)..mixIn(blip, at: 0.09);
      expect(track.peak, lessThanOrEqualTo(1.0));
    });

    test('a looped buffer joins back onto itself without a step', () {
      // The tone is fitted to the 0.9 s loop, so the crossfade blends material
      // that is already in phase.
      final frequency = SoundBank.fitToLoop(137.3, 0.9);
      final loop = Wave.seconds(8000, 1.0)
        ..addOscillator(from: frequency)
        ..makeSeamless(crossfade: 0.1);
      final trimmed = loop.trimmed(0.9);

      // Level either side of the join has to match, or the loop ticks.
      final head = rmsOf(trimmed.samples, 0, 400);
      final tail = rmsOf(trimmed.samples, trimmed.length - 400, trimmed.length);
      expect(head, closeTo(tail, 0.03));
      expect(trimmed.duration, closeTo(0.9, 1e-9));
    });

    test('fadeEdges silences the very ends', () {
      final wave = Wave.seconds(8000, 0.3)
        ..addOscillator(from: 300)
        ..fadeEdges();
      expect(wave.samples.first, 0);
      expect(wave.samples.last, 0);
    });
  });

  group('WAV encoding', () {
    test('round-trips samples, rate and length', () {
      final wave = Wave.seconds(22050, 0.25)..addOscillator(from: 440);
      final decoded = decodeWav(wave.toWav());

      expect(decoded.sampleRate, 22050);
      expect(decoded.frames, wave.length);
      for (var i = 0; i < wave.length; i += 97) {
        expect(decoded.samples[i], closeTo(wave.samples[i], 1 / 32767));
      }
    });

    test('clips rather than wrapping around when a sample is too hot', () {
      final wave = Wave.seconds(8000, 0.01)
        ..addOscillator(from: 200, amplitude: 4);
      final decoded = decodeWav(wave.toWav());
      expect(decoded.samples.every((s) => s.abs() <= 1.0), isTrue);
      expect(decoded.samples.any((s) => s > 0.99), isTrue);
    });
  });

  group('SoundBank', () {
    const bank = SoundBank();

    test('builds a usable sound for every cue and every loop', () {
      final built = bank.buildAll();
      for (final cue in SoundCue.values) {
        expect(built, contains(cue.asset), reason: '${cue.name} is missing');
      }
      for (final loop in SoundLoop.values) {
        expect(built, contains(loop.asset), reason: '${loop.name} is missing');
      }

      built.forEach((name, wave) {
        expect(wave.duration, greaterThan(0.2), reason: '$name too short');
        expect(wave.duration, lessThan(5.0), reason: '$name too long');
        expect(wave.peak, greaterThan(0.2), reason: '$name is nearly silent');
        expect(wave.peak, lessThanOrEqualTo(1.0), reason: '$name clips');
        expect(
          wave.samples.any((s) => s.isNaN || s.isInfinite),
          isFalse,
          reason: '$name has broken samples',
        );
      });
    });

    test('explosions hit hard and then get out of the way', () {
      for (final name in const ['hit', 'mine', 'launch', 'splash']) {
        final wave = bank.build(name);
        final opening = rmsOf(wave.samples, 0, wave.sampleRate ~/ 10);
        final ending = rmsOf(
          wave.samples,
          wave.length - wave.sampleRate ~/ 10,
          wave.length,
        );
        expect(opening, greaterThan(0.05), reason: '$name has no attack');
        expect(ending * 20, lessThan(opening), reason: '$name never decays');
      }
    });

    test('loops hold a steady level all the way through', () {
      for (final loop in SoundLoop.values) {
        final wave = bank.build(loop.name);
        final quarter = wave.length ~/ 4;
        final early = rmsOf(wave.samples, quarter ~/ 2, quarter);
        final late = rmsOf(wave.samples, quarter * 3, quarter * 4);
        expect(
          early,
          closeTo(late, math.max(early, late) * 0.55),
          reason: '${loop.name} is not steady enough to loop',
        );
      }
    });

    test('the mine is brighter than the torpedo hit', () {
      int zeroCrossings(Wave wave) {
        var count = 0;
        for (var i = 1; i < wave.length; i++) {
          if ((wave.samples[i - 1] < 0) != (wave.samples[i] < 0)) count++;
        }
        return count * wave.sampleRate ~/ wave.length;
      }

      expect(
        zeroCrossings(bank.build('mine')),
        greaterThan(zeroCrossings(bank.build('hit'))),
      );
    });

    test('low-pitched sounds are generated at a smaller sample rate', () {
      expect(bank.rateFor('sea'), lessThan(bank.rateFor('hit')));
      expect(bank.build('sea').sampleRate, bank.rateFor('sea'));
      expect(bank.build('hit').sampleRate, 22050);
    });

    test('an unknown name is a mistake, not silence', () {
      expect(() => bank.build('kraken'), throwsArgumentError);
    });

    test('loop tones complete whole cycles in the loop', () {
      final fitted = SoundBank.fitToLoop(194, 0.9);
      expect(fitted * 0.9, closeTo((fitted * 0.9).round(), 1e-9));
      expect(fitted, closeTo(194, 2));
      // Never collapses a slow modulation to nothing.
      expect(SoundBank.fitToLoop(0.05, 4.0), greaterThan(0));
    });

    test('generation is deterministic, so the committed files are stable', () {
      final first = const SoundBank().build('hit').toWav();
      final second = const SoundBank().build('hit').toWav();
      expect(first, orderedEquals(second));
    });
  });
}
