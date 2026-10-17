import 'package:flutter_test/flutter_test.dart';
import 'package:nubify/utils/link_detector.dart';

void main() {
  group('Nubify Marketplace deep links', () {
    test('accepts the official Marketplace hosts', () {
      expect(
        LinkDetector.isNubifyUrl(
          'https://nubify.app/marketplace/listing_123',
        ),
        isTrue,
      );
      expect(
        LinkDetector.isNubifyUrl(
          'https://www.nubify.app/product/listing_123',
        ),
        isTrue,
      );
    });

    test('rejects lookalike and unrelated hosts', () {
      expect(
        LinkDetector.isNubifyUrl(
          'https://nubify.app.attacker.example/marketplace/listing_123',
        ),
        isFalse,
      );
      expect(
        LinkDetector.isNubifyUrl(
          'https://example.com/marketplace/listing_123',
        ),
        isFalse,
      );
    });

    test('removes sentence punctuation from a shared link', () {
      expect(
        LinkDetector.cleanUrl(
          'https://nubify.app/marketplace/listing_123).',
        ),
        'https://nubify.app/marketplace/listing_123',
      );
    });
  });
}
