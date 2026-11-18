import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nubify/screens/honorary_recognition_screen.dart';

void main() {
  Future<void> pumpScreen(
    WidgetTester tester, {
    required double width,
    required Brightness brightness,
  }) async {
    tester.view.physicalSize = Size(width, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: brightness),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: const HonoraryRecognitionScreen(),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
  }

  for (final double width in [320.0, 411.0]) {
    for (final Brightness brightness in Brightness.values) {
      testWidgets('renders without overflow at $width px, ${brightness.name}',
          (tester) async {
        await pumpScreen(tester, width: width, brightness: brightness);

        expect(tester.takeException(), isNull);
        expect(find.text('Wall of Honour'), findsOneWidget);
      });
    }
  }

  testWidgets('lists everyone together without group headers or count',
      (tester) async {
    await pumpScreen(tester, width: 411, brightness: Brightness.dark);

    for (final String name in [
      'Umar Harun',
      "Mubarak Rabi'u",
      'Abdulsalam Modu',
      'Abdulrahman Buhari',
      'Yakub (Badoo)',
      'Hindatu Zakari',
    ]) {
      expect(find.text(name), findsOneWidget);
    }
    expect(find.text('Grand Patron of Nubify'), findsOneWidget);
    expect(find.text('Moderator'), findsNWidgets(3));
    expect(find.text('Member'), findsNWidgets(2));

    for (final String header in ['Patron', 'Moderators', 'Members']) {
      expect(find.text(header), findsNothing);
    }
    expect(find.textContaining('honourees'), findsNothing);
  });

  testWidgets('each faculty uses its sign-up icon', (tester) async {
    await pumpScreen(tester, width: 411, brightness: Brightness.light);

    expect(find.byIcon(Icons.accessibility_new_rounded), findsOneWidget);
    expect(find.byIcon(Icons.medical_services_rounded), findsNWidgets(3));
    expect(find.byIcon(Icons.computer_rounded), findsOneWidget);
    expect(find.byIcon(Icons.health_and_safety_rounded), findsOneWidget);
    expect(find.byIcon(Icons.school_outlined), findsNothing);
  });

  testWidgets('tapping a card no longer opens a thank-you sheet',
      (tester) async {
    await pumpScreen(tester, width: 411, brightness: Brightness.light);

    await tester.tap(find.text('Umar Harun'));
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(BottomSheet), findsNothing);
    expect(find.textContaining('Thank you'), findsNothing);
  });
}
