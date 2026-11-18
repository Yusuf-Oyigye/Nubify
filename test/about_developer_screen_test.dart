import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nubify/screens/about_developer_screen.dart';

void main() {
  Future<void> pumpScreen(
    WidgetTester tester, {
    required double width,
    required Brightness brightness,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: brightness),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: const AboutDeveloperScreen(),
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
        expect(find.text('Yusuf Oyigye'), findsOneWidget);
        expect(find.text('@Digitaldoc'), findsOneWidget);
        expect(find.text('Faculty of Medicine'), findsOneWidget);
        expect(
          find.text('Founder / Developer / Super-Admin of Nubify'),
          findsOneWidget,
        );

        await tester.scrollUntilVisible(
          find.text('Welcome to Nubify — Campus Social.'),
          300,
        );
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('uses the sign-up faculty icon and no copy button',
      (tester) async {
    await pumpScreen(tester, width: 411, brightness: Brightness.dark);

    expect(find.byIcon(Icons.medical_services_rounded), findsOneWidget);
    expect(find.byIcon(Icons.copy_rounded), findsNothing);
    expect(find.byIcon(Icons.format_quote_rounded), findsNothing);
    expect(find.text('What I built'), findsNothing);
  });

  testWidgets('hides the change-photo button for normal users',
      (tester) async {
    await pumpScreen(tester, width: 411, brightness: Brightness.light);

    expect(find.byIcon(Icons.photo_camera_rounded), findsNothing);
  });
}
