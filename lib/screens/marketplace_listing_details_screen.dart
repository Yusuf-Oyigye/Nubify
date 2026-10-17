import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../models/marketplace_listing.dart';
import '../services/cellular_call_service.dart';
import '../services/chat_sevice.dart';
import '../services/marketplace_service.dart';
import '../utils/marketplace_constants.dart';
import '../utils/marketplace_theme.dart';
import '../widgets/marketplace_media_gallery.dart';
import '../widgets/marketplace_more_from_seller.dart';
import '../widgets/marketplace_verified_seller_badge.dart';
import 'chat_forward_screen.dart';
import 'conversation_screen.dart';
import 'create_marketplace_listing_screen.dart';
import 'create_story_screen.dart';
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

  String _listingLink(MarketplaceListing listing) {
    return 'https://nubify.app/marketplace/${listing.listingId}';
  }

  Future<void> _shareExternal(MarketplaceListing listing) async {
    await SharePlus.instance.share(
      ShareParams(
        subject: listing.title,
        text:
            '${listing.title}\n${listing.priceLabel}\n${_listingLink(listing)}',
      ),
    );
  }

  Future<void> _copyLink(MarketplaceListing listing) async {
    await Clipboard.setData(ClipboardData(text: _listingLink(listing)));
    if (mounted) {
      _message('Listing link copied.');
    }
  }

  Future<void> _shareToStory(MarketplaceListing listing) async {
    final bool? shared = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => CreateStoryScreen(
          initialLinkUrl: _listingLink(listing),
          initialText: '${listing.title}\n${listing.priceLabel}',
          initialCaption: 'Discover this on NUB Marketplace',
          initialBackgroundColor: 0xFF102A43,
        ),
      ),
    );
    if (mounted && shared == true) {
      _message('Listing added to your Story.');
    }
  }

  Future<void> _shareToChat(MarketplaceListing listing) async {
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
    if (mounted && sent == true) {
      _message('Listing sent.');
    }
  }

  Future<void> _showShareOptions(MarketplaceListing listing) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text(
                'Share Listing',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.auto_stories_outlined),
                title: const Text('Share to Story'),
                subtitle: const Text(
                  'Edit it in the existing Nubify Story editor',
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _shareToStory(listing);
                },
              ),
              ListTile(
                leading: const Icon(Icons.forum_outlined),
                title: const Text('Share to Chat'),
                subtitle: const Text('Choose direct messages or groups'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _shareToChat(listing);
                },
              ),
              ListTile(
                leading: const Icon(Icons.link_rounded),
                title: const Text('Copy Link'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _copyLink(listing);
                },
              ),
              ListTile(
                leading: const Icon(Icons.ios_share_rounded),
                title: const Text('Share to Other Apps'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _shareExternal(listing);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _reportListing(MarketplaceListing listing) async {
    String reason = MarketplaceConstants.reportReasons.first;
    final TextEditingController explanation = TextEditingController();
    final bool? submit = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) =>
            AlertDialog(
              title: const Text('Report Listing'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    DropdownButtonFormField<String>(
                      initialValue: reason,
                      decoration: const InputDecoration(
                        labelText: 'Reason',
                        border: OutlineInputBorder(),
                      ),
                      items: MarketplaceConstants.reportReasons
                          .map(
                            (String value) => DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (String? value) {
                        if (value != null) {
                          setDialogState(() => reason = value);
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: explanation,
                      maxLength: 1000,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: reason == 'Other'
                            ? 'Explanation (required)'
                            : 'Explanation (optional)',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (reason == 'Other' && explanation.text.trim().isEmpty) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text('Please add an explanation.'),
                        ),
                      );
                      return;
                    }
                    Navigator.pop(dialogContext, true);
                  },
                  child: const Text('Submit Report'),
                ),
              ],
            ),
      ),
    );
    final String details = explanation.text;
    explanation.dispose();
    if (submit != true) {
      return;
    }
    try {
      await _service.reportListing(
        listing: listing,
        reason: reason,
        explanation: details,
      );
      if (mounted) {
        _message('Report submitted for moderator review.');
      }
    } catch (error) {
      if (mounted) {
        _message(error.toString().replaceFirst('Bad state: ', ''));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MarketplaceListing?>(
      stream: _service.watchListing(widget.listingId),
      builder: (BuildContext context, AsyncSnapshot<MarketplaceListing?> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return _UnavailableListingView(
            message:
                'This listing is sold, unavailable, private, or you no longer have access to it.',
          );
        }
        final MarketplaceListing? listing = snapshot.data;
        if (listing == null) {
          return const _UnavailableListingView(
            message: 'This listing was removed or no longer exists.',
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
                    onPressed: () => _showShareOptions(listing),
                    icon: const Icon(Icons.share_outlined),
                  ),
                  if (owner)
                    PopupMenuButton<String>(
                      onSelected: (String value) =>
                          _ownerAction(listing, value),
                      itemBuilder: (_) => <PopupMenuEntry<String>>[
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('Edit Listing'),
                        ),
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
                  if (!owner && listing.isAvailable)
                    PopupMenuButton<String>(
                      onSelected: (String value) {
                        if (value == 'report') {
                          _reportListing(listing);
                        } else if (value == 'copy') {
                          _copyLink(listing);
                        }
                      },
                      itemBuilder: (_) => const <PopupMenuEntry<String>>[
                        PopupMenuItem(value: 'copy', child: Text('Copy Link')),
                        PopupMenuItem(
                          value: 'report',
                          child: Text('Report Listing'),
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
                              backgroundImage: listing.sellerPhotoUrl.isEmpty
                                  ? null
                                  : NetworkImage(listing.sellerPhotoUrl),
                              child: listing.sellerPhotoUrl.isEmpty
                                  ? const Icon(Icons.person_rounded)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  MarketplaceVerifiedSellerBadge(
                                    sellerId: listing.sellerId,
                                    fallbackText: 'Student Seller',
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Nubify Profile',
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      ProfileScreen(userId: listing.sellerId),
                                ),
                              ),
                              icon: const Icon(Icons.person_outline_rounded),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    MarketplaceMoreFromSeller(
                      sellerId: listing.sellerId,
                      currentListingId: listing.listingId,
                      onViewStore: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => MarketplaceSellerStoreScreen(
                            sellerId: listing.sellerId,
                          ),
                        ),
                      ),
                      onOpenListing: (MarketplaceListing other) =>
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => MarketplaceListingDetailsScreen(
                                listingId: other.listingId,
                              ),
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
                            icon: const Icon(Icons.chat_bubble_outline_rounded),
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
      if (action == 'edit') {
        await Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (_) =>
                CreateMarketplaceListingScreen(listingId: listing.listingId),
          ),
        );
      } else if (action == 'delete') {
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

class _UnavailableListingView extends StatelessWidget {
  const _UnavailableListingView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Listing')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  color: MarketplaceTheme.sky.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.storefront_outlined,
                  size: 42,
                  color: MarketplaceTheme.sky,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'No Longer Available',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
