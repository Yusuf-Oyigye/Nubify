import 'package:flutter/foundation.dart';
import 'package:google_mlkit_language_id/google_mlkit_language_id.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

import '../../utils/common/language_guess.dart';

//===================================================
// TRANSLATE WHAT PEOPLE WRITE (ON THE PHONE)
//
// Used by the blue "Translate" button on posts,
// comments, replies, marketplace descriptions and
// NUBuzz captions. Google ML Kit translates on the
// phone itself: free, no limit, and it works offline
// once a language is downloaded (about 30 MB, the
// first time only).
//
// ML Kit has English, Arabic, French and Hindi, but no
// Hausa or Yoruba: Hausa and Yoruba readers get
// "Translate to English" instead, and posts written in
// Hausa or Yoruba show no button.
//===================================================

class TranslationService {
  TranslationService._();

  static final TranslationService instance = TranslationService._();

  // App language -> ML Kit language.
  static const Map<String, TranslateLanguage> _languages =
  <String, TranslateLanguage>{
    'en': TranslateLanguage.english,
    'ar': TranslateLanguage.arabic,
    'fr': TranslateLanguage.french,
    'hi': TranslateLanguage.hindi,
  };

  /// True when the phone can translate into [language].
  static bool canTranslateInto(String language) =>
      _languages.containsKey(language);

  /// The language a reader using the app in [appLanguage]
  /// gets: their own, or English when the phone cannot
  /// translate into it (Hausa, Yoruba).
  static String targetFor(String appLanguage) =>
      canTranslateInto(appLanguage) ? appLanguage : 'en';

  /// False when the text is clearly in a language the
  /// phone cannot translate (Hausa, Yoruba). [guess] is
  /// LanguageGuess.of(text); null means "not sure".
  static bool canTranslateFrom(String? guess) =>
      guess == null || _languages.containsKey(guess);

  /// ML Kit guesses badly on one or two words ("ddd" came
  /// back as Welsh, and started a Welsh download). For
  /// those: Arabic or Hindi letters are Arabic or Hindi,
  /// Latin letters are English (or French when they say
  /// so). Null for longer text, or nothing to read.
  @visibleForTesting
  static TranslateLanguage? shortTextSource(String text) {
    if (LanguageGuess.wordCount(text) >= 3) return null;
    final String? guess = LanguageGuess.of(text);
    if (guess != null) return _languages[guess];
    return LanguageGuess.hasLetters(text) ? TranslateLanguage.english : null;
  }

  /// ML Kit says "und" (not sure) on very short text like
  /// "ok" or "Hello guys", and "ar-Latn" (Arabic in
  /// English letters) on words like "Alhamdulillah" that
  /// it has no translator for. Use the app's own guess
  /// then, and English for Latin-letter posts (the same
  /// rule that shows the button). A language ML Kit did
  /// recognise but cannot translate (Hausa, Yoruba) stays
  /// unknown.
  @visibleForTesting
  static TranslateLanguage? sourceWhenUnsure(String code, String text) {
    if (code != 'und' && !code.endsWith('-Latn')) return null;
    final String? guess = LanguageGuess.of(text);
    if (guess != null) return _languages[guess];
    return LanguageGuess.hasLetters(text) ? TranslateLanguage.english : null;
  }

  // ML Kit's guess for longer text.
  Future<TranslateLanguage> _identify(String text) async {
    final String code = await _identifier.identifyLanguage(text);
    final TranslateLanguage? source =
        BCP47Code.fromRawValue(code) ?? sourceWhenUnsure(code, text);
    if (source == null) {
      debugPrint('Translate: cannot read language "$code"');
      throw const TranslationException(TranslationProblem.unknownLanguage);
    }
    return source;
  }

  final LanguageIdentifier _identifier = LanguageIdentifier(
    confidenceThreshold: 0.5,
  );

  final OnDeviceTranslatorModelManager _models =
  OnDeviceTranslatorModelManager();

  final Map<String, OnDeviceTranslator> _translators =
  <String, OnDeviceTranslator>{};

  // Translations already made while the app is open.
  final Map<String, String> _cache = <String, String>{};

  /// [text] in [language] ('en', 'ar', 'fr' or 'hi').
  /// [onDownload] runs first when the phone still has to
  /// download a language (only the first time).
  Future<String> translate(
      String text,
      String language, {
        void Function()? onDownload,
      }) async {
    final TranslateLanguage? target = _languages[language];
    if (target == null) {
      throw const TranslationException(TranslationProblem.unsupported);
    }

    final String key = '$language\n$text';
    final String? cached = _cache[key];
    if (cached != null) return cached;

    // Which language did the person write in? One or two
    // words: the app's own guess. Longer: ML Kit.
    final TranslateLanguage source =
        shortTextSource(text) ?? await _identify(text);
    if (source == target) return text;

    // First time only: download both languages.
    final bool ready =
        await _models.isModelDownloaded(source.bcpCode) &&
            await _models.isModelDownloaded(target.bcpCode);
    if (!ready) {
      onDownload?.call();
      await _models.downloadModel(source.bcpCode, isWifiRequired: false);
      await _models.downloadModel(target.bcpCode, isWifiRequired: false);
    }

    final OnDeviceTranslator translator = _translators.putIfAbsent(
      '${source.bcpCode}>${target.bcpCode}',
          () => OnDeviceTranslator(sourceLanguage: source, targetLanguage: target),
    );

    final String translation = (await translator.translateText(text)).trim();
    if (translation.isEmpty) {
      throw const TranslationException(TranslationProblem.failed);
    }

    _cache[key] = translation;
    return translation;
  }
}

enum TranslationProblem { unsupported, unknownLanguage, failed }

class TranslationException implements Exception {
  const TranslationException(this.problem);

  final TranslationProblem problem;

  @override
  String toString() => 'TranslationException: ${problem.name}';
}