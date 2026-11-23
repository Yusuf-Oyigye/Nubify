import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

//===================================================
// LANGUAGE PREFERENCE
//
// The same setting as Menu → Language: saved on the
// phone and, when signed in, on the profile
// (users/{uid}.languagePreference).
//===================================================

class NubifyLanguage {
  const NubifyLanguage(this.code, this.label, this.arabicName, this.nativeName);

  final String code;

  // English name, e.g. French.
  final String label;

  // Arabic name, e.g. الفرنسية. Most NUB students read
  // Arabic, so it always shows next to the own name.
  final String arabicName;

  // The language's own name, e.g. Français.
  final String nativeName;

  /// The bold line in the language lists: own name, then
  /// Arabic, e.g. "Français · الفرنسية" ("العربية" alone).
  String get nativeAndArabic =>
      nativeName == arabicName ? nativeName : '$nativeName · $arabicName';

  /// The English name under the bold line, when the bold
  /// line does not already show it.
  String? get englishUnder => nativeName == label ? null : label;

  /// Own name with English in brackets, e.g.
  /// "Français (French)". Used on the Menu card.
  String get nativeWithEnglish =>
      nativeName == label ? label : '$nativeName ($label)';
}

abstract final class LanguagePreference {
  // Same key the Menu screen uses.
  static const String storageKey = 'nubify_language_preference_v1';

  static const List<NubifyLanguage> options = <NubifyLanguage>[
    NubifyLanguage('en', 'English', 'الإنجليزية', 'English'),
    NubifyLanguage('ar', 'Arabic', 'العربية', 'العربية'),
    NubifyLanguage('ha', 'Hausa', 'الهوسا', 'Hausa'),
    NubifyLanguage('yo', 'Yoruba', 'اليوروبا', 'Yorùbá'),
    NubifyLanguage('hi', 'Hindi', 'الهندية', 'हिन्दी'),
    NubifyLanguage('fr', 'French', 'الفرنسية', 'Français'),
  ];

  // Shared English + Arabic wording for the pickers.
  static const String title = 'Language · اللغة';
  static const String chooseLanguage = 'Choose language · اختر اللغة';
  static const String chooseTitle = 'Choose your language';
  static const String chooseTitleArabic = 'اختر لغتك';

  static NubifyLanguage byCode(String code) => options.firstWhere(
    (NubifyLanguage option) => option.code == code,
    orElse: () => options.first,
  );

  /// The language saved on this phone (English by default).
  static Future<String> load() async {
    try {
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      final String code = preferences.getString(storageKey) ?? 'en';
      return byCode(code).code;
    } catch (_) {
      return 'en';
    }
  }

  /// Saves on this phone and, if signed in, on the profile.
  static Future<void> save(String code) async {
    final String clean = byCode(code).code;

    try {
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      await preferences.setString(storageKey, clean);

      final User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
          <String, dynamic>{'languagePreference': clean},
          SetOptions(merge: true),
        );
      }
    } catch (error) {
      debugPrint('Language preference not saved: $error');
    }
  }
}
