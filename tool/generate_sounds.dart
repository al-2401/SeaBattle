// Regenerates every sound in assets/audio from the recipes in
// lib/audio/sound_bank.dart:
//
//     dart run tool/generate_sounds.dart
//
// Nothing is recorded or downloaded — the whole soundtrack is synthesised, so
// tweaking a noise means editing a number in the bank and running this again.
import 'dart:io';

import 'package:sea_battle/audio/sound_bank.dart';

void main(List<String> args) {
  const bank = SoundBank();
  final outputRoot = Directory('assets');
  var total = 0;

  for (final entry in bank.buildAll().entries) {
    final file = File('${outputRoot.path}/${entry.key}');
    file.parent.createSync(recursive: true);
    final bytes = entry.value.toWav();
    file.writeAsBytesSync(bytes);
    total += bytes.length;
    stdout.writeln(
      '${entry.key.padRight(22)} '
      '${entry.value.duration.toStringAsFixed(2)}s  '
      '${(bytes.length / 1024).toStringAsFixed(0)} KB  '
      'peak ${entry.value.peak.toStringAsFixed(2)}',
    );
  }
  stdout.writeln('— ${(total / 1024).toStringAsFixed(0)} KB total');
}
