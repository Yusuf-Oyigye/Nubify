import 'package:flutter_test/flutter_test.dart';
import 'package:nubify/utils/common/email_check.dart';
import 'package:nubify/utils/profile/username_rules.dart';

void main() {
  group('UsernameRules.validate', () {
    test('accepts valid usernames', () {
      for (final String name in <String>[
        'muhammad',
        'Muhammad',
        'abc',
        'yusuf.o',
        'yusuf_o',
        'a1b2c3',
        'nub.student_2026',
        'abcdefghijklmnopqrst', // 20
        'name_',
      ]) {
        expect(UsernameRules.validate(name), isNull, reason: name);
      }
    });

    test('gives the right message for each broken rule', () {
      expect(UsernameRules.validate(''), UsernameRules.tooShort);
      expect(UsernameRules.validate('ab'), UsernameRules.tooShort);
      expect(
        UsernameRules.validate('abcdefghijklmnopqrstu'),
        UsernameRules.tooLong,
      );
      expect(UsernameRules.validate('1abc'), UsernameRules.mustStartWithLetter);
      expect(UsernameRules.validate('_abc'), UsernameRules.mustStartWithLetter);
      expect(UsernameRules.validate('.abc'), UsernameRules.mustStartWithLetter);
      expect(UsernameRules.validate('ab..c'), UsernameRules.doublePeriod);
      expect(UsernameRules.validate('ab__c'), UsernameRules.doubleUnderscore);
      expect(UsernameRules.validate('abc.'), UsernameRules.endsWithPeriod);
    });

    test('blocks spaces, symbols, emojis and Arabic', () {
      for (final String name in <String>[
        'ab c',
        'ab-c',
        'ab!c',
        r'ab$c',
        'ab%c',
        'ab&c',
        'ab*c',
        'ab+c',
        'ab/c',
        'abc😀',
        'محمد',
        'ab@c',
      ]) {
        expect(
          UsernameRules.validate(name),
          UsernameRules.invalidCharacters,
          reason: name,
        );
      }
    });

    test('ignores a typed leading @', () {
      expect(UsernameRules.validate('@muhammad'), isNull);
      expect(UsernameRules.clean('@@muhammad'), 'muhammad');
    });
  });

  test('usernames are case-insensitive', () {
    expect(UsernameRules.normalize('MUHAMMAD'), 'muhammad');
    expect(UsernameRules.normalize(' Muhammad '), 'muhammad');
    expect(UsernameRules.normalize('@Muhammad'), 'muhammad');
  });

  test('display adds @ once', () {
    expect(UsernameRules.at('yusuf'), '@yusuf');
    expect(UsernameRules.at('@yusuf'), '@yusuf');
    expect(UsernameRules.at(''), '');
  });

  test('suggestions are always valid', () {
    for (final String seed in <String>[
      'John.Doe99',
      '123abc',
      'a..b__c.',
      'ح',
      'very.long.email.name.that.keeps.going',
    ]) {
      final String suggestion = UsernameRules.suggestFrom(seed);
      expect(
        suggestion.isEmpty || UsernameRules.isValid(suggestion),
        isTrue,
        reason: '$seed -> $suggestion',
      );
    }
  });

  group('EmailCheck.validateFormat', () {
    test('accepts normal emails', () {
      expect(EmailCheck.validateFormat('student@nub.edu.eg'), isNull);
      expect(EmailCheck.validateFormat('a.b+c@gmail.com'), isNull);
    });

    test('rejects broken emails', () {
      expect(EmailCheck.validateFormat(''), isNotNull);
      expect(EmailCheck.validateFormat('studentgmail.com'), contains('@'));
      expect(EmailCheck.validateFormat('a@b'), isNotNull);
      expect(EmailCheck.validateFormat('a@@gmail.com'), isNotNull);
      expect(EmailCheck.validateFormat('a b@gmail.com'), isNotNull);
      expect(EmailCheck.validateFormat('a..b@gmail.com'), isNotNull);
    });

    test('suggests a fix for common typos', () {
      expect(
        EmailCheck.validateFormat('yusuf@gmial.com'),
        'Did you mean yusuf@gmail.com?',
      );
    });
  });
}
