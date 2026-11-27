import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:nubify/l10n/nubify_text.dart';
import 'package:nubify/services/common/translation_service.dart';
import 'package:nubify/widgets/common/translatable_text.dart';

void main() {
  Future<void> showApp(WidgetTester tester, String language, Widget child) {
    return tester.pumpWidget(
      MaterialApp(
        locale: Locale(language),
        supportedLocales: NubifyText.supportedLocales,
        localizationsDelegates: NubifyText.delegates,
        home: Scaffold(body: child),
      ),
    );
  }

  Future<void> show(WidgetTester tester, String language, String text) {
    return showApp(
      tester,
      language,
      TranslatableText(text: text, builder: (String shown) => Text(shown)),
    );
  }

  const String arabic = 'مرحبا بكم في الجامعة اليوم';
  const String english = 'See you all in the library after the lecture';
  const String french = 'Je suis dans la bibliothèque avec mon ami';
  const String hausa = 'Ina ƙaunar wannan jami’a sosai';

  testWidgets('Arabic post, English reader: 文A Translate shows', (
    WidgetTester tester,
  ) async {
    await show(tester, 'en', arabic);
    expect(find.text('Translate'), findsOneWidget);
    expect(find.byIcon(Icons.translate_rounded), findsOneWidget);
  });

  testWidgets('English post, Arabic reader: ترجمة shows', (
    WidgetTester tester,
  ) async {
    await show(tester, 'ar', english);
    expect(find.text('ترجمة'), findsOneWidget);
  });

  testWidgets('English post, French reader: Traduire shows', (
    WidgetTester tester,
  ) async {
    await show(tester, 'fr', english);
    expect(find.text('Traduire'), findsOneWidget);
  });

  testWidgets('post already in your language: no button', (
    WidgetTester tester,
  ) async {
    await show(tester, 'en', english);
    expect(find.text('Translate'), findsNothing);
    expect(find.text(english), findsOneWidget);
  });

  testWidgets('Hausa and Yoruba readers: no button (phone cannot do it)', (
    WidgetTester tester,
  ) async {
    for (final String text in <String>[arabic, french, english]) {
      await show(tester, 'ha', text);
      expect(find.text('Fassara'), findsNothing);
      expect(find.byIcon(Icons.translate_rounded), findsNothing);
      expect(find.text(text), findsOneWidget);

      await show(tester, 'yo', text);
      expect(find.text('Túmọ̀'), findsNothing);
      expect(find.byIcon(Icons.translate_rounded), findsNothing);
    }

    // Marketplace style heading: the title stays, no button.
    await showApp(
      tester,
      'ha',
      TranslatableText(
        text: arabic,
        heading: const Text('Description'),
        builder: (String shown) => Text(shown),
      ),
    );
    expect(find.text('Description'), findsOneWidget);
    expect(find.byIcon(Icons.translate_rounded), findsNothing);
  });

  testWidgets('posts written in Hausa: no button (phone cannot read it)', (
    WidgetTester tester,
  ) async {
    await show(tester, 'en', hausa);
    expect(find.text('Translate'), findsNothing);
    await show(tester, 'ar', hausa);
    expect(find.text('ترجمة'), findsNothing);
  });

  testWidgets('heading: the button sits beside the title', (
    WidgetTester tester,
  ) async {
    await showApp(
      tester,
      'en',
      TranslatableText(
        text: arabic,
        heading: const Text('Description'),
        builder: (String shown) => Text(shown),
      ),
    );

    final Offset title = tester.getCenter(find.text('Description'));
    final Offset button = tester.getCenter(find.text('Translate'));
    expect((title.dy - button.dy).abs(), lessThan(12));
    expect(button.dx, greaterThan(title.dx));
    expect(find.text(arabic), findsOneWidget);
  });

  testWidgets('heading stays when no button is needed', (
    WidgetTester tester,
  ) async {
    await showApp(
      tester,
      'en',
      TranslatableText(
        text: english,
        heading: const Text('Description'),
        builder: (String shown) => Text(shown),
      ),
    );

    expect(find.text('Description'), findsOneWidget);
    expect(find.text(english), findsOneWidget);
    expect(find.text('Translate'), findsNothing);
  });

  testWidgets('header button follows its controller', (
    WidgetTester tester,
  ) async {
    final TranslationController controller = TranslationController()
      ..update(arabic);
    addTearDown(controller.dispose);

    await showApp(tester, 'en', TranslateButton(controller: controller));
    expect(find.text('Translate'), findsOneWidget);

    controller.update('');
    await showApp(tester, 'en', TranslateButton(controller: controller));
    expect(find.text('Translate'), findsNothing);
  });

  test('short posts ML Kit cannot place are read as English', () {
    expect(
      TranslationService.sourceWhenUnsure('und', 'ok'),
      TranslateLanguage.english,
    );
    expect(
      TranslationService.sourceWhenUnsure('und', 'Hello guys'),
      TranslateLanguage.english,
    );
    expect(
      TranslationService.sourceWhenUnsure('und', 'مرحبا بكم'),
      TranslateLanguage.arabic,
    );
    // One or two words: the app's own guess, no ML Kit.
    expect(
      TranslationService.shortTextSource('ddd'),
      TranslateLanguage.english,
    );
    expect(
      TranslationService.shortTextSource('Alhamdulillah'),
      TranslateLanguage.english,
    );
    expect(
      TranslationService.shortTextSource('مرحبا'),
      TranslateLanguage.arabic,
    );
    expect(TranslationService.shortTextSource('🔥🔥'), isNull);
    expect(
      TranslationService.shortTextSource('See you all in the library'),
      isNull,
    );
    // Arabic in English letters.
    expect(
      TranslationService.sourceWhenUnsure('ar-Latn', 'Alhamdulillah'),
      TranslateLanguage.english,
    );
    // Hausa or Yoruba, or nothing to read: still unknown.
    expect(TranslationService.sourceWhenUnsure('und', 'Ina ƙaunar ku'), isNull);
    expect(TranslationService.sourceWhenUnsure('und', '🔥 2026'), isNull);
    expect(TranslationService.sourceWhenUnsure('ha', 'Ina son ku'), isNull);
  });
}
