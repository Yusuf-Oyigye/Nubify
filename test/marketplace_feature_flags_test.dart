import 'package:flutter_test/flutter_test.dart';
import 'package:nubify/config/marketplace_feature_flags.dart';

void main() {
  test('seller approval is temporarily disabled during development', () {
    expect(MarketplaceFeatureFlags.requireSellerApproval, isFalse);
  });
}
