import 'package:cloud_functions/cloud_functions.dart';

//===================================================
// TRANSLATE WHAT PEOPLE WRITE
//
// Used by the blue "Translate" button on posts. The
// translateText Cloud Function (functions/translate.js)
// does the work; results are remembered for this session.
//===================================================

class TranslationService {
  TranslationService._();

  static final TranslationService instance = TranslationService._();

  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'europe-west1',
  );

  final Map<String, String> _cache = <String, String>{};

  /// [text] in [language] ('en', 'ar', 'fr', 'ha', 'yo', 'hi').
  Future<String> translate(String text, String language) async {
    final String key = '$language\n$text';
    final String? cached = _cache[key];
    if (cached != null) return cached;

    final HttpsCallableResult<dynamic> result = await _functions
        .httpsCallable('translateText')
        .call(<String, dynamic>{'text': text, 'target': language});

    final Object? data = result.data;
    final String translation = data is Map
        ? (data['translation'] ?? '').toString().trim()
        : '';

    if (translation.isEmpty) {
      throw Exception('Translation failed.');
    }

    _cache[key] = translation;
    return translation;
  }
}
