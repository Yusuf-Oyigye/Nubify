import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/nubify_appearance_controller.dart';

// NUBIFY — PREMIUM MENU DESIGN SYSTEM

const Color nubifySky = Color(0xFF29B6F6);

// MATURE MULTICOLOR PALETTE
class NubifyPalette {
  static const Color purple = Color(0xFF8560DC);
  static const Color coral = Color(0xFFE7785D);
  static const Color emerald = Color(0xFF2EB58A);
  static const Color sapphire = Color(0xFF397FD4);
  static const Color amber = Color(0xFFCD9237);
  static const Color teal = Color(0xFF25AAB6);
  static const Color indigo = Color(0xFF6872CC);
  static const Color slate = Color(0xFF7187A2);
  static const Color violet = Color(0xFF9A70D9);
  static const Color crimson = Color(0xFFCD5960);
}

//===================================================
// LIGHT AND DARK MODE COLORS
//===================================================

class NubifyMenuColors {
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color background(BuildContext context) =>
      isDark(context) ? const Color(0xFF101824) : const Color(0xFFF5F7FB);

  static Color surface(BuildContext context) =>
      isDark(context) ? const Color(0xFF1C2735) : Colors.white;

  static Color primaryText(BuildContext context) =>
      isDark(context) ? const Color(0xFFF3F5F9) : const Color(0xFF202D40);

  static Color secondaryText(BuildContext context) =>
      isDark(context) ? const Color(0xFFA6B3C3) : const Color(0xFF69788B);

  static Color stroke(BuildContext context) =>
      isDark(context) ? const Color(0xFF334153) : const Color(0xFFE5EAF1);

  static Color tint(BuildContext context, Color color) =>
      color.withValues(alpha: isDark(context) ? .18 : .095);
}

//===================================================
// COLORFUL VECTOR ICON TILE
//===================================================

class NubifyIconTile extends StatelessWidget {
  const NubifyIconTile({
    super.key,
    required this.icon,
    required this.color,
    this.size = 46,
    this.iconSize = 23,
    this.image,
    this.fill,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;

  // A 3D picture (PNG asset) shown instead of the icon.
  // The icon still shows if the picture can't load.
  final String? image;

  // 1 = solid Material Symbols icon, 0 = outlined.
  final double? fill;

  @override
  Widget build(BuildContext context) {
    final String? picture = image;
    final Widget symbol = Icon(icon, color: color, size: iconSize, fill: fill);

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: NubifyMenuColors.tint(context, color),
        borderRadius: BorderRadius.circular(15),
      ),
      child: picture == null
          ? symbol
          : Image.asset(
              picture,
              width: size * .7,
              height: size * .7,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, _, _) => symbol,
            ),
    );
  }
}

//===================================================
// COMMON PREMIUM DETAIL PAGE
//===================================================

class NubifyMenuPage extends StatelessWidget {
  const NubifyMenuPage({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NubifyMenuColors.background(context),

      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: NubifyMenuColors.background(context),
        foregroundColor: NubifyMenuColors.primaryText(context),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),

      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 36),
          children: <Widget>[
            if (subtitle != null) ...<Widget>[
              Text(
                subtitle!,
                style: TextStyle(
                  color: NubifyMenuColors.secondaryText(context),
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 22),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

//===================================================
// ANIMATED LIGHT / DARK / SYSTEM SELECTOR
//===================================================

class NubifyAppearanceSelector extends StatelessWidget {
  const NubifyAppearanceSelector({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<NubifyAppearanceController>();

    final dark = NubifyMenuColors.isDark(context);

    final choices = <(ThemeMode, String, IconData, Color)>[
      (
        ThemeMode.light,
        'Light',
        Icons.wb_sunny_rounded,
        const Color(0xFFE3A52E),
      ),
      (ThemeMode.dark, 'Dark', Icons.nightlight_round, const Color(0xFF8289E1)),
      (
        ThemeMode.system,
        'System',
        Icons.settings_brightness_rounded,
        nubifySky,
      ),
    ];

    return Container(
      padding: EdgeInsets.all(compact ? 3 : 5),
      decoration: BoxDecoration(
        color: NubifyMenuColors.surface(context),
        borderRadius: BorderRadius.circular(compact ? 14 : 18),
        border: Border.all(color: NubifyMenuColors.stroke(context)),
      ),

      child: Row(
        children: choices.map((option) {
          final selected = controller.mode == option.$1;

          return Expanded(
            child: Semantics(
              button: true,
              selected: selected,
              label: '${option.$2} appearance',

              child: InkWell(
                onTap: () async {
                  try {
                    await context.read<NubifyAppearanceController>().setMode(
                      option.$1,
                    );
                  } catch (_) {
                    if (!context.mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Could not save appearance. Please retry.',
                        ),
                      ),
                    );
                  }
                },

                borderRadius: BorderRadius.circular(compact ? 11 : 14),

                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),

                  curve: Curves.easeOutCubic,

                  padding: EdgeInsets.symmetric(
                    vertical: compact ? 7 : 12,
                    horizontal: compact ? 3 : 5,
                  ),

                  decoration: BoxDecoration(
                    color: selected
                        ? (dark
                              ? const Color(0xFF2C3C50)
                              : const Color(0xFFEAF3FD))
                        : Colors.transparent,

                    borderRadius: BorderRadius.circular(compact ? 11 : 14),

                    border: selected
                        ? Border.all(color: option.$4.withValues(alpha: .32))
                        : null,
                  ),

                  child: FittedBox(
                    fit: BoxFit.scaleDown,

                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,

                      children: [
                        Icon(
                          option.$3,
                          size: compact ? 16 : 18,
                          color: option.$4,
                        ),
                        SizedBox(width: compact ? 4 : 6),
                        Text(
                          option.$2,
                          style: TextStyle(
                            color: NubifyMenuColors.primaryText(context),
                            fontSize: compact ? 12 : 13,
                            fontWeight: selected
                                ? FontWeight.w800
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
