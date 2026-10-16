import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nubify/widgets/profile_vertical_feed.dart';
import 'package:nubify/widgets/universal_link_text.dart';

void main() {
  testWidgets(
    'opens on the tapped item and can scroll to items on both sides',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ProfileVerticalFeed<String>(
            title: 'Posts',
            items: const <String>['Previous post', 'Tapped post', 'Next post'],
            initialIndex: 1,
            itemBuilder: (BuildContext context, String item, int index) {
              return SizedBox(height: 400, child: Center(child: Text(item)));
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Tapped post'), findsOneWidget);

      final ScrollableState scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable),
      );

      expect(scrollable.position.pixels, 0);
      expect(scrollable.position.minScrollExtent, lessThan(0));
      expect(scrollable.position.maxScrollExtent, greaterThan(0));

      scrollable.position.jumpTo(scrollable.position.minScrollExtent);
      await tester.pump();

      expect(find.text('Previous post'), findsOneWidget);

      scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
      await tester.pump();

      expect(find.text('Next post'), findsOneWidget);
    },
  );

  testWidgets('closing quote decoration follows the quote text', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: UniversalLinkText(
              text: 'Short quote',
              showPreview: false,
              leadingSpan: WidgetSpan(
                child: Icon(
                  Icons.format_quote_rounded,
                  key: ValueKey<String>('opening-quote'),
                ),
              ),
              trailingSpan: WidgetSpan(
                child: Icon(
                  Icons.format_quote_rounded,
                  key: ValueKey<String>('closing-quote'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    final Rect closingQuote = tester.getRect(
      find.byKey(const ValueKey<String>('closing-quote')),
    );

    expect(closingQuote.left, lessThan(200));
  });
}
