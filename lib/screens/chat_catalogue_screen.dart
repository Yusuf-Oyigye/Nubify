import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../widgets/marketplace_brand_icon.dart';
import 'marketplace_listing_details_screen.dart';

//===============================
// CHAT CATALOGUE SCREEN
//===============================

class ChatCatalogueScreen extends StatelessWidget {
  ChatCatalogueScreen({
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

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const Color _blue = Color(0xFF29B6F6);

  //===============================
  // BUILD
  //===============================

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool dark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        title: const Text(
          'Catalogue',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: <Widget>[
          //===============================
          // SELLER HEADER
          //===============================

          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: dark
                    ? const <Color>[Color(0xFF15242D), Color(0xFF0B1116)]
                    : <Color>[scheme.surface, theme.scaffoldBackgroundColor],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 32,
                  backgroundColor: scheme.surfaceContainerHighest,
                  backgroundImage: sellerPhotoUrl.trim().isNotEmpty
                      ? NetworkImage(sellerPhotoUrl)
                      : null,
                  child: sellerPhotoUrl.trim().isEmpty
                      ? Icon(
                          Icons.person_rounded,
                          color: scheme.onSurfaceVariant,
                        )
                      : null,
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        sellerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      if (sellerUsername.trim().isNotEmpty)
                        Text(
                          '@$sellerUsername',
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          //===============================
          // PRODUCTS
          //===============================
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _firestore
                  .collection('marketplaceProducts')
                  .where('sellerId', isEqualTo: sellerId)
                  .where('status', isEqualTo: 'available')
                  .where('publicVisible', isEqualTo: true)
                  .limit(50)
                  .snapshots(),
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
                  ) {
                    if (snapshot.hasError) {
                      return const Center(
                        child: Text(
                          'Products could not load right now. Please try again.',
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: _blue),
                      );
                    }

                    final docs = snapshot.data?.docs ?? [];

                    if (docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            MarketplaceBrandIcon(
                              size: 56,
                              tintColor: scheme.onSurfaceVariant,
                              fallbackColor: scheme.onSurfaceVariant,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'No products listed yet.',
                              style: TextStyle(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: docs.length,
                      separatorBuilder: (_, _) =>
                          Divider(height: 1, color: scheme.outlineVariant),
                      itemBuilder: (BuildContext context, int index) {
                        final document = docs[index];

                        final product = document.data();

                        final String listingId =
                            (product['listingId'] ?? document.id).toString();

                        final String title =
                            (product['title'] ?? product['name'] ?? 'Product')
                                .toString();

                        final String description =
                            (product['description'] ?? '').toString();

                        final dynamic rawMedia = product['media'];

                        String imageUrl =
                            (product['thumbnailUrl'] ??
                                    product['imageUrl'] ??
                                    '')
                                .toString();

                        if (imageUrl.trim().isEmpty &&
                            rawMedia is List &&
                            rawMedia.isNotEmpty &&
                            rawMedia.first is Map) {
                          final Map<String, dynamic> firstMedia =
                              Map<String, dynamic>.from(rawMedia.first as Map);
                          imageUrl =
                              (firstMedia['thumbnailUrl'] ??
                                      firstMedia['url'] ??
                                      '')
                                  .toString();
                        }

                        final dynamic rawPrice = product['price'];

                        final String price = rawPrice == null
                            ? ''
                            : rawPrice.toString();

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(13),
                            child: Container(
                              width: 66,
                              height: 66,
                              color: scheme.surfaceContainerHighest,
                              child: imageUrl.trim().isNotEmpty
                                  ? Image.network(imageUrl, fit: BoxFit.cover)
                                  : const MarketplaceBrandIcon(
                                      size: 26,
                                      tintColor: _blue,
                                      fallbackColor: _blue,
                                    ),
                            ),
                          ),
                          title: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              if (description.trim().isNotEmpty)
                                Text(
                                  description,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),

                              if (price.isNotEmpty)
                                Text(
                                  'EGP $price',
                                  style: const TextStyle(
                                    color: _blue,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                            ],
                          ),
                          onTap: () {
                            Navigator.push<void>(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => MarketplaceListingDetailsScreen(
                                  listingId: listingId,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
            ),
          ),
        ],
      ),
    );
  }
}
