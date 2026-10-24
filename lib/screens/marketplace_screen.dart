import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/marketplace_listing.dart';
import '../services/chat_sevice.dart';
import '../services/marketplace_service.dart';
import '../services/notification_service.dart';
import '../utils/marketplace_constants.dart';
import '../utils/marketplace_motion.dart';
import '../utils/marketplace_theme.dart';
import '../widgets/marketplace_listing_card.dart';
import 'campus_sellers_screen.dart';
import 'chat_screen.dart';
import 'marketplace_listing_details_screen.dart';
import 'marketplace_search_screen.dart';
import 'marketplace_seller_store_screen.dart';
import 'my_marketplace_listings_screen.dart';
import 'notifications_screen.dart';
import 'saved_marketplace_listings_screen.dart';

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
  late final Stream<Set<String>> _savedIdsStream;
  MarketplaceHomeDiscovery? _discovery;
  bool _loadingDiscovery = true;
  StreamSubscription<int>? _chatUnreadSubscription;
  StreamSubscription<int>? _notificationUnreadSubscription;
  int _chatUnreadCount = 0;
  int _notificationUnreadCount = 0;
  bool _chatBadgeAcknowledged = false;
  bool _notificationBadgeAcknowledged = false;

  @override
  void initState() {
    super.initState();
    _savedIdsStream = _service.watchSavedIds();
    final MarketplaceListingPage? cachedFresh = _service.cachedFreshPage;
    if (cachedFresh != null) {
      _freshListings = cachedFresh.listings;
      _freshLastPage = cachedFresh;
      _hasMoreFresh = cachedFresh.hasMore;
      _loadingFresh = false;
    }
    _discovery = _service.cachedHomeDiscovery;
    _loadingDiscovery = _discovery == null;
    _scrollController.addListener(_handleScroll);
    _chatUnreadSubscription = ChatService().totalUnreadCountStream().listen((
      int count,
    ) {
      if (!mounted) return;
      setState(() {
        if (count > _chatUnreadCount) _chatBadgeAcknowledged = false;
        _chatUnreadCount = count;
      });
    });
    _notificationUnreadSubscription = NotificationService()
        .unreadCountStream()
        .listen((int count) {
          if (!mounted) return;
          setState(() {
            if (count > _notificationUnreadCount) {
              _notificationBadgeAcknowledged = false;
            }
            _notificationUnreadCount = count;
          });
        });
    unawaited(_loadFreshListings(reset: true));
    unawaited(_loadDiscovery());
    WidgetsBinding.instance.addPostFrameCallback((_) => _openInitialListing());
  }

  void _handleScroll() {
    if (_scrollController.position.extentAfter < 700) {
      unawaited(_loadFreshListings());
    }
  }

  Widget _unreadDot({required Widget child, required bool visible}) {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        child,
        if (visible)
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: const Color(0xFFE53935),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.4),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _loadFreshListings({bool reset = false}) async {
    if (reset) {
      _freshGeneration += 1;
      setState(() {
        _loadingFresh = true;
        _loadingMoreFresh = false;
        _freshError = null;
        if (_freshListings.isEmpty) {
          _hasMoreFresh = true;
          _freshLastPage = null;
        }
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

  Future<void> _loadDiscovery() async {
    if (_discovery == null && mounted) {
      setState(() {
        _loadingDiscovery = true;
      });
    }
    try {
      final MarketplaceHomeDiscovery discovery = await _service
          .fetchHomeDiscovery();
      if (!mounted) {
        return;
      }
      setState(() {
        _discovery = discovery;
        _loadingDiscovery = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingDiscovery = false;
      });
    }
  }

  // A listing instantly qualifies its owner for the Campus Sellers preview.
  // Merge new sellers from real available listings with server statistics,
  // without depending on a separate seller-registration step.
  List<MarketplaceSellerSummary> get _visibleCampusSellers {
    final List<MarketplaceSellerSummary> authoritative =
        _discovery?.campusSellers ?? const <MarketplaceSellerSummary>[];
    final Map<String, MarketplaceSellerSummary> summaries =
        <String, MarketplaceSellerSummary>{};

    for (final MarketplaceListing listing in _freshListings) {
      if (!listing.isAvailable || listing.sellerId.isEmpty) continue;
      summaries.putIfAbsent(
        listing.sellerId,
        () => MarketplaceSellerSummary(
          sellerId: listing.sellerId,
          sellerName: listing.sellerName,
          sellerPhotoUrl: listing.sellerPhotoUrl,
          availableListingCount: 0,
          countVerified: false,
        ),
      );
    }
    for (final MarketplaceSellerSummary seller in authoritative) {
      if (seller.availableListingCount > 0) {
        summaries[seller.sellerId] = seller;
      }
    }
    return summaries.values.take(20).toList(growable: false);
  }

  Future<void> _refreshMarketplace() async {
    await Future.wait<void>(<Future<void>>[
      _loadFreshListings(reset: true),
      _loadDiscovery(),
    ]);
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
    if (!mounted) {
      return;
    }
    await Navigator.pushNamed(context, '/marketplace/create');
    if (mounted) {
      await _refreshMarketplace();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
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
          _MarketplaceHeaderAction(
            title: 'Saved Listings',
            label: 'Saved',
            color: Colors.redAccent,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const SavedMarketplaceListingsScreen(),
              ),
            ),
            child: const Icon(Icons.favorite_rounded, size: 20),
          ),
          _MarketplaceHeaderAction(
            title: 'Chats',
            label: 'Chat',
            color: MarketplaceTheme.sky,
            onPressed: () {
              setState(() => _chatBadgeAcknowledged = true);
              Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => const ChatScreen()),
              );
            },
            child: _unreadDot(
              visible: _chatUnreadCount > 0 && !_chatBadgeAcknowledged,
              child: const Icon(Icons.chat_bubble_rounded, size: 19),
            ),
          ),
          _MarketplaceHeaderAction(
            title: 'Notifications',
            label: 'Alerts',
            color: MarketplaceTheme.gold,
            onPressed: () {
              setState(() => _notificationBadgeAcknowledged = true);
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const NotificationsScreen(),
                ),
              );
            },
            child: _unreadDot(
              visible:
                  _notificationUnreadCount > 0 &&
                  !_notificationBadgeAcknowledged,
              child: CachedNetworkImage(
                imageUrl:
                    'https://img.icons8.com/?size=100&id=F5WMYjiT3vpJ&format=png&color=000000',
                width: 21,
                height: 21,
                fit: BoxFit.contain,
                errorWidget: (_, _, _) => const Icon(
                  Icons.notifications_rounded,
                  size: 20,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          _MarketplaceHeaderAction(
            title: 'My Listings',
            label: 'Mine',
            color: MarketplaceTheme.copper,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const MyMarketplaceListingsScreen(),
              ),
            ),
            child: const Icon(Icons.inventory_2_rounded, size: 19),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshMarketplace,
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
            SliverToBoxAdapter(
              child: _CategoriesStrip(
                counts: _discovery?.categoryCounts ?? const <String, int>{},
              ),
            ),
            SliverToBoxAdapter(
              child: _SectionHeading(
                title: 'Campus Sellers',
                subtitle: 'Students with available listings',
                action: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const CampusSellersScreen(),
                    ),
                  ),
                  child: const Text('View All'),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _CampusSellerStrip(
                sellers: _visibleCampusSellers,
                loading: _loadingDiscovery,
              ),
            ),
            const SliverToBoxAdapter(
              child: _SectionHeading(
                title: 'Fresh Listings',
                subtitle: 'Newest available items and services',
              ),
            ),
            if (_loadingFresh && _freshListings.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(36),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (_freshListings.isEmpty)
              const SliverToBoxAdapter(
                child: _MarketplaceState(
                  icon: Icons.storefront_outlined,
                  title: 'No fresh listings yet',
                  message: 'New Marketplace items will appear here.',
                ),
              )
            else
              StreamBuilder<Set<String>>(
                stream: _savedIdsStream,
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
    _chatUnreadSubscription?.cancel();
    _notificationUnreadSubscription?.cancel();
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
        padding: const EdgeInsets.all(18),
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
            const Text(
              'Good finds. Real sellers.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                height: 1.05,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Discover products and services, then connect directly with sellers.',
              style: TextStyle(color: Colors.white70, height: 1.4),
            ),
            const SizedBox(height: 14),
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
  const _CategoriesStrip({required this.counts});

  final Map<String, int> counts;

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
                  Icon(category.icon, color: _categoryColor(index)),
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
                  Text(
                    '${counts[category.id] ?? 0} available',
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
      ),
    );
  }
}

class _CampusSellerStrip extends StatelessWidget {
  const _CampusSellerStrip({required this.sellers, required this.loading});

  final List<MarketplaceSellerSummary> sellers;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: sellers.isEmpty ? 72 : 142,
      child: loading && sellers.isEmpty
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : sellers.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Align(
                alignment: Alignment.centerLeft,
                child: const Text('No campus sellers yet.'),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: sellers.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (BuildContext context, int index) {
                final MarketplaceSellerSummary seller = sellers[index];
                return InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => MarketplaceSellerStoreScreen(
                        sellerId: seller.sellerId,
                      ),
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
                          backgroundImage: seller.sellerPhotoUrl.isEmpty
                              ? null
                              : CachedNetworkImageProvider(
                                  seller.sellerPhotoUrl,
                                ),
                          child: seller.sellerPhotoUrl.isEmpty
                              ? const Icon(Icons.person_rounded)
                              : null,
                        ),
                        const SizedBox(height: 7),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Flexible(
                              child: Text(
                                seller.sellerName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          seller.countVerified
                              ? '${seller.availableListingCount} listings'
                              : 'New seller',
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
            ),
    );
  }
}

class _MarketplaceHeaderAction extends StatelessWidget {
  const _MarketplaceHeaderAction({
    required this.title,
    required this.label,
    required this.color,
    required this.onPressed,
    required this.child,
  });

  final String title;
  final String label;
  final Color color;
  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: title,
      child: SizedBox(
        width: 43,
        child: Semantics(
          button: true,
          label: title,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox(
                    width: 30,
                    height: 30,
                    child: IconTheme(
                      data: IconThemeData(color: color),
                      child: Center(child: child),
                    ),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: TextStyle(
                    color: color,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
  });

  final IconData icon;
  final String title;
  final String message;

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
        ],
      ),
    );
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
