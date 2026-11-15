import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

//===================================================
// NUBIFY — GLOBAL APPEARANCE CONTROLLER
//===================================================

class NubifyAppearanceController extends ChangeNotifier {
  static const String _preferenceKey = 'nubify_appearance_v1';

  // Keep the previous dark default until a saved
  // appearance preference is loaded.
  ThemeMode _mode = ThemeMode.dark;

  ThemeMode get mode => _mode;

  NubifyAppearanceController() {
    _load();
  }

  //===================================================
  // LOAD SAVED APPEARANCE
  //===================================================

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final stored = prefs.getString(_preferenceKey);

      _mode = switch (stored) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        _ => ThemeMode.dark,
      };

      notifyListeners();
    } catch (_) {
      // Keep the working dark fallback if local
      // storage is temporarily unavailable.
    }
  }

  //===================================================
  // CHANGE AND SAVE APPEARANCE
  //===================================================

  Future<void> setMode(ThemeMode next) async {
    if (_mode == next) return;

    final previous = _mode;

    _mode = next;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(
        _preferenceKey,
        next.name,
      );
    } catch (_) {
      _mode = previous;
      notifyListeners();
      rethrow;
    }
  }
}