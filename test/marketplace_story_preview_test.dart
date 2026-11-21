import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nubify/models/links/link_preview.dart';
import 'package:nubify/widgets/marketplace/marketplace_brand_icon.dart';
import 'package:nubify/widgets/links/universal_link_preview_card.dart';

void main() {
  testWidgets('Marketplace story card prioritizes a large product image', (
    WidgetTester tester,
  ) async {
    const LinkPreview preview = LinkPreview(
      url: 'https://nubify.app/marketplace/listing-1',
      resolvedUrl: 'https://nubify.app/marketplace/listing-1',
      canonicalUrl: 'https://nubify.app/marketplace/listing-1',
      title: 'Campus textbook',
      description: 'Clean copy',
      siteName: 'Nubify Marketplace',
      domain: 'nubify.app',
      imageUrl: '',
      faviconUrl: '',
      contentType: 'marketplace',
      provider: 'Nubify',
      creator: 'Student seller',
      price: 'EGP 250',
      statusText: 'Available',
      internalType: 'marketplace',
      internalId: 'listing-1',
      isInternal: true,
      isAvailable: true,
      actionLabel: 'View listing',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 380,
            child: UniversalLinkPreviewCard(
              preview: preview,
              compact: false,
              interactive: false,
              heroAspectRatio: 1.28,
              showOriginalUrl: false,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(MarketplaceBrandIcon), findsOneWidget);
    expect(find.text(preview.canonicalUrl), findsNothing);
    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is AspectRatio && widget.aspectRatio == 1.28,
      ),
      findsOneWidget,
    );
  });
}
