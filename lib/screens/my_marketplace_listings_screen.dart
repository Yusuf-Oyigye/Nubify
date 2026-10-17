import 'package:flutter/material.dart';

import '../models/marketplace_listing.dart';
import '../services/marketplace_service.dart';
import '../utils/marketplace_theme.dart';
import 'create_marketplace_listing_screen.dart';
import 'marketplace_listing_details_screen.dart';

class MyMarketplaceListingsScreen extends StatelessWidget {
  const MyMarketplaceListingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Listings'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: <Widget>[
              Tab(text: 'Available'),
              Tab(text: 'Sold'),
              Tab(text: 'Unavailable'),
              Tab(text: 'Drafts'),
              Tab(text: 'Archived'),
            ],
          ),
        ),
        body: const TabBarView(
          children: <Widget>[
            _ListingStatusTab(status: 'available'),
            _ListingStatusTab(status: 'sold'),
            _ListingStatusTab(status: 'unavailable'),
            _ListingStatusTab(status: 'draft'),
            _ListingStatusTab(status: 'archived'),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const CreateMarketplaceListingScreen(),
            ),
          ),
          icon: const Icon(Icons.add_rounded),
          label: const Text('New Listing'),
        ),
      ),
    );
  }
}

class _ListingStatusTab extends StatelessWidget {
  const _ListingStatusTab({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final MarketplaceService service = MarketplaceService();
    return StreamBuilder<List<MarketplaceListing>>(
      stream: service.watchMine(status: status),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<List<MarketplaceListing>> snapshot,
          ) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Text('Unable to load listings. ${snapshot.error}'),
              );
            }
            final List<MarketplaceListing> listings =
                snapshot.data ?? const <MarketplaceListing>[];
            if (listings.isEmpty) {
              return _EmptyStatus(status: status);
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
              itemCount: listings.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (BuildContext context, int index) =>
                  _OwnerListingTile(listing: listings[index]),
            );
          },
    );
  }
}

class _OwnerListingTile extends StatefulWidget {
  const _OwnerListingTile({required this.listing});

  final MarketplaceListing listing;

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
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => MarketplaceListingDetailsScreen(
            listingId: widget.listing.listingId,
          ),
        ),
      );
      return;
    }
    if (value == 'edit') {
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => CreateMarketplaceListingScreen(
            listingId: widget.listing.listingId,
          ),
        ),
      );
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
  const _EmptyStatus({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.inventory_2_outlined,
              size: 60,
              color: MarketplaceTheme.sky,
            ),
            const SizedBox(height: 14),
            Text(
              'No ${status == 'draft' ? 'drafts' : '$status listings'}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              status == 'available'
                  ? 'Published listings will appear here.'
                  : 'This section is currently empty.',
            ),
          ],
        ),
      ),
    );
  }
}
