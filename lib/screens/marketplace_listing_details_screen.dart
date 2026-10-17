import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/marketplace_listing.dart';
import '../services/cellular_call_service.dart';
import '../services/chat_sevice.dart';
import '../services/marketplace_service.dart';
import '../utils/marketplace_constants.dart';
import '../utils/marketplace_theme.dart';
import '../widgets/marketplace_media_gallery.dart';
import 'conversation_screen.dart';
import 'marketplace_seller_store_screen.dart';
import 'profile_screen.dart';

class MarketplaceListingDetailsScreen extends StatefulWidget {
  const MarketplaceListingDetailsScreen({super.key, required this.listingId});

  final String listingId;

  @override
  State<MarketplaceListingDetailsScreen> createState() =>
      _MarketplaceListingDetailsScreenState();
}

class _MarketplaceListingDetailsScreenState
    extends State<MarketplaceListingDetailsScreen> {
  final MarketplaceService _service = MarketplaceService();
  final CellularCallService _calls = CellularCallService();
  final ChatService _chat = ChatService();
  bool _working = false;

  Future<void> _messageSeller(MarketplaceListing listing) async {
    if (_working ||
        listing.sellerId == FirebaseAuth.instance.currentUser?.uid) {
      return;
    }
    setState(() => _working = true);
    try {
      final DocumentSnapshot<Map<String, dynamic>> user =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(listing.sellerId)
              .get();
      final Map<String, dynamic> profile = user.data() ?? <String, dynamic>{};
      await _chat.ensureConversationExists(listing.sellerId);
      await _chat.sendProductMessage(
        receiverId: listing.sellerId,
        productId: listing.listingId,
        productSellerId: listing.sellerId,
        productName: listing.title,
        productImageUrl: listing.coverUrl,
        productPrice: listing.priceLabel,
      );
      if (!mounted) {
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ConversationScreen(
            otherUserId: listing.sellerId,
            otherName: (profile['fullName'] ?? listing.sellerName).toString(),
            otherUsername: (profile['username'] ?? '').toString(),
            otherPhotoUrl: (profile['photoUrl'] ?? listing.sellerPhotoUrl)
                .toString(),
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        _message(error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _working = false);
      }
    }
  }

  Future<void> _callSeller(MarketplaceListing listing) async {
    if (_working) {
      return;
    }
    setState(() => _working = true);
    try {
      await _calls.callSeller(listing.listingId);
    } catch (error) {
      if (mounted) {
        _message(error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _working = false);
      }
    }
  }

  Future<void> _share(MarketplaceListing listing) async {
    await SharePlus.instance.share(
      ShareParams(
        subject: listing.title,
        text:
            '${listing.title}\n${listing.priceLabel}\nhttps://nubify.app/marketplace/${listing.listingId}',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MarketplaceListing?>(
      stream: _service.watchListing(widget.listingId),
      builder:
          (BuildContext context, AsyncSnapshot<MarketplaceListing?> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            final MarketplaceListing? listing = snapshot.data;
            if (listing == null) {
              return Scaffold(
                appBar: AppBar(title: const Text('Listing')),
                body: const Center(
                  child: Text('This listing no longer exists.'),
                ),
              );
            }
            final bool owner =
                listing.sellerId == FirebaseAuth.instance.currentUser?.uid;
            return Scaffold(
              body: CustomScrollView(
                slivers: <Widget>[
                  SliverAppBar(
                    pinned: true,
                    expandedHeight: 410,
                    actions: <Widget>[
                      IconButton(
                        onPressed: () => _share(listing),
                        icon: const Icon(Icons.share_outlined),
                      ),
                      if (owner)
                        PopupMenuButton<String>(
                          onSelected: (String value) =>
                              _ownerAction(listing, value),
                          itemBuilder: (_) => <PopupMenuEntry<String>>[
                            if (listing.status ==
                                'available') ...<PopupMenuEntry<String>>[
                              const PopupMenuItem(
                                value: 'sold',
                                child: Text('Mark Sold'),
                              ),
                              const PopupMenuItem(
                                value: 'unavailable',
                                child: Text('Mark Unavailable'),
                              ),
                            ],
                            if (listing.status == 'unavailable' ||
                                listing.status == 'archived')
                              const PopupMenuItem(
                                value: 'available',
                                child: Text('Restore Available'),
                              ),
                            if (listing.status != 'archived')
                              const PopupMenuItem(
                                value: 'archived',
                                child: Text('Archive'),
                              ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
                        ),
                    ],
                    flexibleSpace: FlexibleSpaceBar(
                      background: Hero(
                        tag: 'marketplace-cover-${listing.listingId}',
                        child: MarketplaceMediaGallery(listing: listing),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 130),
                    sliver: SliverList.list(
                      children: <Widget>[
                        if (!listing.isAvailable)
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 14),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              listing.status == 'sold'
                                  ? 'Sold · No Longer Available'
                                  : 'No Longer Available',
                              style: const TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        Text(
                          listing.priceLabel,
                          style: const TextStyle(
                            color: MarketplaceTheme.sky,
                            fontSize: 27,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          listing.title,
                          style: const TextStyle(
                            fontSize: 25,
                            height: 1.15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            Chip(
                              label: Text(
                                MarketplaceConstants.categoryLabel(
                                  listing.category,
                                ),
                              ),
                            ),
                            Chip(
                              label: Text(
                                MarketplaceConstants.conditionLabel(
                                  listing.condition,
                                ),
                              ),
                            ),
                            Chip(label: Text(listing.status.toUpperCase())),
                          ],
                        ),
                        const SizedBox(height: 22),
                        const Text(
                          'Description',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          listing.description,
                          style: const TextStyle(height: 1.5),
                        ),
                        const SizedBox(height: 24),
                        InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => MarketplaceSellerStoreScreen(
                                sellerId: listing.sellerId,
                              ),
                            ),
                          ),
                          child: Ink(
                            padding: const EdgeInsets.all(16),
                            decoration: MarketplaceTheme.premiumCard(context),
                            child: Row(
                              children: <Widget>[
                                CircleAvatar(
                                  radius: 28,
                                  backgroundImage:
                                      listing.sellerPhotoUrl.isEmpty
                                      ? null
                                      : NetworkImage(listing.sellerPhotoUrl),
                                  child: listing.sellerPhotoUrl.isEmpty
                                      ? const Icon(Icons.person_rounded)
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Row(
                                        children: <Widget>[
                                          Flexible(
                                            child: Text(
                                              listing.sellerName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          const Icon(
                                            Icons.verified_rounded,
                                            size: 17,
                                            color: MarketplaceTheme.sky,
                                          ),
                                        ],
                                      ),
                                      const Text('Verified Student Seller'),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Nubify Profile',
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder: (_) => ProfileScreen(
                                        userId: listing.sellerId,
                                      ),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.person_outline_rounded,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              bottomNavigationBar: owner || !listing.isAvailable
                  ? null
                  : SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _working || !listing.allowMessages
                                    ? null
                                    : () => _messageSeller(listing),
                                icon: const Icon(
                                  Icons.chat_bubble_outline_rounded,
                                ),
                                label: const Text('Message Seller'),
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(52),
                                ),
                              ),
                            ),
                            if (listing.allowCalls) ...<Widget>[
                              const SizedBox(width: 10),
                              IconButton.filled(
                                tooltip: 'Call Seller',
                                onPressed: _working
                                    ? null
                                    : () => _callSeller(listing),
                                icon: const Icon(Icons.phone_rounded),
                                style: IconButton.styleFrom(
                                  minimumSize: const Size(54, 54),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
            );
          },
    );
  }

  Future<void> _ownerAction(MarketplaceListing listing, String action) async {
    try {
      if (action == 'delete') {
        final bool? confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('Delete listing?'),
            content: const Text('This cannot be undone.'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          await _service.deleteListing(listing);
          if (mounted) Navigator.pop(context);
        }
      } else {
        await _service.updateStatus(listing.listingId, action);
      }
    } catch (error) {
      if (mounted) _message(error.toString());
    }
  }

  void _message(String value) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value)));
  }
}
