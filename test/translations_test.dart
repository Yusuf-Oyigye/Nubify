import 'package:flutter_test/flutter_test.dart';
import 'package:nubify/l10n/nubify_text.dart';
import 'package:nubify/l10n/translations/chat.dart';
import 'package:nubify/l10n/translations/faculties.dart';
import 'package:nubify/l10n/translations/information.dart';
import 'package:nubify/l10n/translations/marketplace.dart';
import 'package:nubify/l10n/translations/notifications.dart';

void main() {
  const List<String> languages = <String>['ar', 'fr', 'ha', 'yo', 'hi'];

  final Map<String, Map<String, Map<String, String>>> files =
      <String, Map<String, Map<String, String>>>{
        'chat': chatTranslations,
        'faculties': facultiesTranslations,
        'information': informationTranslations,
        'marketplace': marketplaceTranslations,
        'notifications': notificationsTranslations,
      };

  final RegExp placeholder = RegExp(r'\{[a-z]+\}');

  test('every phrase is in all five languages', () {
    files.forEach((String file, Map<String, Map<String, String>> words) {
      for (final String english in words['ar']!.keys) {
        // "(female)" lines only exist where the verb changes.
        if (english.endsWith('(female)')) {
          continue;
        }
        for (final String language in languages) {
          expect(
            words[language]![english],
            isNotNull,
            reason: '$file: "$english" has no $language',
          );
        }
      }
    });
  });

  test('{name}, {count} ... are kept in every translation', () {
    files.forEach((String file, Map<String, Map<String, String>> words) {
      for (final String language in languages) {
        words[language]!.forEach((String english, String translated) {
          final Set<String> wanted = placeholder
              .allMatches(english)
              .map((Match m) => m[0]!)
              .toSet();
          final Set<String> got = placeholder
              .allMatches(translated)
              .map((Match m) => m[0]!)
              .toSet();
          expect(got, wanted, reason: '$file $language: "$english"');
        });
      }
    });
  });

  test('NUB Trend and NUB Map stay English (brand names)', () {
    for (final String language in languages) {
      expect(NubifyText.tr('NUB Trend', const <String, Object>{}, language),
          'NUB Trend');
      expect(NubifyText.tr('NUB Map', const <String, Object>{}, language),
          'NUB Map');
    }
  });

  test('notification sentences and the female forms', () {
    expect(
      NubifyText.tr('liked your post', const <String, Object>{}, 'ar'),
      'أُعجب بمنشورك',
    );
    expect(
      NubifyText.tr('liked your post (female)', const <String, Object>{}, 'ar'),
      'أُعجبت بمنشورك',
    );
    // French has no female line: the screen falls back to the normal one.
    expect(
      NubifyText.tr('liked your post (female)', const <String, Object>{}, 'fr'),
      'liked your post (female)',
    );
  });

  test('placeholders are filled in', () {
    expect(
      NubifyText.tr('Say hi to {name}', <String, Object>{'name': 'Amina'}, 'fr'),
      'Dites bonjour à Amina',
    );
    expect(
      NubifyText.tr('{count} members', <String, Object>{'count': 12}, 'hi'),
      '12 सदस्य',
    );
  });
}
