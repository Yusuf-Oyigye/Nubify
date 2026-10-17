import 'dart:async';

import 'package:flutter/material.dart';

import '../models/marketplace_filter.dart';
import '../models/marketplace_listing.dart';
import '../services/marketplace_service.dart';
import '../utils/marketplace_constants.dart';
import '../utils/marketplace_theme.dart';
import '../widgets/marketplace_listing_card.dart';
import 'marketplace_listing_details_screen.dart';

class MarketplaceSearchScreen extends StatefulWidget {
  const MarketplaceSearchScreen({super.key, this.initialCategory});

  final String? initialCategory;

  @override
  State<MarketplaceSearchScreen> createState() =>
      _MarketplaceSearchScreenState();
}

class _MarketplaceSearchScreenState extends State<MarketplaceSearchScreen> {
  final MarketplaceService _service = MarketplaceService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;
  late MarketplaceFilter _filter;
  List<MarketplaceListing> _results = const <MarketplaceListing>[];
  Object? _loadError;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _requestGeneration = 0;
  MarketplaceListingPage? _lastPage;

  @override
  void initState() {
    super.initState();
    _filter = MarketplaceFilter(category: widget.initialCategory);
    _scrollController.addListener(_handleScroll);
    unawaited(_loadResults(reset: true));
  }

  void _handleScroll() {
    if (_scrollController.position.extentAfter < 500) {
      unawaited(_loadResults());
    }
  }

  void _replaceFilter(MarketplaceFilter filter) {
    setState(() => _filter = filter);
    unawaited(_loadResults(reset: true));
  }

  Future<void> _loadResults({bool reset = false}) async {
    if (reset) {
      _requestGeneration += 1;
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

    final int generation = _requestGeneration;
    final MarketplaceFilter requestedFilter = _filter;
    try {
      final MarketplaceListingPage page = await _service.fetchSearchPage(
        requestedFilter,
        after: reset ? null : _lastPage?.lastDocument,
      );
      if (!mounted || generation != _requestGeneration) {
        return;
      }
      final Set<String> existingIds = _results
          .map((MarketplaceListing item) => item.listingId)
          .toSet();
      final List<MarketplaceListing> combined = reset
          ? page.listings
          : <MarketplaceListing>[
              ..._results,
              ...page.listings.where(
                (MarketplaceListing item) => existingIds.add(item.listingId),
              ),
            ];
      setState(() {
        _results = combined;
        _lastPage = page;
        _hasMore = page.hasMore;
        _loading = false;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted || generation != _requestGeneration) {
        return;
      }
      setState(() {
        _loadError = error;
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) {
        _replaceFilter(_filter.copyWith(query: value));
      }
    });
  }

  Future<void> _openFilters() async {
    final MarketplaceFilter? next =
        await showModalBottomSheet<MarketplaceFilter>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => _FilterSheet(initial: _filter),
        );
    if (next != null && mounted) {
      _replaceFilter(next);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search Marketplace')),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _searchController,
              autofocus: widget.initialCategory == null,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search products, services, or sellers…',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  onPressed: _openFilters,
                  icon: const Icon(Icons.tune_rounded),
                ),
                filled: true,
                fillColor: MarketplaceTheme.softSurface(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          if (_filter.category != null || _filter.condition != null)
            SizedBox(
              height: 44,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                children: <Widget>[
                  if (_filter.category != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InputChip(
                        label: Text(
                          MarketplaceConstants.categoryLabel(_filter.category!),
                        ),
                        onDeleted: () => _replaceFilter(
                          _filter.copyWith(clearCategory: true),
                        ),
                      ),
                    ),
                  if (_filter.condition != null)
                    InputChip(
                      label: Text(
                        MarketplaceConstants.conditionLabel(_filter.condition!),
                      ),
                      onDeleted: () => _replaceFilter(
                        _filter.copyWith(clearCondition: true),
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: StreamBuilder<Set<String>>(
              stream: _service.watchSavedIds(),
              builder: (BuildContext context, AsyncSnapshot<Set<String>> saved) {
                if (_loading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (_results.isEmpty && _loadError != null) {
                  return _SearchState(
                    icon: Icons.manage_search_rounded,
                    title: 'Search needs attention',
                    message:
                        'A Firebase index may still be building for this filter. $_loadError',
                    actionLabel: 'Try Again',
                    onAction: () => unawaited(_loadResults(reset: true)),
                  );
                }
                if (_results.isEmpty) {
                  return const _SearchState(
                    icon: Icons.search_off_rounded,
                    title: 'No matching listings',
                    message:
                        'Try a different word, category, condition, or price range.',
                  );
                }
                return Column(
                  children: <Widget>[
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () => _loadResults(reset: true),
                        child: GridView.builder(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
                          itemCount: _results.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 0.69,
                              ),
                          itemBuilder: (BuildContext context, int index) {
                            final MarketplaceListing listing = _results[index];
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
                          onPressed: () => unawaited(_loadResults()),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Could not load more — retry'),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.initial});

  final MarketplaceFilter initial;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late MarketplaceFilter _filter;
  late final TextEditingController _minimum;
  late final TextEditingController _maximum;

  @override
  void initState() {
    super.initState();
    _filter = widget.initial;
    _minimum = TextEditingController(
      text: widget.initial.minimumPrice?.toString() ?? '',
    );
    _maximum = TextEditingController(
      text: widget.initial.maximumPrice?.toString() ?? '',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Filter Listings',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              initialValue: _filter.category,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: <DropdownMenuItem<String?>>[
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All categories'),
                ),
                ...MarketplaceConstants.categories.map(
                  (MarketplaceCategory category) => DropdownMenuItem<String?>(
                    value: category.id,
                    child: Text(category.label),
                  ),
                ),
              ],
              onChanged: (String? value) => setState(
                () => _filter = value == null
                    ? _filter.copyWith(clearCategory: true)
                    : _filter.copyWith(category: value),
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String?>(
              initialValue: _filter.condition,
              decoration: const InputDecoration(
                labelText: 'Condition',
                border: OutlineInputBorder(),
              ),
              items: <DropdownMenuItem<String?>>[
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All conditions'),
                ),
                ...MarketplaceConstants.conditions.map(
                  (String value) => DropdownMenuItem<String?>(
                    value: value,
                    child: Text(MarketplaceConstants.conditionLabel(value)),
                  ),
                ),
              ],
              onChanged: (String? value) => setState(
                () => _filter = value == null
                    ? _filter.copyWith(clearCondition: true)
                    : _filter.copyWith(condition: value),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _minimum,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Minimum EGP',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _maximum,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Maximum EGP',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'A price range uses price order so every next page remains correctly sorted.',
                style: TextStyle(fontSize: 11),
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<MarketplaceSort>(
              initialValue: _filter.sort,
              decoration: const InputDecoration(
                labelText: 'Sort',
                border: OutlineInputBorder(),
              ),
              items: const <DropdownMenuItem<MarketplaceSort>>[
                DropdownMenuItem(
                  value: MarketplaceSort.newest,
                  child: Text('Newest First'),
                ),
                DropdownMenuItem(
                  value: MarketplaceSort.oldest,
                  child: Text('Oldest First'),
                ),
                DropdownMenuItem(
                  value: MarketplaceSort.priceLowToHigh,
                  child: Text('Price Low to High'),
                ),
                DropdownMenuItem(
                  value: MarketplaceSort.priceHighToLow,
                  child: Text('Price High to Low'),
                ),
              ],
              onChanged: (MarketplaceSort? value) {
                if (value != null) {
                  setState(() => _filter = _filter.copyWith(sort: value));
                }
              },
            ),
            const SizedBox(height: 20),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(
                      context,
                      MarketplaceFilter(query: widget.initial.query),
                    ),
                    child: const Text('Reset'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _applyFilters,
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _applyFilters() {
    final String minimumText = _minimum.text.trim();
    final String maximumText = _maximum.text.trim();
    final double? minimum = double.tryParse(minimumText);
    final double? maximum = double.tryParse(maximumText);
    if ((minimumText.isNotEmpty && (minimum == null || minimum < 0)) ||
        (maximumText.isNotEmpty && (maximum == null || maximum < 0))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid price of 0 or more.')),
      );
      return;
    }
    if (minimum != null && maximum != null && minimum > maximum) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Minimum price cannot be greater than maximum price.'),
        ),
      );
      return;
    }
    final bool hasPriceRange = minimum != null || maximum != null;
    final MarketplaceSort sort = hasPriceRange
        ? switch (_filter.sort) {
            MarketplaceSort.priceHighToLow => MarketplaceSort.priceHighToLow,
            _ => MarketplaceSort.priceLowToHigh,
          }
        : _filter.sort;
    Navigator.pop(
      context,
      _filter.copyWith(
        minimumPrice: minimum,
        clearMinimumPrice: minimum == null,
        maximumPrice: maximum,
        clearMaximumPrice: maximum == null,
        sort: sort,
      ),
    );
  }

  @override
  void dispose() {
    _minimum.dispose();
    _maximum.dispose();
    super.dispose();
  }
}

class _SearchState extends StatelessWidget {
  const _SearchState({
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
            Icon(icon, color: MarketplaceTheme.sky, size: 58),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
            ),
            const SizedBox(height: 7),
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
