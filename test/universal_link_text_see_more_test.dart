import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nubify/widgets/links/universal_link_text.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(width: 320, child: child),
    ),
  );
}

void main() {
  final String longText = List<String>.filled(
    400,
    'Nubify students sharing a long story',
  ).join(' ');

  testWidgets('long text is cut off until See more is tapped', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(UniversalLinkText(text: longText, collapsedMaxLines: 5)),
    );

    expect(find.text('See more'), findsOneWidget);

    final double collapsedHeight = tester
        .getSize(find.byType(UniversalLinkText))
        .height;

    await tester.tap(find.text('See more'));
    await tester.pump();

    expect(find.text('See more'), findsNothing);
    expect(
      tester.getSize(find.byType(UniversalLinkText)).height,
      greaterThan(collapsedHeight),
    );
  });

  testWidgets('short text shows no See more button', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const UniversalLinkText(
          text: 'A short post',
          collapsedMaxLines: 5,
        ),
      ),
    );

    expect(find.text('See more'), findsNothing);
    expect(find.text('A short post'), findsOneWidget);
  });

  testWidgets('text is never cut off without collapsedMaxLines', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(UniversalLinkText(text: longText)));

    expect(find.text('See more'), findsNothing);
  });
}
