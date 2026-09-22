import 'dart:math' as math;

import '../engine/sound_cue.dart';
import 'synth.dart';

/// Builds every noise the game makes, from scratch.
///
/// Each recipe is deliberately crude — swept oscillators, filtered noise and
/// a decay — because that is what the cabinet's sound board could manage, and
/// it lands closer to the memory than any recording of a real torpedo would.
class SoundBank {
  const SoundBank({this.sampleRate = 22050});

  final int sampleRate;

  /// Every generated buffer, keyed by its asset path.
  Map<String, Wave> buildAll() => {
    for (final cue in SoundCue.values) cue.asset: build(cue.name),
    for (final loop in SoundLoop.values) loop.asset: build(loop.name),
  };

  Wave build(String name) => switch (name) {
    'launch' => _launch(),
    'hit' => _hit(),
    'mine' => _mine(),
    'splash' => _splash(),
    'reload' => _reload(),
    'clunk' => _clunk(),
    'depthCharge' => _depthCharge(),
    'horn' => _horn(),
    'gameOver' => _gameOver(),
    'motor' => _motor(),
    'torpedo' => _torpedo(),
    'sea' => _sea(),
    _ => throw ArgumentError('unknown sound: $name'),
  };

  /// Sounds with nothing above a few hundred hertz are generated at a lower
  /// rate — a third of the bytes, and not a sample of it audible.
  static const Set<String> _lowFidelity = {
    'motor',
    'torpedo',
    'sea',
    'horn',
    'depthCharge',
  };

  int rateFor(String name) => _lowFidelity.contains(name) ? 12000 : sampleRate;

  /// Nudges [frequency] to the nearest one that completes a whole number of
  /// cycles in [loopSeconds].
  ///
  /// A loop whose tones fit its own length is already continuous where it
  /// joins back on itself, so the crossfade blends identical material instead
  /// of two tones in different phase — which would cancel and leave an
  /// audible dip on every repeat.
  static double fitToLoop(double frequency, double loopSeconds) {
    final cycles = math.max(1.0, (frequency * loopSeconds).roundToDouble());
    return cycles / loopSeconds;
  }

  math.Random _rng(int seed) => math.Random(seed);

  Wave _blank(double seconds, [int? rate]) =>
      Wave.seconds(rate ?? sampleRate, seconds);

  // --------------------------------------------------------------- one-shots

  /// Compressed air, then the thump of the tube.
  Wave _launch() {
    final air = _blank(0.5)
      ..addNoise(random: _rng(11), amplitude: 1, amplitudeEnd: 0.02)
      ..lowPass(3200, cutoffEnd: 700)
      ..percussive(attack: 0.012, release: 0.14);

    final thump = _blank(0.5)
      ..addOscillator(
        from: 165,
        to: 46,
        amplitude: 1,
        amplitudeEnd: 0,
        frequencyCurve: Curve.easeOut,
      )
      ..percussive(attack: 0.004, release: 0.13);

    return _blank(0.5)
      ..mixIn(air, gain: 0.55)
      ..mixIn(thump, gain: 1.0)
      ..fadeEdges()
      ..normalize(0.85);
  }

  /// A hit: the crack, the boom rolling away, and the hull ringing.
  Wave _hit() {
    final blast = _blank(2.0)
      ..addNoise(random: _rng(23), amplitude: 1, amplitudeEnd: 0.05)
      ..lowPass(2400, cutoffEnd: 150)
      ..percussive(attack: 0.003, release: 0.52);

    final boom = _blank(2.0)
      ..addOscillator(
        from: 96,
        to: 26,
        amplitude: 1,
        amplitudeEnd: 0,
        frequencyCurve: Curve.easeOut,
      )
      ..percussive(attack: 0.010, release: 0.58);

    final ring = _blank(2.0)
      ..addOscillator(from: 331, amplitude: 0.6, waveform: Waveform.square)
      ..addOscillator(from: 517, amplitude: 0.35, waveform: Waveform.triangle)
      ..percussive(attack: 0.001, release: 0.10);

    return _blank(2.0)
      ..mixIn(blast, gain: 0.85)
      ..mixIn(boom, gain: 1.0)
      ..mixIn(ring, gain: 0.22)
      ..fadeEdges()
      ..normalize(0.95);
  }

  /// A mine: sharper and brighter than a torpedo in a hull.
  Wave _mine() {
    final blast = _blank(1.4)
      ..addNoise(random: _rng(37), amplitude: 1, amplitudeEnd: 0.03)
      ..lowPass(5200, cutoffEnd: 420)
      ..percussive(attack: 0.001, release: 0.30);

    final boom = _blank(1.4)
      ..addOscillator(
        from: 148,
        to: 40,
        amplitude: 1,
        amplitudeEnd: 0,
        frequencyCurve: Curve.easeOut,
      )
      ..percussive(attack: 0.004, release: 0.32);

    final shrapnel = _blank(1.4)
      ..addOscillator(from: 812, amplitude: 0.5, waveform: Waveform.triangle)
      ..percussive(attack: 0.001, release: 0.16);

    return _blank(1.4)
      ..mixIn(blast, gain: 0.95)
      ..mixIn(boom, gain: 0.8)
      ..mixIn(shrapnel, gain: 0.25)
      ..fadeEdges()
      ..normalize(0.92);
  }

  /// A torpedo at the end of its run: water, and nothing else.
  Wave _splash() {
    final water = _blank(1.0)
      ..addNoise(random: _rng(53), amplitude: 1, amplitudeEnd: 0.04)
      ..highPass(520)
      ..lowPass(5200, cutoffEnd: 1500)
      ..percussive(attack: 0.008, release: 0.24);

    final gulp = _blank(1.0)
      ..addOscillator(from: 240, to: 84, amplitude: 1, amplitudeEnd: 0)
      ..percussive(attack: 0.012, release: 0.11);

    return _blank(1.0)
      ..mixIn(water, gain: 1.0)
      ..mixIn(gulp, gain: 0.30)
      ..fadeEdges()
      ..normalize(0.72);
  }

  /// Two metallic clacks: the breech, then the interlock.
  Wave _reload() {
    Wave clack(int seed, double pitch) {
      final click = _blank(0.16)
        ..addNoise(random: _rng(seed), amplitude: 1, amplitudeEnd: 0)
        ..highPass(1400)
        ..percussive(attack: 0.0005, release: 0.018);
      final body = _blank(0.16)
        ..addOscillator(from: pitch, amplitude: 1, waveform: Waveform.square)
        ..percussive(attack: 0.001, release: 0.030);
      return _blank(0.16)
        ..mixIn(click, gain: 0.7)
        ..mixIn(body, gain: 0.35);
    }

    return _blank(0.42)
      ..mixIn(clack(67, 196), gain: 1.0)
      ..mixIn(clack(71, 262), gain: 0.85, at: 0.15)
      ..fadeEdges()
      ..normalize(0.70);
  }

  /// The training gear slamming into its stop.
  Wave _clunk() {
    final thud = _blank(0.38)
      ..addOscillator(from: 124, to: 88, amplitude: 1, amplitudeEnd: 0)
      ..percussive(attack: 0.002, release: 0.075);

    final strike = _blank(0.38)
      ..addNoise(random: _rng(83), amplitude: 1, amplitudeEnd: 0)
      ..highPass(800)
      ..percussive(attack: 0.0005, release: 0.030);

    final ring = _blank(0.38)
      ..addOscillator(from: 243, amplitude: 1, waveform: Waveform.triangle)
      ..percussive(attack: 0.001, release: 0.13);

    return _blank(0.38)
      ..mixIn(thud, gain: 1.0)
      ..mixIn(strike, gain: 0.45)
      ..mixIn(ring, gain: 0.20)
      ..fadeEdges()
      ..normalize(0.80);
  }

  /// A pattern of depth charges going off around the boat.
  ///
  /// Heard from inside a pressure hull under water: no crack at all, just two
  /// blows in the belly of the sound and the frames ringing afterwards. The
  /// noise is low-passed hard, which is what tells the ear this one happened
  /// to us rather than to something out on the water.
  Wave _depthCharge() {
    Wave blow(int seed, double from, double gain) {
      final press = _blank(2.2, rateFor('depthCharge'))
        ..addNoise(random: _rng(seed), amplitude: 1, amplitudeEnd: 0.04)
        ..lowPass(900, cutoffEnd: 90)
        ..percussive(attack: 0.006, release: 0.46);
      final thud = _blank(2.2, rateFor('depthCharge'))
        ..addOscillator(
          from: from,
          to: 21,
          amplitude: 1,
          amplitudeEnd: 0,
          frequencyCurve: Curve.easeOut,
        )
        ..percussive(attack: 0.014, release: 0.50);
      return _blank(2.2, rateFor('depthCharge'))
        ..mixIn(press, gain: 0.6 * gain)
        ..mixIn(thud, gain: 1.0 * gain);
    }

    // The hull answers the blow: low frames groaning, not a bell.
    final frames = _blank(2.2, rateFor('depthCharge'))
      ..addOscillator(from: 74, amplitude: 0.7, waveform: Waveform.triangle)
      ..addOscillator(from: 117, to: 109, amplitude: 0.4)
      ..percussive(attack: 0.02, release: 0.62);

    return _blank(2.2, rateFor('depthCharge'))
      ..mixIn(blow(97, 88, 1.0))
      ..mixIn(blow(101, 71, 0.75), at: 0.34)
      ..mixIn(frames, gain: 0.30)
      ..lowPass(1400)
      ..fadeEdges()
      ..normalize(0.95);
  }

  /// A merchant sounding off, well out of sight.
  Wave _horn() {
    final horn = _blank(2.2, rateFor('horn'))
      ..addOscillator(from: 164, amplitude: 1, waveform: Waveform.saw)
      ..addOscillator(from: 166.4, amplitude: 0.7, waveform: Waveform.saw)
      ..addOscillator(from: 246, amplitude: 0.45, waveform: Waveform.sine)
      ..lowPass(900) // distance eats the top end
      ..shape((t) {
        final rise = math.min(1.0, t / 0.16);
        final fall = t < 1.15 ? 1.0 : math.exp(-(t - 1.15) / 0.34);
        return rise * fall;
      })
      ..tremolo(rate: 5.5, depth: 0.12);

    return horn
      ..fadeEdges(seconds: 0.02)
      ..normalize(0.42);
  }

  /// Отбой: the two-tone klaxon when the last torpedo has run.
  Wave _gameOver() {
    final klaxon = _blank(1.9)
      ..addOscillator(
        from: 392,
        to: 294,
        amplitude: 0.9,
        waveform: Waveform.square,
        start: 0.0,
        end: 0.62,
      )
      ..addOscillator(
        from: 294,
        to: 186,
        amplitude: 0.9,
        amplitudeEnd: 0.0,
        waveform: Waveform.square,
        start: 0.66,
        end: 1.70,
        amplitudeCurve: Curve.easeIn,
      )
      ..lowPass(1500)
      ..tremolo(rate: 7, depth: 0.25);

    final wash = _blank(1.9)
      ..addNoise(random: _rng(97), amplitude: 1, amplitudeEnd: 0)
      ..lowPass(600)
      ..percussive(attack: 0.02, release: 0.5);

    return _blank(1.9)
      ..mixIn(klaxon, gain: 0.55)
      ..mixIn(wash, gain: 0.30)
      ..fadeEdges(seconds: 0.03)
      ..normalize(0.62);
  }

  // ------------------------------------------------------------------- loops

  /// The training motor. Played back faster and louder the harder the optics
  /// are swinging, which is what makes the inertia audible.
  Wave _motor() {
    const loop = 0.9;
    const crossfade = 0.1;
    final base = fitToLoop(28.5, loop);
    final wobble = fitToLoop(9, loop);

    final motor = _blank(loop + crossfade, rateFor('motor'))
      ..addOscillator(from: base * 2, amplitude: 0.50, waveform: Waveform.saw)
      ..addOscillator(from: base * 4, amplitude: 0.20, waveform: Waveform.saw)
      ..addOscillator(from: base, amplitude: 0.30)
      ..addNoise(random: _rng(101), amplitude: 0.10)
      ..lowPass(820)
      ..tremolo(rate: wobble, depth: 0.22)
      ..normalize(0.80)
      ..makeSeamless(crossfade: crossfade);
    return motor.trimmed(loop);
  }

  /// Propellers and bubbles of a torpedo on its way out.
  Wave _torpedo() {
    const loop = 0.9;
    const crossfade = 0.1;
    final blade = fitToLoop(194, loop);

    final run = _blank(loop + crossfade, rateFor('torpedo'))
      ..addOscillator(from: blade, amplitude: 0.30, waveform: Waveform.saw)
      ..addOscillator(from: blade * 2, amplitude: 0.12)
      ..addNoise(random: _rng(103), amplitude: 0.55)
      ..lowPass(2800)
      ..highPass(420)
      ..tremolo(rate: fitToLoop(24, loop), depth: 0.35)
      ..normalize(0.74)
      ..makeSeamless(crossfade: crossfade);
    return run.trimmed(loop);
  }

  /// Sea against the hull, and the boat's own hum under it.
  Wave _sea() {
    const loop = 4.0;
    const crossfade = 0.4;
    final hull = fitToLoop(41, loop);

    final sea = _blank(loop + crossfade, rateFor('sea'))
      ..addNoise(random: _rng(107), amplitude: 1)
      ..lowPass(300)
      ..lowPass(220) // second pass for a steeper, browner roll-off
      ..normalize(0.85)
      ..tremolo(rate: fitToLoop(0.21, loop), depth: 0.45)
      ..tremolo(rate: fitToLoop(0.5, loop), depth: 0.25, phase: 0.3);

    final hum = _blank(loop + crossfade, rateFor('sea'))
      ..addOscillator(from: hull, amplitude: 0.5)
      ..addOscillator(from: hull * 2, amplitude: 0.16)
      ..addOscillator(from: hull * 3, amplitude: 0.06);

    final mixed = _blank(loop + crossfade, rateFor('sea'))
      ..mixIn(sea, gain: 0.75)
      ..mixIn(hum, gain: 0.35)
      ..normalize(0.58)
      ..makeSeamless(crossfade: crossfade);
    return mixed.trimmed(loop);
  }
}
