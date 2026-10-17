import 'dart:async';

import 'package:flutter/material.dart';

import '../models/marketplace_listing.dart';
import '../services/marketplace_service.dart';
import '../utils/marketplace_theme.dart';
import 'create_marketplace_listing_screen.dart';
import 'marketplace_listing_details_screen.dart';

class MyMarketplaceListingsScreen extends StatefulWidget {
  const MyMarketplaceListingsScreen({super.key});

  @override
  State<MyMarketplaceListingsScreen> createState() =>
      _MyMarketplaceListingsScreenState();
}

class _MyMarketplaceListingsScreenState
    extends State<MyMarketplaceListingsScreen> {
  static const List<String> _statuses = <String>[
    'available',
    'sold',
    'unavailable',
    'draft',
    'archived',
  ];
  final MarketplaceService _service = MarketplaceService();
  Map<String, int> _counts = const <String, int>{};
  int _countGeneration = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_loadCounts());
  }

  Future<void> _loadCounts() async {
    final int generation = ++_countGeneration;
    try {
      final Map<String, int> values = await _service.myListingCounts();
      if (!mounted || generation != _countGeneration) {
        return;
      }
      setState(() => _counts = values);
    } catch (_) {
      // Each status tab still loads independently and displays its own error.
    }
  }

  String _tabLabel(String status) {
    final String name = switch (status) {
      'available' => 'Available',
      'sold' => 'Sold',
      'unavailable' => 'Unavailable',
      'draft' => 'Drafts',
      _ => 'Archived',
    };
    final int? count = _counts[status];
    return count == null ? name : '$name ($count)';
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Listings'),
          bottom: TabBar(
            isScrollable: true,
            tabs: <Widget>[
              for (final String status in _statuses)
                Tab(text: _tabLabel(status)),
            ],
          ),
        ),
        body: TabBarView(
          children: <Widget>[
            for (final String status in _statuses)
              _ListingStatusTab(status: status, onChanged: _loadCounts),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            await Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const CreateMarketplaceListingScreen(),
              ),
            );
            unawaited(_loadCounts());
          },
          icon: const Icon(Icons.add_rounded),
          label: const Text('New Listing'),
        ),
      ),
    );
  }
}

class _ListingStatusTab extends StatefulWidget {
  const _ListingStatusTab({required this.status, required this.onChanged});

  final String status;
  final VoidCallback onChanged;

  @override
  State<_ListingStatusTab> createState() => _ListingStatusTabState();
}

class _ListingStatusTabState extends State<_ListingStatusTab>
    with AutomaticKeepAliveClientMixin<_ListingStatusTab> {
  final MarketplaceService _service = MarketplaceService();
  final ScrollController _scrollController = ScrollController();
  List<MarketplaceListing> _listings = const <MarketplaceListing>[];
  MarketplaceListingPage? _lastPage;
  Object? _loadError;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    unawaited(_loadListings(reset: true));
  }

  @override
  void didUpdateWidget(covariant _ListingStatusTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      unawaited(_loadListings(reset: true));
    }
  }

  void _handleScroll() {
    if (_scrollController.position.extentAfter < 450) {
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
      final MarketplaceListingPage page = await _service.fetchMinePage(
        status: widget.status,
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

  void _listingChanged() {
    widget.onChanged();
    unawaited(_loadListings(reset: true));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_listings.isEmpty && _loadError != null) {
      return _EmptyStatus(
        status: widget.status,
        error: _loadError,
        onRetry: () => unawaited(_loadListings(reset: true)),
      );
    }
    if (_listings.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _loadListings(reset: true),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: <Widget>[
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyStatus(status: widget.status),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _loadListings(reset: true),
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
        itemCount: _listings.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (BuildContext context, int index) {
          if (index == _listings.length) {
            return Center(
              child: _loadingMore
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : _loadError != null
                  ? TextButton.icon(
                      onPressed: () => unawaited(_loadListings()),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Could not load more — retry'),
                    )
                  : !_hasMore
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('End of this section.'),
                    )
                  : const SizedBox(height: 24),
            );
          }
          return _OwnerListingTile(
            listing: _listings[index],
            onChanged: _listingChanged,
          );
        },
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}

class _OwnerListingTile extends StatefulWidget {
  const _OwnerListingTile({required this.listing, required this.onChanged});

  final MarketplaceListing listing;
  final VoidCallback onChanged;

  @override
  State<_OwnerListingTile> createState() => _OwnerListingTileState();
}

class _OwnerListingTileState extends State<_OwnerListingTile> {
  final MarketplaceService _service = MarketplaceService();
  bool _working = false;

  Future<void> _action(String value) async {
    if (_working) {
      return;
    }
    if (value == 'view') {
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => MarketplaceListingDetailsScreen(
            listingId: widget.listing.listingId,
          ),
        ),
      );
      widget.onChanged();
      return;
    }
    if (value == 'edit') {
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => CreateMarketplaceListingScreen(
            listingId: widget.listing.listingId,
          ),
        ),
      );
      widget.onChanged();
      return;
    }
    if (value == 'delete') {
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: const Text('Delete this listing?'),
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
      if (confirmed != true) {
        return;
      }
    }
    setState(() => _working = true);
    try {
      if (value == 'publish') {
        await _service.publish(widget.listing.listingId);
      } else if (value == 'delete') {
        await _service.deleteListing(widget.listing);
      } else {
        await _service.updateStatus(widget.listing.listingId, value);
      }
      widget.onChanged();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _working = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final MarketplaceListing listing = widget.listing;
    return Material(
      color: MarketplaceTheme.surface(context),
      borderRadius: BorderRadius.circular(18),
      child: ListTile(
        contentPadding: const EdgeInsets.all(10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: Theme.of(context).dividerColor),
        ),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: SizedBox(
            width: 68,
            height: 68,
            child: listing.coverUrl.isEmpty
                ? const ColoredBox(
                    color: MarketplaceTheme.navy,
                    child: Icon(
                      Icons.storefront_rounded,
                      color: MarketplaceTheme.sky,
                    ),
                  )
                : Image.network(listing.coverUrl, fit: BoxFit.cover),
          ),
        ),
        title: Text(
          listing.title.isEmpty ? 'Untitled draft' : listing.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              listing.priceType.isEmpty ? 'Price not set' : listing.priceLabel,
            ),
            Text(
              listing.status.toUpperCase(),
              style: const TextStyle(
                color: MarketplaceTheme.sky,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        trailing: _working
            ? const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : PopupMenuButton<String>(
                onSelected: _action,
                itemBuilder: (_) => _actions(listing),
              ),
        onTap: () => _action('view'),
      ),
    );
  }

  List<PopupMenuEntry<String>> _actions(MarketplaceListing listing) {
    return <PopupMenuEntry<String>>[
      const PopupMenuItem(value: 'view', child: Text('View Details')),
      const PopupMenuItem(value: 'edit', child: Text('Edit Listing')),
      if (listing.status == 'draft')
        const PopupMenuItem(value: 'publish', child: Text('Publish Draft')),
      if (listing.status == 'available') ...<PopupMenuEntry<String>>[
        const PopupMenuItem(value: 'sold', child: Text('Mark Sold')),
        const PopupMenuItem(
          value: 'unavailable',
          child: Text('Mark Unavailable'),
        ),
      ],
      if (listing.status == 'unavailable' || listing.status == 'archived')
        const PopupMenuItem(
          value: 'available',
          child: Text('Restore Available'),
        ),
      if (listing.status != 'archived')
        const PopupMenuItem(value: 'archived', child: Text('Archive')),
      const PopupMenuDivider(),
      const PopupMenuItem(value: 'delete', child: Text('Delete')),
    ];
  }
}

class _EmptyStatus extends StatelessWidget {
  const _EmptyStatus({required this.status, this.error, this.onRetry});

  final String status;
  final Object? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              error == null
                  ? Icons.inventory_2_outlined
                  : Icons.cloud_off_rounded,
              size: 60,
              color: MarketplaceTheme.sky,
            ),
            const SizedBox(height: 14),
            Text(
              error == null
                  ? 'No ${status == 'draft' ? 'drafts' : '$status listings'}'
                  : 'Unable to load listings',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              error != null
                  ? error.toString()
                  : status == 'available'
                  ? 'Published listings will appear here.'
                  : 'This section is currently empty.',
              textAlign: TextAlign.center,
            ),
            if (error != null && onRetry != null) ...<Widget>[
              const SizedBox(height: 12),
              FilledButton(onPressed: onRetry, child: const Text('Try Again')),
            ],
          ],
        ),
      ),
    );
  }
}
