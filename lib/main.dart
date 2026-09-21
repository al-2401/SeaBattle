import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ui/game_page.dart';
import 'ui/palette.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  runApp(const SeaBattleApp());
}

class SeaBattleApp extends StatelessWidget {
  const SeaBattleApp({super.key});

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
      home: const Scaffold(body: GamePage()),
    );
  }
}
