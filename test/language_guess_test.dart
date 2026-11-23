import 'package:flutter_test/flutter_test.dart';
import 'package:nubify/l10n/nubify_text.dart';
import 'package:nubify/utils/common/language_guess.dart';

void main() {
  group('LanguageGuess.of', () {
    test('reads the alphabet', () {
      expect(LanguageGuess.of('مرحبا بكم في الجامعة'), 'ar');
      expect(LanguageGuess.of('आज कक्षा कब है?'), 'hi');
    });

    test('reads common words', () {
      expect(LanguageGuess.of('What is the time for the lecture?'), 'en');
      expect(
        LanguageGuess.of('Je suis dans la bibliothèque avec mon ami'),
        'fr',
      );
    });

    test('reads special letters', () {
      expect(LanguageGuess.of('Ẹ káàbọ̀ sí ilé ẹ̀kọ́'), 'yo');
      expect(LanguageGuess.of('Ina ƙaunar wannan jami’a'), 'ha');
    });

    test('says unsure for very little text', () {
      expect(LanguageGuess.of('😂🔥'), isNull);
      expect(LanguageGuess.of('ok'), isNull);
    });
  });

  group('LanguageGuess.shouldOffer', () {
    test('hides Translate on posts already in your language', () {
      expect(
        LanguageGuess.shouldOffer('See you in the library', 'en'),
        isFalse,
      );
      expect(LanguageGuess.shouldOffer('مرحبا بكم في الجامعة', 'ar'), isFalse);
    });

    test('shows Translate on posts in another language', () {
      expect(LanguageGuess.shouldOffer('مرحبا بكم في الجامعة', 'en'), isTrue);
      expect(LanguageGuess.shouldOffer('See you in the library', 'ar'), isTrue);
    });

    test('does not offer for emoji or empty posts', () {
      expect(LanguageGuess.shouldOffer('', 'en'), isFalse);
      expect(LanguageGuess.shouldOffer('🔥🔥', 'ar'), isFalse);
    });
  });

  test('app words translate and fall back to English', () {
    expect(NubifyText.tr('Translate', const <String, Object>{}, 'ar'), 'ترجمة');
    expect(NubifyText.tr('Translate', const <String, Object>{}, 'yo'), 'Túmọ̀');
    expect(
      NubifyText.tr('Not translated yet', const <String, Object>{}, 'fr'),
      'Not translated yet',
    );
  });
}
