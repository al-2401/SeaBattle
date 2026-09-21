import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sea_battle/main.dart';

void main() {
  testWidgets('the cabinet starts on its attract screen', (tester) async {
    await tester.pumpWidget(const SeaBattleApp());
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.text('ПОГРУЖЕНИЕ'), findsOneWidget);
    expect(find.text('ТОРПЕДЫ  12'), findsOneWidget);
  });

  testWidgets('pressing the start button clears the overlay', (tester) async {
    await tester.pumpWidget(const SeaBattleApp());
    await tester.pump(const Duration(milliseconds: 16));

    await tester.tap(find.text('ПОГРУЖЕНИЕ'));
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.text('ПОГРУЖЕНИЕ'), findsNothing);
  });

  testWidgets('the torpedo button spends a torpedo', (tester) async {
    await tester.pumpWidget(const SeaBattleApp());
    await tester.pump(const Duration(milliseconds: 16));
    await tester.tap(find.text('ПОГРУЖЕНИЕ'));
    await tester.pump(const Duration(milliseconds: 16));

    await tester.tap(find.text('ТОРПЕДА'));
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.text('ТОРПЕДЫ  11'), findsOneWidget);
  });

  testWidgets('the picture keeps running frame after frame', (tester) async {
    await tester.pumpWidget(const SeaBattleApp());
    for (var i = 0; i < 90; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('it lays out on a phone-sized screen', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const SeaBattleApp());
    await tester.pump(const Duration(milliseconds: 16));

    expect(tester.takeException(), isNull);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
