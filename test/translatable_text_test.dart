import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nubify/l10n/nubify_text.dart';
import 'package:nubify/widgets/common/translatable_text.dart';

void main() {
  Future<void> show(WidgetTester tester, String language, String text) {
    return tester.pumpWidget(
      MaterialApp(
        locale: Locale(language),
        supportedLocales: NubifyText.supportedLocales,
        localizationsDelegates: NubifyText.delegates,
        home: Scaffold(
          body: TranslatableText(
            text: text,
            builder: (String shown) => Text(shown),
          ),
        ),
      ),
    );
  }

  const String arabic = 'مرحبا بكم في الجامعة اليوم';
  const String english = 'See you all in the library after the lecture';

  testWidgets('Arabic post, English reader: Translate shows', (
    WidgetTester tester,
  ) async {
    await show(tester, 'en', arabic);
    expect(find.text('Translate'), findsOneWidget);
  });

  testWidgets('English post, Arabic reader: ترجمة shows', (
    WidgetTester tester,
  ) async {
    await show(tester, 'ar', english);
    expect(find.text('ترجمة'), findsOneWidget);
  });

  testWidgets('post already in your language: no button', (
    WidgetTester tester,
  ) async {
    await show(tester, 'en', english);
    expect(find.text('Translate'), findsNothing);
    expect(find.text(english), findsOneWidget);
  });

  testWidgets('Hausa and Yoruba readers: no button', (
    WidgetTester tester,
  ) async {
    await show(tester, 'ha', english);
    expect(find.text('Fassara'), findsNothing);
    await show(tester, 'yo', arabic);
    expect(find.text('Túmọ̀'), findsNothing);
  });
}
