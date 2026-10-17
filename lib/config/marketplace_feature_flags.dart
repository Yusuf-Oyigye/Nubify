//===================================================
// MARKETPLACE DEVELOPMENT FEATURE FLAGS
//===================================================

/// Temporary switches for Marketplace features that are still being built.
///
/// Seller verification has deliberately not been deleted. Keep this value in
/// sync with the equivalent switches in `functions/marketplace.js` and
/// `firestore.rules`. Change all three switches to `true` when administrative
/// approval is ready to become mandatory again.
abstract final class MarketplaceFeatureFlags {
  static const bool requireSellerApproval = false;
}
