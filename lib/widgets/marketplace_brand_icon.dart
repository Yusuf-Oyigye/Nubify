import 'package:flutter/material.dart';

/// Shared visual assets used for NUB Marketplace branding.
abstract final class MarketplaceBrandAssets {
  static const String iconUrl =
      'https://img.icons8.com/?size=100&id=fhk2K3BpkLYx&format=png&color=000000';
}

/// Displays the official Marketplace cart icon with a local Material fallback.
///
/// The remote PNG is black, so it is automatically tinted for the current
/// brightness unless [tintColor] is supplied. Loading or network failures never
/// leave an empty space: a shopping-cart icon is shown immediately instead.
class MarketplaceBrandIcon extends StatelessWidget {
  const MarketplaceBrandIcon({
    super.key,
    this.size = 24,
    this.tintColor,
    this.fallbackColor,
    this.backgroundColor,
    this.padding = 0,
    this.borderRadius,
  });

  final double size;
  final Color? tintColor;
  final Color? fallbackColor;
  final Color? backgroundColor;
  final double padding;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    // Keep the supplied PNG's original black pixels untouched in light mode.
    // A light tint is only required in dark mode so the same asset stays clear.
    final Color? effectiveTint =
        tintColor ??
        (theme.brightness == Brightness.dark
            ? theme.colorScheme.onSurface
            : null);
    final Color effectiveFallback =
        fallbackColor ?? tintColor ?? theme.colorScheme.onSurface;
    final double iconSize = (size - (padding * 2)).clamp(1, size);
    final int cacheSize =
        (iconSize * MediaQuery.devicePixelRatioOf(context)).ceil();

    final Widget fallback = Center(
      child: Icon(
        Icons.shopping_cart_rounded,
        size: iconSize,
        color: effectiveFallback,
      ),
    );

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
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: Image.network(
              MarketplaceBrandAssets.iconUrl,
              width: iconSize,
              height: iconSize,
              fit: BoxFit.contain,
              color: effectiveTint,
              colorBlendMode: effectiveTint == null ? null : BlendMode.srcIn,
              filterQuality: FilterQuality.high,
              gaplessPlayback: true,
              cacheWidth: cacheSize,
              cacheHeight: cacheSize,
              loadingBuilder: (
                BuildContext context,
                Widget child,
                ImageChunkEvent? progress,
              ) => progress == null ? child : fallback,
              errorBuilder: (
                BuildContext context,
                Object error,
                StackTrace? stackTrace,
              ) => fallback,
            ),
          ),
        ),
      ),
    );
  }
}
