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
  const NubifyLanguage(this.code, this.label, this.nativeName);

  final String code;
  final String label;
  final String nativeName;
}

abstract final class LanguagePreference {
  // Same key the Menu screen uses.
  static const String storageKey = 'nubify_language_preference_v1';

  static const List<NubifyLanguage> options = <NubifyLanguage>[
    NubifyLanguage('en', 'English', 'English'),
    NubifyLanguage('ar', 'Arabic', 'العربية'),
    NubifyLanguage('ha', 'Hausa', 'Hausa'),
    NubifyLanguage('yo', 'Yoruba', 'Yorùbá'),
    NubifyLanguage('hi', 'Hindi', 'हिन्दी'),
    NubifyLanguage('fr', 'French', 'Français'),
  ];

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
