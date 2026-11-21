import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nubify/widgets/marketplace/marketplace_brand_icon.dart';

void main() {
  test('Marketplace icon uses the bundled Twemoji cart', () {
    expect(
      MarketplaceBrandAssets.cartIcon,
      'assets/icons/marketplace_cart.svg',
    );
  });

  testWidgets('Marketplace icon renders the cart at the requested size', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(child: MarketplaceBrandIcon(size: 40)),
      ),
    );

    final SvgPicture picture = tester.widget<SvgPicture>(
      find.byType(SvgPicture),
    );

    expect(
      (picture.bytesLoader as SvgAssetLoader).assetName,
      MarketplaceBrandAssets.cartIcon,
    );
    expect(find.bySemanticsLabel('NUB Marketplace'), findsOneWidget);
    expect(
      tester.getSize(find.byType(MarketplaceBrandIcon)),
      const Size(40, 40),
    );
  });
}
