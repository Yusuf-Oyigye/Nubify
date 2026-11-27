//===================================================
// WHICH LANGUAGE IS THIS TEXT IN?
//
// A quick guess on the phone, used to show "Translate"
// only on posts that are not already in the reader's
// language (like X). It looks at the alphabet first
// (Arabic, Hindi), then at special letters and common
// little words for English, French, Hausa and Yoruba.
//===================================================

abstract final class LanguageGuess {
  static final RegExp _arabic = RegExp(r'[؀-ۿݐ-ݿ]');
  static final RegExp _devanagari = RegExp(r'[ऀ-ॿ]');
  static final RegExp _latin = RegExp(r'[A-Za-zÀ-ɏḀ-ỿ]');

  // Letters only Yoruba or Hausa use.
  static final RegExp _yorubaLetters = RegExp(r'[ẹọṣẸỌṢ]|̣');
  static final RegExp _hausaLetters = RegExp(r'[ɓɗƙƴƁƊƘƳ]');

  static final RegExp _word = RegExp(r"[\p{L}']+", unicode: true);

  static const Map<String, Set<String>> _commonWords = <String, Set<String>>{
    'en': <String>{
      'the',
      'and',
      'is',
      'are',
      'to',
      'of',
      'you',
      'i',
      'in',
      'for',
      'it',
      'on',
      'my',
      'this',
      'that',
      'with',
      'be',
      'have',
      'not',
      'what',
      'we',
      'was',
      'your',
      'will',
      'just',
      'so',
      'but',
      'me',
    },
    'fr': <String>{
      'le',
      'la',
      'les',
      'et',
      'est',
      'je',
      'tu',
      'de',
      'des',
      'un',
      'une',
      'pas',
      'pour',
      'que',
      'qui',
      'dans',
      'avec',
      'mon',
      'ma',
      'nous',
      'vous',
      'sur',
      'au',
      'du',
      "c'est",
      'très',
      'mais',
    },
    'ha': <String>{
      'da',
      'na',
      'ta',
      'ba',
      'ne',
      'ce',
      'ya',
      'su',
      'ka',
      'ni',
      'mu',
      'kuma',
      'amma',
      'wannan',
      'shi',
      'ita',
      'yau',
      'mai',
      'don',
      'sai',
      'ina',
      'kai',
      'zan',
      'muna',
    },
    'yo': <String>{
      'ni',
      'ti',
      'ati',
      'àti',
      'mo',
      'wa',
      'kò',
      'ko',
      'sí',
      'si',
      'fún',
      'fun',
      'pé',
      'pe',
      'rẹ',
      're',
      'yìí',
      'yii',
      'àwọn',
      'awon',
      'ṣe',
      'se',
      'náà',
      'naa',
    },
  };

  /// The likely language ('en', 'ar', 'fr', 'ha', 'yo',
  /// 'hi'), or null when unsure.
  static String? of(String text) {
    final int arabic = _arabic.allMatches(text).length;
    final int devanagari = _devanagari.allMatches(text).length;
    final int latin = _latin.allMatches(text).length;

    if (arabic > latin && arabic >= devanagari && arabic > 0) return 'ar';
    if (devanagari > latin && devanagari > 0) return 'hi';
    if (latin == 0) return null;

    if (_yorubaLetters.hasMatch(text)) return 'yo';
    if (_hausaLetters.hasMatch(text)) return 'ha';

    final List<String> words = _word
        .allMatches(text.toLowerCase())
        .map((Match m) => m.group(0)!)
        .toList();

    String? best;
    int bestHits = 0;
    _commonWords.forEach((String code, Set<String> common) {
      final int hits = words.where(common.contains).length;
      if (hits > bestHits) {
        best = code;
        bestHits = hits;
      }
    });

    return bestHits >= 2 ? best : null;
  }

  /// True when [text] is worth offering to translate into
  /// [language]: another language, or a post we cannot
  /// place (see below).
  static bool shouldOffer(String text, String language) {
    final String clean = text.trim();
    if (clean.isEmpty) return false;

    final String? guess = of(clean);
    if (guess == language) return false;
    if (guess != null) return true;

    // Unsure: short Latin-letter posts ("Hello guys") are
    // most often English, so every reader except English
    // ones gets the link. English readers only get it on
    // longer posts. No letters (emoji, numbers): no link.
    if (_latin.allMatches(clean).length < 2) return false;
    if (language != 'en') return true;

    return _word.allMatches(clean).length >= 3;
  }
}
