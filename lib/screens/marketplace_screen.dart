import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/marketplace_listing.dart';
import '../services/marketplace_service.dart';
import '../services/seller_verification_service.dart';
import '../utils/marketplace_constants.dart';
import '../utils/marketplace_motion.dart';
import '../utils/marketplace_theme.dart';
import '../widgets/marketplace_listing_card.dart';
import 'campus_sellers_screen.dart';
import 'chat_screen.dart';
import 'marketplace_listing_details_screen.dart';
import 'marketplace_search_screen.dart';
import 'marketplace_seller_store_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'saved_marketplace_listings_screen.dart';
import 'seller_verification_screen.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key, this.initialProductId = ''});

  final String initialProductId;

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  final MarketplaceService _service = MarketplaceService();
  final ScrollController _scrollController = ScrollController();
  bool _openedInitialListing = false;
  List<MarketplaceListing> _freshListings = const <MarketplaceListing>[];
  MarketplaceListingPage? _freshLastPage;
  Object? _freshError;
  bool _loadingFresh = true;
  bool _loadingMoreFresh = false;
  bool _hasMoreFresh = true;
  int _freshGeneration = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    unawaited(_loadFreshListings(reset: true));
    WidgetsBinding.instance.addPostFrameCallback((_) => _openInitialListing());
  }

  void _handleScroll() {
    if (_scrollController.position.extentAfter < 700) {
      unawaited(_loadFreshListings());
    }
  }

  Future<void> _loadFreshListings({bool reset = false}) async {
    if (reset) {
      _freshGeneration += 1;
      setState(() {
        _loadingFresh = true;
        _loadingMoreFresh = false;
        _hasMoreFresh = true;
        _freshError = null;
        _freshLastPage = null;
      });
    } else if (_loadingFresh || _loadingMoreFresh || !_hasMoreFresh) {
      return;
    } else {
      setState(() {
        _loadingMoreFresh = true;
        _freshError = null;
      });
    }

    final int generation = _freshGeneration;
    try {
      final MarketplaceListingPage page = await _service.fetchAvailablePage(
        after: reset ? null : _freshLastPage?.lastDocument,
      );
      if (!mounted || generation != _freshGeneration) {
        return;
      }
      final Set<String> existingIds = _freshListings
          .map((MarketplaceListing item) => item.listingId)
          .toSet();
      setState(() {
        _freshListings = reset
            ? page.listings
            : <MarketplaceListing>[
                ..._freshListings,
                ...page.listings.where(
                  (MarketplaceListing item) => existingIds.add(item.listingId),
                ),
              ];
        _freshLastPage = page;
        _hasMoreFresh = page.hasMore;
        _loadingFresh = false;
        _loadingMoreFresh = false;
      });
    } catch (error) {
      if (!mounted || generation != _freshGeneration) {
        return;
      }
      setState(() {
        _freshError = error;
        _loadingFresh = false;
        _loadingMoreFresh = false;
      });
    }
  }

  void _openInitialListing() {
    if (!mounted ||
        _openedInitialListing ||
        widget.initialProductId.trim().isEmpty) {
      return;
    }
    _openedInitialListing = true;
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => MarketplaceListingDetailsScreen(
          listingId: widget.initialProductId.trim(),
        ),
      ),
    );
  }

  Future<void> _startSelling() async {
    final verification = await SellerVerificationService().getMine();
    if (!mounted) {
      return;
    }
    if (verification.isApproved) {
      Navigator.pushNamed(context, '/marketplace/create');
    } else {
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => const SellerVerificationScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final String currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'NUB Marketplace',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            Text(
              'Discover. Connect. Trade.',
              style: TextStyle(fontSize: 10, color: MarketplaceTheme.sky),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Saved Listings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const SavedMarketplaceListingsScreen(),
              ),
            ),
            icon: const Icon(Icons.favorite_border_rounded),
          ),
          IconButton(
            tooltip: 'Chats',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const ChatScreen()),
            ),
            icon: const Icon(Icons.chat_bubble_outline_rounded),
          ),
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const NotificationsScreen(),
              ),
            ),
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          _ProfileAction(uid: currentUid),
          const SizedBox(width: 6),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadFreshListings(reset: true),
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: <Widget>[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              sliver: SliverToBoxAdapter(
                child: _HeroBanner(onSell: _startSelling),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
              sliver: SliverToBoxAdapter(
                child: InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const MarketplaceSearchScreen(),
                    ),
                  ),
                  borderRadius: BorderRadius.circular(18),
                  child: Ink(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: MarketplaceTheme.softSurface(context),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: const Row(
                      children: <Widget>[
                        Icon(Icons.search_rounded, color: MarketplaceTheme.sky),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text('Search products, services, or sellers…'),
                        ),
                        Icon(Icons.tune_rounded),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: _SectionHeading(
                title: 'Browse Categories',
                subtitle: 'Find exactly what campus has to offer',
              ),
            ),
            const SliverToBoxAdapter(child: _CategoriesStrip()),
            SliverToBoxAdapter(
              child: _SectionHeading(
                title: 'Campus Sellers',
                subtitle: 'Approved students with available listings',
                action: TextButton(onPressed: null, child: Text('')),
              ),
            ),
            SliverToBoxAdapter(
              child: Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const CampusSellersScreen(),
                      ),
                    ),
                    child: const Text('View All Sellers'),
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: _CampusSellerStrip()),
            const SliverToBoxAdapter(
              child: _SectionHeading(
                title: 'Fresh Listings',
                subtitle: 'Newest available items and services',
              ),
            ),
            if (_loadingFresh)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(36),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (_freshListings.isEmpty && _freshError != null)
              SliverToBoxAdapter(
                child: _MarketplaceState(
                  icon: Icons.cloud_off_rounded,
                  title: 'Listings could not load',
                  message: _freshError.toString(),
                  actionLabel: 'Try Again',
                  onAction: () => unawaited(_loadFreshListings(reset: true)),
                ),
              )
            else if (_freshListings.isEmpty)
              const SliverToBoxAdapter(
                child: _MarketplaceState(
                  icon: Icons.storefront_outlined,
                  title: 'Campus Marketplace is ready',
                  message:
                      'Approved sellers can publish the first real listing.',
                ),
              )
            else
              StreamBuilder<Set<String>>(
                stream: _service.watchSavedIds(),
                builder:
                    (BuildContext context, AsyncSnapshot<Set<String>> saved) {
                      return SliverPadding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                        sliver: SliverGrid.builder(
                          itemCount: _freshListings.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 0.69,
                              ),
                          itemBuilder: (BuildContext context, int index) {
                            final MarketplaceListing listing =
                                _freshListings[index];
                            return MarketplaceListingCard(
                              listing: listing,
                              saved:
                                  saved.data?.contains(listing.listingId) ??
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
            if (_freshListings.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 110),
                  child: Center(
                    child: _loadingMoreFresh
                        ? const CircularProgressIndicator(strokeWidth: 2)
                        : _freshError != null
                        ? TextButton.icon(
                            onPressed: () => unawaited(_loadFreshListings()),
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Could not load more — retry'),
                          )
                        : !_hasMoreFresh
                        ? const Text('You have reached the latest listings.')
                        : const SizedBox(height: 24),
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _startSelling,
        backgroundColor: MarketplaceTheme.sky,
        foregroundColor: MarketplaceTheme.midnight,
        icon: const Icon(Icons.add_business_rounded),
        label: const Text(
          'Sell',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.onSell});

  final VoidCallback onSell;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: MarketplaceMotion.duration(context, MarketplaceMotion.screen),
      curve: MarketplaceMotion.enterCurve,
      builder: (BuildContext context, double value, Widget? child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - value)),
          child: child,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: MarketplaceTheme.heroGradient,
          borderRadius: BorderRadius.circular(28),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: MarketplaceTheme.sky.withValues(alpha: 0.18),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: MarketplaceTheme.copper.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: MarketplaceTheme.copper.withValues(alpha: 0.5),
                ),
              ),
              child: const Text(
                'FOR NAHDA UNIVERSITY STUDENTS',
                style: TextStyle(
                  color: MarketplaceTheme.ivory,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.7,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Good finds.\nReal campus sellers.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 29,
                height: 1.05,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Discover products and services, then connect directly with verified student sellers.',
              style: TextStyle(color: Colors.white70, height: 1.4),
            ),
            const SizedBox(height: 18),
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onSell,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Sell Something'),
                    style: FilledButton.styleFrom(
                      backgroundColor: MarketplaceTheme.sky,
                      foregroundColor: MarketplaceTheme.midnight,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  tooltip: 'Explore sellers',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const CampusSellersScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.groups_2_outlined),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoriesStrip extends StatelessWidget {
  const _CategoriesStrip();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 112,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: MarketplaceConstants.categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (BuildContext context, int index) {
          final MarketplaceCategory category =
              MarketplaceConstants.categories[index];
          return InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) =>
                    MarketplaceSearchScreen(initialCategory: category.id),
              ),
            ),
            child: Ink(
              width: 105,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _categoryColor(index).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _categoryColor(index).withValues(alpha: 0.32),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    _categoryIcon(category.id),
                    color: _categoryColor(index),
                  ),
                  const Spacer(),
                  Text(
                    category.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('marketplaceCategoryStats')
                        .doc(category.id)
                        .snapshots(),
                    builder:
                        (
                          BuildContext context,
                          AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>>
                          snapshot,
                        ) {
                          final dynamic raw = snapshot.data
                              ?.data()?['availableListingCount'];
                          final int count = raw is num ? raw.toInt() : 0;
                          return Text(
                            '$count available',
                            style: TextStyle(
                              fontSize: 9,
                              color: MarketplaceTheme.mutedText(context),
                            ),
                          );
                        },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CampusSellerStrip extends StatelessWidget {
  const _CampusSellerStrip();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 142,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('marketplaceSellerStats')
            .where('active', isEqualTo: true)
            .orderBy('availableListingCount', descending: true)
            .limit(10)
            .snapshots(),
        builder:
            (
              BuildContext context,
              AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
            ) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                );
              }
              final docs =
                  snapshot.data?.docs ??
                  const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
              if (docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 18),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Approved sellers with available listings will appear here.',
                    ),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: docs.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (BuildContext context, int index) {
                  final data = docs[index].data();
                  final String sellerId = (data['sellerId'] ?? docs[index].id)
                      .toString();
                  return InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            MarketplaceSellerStoreScreen(sellerId: sellerId),
                      ),
                    ),
                    child: Ink(
                      width: 126,
                      padding: const EdgeInsets.all(12),
                      decoration: MarketplaceTheme.premiumCard(context),
                      child: Column(
                        children: <Widget>[
                          CircleAvatar(
                            radius: 30,
                            backgroundImage:
                                (data['sellerPhotoUrl'] ?? '')
                                    .toString()
                                    .isEmpty
                                ? null
                                : NetworkImage(
                                    data['sellerPhotoUrl'].toString(),
                                  ),
                            child:
                                (data['sellerPhotoUrl'] ?? '')
                                    .toString()
                                    .isEmpty
                                ? const Icon(Icons.person_rounded)
                                : null,
                          ),
                          const SizedBox(height: 7),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Flexible(
                                child: Text(
                                  (data['sellerName'] ?? 'Student seller')
                                      .toString(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              if (data['verifiedSeller'] == true) ...<Widget>[
                                const SizedBox(width: 3),
                                const Icon(
                                  Icons.verified_rounded,
                                  size: 14,
                                  color: MarketplaceTheme.sky,
                                ),
                              ],
                            ],
                          ),
                          Text(
                            '${data['availableListingCount'] ?? 0} listings',
                            style: TextStyle(
                              fontSize: 9,
                              color: MarketplaceTheme.mutedText(context),
                            ),
                          ),
                        ],
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

class _ProfileAction extends StatelessWidget {
  const _ProfileAction({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) {
      return const SizedBox.shrink();
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
          ) {
            final String photoUrl = (snapshot.data?.data()?['photoUrl'] ?? '')
                .toString();
            return GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => ProfileScreen(userId: uid),
                ),
              ),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: MarketplaceTheme.sky.withValues(alpha: 0.2),
                backgroundImage: photoUrl.isEmpty
                    ? null
                    : NetworkImage(photoUrl),
                child: photoUrl.isEmpty
                    ? const Icon(
                        Icons.person_rounded,
                        size: 18,
                        color: MarketplaceTheme.sky,
                      )
                    : null,
              ),
            );
          },
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.subtitle,
    this.action,
  });

  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 12, 12),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: MarketplaceTheme.mutedText(context),
                  ),
                ),
              ],
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

class _MarketplaceState extends StatelessWidget {
  const _MarketplaceState({
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
    return Padding(
      padding: const EdgeInsets.all(36),
      child: Column(
        children: <Widget>[
          Icon(icon, size: 55, color: MarketplaceTheme.sky),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          Text(message, textAlign: TextAlign.center),
          if (actionLabel != null && onAction != null) ...<Widget>[
            const SizedBox(height: 12),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

IconData _categoryIcon(String id) {
  switch (id) {
    case 'rent_housing':
      return Icons.home_work_outlined;
    case 'food_snacks':
      return Icons.restaurant_outlined;
    case 'electrical_gadgets':
      return Icons.devices_other_outlined;
    case 'textbooks_books':
      return Icons.menu_book_rounded;
    case 'medical_laboratory':
      return Icons.biotech_outlined;
    case 'printing_photocopying':
      return Icons.print_outlined;
    case 'clothes_fashion':
      return Icons.checkroom_outlined;
    case 'furniture_room':
      return Icons.chair_outlined;
    case 'watches_accessories':
      return Icons.watch_outlined;
    case 'student_services':
      return Icons.design_services_outlined;
    case 'beauty_personal_care':
      return Icons.spa_outlined;
    default:
      return Icons.grid_view_rounded;
  }
}

Color _categoryColor(int index) {
  const List<Color> colors = <Color>[
    MarketplaceTheme.sky,
    MarketplaceTheme.copper,
    MarketplaceTheme.gold,
    MarketplaceTheme.emerald,
    MarketplaceTheme.plum,
  ];
  return colors[index % colors.length];
}
