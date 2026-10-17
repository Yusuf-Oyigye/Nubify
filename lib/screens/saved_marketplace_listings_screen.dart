import 'package:flutter/material.dart';

import '../models/marketplace_listing.dart';
import '../services/marketplace_service.dart';
import '../utils/marketplace_theme.dart';
import '../widgets/marketplace_listing_card.dart';
import 'marketplace_listing_details_screen.dart';

class SavedMarketplaceListingsScreen extends StatelessWidget {
  const SavedMarketplaceListingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final MarketplaceService service = MarketplaceService();
    return Scaffold(
      appBar: AppBar(title: const Text('Saved Listings')),
      body: StreamBuilder<List<MarketplaceListing>>(
        stream: service.watchSavedListings(),
        builder:
            (
              BuildContext context,
              AsyncSnapshot<List<MarketplaceListing>> snapshot,
            ) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Unable to load saved listings. ${snapshot.error}',
                  ),
                );
              }
              final List<MarketplaceListing> listings =
                  snapshot.data ?? const <MarketplaceListing>[];
              if (listings.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(30),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.favorite_border_rounded,
                          size: 62,
                          color: MarketplaceTheme.sky,
                        ),
                        SizedBox(height: 14),
                        Text(
                          'No saved listings yet',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text('Tap the heart on a listing to keep it here.'),
                      ],
                    ),
                  ),
                );
              }
              return GridView.builder(
                padding: const EdgeInsets.all(14),
                itemCount: listings.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.69,
                ),
                itemBuilder: (BuildContext context, int index) {
                  final MarketplaceListing listing = listings[index];
                  return Opacity(
                    opacity: listing.isAvailable ? 1 : 0.55,
                    child: MarketplaceListingCard(
                      listing: listing,
                      saved: true,
                      onOpen: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => MarketplaceListingDetailsScreen(
                            listingId: listing.listingId,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
      ),
    );
  }
}
