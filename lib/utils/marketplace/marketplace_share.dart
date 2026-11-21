import 'package:flutter/material.dart';

import '../../models/marketplace/marketplace_listing.dart';
import '../../screens/chat/chat_forward_screen.dart';
import '../../screens/stories/create_story_screen.dart';

//===================================================
// SHARE A MARKETPLACE LISTING
//
// Used by the listing page and by My Listings, so a
// buyer or the owner shares a listing the same way.
//===================================================

String marketplaceListingLink(MarketplaceListing listing) {
  return 'https://nubify.app/marketplace/${listing.listingId}';
}

/// Opens the Story editor with the listing ready to post.
/// Returns true when the story was shared.
Future<bool> shareListingToStory(
  BuildContext context,
  MarketplaceListing listing,
) async {
  final bool? shared = await Navigator.push<bool>(
    context,
    MaterialPageRoute<bool>(
      builder: (_) => CreateStoryScreen(
        initialLinkUrl: marketplaceListingLink(listing),
        initialText: '${listing.title}\n${listing.priceLabel}',
        initialCaption: 'Discover this on NUB Marketplace',
        initialBackgroundColor: 0xFF102A43,
      ),
    ),
  );

  return shared == true;
}

/// Lets you pick chats or groups to send the listing to.
/// Returns true when it was sent.
Future<bool> shareListingToChat(
  BuildContext context,
  MarketplaceListing listing,
) async {
  final bool? sent = await Navigator.push<bool>(
    context,
    MaterialPageRoute<bool>(
      builder: (_) => ChatForwardScreen(
        productId: listing.listingId,
        productSellerId: listing.sellerId,
        productName: listing.title,
        productImageUrl: listing.coverUrl,
        productPrice: listing.priceLabel,
      ),
    ),
  );

  return sent == true;
}
