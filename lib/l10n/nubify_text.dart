import 'package:flutter/cupertino.dart' show CupertinoLocalizations;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../services/common/language_preference.dart';
import 'translations/chat.dart';
import 'translations/common.dart';
import 'translations/egyptian_arabic.dart';
import 'translations/faculties.dart';
import 'translations/feed.dart';
import 'translations/huddles.dart';
import 'translations/marketplace.dart';
import 'translations/menu.dart';
import 'translations/notifications.dart';
import 'translations/nubi.dart';
import 'translations/nubuzz.dart';
import 'translations/profile.dart';
import 'translations/stories.dart';

//===================================================
// THE APP'S WORDS IN EVERY LANGUAGE
//
// Write app text in English and wrap it:
//   Text(context.tr('Settings'))
//   context.tr('{n} likes', {'n': count})
// It shows in the language chosen on login, signup or
// Menu, and switches live. Each feature keeps its own
// translations in lib/l10n/translations/<feature>.dart,
// keyed by the English text. Anything not translated
// yet stays in English.
//
// Only the app's own words are translated. What people
// write (posts, comments, messages) stays as written
// until they tap "Translate".
//===================================================

abstract final class NubifyText {
  static final Map<String, Map<String, String>> _all =
      _merge(<Map<String, Map<String, String>>>[
        commonTranslations,
        menuTranslations,
        feedTranslations,
        chatTranslations,
        storiesTranslations,
        nubuzzTranslations,
        marketplaceTranslations,
        nubiTranslations,
        huddlesTranslations,
        profileTranslations,
        notificationsTranslations,
        facultiesTranslations,
        egyptianArabicTranslations,
      ]);

  static Map<String, Map<String, String>> _merge(
    List<Map<String, Map<String, String>>> parts,
  ) {
    final Map<String, Map<String, String>> merged =
        <String, Map<String, String>>{};
    for (final Map<String, Map<String, String>> part in parts) {
      part.forEach((String code, Map<String, String> words) {
        merged.putIfAbsent(code, () => <String, String>{}).addAll(words);
      });
    }
    return merged;
  }

  /// [english] in [code] (the app language when null),
  /// with {name} placeholders filled from [values].
  static String tr(
    String english, [
    Map<String, Object> values = const <String, Object>{},
    String? code,
  ]) {
    String text = _all[code ?? AppLanguage.code.value]?[english] ?? english;
    values.forEach((String key, Object value) {
      text = text.replaceAll('{$key}', '$value');
    });
    return text;
  }

  //=================================================
  // APP LOCALE (main.dart)
  //=================================================

  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ar'),
    Locale('ha'),
    Locale('yo'),
    Locale('hi'),
    Locale('fr'),
  ];

  // Flutter's own words (copy, paste, date pickers) exist
  // for English, Arabic, French and Hindi; Hausa and
  // Yoruba use English for those few.
  static const List<LocalizationsDelegate<dynamic>> delegates =
      <LocalizationsDelegate<dynamic>>[
        _OrEnglish<MaterialLocalizations>(GlobalMaterialLocalizations.delegate),
        _OrEnglish<WidgetsLocalizations>(GlobalWidgetsLocalizations.delegate),
        _OrEnglish<CupertinoLocalizations>(
          GlobalCupertinoLocalizations.delegate,
        ),
      ];
}

extension NubifyTextContext on BuildContext {
  /// [english] in the app language. The widget rebuilds
  /// when the language changes.
  String tr(
    String english, [
    Map<String, Object> values = const <String, Object>{},
  ]) {
    final String code =
        Localizations.maybeLocaleOf(this)?.languageCode ??
        AppLanguage.code.value;
    return NubifyText.tr(english, values, code);
  }
}

class _OrEnglish<T> extends LocalizationsDelegate<T> {
  const _OrEnglish(this.inner);

  final LocalizationsDelegate<T> inner;

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<T> load(Locale locale) =>
      inner.load(inner.isSupported(locale) ? locale : const Locale('en'));

  @override
  bool shouldReload(_OrEnglish<T> old) => false;
}
