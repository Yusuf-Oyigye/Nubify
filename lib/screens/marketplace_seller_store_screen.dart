import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/marketplace_listing.dart';
import '../services/chat_sevice.dart';
import '../services/marketplace_service.dart';
import '../utils/marketplace_theme.dart';
import '../widgets/marketplace_listing_card.dart';
import 'conversation_screen.dart';
import 'marketplace_listing_details_screen.dart';
import 'profile_screen.dart';

class MarketplaceSellerStoreScreen extends StatefulWidget {
  const MarketplaceSellerStoreScreen({super.key, required this.sellerId});

  final String sellerId;

  @override
  State<MarketplaceSellerStoreScreen> createState() =>
      _MarketplaceSellerStoreScreenState();
}

class _MarketplaceSellerStoreScreenState
    extends State<MarketplaceSellerStoreScreen> {
  final MarketplaceService _service = MarketplaceService();
  final ChatService _chat = ChatService();
  final ScrollController _scrollController = ScrollController();
  List<MarketplaceListing> _listings = const <MarketplaceListing>[];
  MarketplaceListingPage? _lastPage;
  Object? _loadError;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _openingChat = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    unawaited(_loadListings(reset: true));
  }

  @override
  void didUpdateWidget(covariant MarketplaceSellerStoreScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sellerId != widget.sellerId) {
      unawaited(_loadListings(reset: true));
    }
  }

  void _handleScroll() {
    if (_scrollController.position.extentAfter < 600) {
      unawaited(_loadListings());
    }
  }

  Future<void> _loadListings({bool reset = false}) async {
    if (reset) {
      _generation += 1;
      setState(() {
        _loading = true;
        _loadingMore = false;
        _hasMore = true;
        _loadError = null;
        _lastPage = null;
      });
    } else if (_loading || _loadingMore || !_hasMore) {
      return;
    } else {
      setState(() {
        _loadingMore = true;
        _loadError = null;
      });
    }

    final int generation = _generation;
    try {
      final MarketplaceListingPage page = await _service.fetchAvailablePage(
        sellerId: widget.sellerId,
        after: reset ? null : _lastPage?.lastDocument,
      );
      if (!mounted || generation != _generation) {
        return;
      }
      final Set<String> existingIds = _listings
          .map((MarketplaceListing item) => item.listingId)
          .toSet();
      setState(() {
        _listings = reset
            ? page.listings
            : <MarketplaceListing>[
                ..._listings,
                ...page.listings.where(
                  (MarketplaceListing item) => existingIds.add(item.listingId),
                ),
              ];
        _lastPage = page;
        _hasMore = page.hasMore;
        _loading = false;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted || generation != _generation) {
        return;
      }
      setState(() {
        _loadError = error;
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _messageSeller(Map<String, dynamic> profile) async {
    final String currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (_openingChat || currentUid.isEmpty || currentUid == widget.sellerId) {
      return;
    }
    setState(() => _openingChat = true);
    try {
      await _chat.ensureConversationExists(widget.sellerId);
      if (!mounted) {
        return;
      }
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ConversationScreen(
            otherUserId: widget.sellerId,
            otherName:
                (profile['fullName'] ?? profile['username'] ?? 'Student Seller')
                    .toString(),
            otherUsername: (profile['username'] ?? '').toString(),
            otherPhotoUrl: (profile['photoUrl'] ?? '').toString(),
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _openingChat = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool owner =
        FirebaseAuth.instance.currentUser?.uid == widget.sellerId;
    return Scaffold(
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.sellerId)
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
              return RefreshIndicator(
                onRefresh: () => _loadListings(reset: true),
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: <Widget>[
                    SliverAppBar.large(
                      pinned: true,
                      expandedHeight: 290,
                      title: Text(name),
                      flexibleSpace: FlexibleSpaceBar(
                        background: Container(
                          decoration: const BoxDecoration(
                            gradient: MarketplaceTheme.heroGradient,
                          ),
                          child: SafeArea(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                42,
                                20,
                                18,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: <Widget>[
                                  CircleAvatar(
                                    radius: 44,
                                    backgroundImage: photo.isEmpty
                                        ? null
                                        : NetworkImage(photo),
                                    child: photo.isEmpty
                                        ? const Icon(
                                            Icons.person_rounded,
                                            size: 42,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: <Widget>[
                                      Flexible(
                                        child: Text(
                                          name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 20,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  _SellerListingCount(
                                    sellerId: widget.sellerId,
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () => Navigator.push(
                                            context,
                                            MaterialPageRoute<void>(
                                              builder: (_) => ProfileScreen(
                                                userId: widget.sellerId,
                                              ),
                                            ),
                                          ),
                                          icon: const Icon(
                                            Icons.person_outline_rounded,
                                          ),
                                          label: const Text('Nubify Profile'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.white,
                                          ),
                                        ),
                                      ),
                                      if (!owner) ...<Widget>[
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: FilledButton.icon(
                                            onPressed: _openingChat
                                                ? null
                                                : () => _messageSeller(profile),
                                            icon: _openingChat
                                                ? const SizedBox.square(
                                                    dimension: 16,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                        ),
                                                  )
                                                : const Icon(
                                                    Icons.chat_bubble_outline,
                                                  ),
                                            label: const Text('Message Seller'),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_loading)
                      const SliverFillRemaining(
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_listings.isEmpty && _loadError != null)
                      SliverFillRemaining(
                        child: _StoreState(
                          icon: Icons.cloud_off_rounded,
                          title: 'No available listings yet',
                          message:
                              'This seller has no Marketplace item showing right now.',
                          actionLabel: 'Try Again',
                          onAction: () => unawaited(_loadListings(reset: true)),
                        ),
                      )
                    else if (_listings.isEmpty)
                      const SliverFillRemaining(
                        child: _StoreState(
                          icon: Icons.storefront_outlined,
                          title: 'No available listings',
                          message:
                              'This seller does not have a public item or service right now.',
                        ),
                      )
                    else
                      StreamBuilder<Set<String>>(
                        stream: _service.watchSavedIds(),
                        builder:
                            (
                              BuildContext context,
                              AsyncSnapshot<Set<String>> saved,
                            ) {
                              return SliverPadding(
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  14,
                                  14,
                                  8,
                                ),
                                sliver: SliverGrid.builder(
                                  itemCount: _listings.length,
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        mainAxisSpacing: 12,
                                        crossAxisSpacing: 12,
                                        childAspectRatio: 0.69,
                                      ),
                                  itemBuilder: (BuildContext context, int index) {
                                    final MarketplaceListing listing =
                                        _listings[index];
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
                      ),
                    if (_listings.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                          child: Center(
                            child: _loadingMore
                                ? const CircularProgressIndicator(
                                    strokeWidth: 2,
                                  )
                                : _loadError != null
                                ? TextButton.icon(
                                    onPressed: () => unawaited(_loadListings()),
                                    icon: const Icon(Icons.refresh_rounded),
                                    label: const Text(
                                      'Could not load more — retry',
                                    ),
                                  )
                                : !_hasMore
                                ? const Text(
                                    'You reached the end of this store.',
                                  )
                                : const SizedBox(height: 20),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}

class _SellerListingCount extends StatelessWidget {
  const _SellerListingCount({required this.sellerId});

  final String sellerId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('marketplaceSellerStats')
          .doc(sellerId)
          .snapshots(),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
          ) {
            final dynamic raw = snapshot.data?.data()?['availableListingCount'];
            final int count = raw is num ? raw.toInt() : 0;
            return Text(
              '$count available ${count == 1 ? 'listing' : 'listings'}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            );
          },
    );
  }
}

class _StoreState extends StatelessWidget {
  const _StoreState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 58, color: MarketplaceTheme.sky),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...<Widget>[
              const SizedBox(height: 12),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
