import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
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
  Future<Map<String, int>>? _ownerCountsFuture;
  Object? _loadError;
  String _selectedStatus = 'available';
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _openingChat = false;
  int _generation = 0;

  bool get _isOwner =>
      FirebaseAuth.instance.currentUser?.uid == widget.sellerId;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _resetOwnerCounts();
    unawaited(_loadListings(reset: true));
  }

  @override
  void didUpdateWidget(covariant MarketplaceSellerStoreScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sellerId != widget.sellerId) {
      _selectedStatus = 'available';
      _resetOwnerCounts();
      unawaited(_loadListings(reset: true));
    }
  }

  void _resetOwnerCounts() {
    _ownerCountsFuture = _isOwner ? _service.myListingCounts() : null;
  }

  void _handleScroll() {
    if (_scrollController.position.extentAfter < 600) {
      unawaited(_loadListings());
    }
  }

  Future<void> _refresh() async {
    setState(_resetOwnerCounts);
    await _loadListings(reset: true);
  }

  Future<void> _selectStatus(String status) async {
    if (_selectedStatus == status) {
      return;
    }
    setState(() => _selectedStatus = status);
    await _loadListings(reset: true);
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
      final MarketplaceListingPage page = _selectedStatus == 'available'
          ? await _service.fetchAvailablePage(
              sellerId: widget.sellerId,
              after: reset ? null : _lastPage?.lastDocument,
            )
          : await _service.fetchSellerStorePage(
              sellerId: widget.sellerId,
              status: 'sold',
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
    unawaited(
      _chat.ensureConversationExists(widget.sellerId).catchError((
        Object error,
      ) {
        debugPrint('Seller-store conversation preparation failed: $error');
      }),
    );
    if (!mounted) {
      return;
    }
    setState(() => _openingChat = false);
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
  }

  void _openProfile() {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ProfileScreen(userId: widget.sellerId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Seller profile',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
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
              return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('marketplaceSellerStats')
                    .doc(widget.sellerId)
                    .snapshots(),
                builder:
                    (
                      BuildContext context,
                      AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>>
                      statsSnapshot,
                    ) {
                      return FutureBuilder<Map<String, int>>(
                        future: _ownerCountsFuture,
                        builder:
                            (
                              BuildContext context,
                              AsyncSnapshot<Map<String, int>> ownerCounts,
                            ) {
                              final Map<String, dynamic> stats =
                                  statsSnapshot.data?.data() ??
                                  <String, dynamic>{};
                              return RefreshIndicator(
                                onRefresh: _refresh,
                                child: CustomScrollView(
                                  controller: _scrollController,
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  slivers: <Widget>[
                                    SliverToBoxAdapter(
                                      child: _SellerProfileCard(
                                        profile: profile,
                                        stats: stats,
                                        ownerCounts: ownerCounts.data,
                                        loadedAvailableCount:
                                            _selectedStatus == 'available'
                                            ? _listings.length
                                            : 0,
                                        isOwner: _isOwner,
                                        openingChat: _openingChat,
                                        onMessage: () =>
                                            _messageSeller(profile),
                                        onProfile: _openProfile,
                                      ),
                                    ),
                                    SliverToBoxAdapter(
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          18,
                                          24,
                                          18,
                                          14,
                                        ),
                                        child: Row(
                                          children: <Widget>[
                                            Expanded(
                                              child: AnimatedSwitcher(
                                                duration: const Duration(
                                                  milliseconds: 220,
                                                ),
                                                child: Text(
                                                  _selectedStatus == 'available'
                                                      ? 'Available listings'
                                                      : 'Sold listings',
                                                  key: ValueKey<String>(
                                                    _selectedStatus,
                                                  ),
                                                  style: const TextStyle(
                                                    fontSize: 23,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            _StoreStatusSwitch(
                                              selected: _selectedStatus,
                                              onSelected: (String status) =>
                                                  unawaited(
                                                    _selectStatus(status),
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    ..._listingSlivers(),
                                  ],
                                ),
                              );
                            },
                      );
                    },
              );
            },
      ),
    );
  }

  List<Widget> _listingSlivers() {
    if (_loading) {
      return const <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    if (_listings.isEmpty) {
      return <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: _StoreState(
            icon: _loadError == null
                ? Icons.storefront_outlined
                : Icons.cloud_off_rounded,
            title: _selectedStatus == 'available'
                ? 'No available listings'
                : 'No sold listing yet',
            message: _loadError == null
                ? _selectedStatus == 'available'
                      ? 'This seller does not have a public item or service right now.'
                      : 'Items this seller marks as sold will appear here.'
                : 'The listings could not load right now. Pull down or try again.',
            actionLabel: _loadError == null ? null : 'Try Again',
            onAction: _loadError == null
                ? null
                : () => unawaited(_loadListings(reset: true)),
          ),
        ),
      ];
    }

    return <Widget>[
      StreamBuilder<Set<String>>(
        stream: _service.watchSavedIds(),
        builder: (BuildContext context, AsyncSnapshot<Set<String>> saved) {
          return SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            sliver: SliverGrid.builder(
              itemCount: _listings.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.69,
              ),
              itemBuilder: (BuildContext context, int index) {
                final MarketplaceListing listing = _listings[index];
                return MarketplaceListingCard(
                  listing: listing,
                  saved: saved.data?.contains(listing.listingId) ?? false,
                  onOpen: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => MarketplaceListingDetailsScreen(
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
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Center(
            child: _loadingMore
                ? const CircularProgressIndicator(strokeWidth: 2)
                : _loadError != null
                ? TextButton.icon(
                    onPressed: () => unawaited(_loadListings()),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Could not load more — retry'),
                  )
                : !_hasMore
                ? const Text('You reached the end of this store.')
                : const SizedBox(height: 20),
          ),
        ),
      ),
    ];
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}

class _SellerProfileCard extends StatelessWidget {
  const _SellerProfileCard({
    required this.profile,
    required this.stats,
    required this.ownerCounts,
    required this.loadedAvailableCount,
    required this.isOwner,
    required this.openingChat,
    required this.onMessage,
    required this.onProfile,
  });

  final Map<String, dynamic> profile;
  final Map<String, dynamic> stats;
  final Map<String, int>? ownerCounts;
  final int loadedAvailableCount;
  final bool isOwner;
  final bool openingChat;
  final VoidCallback onMessage;
  final VoidCallback onProfile;

  int _integer(Object? value) => value is num ? value.toInt() : 0;

  @override
  Widget build(BuildContext context) {
    final String name =
        (profile['fullName'] ?? profile['username'] ?? 'Student Seller')
            .toString();
    final String username = (profile['username'] ?? '').toString().trim();
    final String photo = (profile['photoUrl'] ?? '').toString().trim();

    int available =
        ownerCounts?['available'] ?? _integer(stats['availableListingCount']);
    if (loadedAvailableCount > available) {
      available = loadedAvailableCount;
    }
    final int sold =
        ownerCounts?['sold'] ?? _integer(stats['soldListingCount']);
    final int everListed = ownerCounts == null
        ? (_integer(stats['everListedCount']) > 0
              ? _integer(stats['everListedCount'])
              : available + sold)
        : available +
              sold +
              (ownerCounts?['unavailable'] ?? 0) +
              (ownerCounts?['archived'] ?? 0);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: MarketplaceTheme.premiumCard(
        context,
      ).copyWith(borderRadius: BorderRadius.circular(28)),
      child: Column(
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Hero(
                tag: 'marketplace-seller-avatar-${profile['uid'] ?? name}',
                child: CircleAvatar(
                  radius: 42,
                  backgroundColor: MarketplaceTheme.sky.withValues(alpha: 0.14),
                  backgroundImage: photo.isEmpty
                      ? null
                      : CachedNetworkImageProvider(photo),
                  child: photo.isEmpty
                      ? const Icon(Icons.person_rounded, size: 42)
                      : null,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 23,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      username.isEmpty
                          ? 'NUB Marketplace seller'
                          : '@$username',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: MarketplaceTheme.mutedText(context),
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: <Widget>[
              Expanded(
                child: _SellerMetric(value: available, label: 'Available'),
              ),
              Expanded(
                child: _SellerMetric(value: sold, label: 'Sold'),
              ),
              Expanded(
                child: _SellerMetric(value: everListed, label: 'Ever listed'),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: <Widget>[
              if (!isOwner) ...<Widget>[
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: openingChat ? null : onMessage,
                    icon: openingChat
                        ? const SizedBox.square(
                            dimension: 17,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chat_bubble_rounded),
                    label: const Text('Message seller'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                      backgroundColor: const Color(0xFF728273),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(17),
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onProfile,
                  icon: const Icon(Icons.person_outline_rounded),
                  label: Text(isOwner ? 'My profile' : 'Profile'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17),
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SellerMetric extends StatelessWidget {
  const _SellerMetric({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          '$value',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: MarketplaceTheme.mutedText(context),
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _StoreStatusSwitch extends StatelessWidget {
  const _StoreStatusSwitch({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: MarketplaceTheme.softSurface(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _StoreStatusButton(
            label: 'Available',
            selected: selected == 'available',
            onTap: () => onSelected('available'),
          ),
          _StoreStatusButton(
            label: 'Sold',
            selected: selected == 'sold',
            onTap: () => onSelected('sold'),
          ),
        ],
      ),
    );
  }
}

class _StoreStatusButton extends StatelessWidget {
  const _StoreStatusButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF728273) : Colors.transparent,
        borderRadius: BorderRadius.circular(21),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(21),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 10),
            child: Text(
              label,
              style: TextStyle(
                color: selected
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
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
            const SizedBox(height: 7),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: MarketplaceTheme.mutedText(context)),
            ),
            if (onAction != null && actionLabel != null) ...<Widget>[
              const SizedBox(height: 14),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
