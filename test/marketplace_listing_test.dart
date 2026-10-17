import 'package:flutter_test/flutter_test.dart';
import 'package:nubify/models/marketplace_listing.dart';

MarketplaceListing listing({
  String priceType = 'fixed',
  double? price = 2500,
  List<MarketplaceMedia> media = const <MarketplaceMedia>[],
  String thumbnailUrl = '',
  int coverMediaIndex = 0,
}) {
  return MarketplaceListing(
    listingId: 'listing-1',
    sellerId: 'seller-1',
    sellerName: 'Seller',
    sellerPhotoUrl: '',
    title: 'Laptop',
    description: 'Clean laptop',
    category: 'electrical_gadgets',
    condition: 'used',
    priceType: priceType,
    price: price,
    currency: 'EGP',
    media: media,
    coverMediaIndex: coverMediaIndex,
    thumbnailUrl: thumbnailUrl,
    status: 'available',
    publicVisible: true,
    allowMessages: true,
    allowCalls: false,
    searchPrefixes: const <String>['l', 'la', 'lap'],
  );
}

void main() {
  group('MarketplaceListing price labels', () {
    test('does not show EGP 0 for contact pricing', () {
      expect(
        listing(priceType: 'contact', price: 0).priceLabel,
        'Contact for Price',
      );
    });

    test('shows free and negotiable labels correctly', () {
      expect(listing(priceType: 'free', price: 0).priceLabel, 'Free');
      expect(
        listing(priceType: 'negotiable', price: 1250).priceLabel,
        'EGP 1250 · Negotiable',
      );
    });
  });

  test('coverUrl prefers a generated listing thumbnail', () {
    const MarketplaceMedia image = MarketplaceMedia(
      type: 'image',
      url: 'https://example.com/original.jpg',
      thumbnailUrl: '',
      durationMs: 0,
      displayOrder: 0,
      storagePath: 'marketplace/seller/listing/original.jpg',
    );
    expect(
      listing(
        media: const <MarketplaceMedia>[image],
        thumbnailUrl: 'https://example.com/thumbnail.jpg',
      ).coverUrl,
      'https://example.com/thumbnail.jpg',
    );
  });
}
