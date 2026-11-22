//===================================================
// NUBIFY USERNAME RULES
//
// One place for every username rule, used by signup,
// Edit Profile, search and display. The same rules are
// enforced again by Firestore security rules, so a
// modified app cannot skip them.
//
// - 3 to 20 characters
// - English letters, numbers, "_" and "." only
// - must start with an English letter
// - no "..", no "__", cannot end with "."
// - case-insensitive: "Muhammad" == "muhammad"
//===================================================

abstract final class UsernameRules {
  static const int minLength = 3;
  static const int maxLength = 20;

  static final RegExp _allowed = RegExp(r'^[A-Za-z0-9._]+$');
  static final RegExp _startsWithLetter = RegExp(r'^[A-Za-z]');

  // Messages shown to the user.
  static const String tooShort = 'Username must contain at least 3 characters.';
  static const String tooLong = 'Username cannot exceed 20 characters.';
  static const String mustStartWithLetter =
      'Username must start with an English letter.';
  static const String invalidCharacters =
      'Only English letters, numbers, underscores and periods are allowed.';
  static const String doublePeriod = 'Consecutive periods are not allowed.';
  static const String doubleUnderscore =
      'Consecutive underscores are not allowed.';
  static const String endsWithPeriod = 'Username cannot end with a period.';
  static const String taken = 'This username is already taken.';
  static const String available = 'Username is available.';

  /// What the user typed, without spaces around it and
  /// without a leading "@" (the app adds "@" itself).
  static String clean(String input) {
    String value = input.trim();
    while (value.startsWith('@')) {
      value = value.substring(1);
    }
    return value;
  }

  /// The lowercase form used for uniqueness and search.
  static String normalize(String input) => clean(input).toLowerCase();

  /// The first rule [input] breaks, or null when it is valid.
  static String? validate(String input) {
    final String value = clean(input);

    if (value.isEmpty) return tooShort;
    if (!_allowed.hasMatch(value)) return invalidCharacters;
    if (!_startsWithLetter.hasMatch(value)) return mustStartWithLetter;
    if (value.length < minLength) return tooShort;
    if (value.length > maxLength) return tooLong;
    if (value.contains('..')) return doublePeriod;
    if (value.contains('__')) return doubleUnderscore;
    if (value.endsWith('.')) return endsWithPeriod;

    return null;
  }

  static bool isValid(String input) => validate(input) == null;

  /// "@username" for display. Empty stays empty.
  static String at(String username) {
    final String value = clean(username);
    return value.isEmpty ? '' : '@$value';
  }

  /// A search query ready to match usernames: lowercase,
  /// and a leading "@" is ignored.
  static String searchKey(String query) => normalize(query);

  /// Turns any text (e.g. the part of an email before "@")
  /// into a valid username, or '' when that is impossible.
  /// Used to repair profiles that were never finished.
  static String suggestFrom(String input) {
    String value = input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9._]'), '')
        .replaceAll(RegExp(r'\.{2,}'), '.')
        .replaceAll(RegExp(r'_{2,}'), '_')
        .replaceFirst(RegExp(r'^[^a-z]+'), '');

    if (value.length > maxLength) value = value.substring(0, maxLength);
    while (value.endsWith('.')) {
      value = value.substring(0, value.length - 1);
    }
    if (value.length < minLength) return '';

    return isValid(value) ? value : '';
  }
}
