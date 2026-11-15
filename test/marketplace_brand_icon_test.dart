import 'package:flutter_test/flutter_test.dart';
import 'package:nubify/widgets/marketplace_brand_icon.dart';

void main() {
  test('Marketplace brand icon keeps the requested source URL', () {
    expect(
      MarketplaceBrandAssets.iconUrl,
      'https://img.icons8.com/?size=100&id=fhk2K3BpkLYx&format=png&color=000000',
    );
  });
}
