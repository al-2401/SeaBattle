import 'dart:math' as math;
import 'dart:typed_data';

/// A mono buffer of floating-point samples, and the small toolbox needed to
/// build arcade noises out of nothing.
///
/// Everything the game plays is generated from these primitives rather than
/// recorded, which keeps the repository free of binary sound assets nobody can
/// edit — and gives exactly the electronic timbre the cabinet had.
class Wave {
  Wave(this.sampleRate, int length) : samples = Float64List(length);

  Wave.seconds(this.sampleRate, double seconds)
    : samples = Float64List((seconds * sampleRate).round());

  final int sampleRate;
  final Float64List samples;

  int get length => samples.length;
  double get duration => samples.length / sampleRate;

  double timeAt(int index) => index / sampleRate;

  /// Adds an oscillator whose frequency and amplitude glide from start to end.
  ///
  /// The phase is accumulated sample by sample, so a sweep really does pass
  /// through every frequency between the two ends.
  void addOscillator({
    required double from,
    double? to,
    double amplitude = 1,
    double? amplitudeEnd,
    Waveform waveform = Waveform.sine,
    double start = 0,
    double? end,
    Curve frequencyCurve = Curve.linear,
    Curve amplitudeCurve = Curve.linear,
    double phaseOffset = 0,
  }) {
    final first = (start * sampleRate).round().clamp(0, length);
    final last = ((end ?? duration) * sampleRate).round().clamp(0, length);
    if (last <= first) return;

    var phase = phaseOffset;
    for (var i = first; i < last; i++) {
      final t = (i - first) / (last - first);
      final frequency = _lerp(from, to ?? from, frequencyCurve.apply(t));
      final level = _lerp(
        amplitude,
        amplitudeEnd ?? amplitude,
        amplitudeCurve.apply(t),
      );
      samples[i] += waveform.sample(phase) * level;
      phase += frequency / sampleRate;
      if (phase > 1) phase -= phase.floorToDouble();
    }
  }

  /// Adds white noise, optionally fading between two levels.
  void addNoise({
    required math.Random random,
    double amplitude = 1,
    double? amplitudeEnd,
    double start = 0,
    double? end,
    Curve amplitudeCurve = Curve.linear,
  }) {
    final first = (start * sampleRate).round().clamp(0, length);
    final last = ((end ?? duration) * sampleRate).round().clamp(0, length);
    for (var i = first; i < last; i++) {
      final t = last == first ? 0.0 : (i - first) / (last - first);
      final level = _lerp(
        amplitude,
        amplitudeEnd ?? amplitude,
        amplitudeCurve.apply(t),
      );
      samples[i] += (random.nextDouble() * 2 - 1) * level;
    }
  }

  /// Multiplies the whole buffer by a shaping function of time.
  void shape(double Function(double t) envelope) {
    for (var i = 0; i < length; i++) {
      samples[i] *= envelope(timeAt(i));
    }
  }

  /// A percussive envelope: a fast rise, then an exponential tail.
  void percussive({double attack = 0.004, required double release}) {
    shape((t) {
      final rise = attack <= 0 ? 1.0 : math.min(1.0, t / attack);
      return rise * math.exp(-t / release);
    });
  }

  /// One-pole low pass. [cutoff] may glide, which is what turns a noise burst
  /// into the dull thud of an explosion rolling away over the water.
  void lowPass(double cutoff, {double? cutoffEnd}) {
    var previous = 0.0;
    for (var i = 0; i < length; i++) {
      final t = length <= 1 ? 0.0 : i / (length - 1);
      final frequency = _lerp(cutoff, cutoffEnd ?? cutoff, t);
      final alpha = 1 - math.exp(-2 * math.pi * frequency / sampleRate);
      previous += alpha * (samples[i] - previous);
      samples[i] = previous;
    }
  }

  void highPass(double cutoff) {
    var previous = 0.0;
    final alpha = 1 - math.exp(-2 * math.pi * cutoff / sampleRate);
    for (var i = 0; i < length; i++) {
      previous += alpha * (samples[i] - previous);
      samples[i] -= previous;
    }
  }

  /// Amplitude modulation — the wobble of a motor or the breathing of swell.
  void tremolo({required double rate, double depth = 0.3, double phase = 0}) {
    for (var i = 0; i < length; i++) {
      final lfo = math.sin(2 * math.pi * (rate * timeAt(i) + phase));
      samples[i] *= 1 - depth + depth * (0.5 + 0.5 * lfo);
    }
  }

  /// Mixes [other] into this buffer, optionally starting part way through.
  void mixIn(Wave other, {double gain = 1, double at = 0}) {
    assert(other.sampleRate == sampleRate, 'sample rates must match');
    final offset = (at * sampleRate).round();
    for (var i = 0; i < other.length; i++) {
      final target = offset + i;
      if (target < 0 || target >= length) continue;
      samples[target] += other.samples[i] * gain;
    }
  }

  void gain(double factor) {
    for (var i = 0; i < length; i++) {
      samples[i] *= factor;
    }
  }

  double get peak {
    var maximum = 0.0;
    for (final sample in samples) {
      final magnitude = sample.abs();
      if (magnitude > maximum) maximum = magnitude;
    }
    return maximum;
  }

  double get rms {
    if (length == 0) return 0;
    var total = 0.0;
    for (final sample in samples) {
      total += sample * sample;
    }
    return math.sqrt(total / length);
  }

  void normalize([double target = 0.89]) {
    final current = peak;
    if (current < 1e-9) return;
    gain(target / current);
  }

  /// Fades the very ends to zero so a one-shot cannot click on start or stop.
  void fadeEdges({double seconds = 0.006}) {
    final ramp = (seconds * sampleRate).round();
    if (ramp <= 0) return;
    for (var i = 0; i < math.min(ramp, length); i++) {
      final factor = i / ramp;
      samples[i] *= factor;
      samples[length - 1 - i] *= factor;
    }
  }

  /// Wraps the tail of the buffer back over its head so the sound can be
  /// looped without a seam — used for the training motor and the sea.
  void makeSeamless({double crossfade = 0.08}) {
    final span = (crossfade * sampleRate).round();
    if (span <= 1 || span * 2 >= length) return;
    final tail = Float64List(span);
    for (var i = 0; i < span; i++) {
      tail[i] = samples[length - span + i];
    }
    for (var i = 0; i < span; i++) {
      final t = i / span;
      samples[i] = samples[i] * t + tail[i] * (1 - t);
    }
    // Drop the tail that has now been folded into the head.
    for (var i = length - span; i < length; i++) {
      samples[i] = 0;
    }
  }

  /// Trims trailing samples, for buffers shortened by [makeSeamless].
  Wave trimmed(double seconds) {
    final keep = (seconds * sampleRate).round().clamp(0, length);
    final result = Wave(sampleRate, keep);
    result.samples.setRange(0, keep, samples);
    return result;
  }

  /// Encodes as a 16-bit mono PCM WAV file.
  Uint8List toWav() {
    final dataBytes = length * 2;
    final bytes = ByteData(44 + dataBytes);
    void writeTag(int offset, String tag) {
      for (var i = 0; i < tag.length; i++) {
        bytes.setUint8(offset + i, tag.codeUnitAt(i));
      }
    }

    writeTag(0, 'RIFF');
    bytes.setUint32(4, 36 + dataBytes, Endian.little);
    writeTag(8, 'WAVE');
    writeTag(12, 'fmt ');
    bytes.setUint32(16, 16, Endian.little); // PCM header size
    bytes.setUint16(20, 1, Endian.little); // uncompressed
    bytes.setUint16(22, 1, Endian.little); // mono
    bytes.setUint32(24, sampleRate, Endian.little);
    bytes.setUint32(28, sampleRate * 2, Endian.little); // byte rate
    bytes.setUint16(32, 2, Endian.little); // block align
    bytes.setUint16(34, 16, Endian.little); // bits per sample
    writeTag(36, 'data');
    bytes.setUint32(40, dataBytes, Endian.little);

    for (var i = 0; i < length; i++) {
      final clamped = samples[i].clamp(-1.0, 1.0);
      bytes.setInt16(44 + i * 2, (clamped * 32767).round(), Endian.little);
    }
    return bytes.buffer.asUint8List();
  }
}

enum Waveform {
  sine,
  saw,
  square,
  triangle;

  /// [phase] runs 0..1 over one cycle.
  double sample(double phase) {
    final p = phase - phase.floorToDouble();
    return switch (this) {
      Waveform.sine => math.sin(2 * math.pi * p),
      Waveform.saw => 2 * p - 1,
      Waveform.square => p < 0.5 ? 1.0 : -1.0,
      Waveform.triangle => p < 0.5 ? 4 * p - 1 : 3 - 4 * p,
    };
  }
}

/// Shapes how a swept parameter travels between its two ends.
enum Curve {
  linear,
  easeOut,
  easeIn;

  double apply(double t) => switch (this) {
    Curve.linear => t,
    Curve.easeOut => 1 - math.pow(1 - t, 2.4).toDouble(),
    Curve.easeIn => math.pow(t, 2.4).toDouble(),
  };
}

double _lerp(double a, double b, double t) => a + (b - a) * t;
