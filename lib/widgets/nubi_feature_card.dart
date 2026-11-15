
import 'package:flutter/material.dart';

class NubiFeatureCard extends StatefulWidget {
  const NubiFeatureCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colors,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  State<NubiFeatureCard> createState() =>
      _NubiFeatureCardState();
}

class _NubiFeatureCardState
    extends State<NubiFeatureCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final reducedMotion =
        MediaQuery.of(context).disableAnimations;

    return AnimatedScale(
      scale: _pressed && !reducedMotion
          ? .97 : 1.0,
      duration: reducedMotion
          ? Duration.zero
          : const Duration(milliseconds: 140),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onTapDown: (_) =>
              setState(() => _pressed = true),
          onTapCancel: () =>
              setState(() => _pressed = false),
          onTapUp: (_) =>
              setState(() => _pressed = false),
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              borderRadius:
              BorderRadius.circular(22),
              gradient: LinearGradient(
                colors: widget.colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.colors.first
                      .withValues(alpha: .18),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              mainAxisAlignment:
              MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  widget.icon,
                  size: 30,
                  color: Colors.white,
                ),
                Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      widget.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
