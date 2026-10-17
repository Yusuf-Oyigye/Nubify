//===================================================
// MARKETPLACE SEARCH, FILTER AND SORT STATE
//===================================================

enum MarketplaceSort { newest, oldest, priceLowToHigh, priceHighToLow }

class MarketplaceFilter {
  const MarketplaceFilter({
    this.query = '',
    this.category,
    this.condition,
    this.minimumPrice,
    this.maximumPrice,
    this.sort = MarketplaceSort.newest,
  });

  final String query;
  final String? category;
  final String? condition;
  final double? minimumPrice;
  final double? maximumPrice;
  final MarketplaceSort sort;

  MarketplaceFilter copyWith({
    String? query,
    String? category,
    bool clearCategory = false,
    String? condition,
    bool clearCondition = false,
    double? minimumPrice,
    bool clearMinimumPrice = false,
    double? maximumPrice,
    bool clearMaximumPrice = false,
    MarketplaceSort? sort,
  }) {
    return MarketplaceFilter(
      query: query ?? this.query,
      category: clearCategory ? null : category ?? this.category,
      condition: clearCondition ? null : condition ?? this.condition,
      minimumPrice: clearMinimumPrice
          ? null
          : minimumPrice ?? this.minimumPrice,
      maximumPrice: clearMaximumPrice
          ? null
          : maximumPrice ?? this.maximumPrice,
      sort: sort ?? this.sort,
    );
  }
}
