import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the one structural rule this project lives by.
///
/// The simulation and the synthesiser are plain Dart: no widgets, no
/// `dart:ui`, no plugins. That is what lets the rules and the sound be tested
/// directly, and it is easy to break by accident with one convenient import.
void main() {
  List<File> dartFilesIn(String directory) => Directory(directory)
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .toList();

  List<String> offendingImports(File file, List<String> forbidden) {
    return file
        .readAsLinesSync()
        .where((line) => line.startsWith('import ') || line.startsWith('export '))
        .where((line) => forbidden.any(line.contains))
        .toList();
  }

  test('lib/engine depends on nothing but plain Dart', () {
    const forbidden = ['package:flutter', 'dart:ui', 'package:audioplayers'];
    for (final file in dartFilesIn('lib/engine')) {
      expect(
        offendingImports(file, forbidden),
        isEmpty,
        reason: '${file.path} pulls in the framework — the engine must stay '
            'testable without a widget tree',
      );
    }
  });

  test('the synthesiser depends on nothing but plain Dart', () {
    const forbidden = ['package:flutter', 'dart:ui', 'package:audioplayers'];
    for (final name in const ['lib/audio/synth.dart', 'lib/audio/sound_bank.dart']) {
      expect(
        offendingImports(File(name), forbidden),
        isEmpty,
        reason: '$name must stay runnable from a plain Dart script, since '
            'tool/generate_sounds.dart runs it outside Flutter',
      );
    }
  });

  test('the engine never reaches into the presentation layer', () {
    for (final file in dartFilesIn('lib/engine')) {
      expect(
        offendingImports(file, const ['../ui/', '../audio/']),
        isEmpty,
        reason: '${file.path} depends on the layer above it',
      );
    }
  });
}
