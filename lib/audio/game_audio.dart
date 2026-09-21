import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../engine/sound_cue.dart';

/// How the game makes noise.
///
/// The game talks to this interface and never to the audio plugin, so tests
/// (and anyone who would rather play in silence) can drop in [SilentAudio].
abstract class GameAudio {
  /// Whether anything is audible. Flipping this is the mute button.
  bool get enabled;
  set enabled(bool value);

  Future<void> prepare();

  /// Tells the audio layer that the player has just touched something.
  ///
  /// Browsers refuse to start audio until then, so the loops wait for this.
  void unlock();

  /// Plays a one-off noise.
  void fire(SoundCue cue);

  /// Follows the continuous noises. Called once per frame.
  ///
  /// [trainEffort] is how hard the optics are swinging, 0..1; it drives both
  /// the level and the pitch of the training motor, which is what makes the
  /// heavy gear audible as well as visible.
  void updateLoops({
    required double trainEffort,
    required int torpedoesRunning,
    required bool patrolRunning,
  });

  Future<void> dispose();
}

/// Does nothing, quietly.
class SilentAudio implements GameAudio {
  @override
  bool enabled = false;

  @override
  Future<void> prepare() async {}

  @override
  void unlock() {}

  @override
  void fire(SoundCue cue) {}

  @override
  void updateLoops({
    required double trainEffort,
    required int torpedoesRunning,
    required bool patrolRunning,
  }) {}

  @override
  Future<void> dispose() async {}
}

/// Plays the synthesised sound bank through `audioplayers`.
///
/// Every call is fire-and-forget and swallows its errors: a machine with no
/// working audio device, or a browser that has not seen a click yet, must
/// cost the player nothing worse than silence.
class ArcadeAudio implements GameAudio {
  ArcadeAudio({this.voices = 5});

  /// How many one-off noises can overlap.
  final int voices;

  static const Map<SoundCue, double> _cueLevels = {
    SoundCue.launch: 0.70,
    SoundCue.hit: 0.95,
    SoundCue.mine: 0.85,
    SoundCue.splash: 0.55,
    SoundCue.reload: 0.50,
    SoundCue.clunk: 0.60,
    SoundCue.horn: 0.45,
    SoundCue.gameOver: 0.70,
  };

  final List<AudioPlayer> _voices = [];
  final Map<SoundLoop, AudioPlayer> _loops = {};
  final Map<SoundLoop, double> _level = {for (final l in SoundLoop.values) l: 0};
  final Map<SoundLoop, double> _sentLevel = {
    for (final l in SoundLoop.values) l: -1,
  };
  double _motorRate = 1;
  double _sentMotorRate = -1;

  int _nextVoice = 0;
  bool _ready = false;
  bool _loopsRunning = false;
  bool _enabled = true;

  @override
  bool get enabled => _enabled;

  @override
  set enabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    if (!value) {
      for (final player in _loops.values) {
        _guard(player.setVolume(0));
      }
      for (final player in _voices) {
        _guard(player.stop());
      }
      for (final loop in SoundLoop.values) {
        _sentLevel[loop] = 0;
      }
    }
  }

  @override
  Future<void> prepare() async {
    try {
      for (var i = 0; i < voices; i++) {
        _voices.add(AudioPlayer()..setReleaseMode(ReleaseMode.stop));
      }
      for (final loop in SoundLoop.values) {
        final player = AudioPlayer();
        await player.setReleaseMode(ReleaseMode.loop);
        await player.setVolume(0);
        await player.setSource(AssetSource(loop.asset));
        _loops[loop] = player;
      }
      _ready = true;
    } catch (error) {
      debugPrint('sea_battle: audio unavailable ($error)');
      _ready = false;
    }
  }

  @override
  void unlock() => _startLoops();

  @override
  void fire(SoundCue cue) {
    if (!_ready || !_enabled || _voices.isEmpty) return;
    _startLoops();
    final player = _voices[_nextVoice];
    _nextVoice = (_nextVoice + 1) % _voices.length;
    _guard(player.play(AssetSource(cue.asset), volume: _cueLevels[cue] ?? 0.6));
  }

  @override
  void updateLoops({
    required double trainEffort,
    required int torpedoesRunning,
    required bool patrolRunning,
  }) {
    if (!_ready) return;

    final effort = trainEffort.clamp(0.0, 1.0);
    final targets = <SoundLoop, double>{
      SoundLoop.motor: _enabled ? 0.03 + 0.45 * effort : 0.0,
      SoundLoop.torpedo: _enabled && torpedoesRunning > 0
          ? math.min(0.55, 0.32 + 0.09 * torpedoesRunning)
          : 0.0,
      SoundLoop.sea: _enabled ? (patrolRunning ? 0.32 : 0.18) : 0.0,
    };

    for (final loop in SoundLoop.values) {
      final current = _level[loop]!;
      // Glide instead of jumping, or every change would click.
      final next = current + (targets[loop]! - current) * 0.12;
      _level[loop] = next;
      if ((next - _sentLevel[loop]!).abs() > 0.02) {
        _sentLevel[loop] = next;
        _guard(_loops[loop]?.setVolume(next));
      }
    }

    // The motor also winds up in pitch as the gear picks up speed.
    _motorRate += (0.78 + 0.5 * effort - _motorRate) * 0.12;
    if ((_motorRate - _sentMotorRate).abs() > 0.03) {
      _sentMotorRate = _motorRate;
      _guard(_loops[SoundLoop.motor]?.setPlaybackRate(_motorRate));
    }
  }

  void _startLoops() {
    if (_loopsRunning || !_enabled) return;
    _loopsRunning = true;
    for (final player in _loops.values) {
      _guard(player.resume());
    }
  }

  @override
  Future<void> dispose() async {
    _ready = false;
    for (final player in [..._voices, ..._loops.values]) {
      try {
        await player.dispose();
      } catch (_) {
        // Tearing down a player that never started is not worth a crash.
      }
    }
    _voices.clear();
    _loops.clear();
  }

  void _guard(Future<void>? work) {
    work?.catchError((Object error) {
      debugPrint('sea_battle: audio call failed ($error)');
    });
  }
}
