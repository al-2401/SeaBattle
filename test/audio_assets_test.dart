import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sea_battle/audio/sound_bank.dart';
import 'package:sea_battle/engine/sound_cue.dart';

/// Guards the generated soundtrack.
///
/// The WAVs in `assets/audio` are built by `tool/generate_sounds.dart` from
/// the recipes in the sound bank. These tests fail if a sound is missing, is
/// not a playable file, or has drifted away from its recipe — which is what
/// happens when someone edits the bank and forgets to run the generator.
void main() {
  const bank = SoundBank();

  final assets = <String>[
    for (final cue in SoundCue.values) cue.asset,
    for (final loop in SoundLoop.values) loop.asset,
  ];

  ({int sampleRate, int frames}) readHeader(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    String tag(int at) => String.fromCharCodes(bytes.sublist(at, at + 4));
    expect(tag(0), 'RIFF');
    expect(tag(8), 'WAVE');
    return (
      sampleRate: data.getUint32(24, Endian.little),
      frames: data.getUint32(40, Endian.little) ~/ 2,
    );
  }

  test('every cue and loop has a generated file', () {
    for (final asset in assets) {
      final file = File('assets/$asset');
      expect(
        file.existsSync(),
        isTrue,
        reason: 'assets/$asset is missing — run '
            'dart run tool/generate_sounds.dart',
      );
      expect(file.lengthSync(), greaterThan(1000), reason: '$asset is empty');
    }
  });

  test('the files still match the recipes that made them', () {
    for (final asset in assets) {
      final name = asset.split('/').last.replaceAll('.wav', '');
      final expected = bank.build(name);
      final header = readHeader(File('assets/$asset').readAsBytesSync());

      expect(
        header.sampleRate,
        expected.sampleRate,
        reason: '$asset was generated at a different rate — regenerate it',
      );
      expect(
        header.frames,
        expected.length,
        reason: '$asset is a different length to its recipe — regenerate it',
      );
    }
  });

  test('the whole soundtrack stays small enough to ship', () {
    final total = assets
        .map((asset) => File('assets/$asset').lengthSync())
        .reduce((a, b) => a + b);
    expect(total, lessThan(1024 * 1024), reason: 'soundtrack over 1 MB');
  });

  test('the asset folder holds nothing but the generated sounds', () {
    // `entry.path` uses the platform separator (backslashes on Windows), so
    // the name comes from the URI, which is the same everywhere.
    final strays = Directory('assets/audio')
        .listSync()
        .map((entry) => entry.uri.pathSegments.last)
        .where((name) => name.isNotEmpty && !assets.contains('audio/$name'))
        .toList();
    expect(strays, isEmpty, reason: 'unexpected files in assets/audio');
  });

  test('pubspec ships the audio folder', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('assets/audio/'));
  });
}
