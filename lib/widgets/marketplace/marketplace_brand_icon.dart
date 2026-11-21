import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Shared visual assets used for NUB Marketplace branding.
abstract final class MarketplaceBrandAssets {
  /// Twemoji "shopping cart" (U+1F6D2), v17.0.3, bundled with the app so it
  /// shows instantly and offline.
  ///
  /// Graphics © Twitter, Inc. and other contributors, licensed under
  /// CC-BY 4.0 (https://creativecommons.org/licenses/by/4.0/). The credit is
  /// shown on the About the App screen.
  static const String cartIcon = 'assets/icons/marketplace_cart.svg';
}

/// The NUB Marketplace icon: the full-colour Twemoji shopping cart.
///
/// It keeps its own colours everywhere, like an emoji, and stays crisp at
/// every size because it is a vector image.
class MarketplaceBrandIcon extends StatelessWidget {
  const MarketplaceBrandIcon({
    super.key,
    this.size = 24,
    this.backgroundColor,
    this.padding = 0,
    this.borderRadius,
  });

  final double size;
  final Color? backgroundColor;
  final double padding;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final double iconSize = (size - (padding * 2)).clamp(1, size);

    return Semantics(
      image: true,
      label: 'NUB Marketplace',
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: borderRadius ?? BorderRadius.circular(size * 0.24),
          ),
          child: Center(
            child: SvgPicture.asset(
              MarketplaceBrandAssets.cartIcon,
              width: iconSize,
              height: iconSize,
              fit: BoxFit.contain,
              excludeFromSemantics: true,
            ),
          ),
        ),
      ),
    );
  }
}
