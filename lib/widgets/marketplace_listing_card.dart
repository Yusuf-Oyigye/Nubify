import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/marketplace_listing.dart';
import '../services/marketplace_service.dart';
import '../utils/marketplace_constants.dart';
import '../utils/marketplace_motion.dart';
import '../utils/marketplace_theme.dart';

class MarketplaceListingCard extends StatefulWidget {
  const MarketplaceListingCard({
    super.key,
    required this.listing,
    required this.saved,
    required this.onOpen,
  });

  final MarketplaceListing listing;
  final bool saved;
  final VoidCallback onOpen;

  @override
  State<MarketplaceListingCard> createState() => _MarketplaceListingCardState();
}

class _MarketplaceListingCardState extends State<MarketplaceListingCard> {
  final MarketplaceService _service = MarketplaceService();
  bool _pressed = false;
  bool _saving = false;
  late bool _saved;

  @override
  void initState() {
    super.initState();
    _saved = widget.saved;
  }

  @override
  void didUpdateWidget(covariant MarketplaceListingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_saving && oldWidget.saved != widget.saved) {
      _saved = widget.saved;
    }
  }

  Future<void> _toggleSaved() async {
    if (_saving) {
      return;
    }
    final bool previous = _saved;
    setState(() {
      _saving = true;
      _saved = !previous;
    });
    HapticFeedback.selectionClick();
    try {
      await _service.setSaved(widget.listing.listingId, saved: _saved);
    } catch (_) {
      if (mounted) {
        setState(() => _saved = previous);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update Saved Listings.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final MarketplaceListing listing = widget.listing;
    return AnimatedScale(
      scale: _pressed ? 0.975 : 1,
      duration: MarketplaceMotion.duration(context, MarketplaceMotion.micro),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: widget.onOpen,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          child: Ink(
            decoration: MarketplaceTheme.premiumCard(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Hero(
                    tag: 'marketplace-cover-${listing.listingId}',
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: <Widget>[
                          _CoverImage(url: listing.coverUrl),
                          const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: <Color>[
                                  Colors.black12,
                                  Colors.transparent,
                                  Colors.black45,
                                ],
                              ),
                            ),
                          ),
                          if (!listing.isAvailable)
                            Positioned(
                              left: 10,
                              top: 10,
                              child: _MediaBadge(
                                icon: listing.status == 'sold'
                                    ? Icons.sell_rounded
                                    : Icons.visibility_off_rounded,
                                label: listing.status == 'sold'
                                    ? 'Sold'
                                    : 'Unavailable',
                              ),
                            )
                          else if (listing.hasVideo)
                            const Positioned(
                              left: 10,
                              top: 10,
                              child: _MediaBadge(
                                icon: Icons.play_arrow_rounded,
                                label: 'Video',
                              ),
                            ),
                          Positioned(
                            right: 7,
                            top: 7,
                            child: Material(
                              color: Colors.black45,
                              shape: const CircleBorder(),
                              child: AnimatedScale(
                                scale: _saved ? 1.08 : 1,
                                duration: MarketplaceMotion.duration(
                                  context,
                                  MarketplaceMotion.micro,
                                ),
                                child: IconButton(
                                  visualDensity: VisualDensity.compact,
                                  tooltip: _saved
                                      ? 'Remove from saved'
                                      : 'Save listing',
                                  onPressed: _saving ? null : _toggleSaved,
                                  icon: Icon(
                                    _saved
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                    color: _saved
                                        ? Colors.redAccent
                                        : Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        listing.priceLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: MarketplaceTheme.sky,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        listing.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: <Widget>[
                          CircleAvatar(
                            radius: 10,
                            backgroundImage:
                                listing.sellerPhotoUrl.trim().isEmpty
                                ? null
                                : NetworkImage(listing.sellerPhotoUrl),
                            child: listing.sellerPhotoUrl.trim().isEmpty
                                ? const Icon(Icons.person_rounded, size: 12)
                                : null,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              listing.sellerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: MarketplaceTheme.mutedText(context),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: MarketplaceTheme.softSurface(context),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              MarketplaceConstants.conditionLabel(
                                listing.condition,
                              ),
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
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

class _CoverImage extends StatelessWidget {
  const _CoverImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.trim().isEmpty) {
      return ColoredBox(
        color: MarketplaceTheme.softSurface(context),
        child: const Icon(
          Icons.storefront_rounded,
          color: MarketplaceTheme.sky,
          size: 42,
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      fadeInDuration: MarketplaceMotion.duration(
        context,
        MarketplaceMotion.standard,
      ),
      placeholder: (_, _) => ColoredBox(
        color: MarketplaceTheme.softSurface(context),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      errorWidget: (_, _, _) => ColoredBox(
        color: MarketplaceTheme.softSurface(context),
        child: const Icon(
          Icons.broken_image_outlined,
          color: MarketplaceTheme.sky,
        ),
      ),
    );
  }
}

class _MediaBadge extends StatelessWidget {
  const _MediaBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: Colors.white, size: 13),
          const SizedBox(width: 3),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
