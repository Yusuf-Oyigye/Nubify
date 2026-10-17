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
  Timer? _debounce;
  late MarketplaceFilter _filter;

  @override
  void initState() {
    super.initState();
    _filter = MarketplaceFilter(category: widget.initialCategory);
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) {
        setState(() => _filter = _filter.copyWith(query: value));
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
      setState(() => _filter = next);
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
                        onDeleted: () => setState(
                          () => _filter = _filter.copyWith(clearCategory: true),
                        ),
                      ),
                    ),
                  if (_filter.condition != null)
                    InputChip(
                      label: Text(
                        MarketplaceConstants.conditionLabel(_filter.condition!),
                      ),
                      onDeleted: () => setState(
                        () => _filter = _filter.copyWith(clearCondition: true),
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: StreamBuilder<Set<String>>(
              stream: _service.watchSavedIds(),
              builder: (BuildContext context, AsyncSnapshot<Set<String>> saved) {
                return StreamBuilder<List<MarketplaceListing>>(
                  stream: _service.watchSearch(_filter),
                  builder:
                      (
                        BuildContext context,
                        AsyncSnapshot<List<MarketplaceListing>> snapshot,
                      ) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (snapshot.hasError) {
                          return _SearchState(
                            icon: Icons.manage_search_rounded,
                            title: 'Search needs attention',
                            message:
                                'A Firebase index may still be building for this filter. ${snapshot.error}',
                          );
                        }
                        final List<MarketplaceListing> results =
                            snapshot.data ?? const <MarketplaceListing>[];
                        if (results.isEmpty) {
                          return const _SearchState(
                            icon: Icons.search_off_rounded,
                            title: 'No matching listings',
                            message:
                                'Try a different word, category, condition, or price range.',
                          );
                        }
                        return GridView.builder(
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 40),
                          itemCount: results.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 0.69,
                              ),
                          itemBuilder: (BuildContext context, int index) {
                            final MarketplaceListing listing = results[index];
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
                        );
                      },
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
                    onPressed: () => Navigator.pop(
                      context,
                      _filter.copyWith(
                        minimumPrice: double.tryParse(_minimum.text),
                        clearMinimumPrice: _minimum.text.trim().isEmpty,
                        maximumPrice: double.tryParse(_maximum.text),
                        clearMaximumPrice: _maximum.text.trim().isEmpty,
                      ),
                    ),
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
  });

  final IconData icon;
  final String title;
  final String message;

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
          ],
        ),
      ),
    );
  }
}
