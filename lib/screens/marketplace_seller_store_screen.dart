import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/marketplace_listing.dart';
import '../services/marketplace_service.dart';
import '../utils/marketplace_theme.dart';
import '../widgets/marketplace_listing_card.dart';
import '../widgets/marketplace_verified_seller_badge.dart';
import 'marketplace_listing_details_screen.dart';
import 'profile_screen.dart';

class MarketplaceSellerStoreScreen extends StatelessWidget {
  MarketplaceSellerStoreScreen({super.key, required this.sellerId});

  final String sellerId;
  final MarketplaceService _service = MarketplaceService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(sellerId)
            .snapshots(),
        builder:
            (
              BuildContext context,
              AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>>
              profileSnapshot,
            ) {
              final Map<String, dynamic> profile =
                  profileSnapshot.data?.data() ?? <String, dynamic>{};
              final String name =
                  (profile['fullName'] ??
                          profile['username'] ??
                          'Student Seller')
                      .toString();
              final String photo = (profile['photoUrl'] ?? '').toString();
              return CustomScrollView(
                slivers: <Widget>[
                  SliverAppBar.large(
                    pinned: true,
                    expandedHeight: 230,
                    title: Text(name),
                    flexibleSpace: FlexibleSpaceBar(
                      background: Container(
                        decoration: const BoxDecoration(
                          gradient: MarketplaceTheme.heroGradient,
                        ),
                        child: SafeArea(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: <Widget>[
                              CircleAvatar(
                                radius: 44,
                                backgroundImage: photo.isEmpty
                                    ? null
                                    : NetworkImage(photo),
                                child: photo.isEmpty
                                    ? const Icon(Icons.person_rounded, size: 42)
                                    : null,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  MarketplaceVerifiedSellerBadge(
                                    sellerId: sellerId,
                                  ),
                                ],
                              ),
                              TextButton(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        ProfileScreen(userId: sellerId),
                                  ),
                                ),
                                child: const Text('View Nubify Profile'),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  StreamBuilder<Set<String>>(
                    stream: _service.watchSavedIds(),
                    builder: (BuildContext context, AsyncSnapshot<Set<String>> saved) {
                      return StreamBuilder<List<MarketplaceListing>>(
                        stream: _service.watchAvailable(
                          sellerId: sellerId,
                          limit: 50,
                        ),
                        builder:
                            (
                              BuildContext context,
                              AsyncSnapshot<List<MarketplaceListing>> snapshot,
                            ) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const SliverFillRemaining(
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }
                              final List<MarketplaceListing> listings =
                                  snapshot.data ?? const <MarketplaceListing>[];
                              if (listings.isEmpty) {
                                return const SliverFillRemaining(
                                  child: Center(
                                    child: Text('No available listings.'),
                                  ),
                                );
                              }
                              return SliverPadding(
                                padding: const EdgeInsets.all(14),
                                sliver: SliverGrid.builder(
                                  itemCount: listings.length,
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        mainAxisSpacing: 12,
                                        crossAxisSpacing: 12,
                                        childAspectRatio: 0.69,
                                      ),
                                  itemBuilder: (BuildContext context, int index) {
                                    final MarketplaceListing listing =
                                        listings[index];
                                    return MarketplaceListingCard(
                                      listing: listing,
                                      saved:
                                          saved.data?.contains(
                                            listing.listingId,
                                          ) ??
                                          false,
                                      onOpen: () => Navigator.push(
                                        context,
                                        MaterialPageRoute<void>(
                                          builder: (_) =>
                                              MarketplaceListingDetailsScreen(
                                                listingId: listing.listingId,
                                              ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                      );
                    },
                  ),
                ],
              );
            },
      ),
    );
  }
}
