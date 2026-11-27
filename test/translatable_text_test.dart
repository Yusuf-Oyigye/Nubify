import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

  testWidgets('Hausa and Yoruba readers get Translate (into English)', (
    WidgetTester tester,
  ) async {
    await show(tester, 'ha', arabic);
    expect(find.text('Fassara'), findsOneWidget);

    await show(tester, 'yo', french);
    expect(find.text('Túmọ̀'), findsOneWidget);

    // Already English: nothing to do for them.
    await show(tester, 'ha', english);
    expect(find.text('Fassara'), findsNothing);
  });

  testWidgets('posts written in Hausa: no button (phone cannot read it)', (
    WidgetTester tester,
  ) async {
    await show(tester, 'en', hausa);
    expect(find.text('Translate'), findsNothing);
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

  test('Hausa and Yoruba readers translate into English', () {
    expect(TranslationService.targetFor('ha'), 'en');
    expect(TranslationService.targetFor('yo'), 'en');
    expect(TranslationService.targetFor('ar'), 'ar');
    expect(TranslationService.targetFor('fr'), 'fr');
  });
}
