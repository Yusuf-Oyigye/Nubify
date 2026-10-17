import 'package:flutter/material.dart';

import '../models/marketplace_listing.dart';
import '../services/marketplace_service.dart';
import '../utils/marketplace_theme.dart';
import 'marketplace_listing_card.dart';

//===================================================
// MORE FROM THIS SELLER
//===================================================

class MarketplaceMoreFromSeller extends StatelessWidget {
  MarketplaceMoreFromSeller({
    super.key,
    required this.sellerId,
    required this.currentListingId,
    required this.onOpenListing,
    required this.onViewStore,
  });

  final String sellerId;
  final String currentListingId;
  final ValueChanged<MarketplaceListing> onOpenListing;
  final VoidCallback onViewStore;
  final MarketplaceService _service = MarketplaceService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Set<String>>(
      stream: _service.watchSavedIds(),
      builder: (BuildContext context, AsyncSnapshot<Set<String>> saved) {
        return StreamBuilder<List<MarketplaceListing>>(
          stream: _service.watchAvailable(sellerId: sellerId, limit: 10),
          builder:
              (
                BuildContext context,
                AsyncSnapshot<List<MarketplaceListing>> snapshot,
              ) {
                final List<MarketplaceListing> listings =
                    (snapshot.data ?? const <MarketplaceListing>[])
                        .where(
                          (MarketplaceListing item) =>
                              item.listingId != currentListingId,
                        )
                        .take(8)
                        .toList(growable: false);
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 30),
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }
                if (listings.isEmpty) {
                  return const SizedBox.shrink();
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const Expanded(
                          child: Text(
                            'More From This Seller',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: onViewStore,
                          child: const Text('View Store'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 286,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: listings.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (BuildContext context, int index) {
                          final MarketplaceListing listing = listings[index];
                          return SizedBox(
                            width: 184,
                            child: MarketplaceListingCard(
                              listing: listing,
                              saved:
                                  saved.data?.contains(listing.listingId) ??
                                  false,
                              onOpen: () => onOpenListing(listing),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 4),
                    Divider(
                      color: MarketplaceTheme.sky.withValues(alpha: 0.18),
                    ),
                  ],
                );
              },
        );
      },
    );
  }
}
