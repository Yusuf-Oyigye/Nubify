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

  static const LinearGradient publishGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: <Color>[Color(0xFF1F6F68), Color(0xFF214761), plum],
  );

  static const LinearGradient mediaAccentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[plum, copper],
  );

  static const LinearGradient addMediaGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFF2C294B), Color(0xFF173F4F)],
  );

  static LinearGradient composerBackground(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: dark
          ? const <Color>[Color(0xFF0A101B), Color(0xFF111827)]
          : const <Color>[Color(0xFFF8F6F1), Color(0xFFF1F5F4)],
    );
  }

  static BoxDecoration composerCard(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: dark ? const Color(0xFF151D2B) : const Color(0xFFFFFDFC),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: dark
            ? gold.withValues(alpha: 0.18)
            : plum.withValues(alpha: 0.12),
      ),
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: (dark ? Colors.black : navy).withValues(alpha: 0.12),
          blurRadius: 28,
          offset: const Offset(0, 12),
        ),
      ],
    );
  }

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
