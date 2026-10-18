import 'package:flutter_test/flutter_test.dart';
import 'package:nubify/utils/marketplace_constants.dart';

void main() {
  test('search prefixes are normalized and capped', () {
    final List<String> prefixes = MarketplaceConstants.buildSearchPrefixes(
      <String>['Laptop', 'Medical service'],
    );

    expect(prefixes, containsAll(<String>['l', 'la', 'lap', 'laptop', 'm']));
    expect(prefixes.length, lessThanOrEqualTo(20));
  });

  test('all twelve Marketplace categories remain centralized', () {
    expect(MarketplaceConstants.categories, hasLength(12));
    expect(
      MarketplaceConstants.categories.map((category) => category.id).toSet(),
      hasLength(12),
    );
    expect(
      MarketplaceConstants.categories
          .take(4)
          .map((category) => category.id)
          .toList(),
      <String>[
        'textbooks_books',
        'food_snacks',
        'printing_photocopying',
        'medical_laboratory',
      ],
    );
    expect(
      MarketplaceConstants.categories
          .map((category) => category.icon.codePoint)
          .toSet(),
      hasLength(12),
    );
  });
}
