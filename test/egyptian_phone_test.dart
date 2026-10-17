import 'package:flutter_test/flutter_test.dart';
import 'package:nubify/utils/egyptian_phone.dart';

void main() {
  group('EgyptianPhone', () {
    test('normalizes every supported local prefix', () {
      expect(EgyptianPhone.normalize('01012345678'), '+201012345678');
      expect(EgyptianPhone.normalize('01112345678'), '+201112345678');
      expect(EgyptianPhone.normalize('01212345678'), '+201212345678');
      expect(EgyptianPhone.normalize('01512345678'), '+201512345678');
    });

    test('accepts international and formatted input', () {
      expect(EgyptianPhone.normalize('+20 10 1234 5678'), '+201012345678');
      expect(EgyptianPhone.normalize('10-1234-5678'), '+201012345678');
    });

    test('rejects unsupported or incomplete numbers', () {
      expect(EgyptianPhone.normalize('01312345678'), isNull);
      expect(EgyptianPhone.normalize('0101234'), isNull);
      expect(EgyptianPhone.normalize(''), isNull);
    });

    test('converts a stored E.164 number for local display', () {
      expect(EgyptianPhone.displayLocal('+201012345678'), '01012345678');
      expect(EgyptianPhone.displayLocal('not-a-number'), '');
    });
  });
}
