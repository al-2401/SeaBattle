import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'audio/game_audio.dart';
import 'ui/game_page.dart';
import 'ui/palette.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  // A phone is held on its side, like the cabinet's eyepiece: wheel under
  // one thumb, torpedo button under the other. Either way round will do.
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  // No status or navigation bar over the optic; a swipe from the edge
  // brings them back for a moment.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const SeaBattleApp());
}

class SeaBattleApp extends StatelessWidget {
  const SeaBattleApp({super.key, this.audio});

  /// Sound engine to use. Left null, the cabinet wires up its own; tests pass
  /// a [SilentAudio] so they never reach for an audio device.
  final GameAudio? audio;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Морской бой',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Palette.bezel,
        colorScheme: const ColorScheme.dark(
          primary: Palette.reticle,
          secondary: Palette.lamp,
          surface: Palette.bezel,
        ),
      ),
      home: Scaffold(body: GamePage(audio: audio)),
    );
  }
}
