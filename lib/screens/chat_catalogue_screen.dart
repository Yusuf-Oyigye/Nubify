import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/marketplace_listing.dart';
import '../widgets/marketplace_brand_icon.dart';
import '../widgets/nubify_chat_style.dart';
import 'marketplace_listing_details_screen.dart';

//===============================
// CHAT CATALOGUE SCREEN
//
// The seller's available products, opened from a chat,
// shown as a grid of square tiles: newest first.
//===============================

class ChatCatalogueScreen extends StatefulWidget {
  const ChatCatalogueScreen({
    super.key,
    required this.sellerId,
    required this.sellerName,
    required this.sellerUsername,
    required this.sellerPhotoUrl,
  });

  final String sellerId;

  final String sellerName;

  final String sellerUsername;

  final String sellerPhotoUrl;

  @override
  State<ChatCatalogueScreen> createState() => _ChatCatalogueScreenState();
}

class _ChatCatalogueScreenState extends State<ChatCatalogueScreen> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _productsStream =
      FirebaseFirestore.instance
          .collection('marketplaceProducts')
          .where('sellerId', isEqualTo: widget.sellerId)
          .where('status', isEqualTo: 'available')
          .where('publicVisible', isEqualTo: true)
          .limit(50)
          .snapshots();

  //===============================
  // NEWEST FIRST
  //===============================

  List<MarketplaceListing> _newestFirst(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    DateTime liveAt(MarketplaceListing listing) =>
        listing.publishedAt ??
        listing.createdAt ??
        DateTime.fromMillisecondsSinceEpoch(0);

    return docs.map(MarketplaceListing.fromFirestore).toList()..sort(
      (MarketplaceListing a, MarketplaceListing b) =>
          liveAt(b).compareTo(liveAt(a)),
    );
  }

  void _openListing(MarketplaceListing listing) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            MarketplaceListingDetailsScreen(listingId: listing.listingId),
      ),
    );
  }

  //===============================
  // SELLER HEADER
  //===============================

  Widget _header(int? count) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool dark = NubifyChatStyle.isDark(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 6, 14, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: dark
              ? Colors.white.withValues(alpha: 0.06)
              : const Color(0xFFE3E9F3),
        ),
      ),
      child: Row(
        children: <Widget>[
          NubifyChatAvatar(photoUrl: widget.sellerPhotoUrl, radius: 28),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  widget.sellerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (widget.sellerUsername.trim().isNotEmpty)
                  Text(
                    '@${widget.sellerUsername}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),

          if (count != null && count > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: NubifyChatStyle.royal.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                count == 1 ? '1 product' : '$count products',
                style: const TextStyle(
                  color: NubifyChatStyle.royal,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }

  //===============================
  // SQUARE PRODUCT TILE
  //===============================

  Widget _tile(MarketplaceListing listing) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String cover = listing.coverUrl.trim();

    return Semantics(
      button: true,
      label: '${listing.title}, ${listing.priceLabel}',
      child: GestureDetector(
        onTap: () {
          _openListing(listing);
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              if (cover.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: cover,
                  fit: BoxFit.cover,
                  memCacheWidth: 500,
                  placeholder: (_, _) =>
                      ColoredBox(color: scheme.surfaceContainerHighest),
                  errorWidget: (_, _, _) => ColoredBox(
                    color: scheme.surfaceContainerHighest,
                    child: const Center(child: MarketplaceBrandIcon(size: 36)),
                  ),
                )
              else
                ColoredBox(
                  color: scheme.surfaceContainerHighest,
                  child: const Center(child: MarketplaceBrandIcon(size: 36)),
                ),

              // Dark fade at the bottom so the text stays readable.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: <double>[0.45, 1],
                    colors: <Color>[Colors.transparent, Color(0xCC000000)],
                  ),
                ),
              ),

              if (listing.hasVideo)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.black45,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),

              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      listing.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        gradient: NubifyChatStyle.outgoing,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        listing.priceLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  //===============================
  // BUILD
  //===============================

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Catalogue',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _productsStream,
        builder:
            (
              BuildContext context,
              AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
            ) {
              if (snapshot.hasError) {
                return Column(
                  children: <Widget>[
                    _header(null),
                    const Expanded(
                      child: Center(
                        child: Text(
                          'Products could not load right now. Please try again.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return Column(
                  children: <Widget>[
                    _header(null),
                    const Expanded(
                      child: Center(
                        child: CircularProgressIndicator(
                          color: NubifyChatStyle.royal,
                        ),
                      ),
                    ),
                  ],
                );
              }

              final List<MarketplaceListing> products = _newestFirst(
                snapshot.data?.docs ??
                    <QueryDocumentSnapshot<Map<String, dynamic>>>[],
              );

              if (products.isEmpty) {
                return Column(
                  children: <Widget>[
                    _header(0),
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const MarketplaceBrandIcon(size: 56),
                            const SizedBox(height: 12),
                            Text(
                              'No products listed yet.',
                              style: TextStyle(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }

              return CustomScrollView(
                slivers: <Widget>[
                  SliverToBoxAdapter(child: _header(products.length)),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                    sliver: SliverGrid.builder(
                      itemCount: products.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                          ),
                      itemBuilder: (BuildContext context, int index) {
                        return _tile(products[index]);
                      },
                    ),
                  ),
                ],
              );
            },
      ),
    );
  }
}
