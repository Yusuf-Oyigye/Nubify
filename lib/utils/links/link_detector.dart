//===================================================
// UNIVERSAL LINK DETECTOR
//===================================================

class LinkDetector {
  LinkDetector._();

  static final RegExp _pattern =
  RegExp(
    r'((?:https?:\/\/|www\.)[^\s]+)',
    caseSensitive:
    false,
  );

  //===================================================
  // ALL LINKS
  //===================================================

  static List<String> extractLinks(
      String text,
      ) {
    final List<String> result =
    <String>[];

    for (
    final RegExpMatch match
    in _pattern.allMatches(
      text,
    )
    ) {
      final String raw =
          match.group(
            0,
          ) ??
              '';

      final String clean =
      cleanUrl(
        raw,
      );

      if (clean.isEmpty ||
          !isValidHttpUrl(
            clean,
          )) {
        continue;
      }

      if (!result.contains(
        clean,
      )) {
        result.add(
          clean,
        );
      }
    }

    return result;
  }

  //===================================================
  // FIRST LINK
  //===================================================

  static String? firstLink(
      String text,
      ) {
    final List<String> links =
    extractLinks(
      text,
    );

    return links.isEmpty
        ? null
        : links.first;
  }

  //===================================================
  // CLEAN URL
  //===================================================

  static String cleanUrl(
      String raw,
      ) {
    String value =
    raw.trim();

    while (
    value.isNotEmpty &&
        <String>[
          '.',
          ',',
          '!',
          '?',
          ';',
          ':',
          ')',
          ']',
          '}',
          '"',
          "'",
        ].contains(
          value[
          value.length -
              1],
        )
    ) {
      value =
          value.substring(
            0,
            value.length -
                1,
          );
    }

    if (value.startsWith(
      'www.',
    )) {
      value =
      'https://$value';
    }

    return value;
  }

  //===================================================
  // VALID HTTP / HTTPS
  //===================================================

  static bool isValidHttpUrl(
      String value,
      ) {
    final Uri? uri =
    Uri.tryParse(
      value,
    );

    if (uri == null) {
      return false;
    }

    if (
    uri.scheme !=
        'http' &&
        uri.scheme !=
            'https'
    ) {
      return false;
    }

    return uri.host
        .trim()
        .isNotEmpty;
  }

  //===================================================
  // NUBIFY LINK
  //===================================================

  static bool isNubifyUrl(
      String value,
      ) {
    final Uri? uri =
    Uri.tryParse(
      value,
    );

    if (uri == null) {
      return false;
    }

    final String host =
    uri.host
        .toLowerCase();

    return host ==
        'nubify.app' ||
        host ==
            'www.nubify.app';
  }
}