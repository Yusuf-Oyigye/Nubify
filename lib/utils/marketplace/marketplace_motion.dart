import 'package:flutter/material.dart';

//===================================================
// CENTRAL MARKETPLACE MOTION TOKENS
//===================================================

abstract final class MarketplaceMotion {
  static const Duration micro = Duration(milliseconds: 140);
  static const Duration standard = Duration(milliseconds: 240);
  static const Duration screen = Duration(milliseconds: 360);
  static const Duration success = Duration(milliseconds: 650);

  static const Curve enterCurve = Curves.easeOutCubic;
  static const Curve springCurve = Curves.easeOutBack;

  static bool reduceMotion(BuildContext context) {
    return MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  }

  static Duration duration(BuildContext context, Duration normal) {
    return reduceMotion(context) ? Duration.zero : normal;
  }
}
