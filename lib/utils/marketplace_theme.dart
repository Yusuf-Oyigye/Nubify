import 'package:flutter/material.dart';

//===================================================
// NUB MARKETPLACE VISUAL IDENTITY
//===================================================

abstract final class MarketplaceTheme {
  static const Color sky = Color(0xFF29B6F6);
  static const Color midnight = Color(0xFF0B132B);
  static const Color navy = Color(0xFF16213E);
  static const Color graphite = Color(0xFF111827);
  static const Color ivory = Color(0xFFF7F4ED);
  static const Color copper = Color(0xFFC56A45);
  static const Color gold = Color(0xFFC79A4B);
  static const Color emerald = Color(0xFF2E7D6E);
  static const Color plum = Color(0xFF6D466B);

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[midnight, navy, Color(0xFF153A59)],
  );

  static const LinearGradient sellGradient = LinearGradient(
    colors: <Color>[sky, Color(0xFF168BC0)],
  );

  static Color surface(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF121B2A)
        : Colors.white;
  }

  static Color softSurface(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF172235)
        : const Color(0xFFF1F6FA);
  }

  static Color mutedText(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.white60
        : const Color(0xFF64748B);
  }

  static BoxDecoration premiumCard(BuildContext context) {
    return BoxDecoration(
      color: surface(context),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white10
            : const Color(0xFFE2E8F0),
      ),
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }
}
