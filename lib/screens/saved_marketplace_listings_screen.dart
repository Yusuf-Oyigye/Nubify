import 'dart:async';

import 'package:flutter/material.dart';

import '../models/marketplace_listing.dart';
import '../services/marketplace_service.dart';
import '../utils/marketplace_theme.dart';
import '../widgets/marketplace_listing_card.dart';
import 'marketplace_listing_details_screen.dart';

class SavedMarketplaceListingsScreen extends StatefulWidget {
  const SavedMarketplaceListingsScreen({super.key});

  @override
  State<SavedMarketplaceListingsScreen> createState() =>
      _SavedMarketplaceListingsScreenState();
}

class _SavedMarketplaceListingsScreenState
    extends State<SavedMarketplaceListingsScreen> {
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
    unawaited(_loadSaved(reset: true));
  }

  void _handleScroll() {
    if (_scrollController.position.extentAfter < 500) {
      unawaited(_loadSaved());
    }
  }

  Future<void> _loadSaved({bool reset = false}) async {
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
      final MarketplaceListingPage page = await _service.fetchSavedPage(
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
      if (page.hasMore && _listings.length < 6) {
        unawaited(_loadSaved());
      }
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

  void _savedChanged(MarketplaceListing listing, bool saved) {
    if (!saved) {
      setState(() {
        _listings = _listings
            .where(
              (MarketplaceListing item) => item.listingId != listing.listingId,
            )
            .toList(growable: false);
      });
      if (_hasMore && _listings.length < 6) {
        unawaited(_loadSaved());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saved Listings')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_listings.isEmpty && _loadError != null) {
      return _SavedState(
        icon: Icons.cloud_off_rounded,
        title: 'Saved listings could not load',
        message: _loadError.toString(),
        actionLabel: 'Try Again',
        onAction: () => unawaited(_loadSaved(reset: true)),
      );
    }
    if (_listings.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _loadSaved(reset: true),
        child: const CustomScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          slivers: <Widget>[
            SliverFillRemaining(
              hasScrollBody: false,
              child: _SavedState(
                icon: Icons.favorite_border_rounded,
                title: 'No saved listings yet',
                message: 'Tap the heart on a listing to keep it here.',
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      children: <Widget>[
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _loadSaved(reset: true),
            child: GridView.builder(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(14),
              itemCount: _listings.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.69,
              ),
              itemBuilder: (BuildContext context, int index) {
                final MarketplaceListing listing = _listings[index];
                return Opacity(
                  opacity: listing.isAvailable ? 1 : 0.55,
                  child: MarketplaceListingCard(
                    key: ValueKey<String>(listing.listingId),
                    listing: listing,
                    saved: true,
                    onSavedChanged: (bool saved) =>
                        _savedChanged(listing, saved),
                    onOpen: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => MarketplaceListingDetailsScreen(
                          listingId: listing.listingId,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        if (_loadingMore)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 6, 16, 20),
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else if (_loadError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: TextButton.icon(
              onPressed: () => unawaited(_loadSaved()),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Could not load more — retry'),
            ),
          )
        else if (!_hasMore)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 20),
            child: Text('You reached the end of Saved Listings.'),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}

class _SavedState extends StatelessWidget {
  const _SavedState({
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
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 62, color: MarketplaceTheme.sky),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
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
