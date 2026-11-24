import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../l10n/nubify_text.dart';

//===================================================
// NUBIFY — HONOR WIDGETS
// Shared by "About the Developer" and "Honorary
// Recognition": colours, verified seal, avatar,
// reveal animation, section label and header bar.
//===================================================

//===================================================
// 1. COLOURS
//===================================================

class NubifyHonorColors {
  // Deep backgrounds for the hero headers.
  static const Color ink = Color(0xFF0B1220);
  static const Color inkSoft = Color(0xFF17213A);
  static const Color forest = Color(0xFF06231A);
  static const Color forestSoft = Color(0xFF0E3A2C);

  // Champagne gold (founder).
  static const Color gold = Color(0xFFD4AF37);
  static const Color goldLight = Color(0xFFF5E6A8);
  static const Color goldDeep = Color(0xFF9A7614);

  // Mature emerald (honorary).
  static const Color emerald = Color(0xFF1E9E6A);
  static const Color emeraldLight = Color(0xFF7BE0B2);
  static const Color emeraldDeep = Color(0xFF0A5C40);

  static const List<Color> goldGradient = [goldLight, gold, goldDeep];
  static const List<Color> emeraldGradient = [
    emeraldLight,
    emerald,
    emeraldDeep,
  ];

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color page(BuildContext context) =>
      isDark(context) ? const Color(0xFF070B13) : const Color(0xFFF6F4EF);

  static Color card(BuildContext context) =>
      isDark(context) ? const Color(0xFF101828) : Colors.white;

  static Color line(BuildContext context) =>
      isDark(context) ? const Color(0xFF1F2B42) : const Color(0xFFE9E4D8);

  static Color text(BuildContext context) =>
      isDark(context) ? const Color(0xFFF2F4F8) : const Color(0xFF141A27);

  static Color muted(BuildContext context) =>
      isDark(context) ? const Color(0xFF97A3B8) : const Color(0xFF6A7284);
}

//===================================================
// 2. VERIFIED SEAL (gold or green)
//===================================================

enum NubifySealTone { gold, green }

class NubifyVerifiedSeal extends StatefulWidget {
  const NubifyVerifiedSeal({
    super.key,
    required this.tone,
    this.size = 22,
    this.shimmer = false,
    this.message,
  });

  final NubifySealTone tone;
  final double size;

  // A soft light sweeps across the seal every few seconds.
  final bool shimmer;

  // Shown in a bubble when the seal is tapped.
  final String? message;

  @override
  State<NubifyVerifiedSeal> createState() => _NubifyVerifiedSealState();
}

class _NubifyVerifiedSealState extends State<NubifyVerifiedSeal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Respect the phone's "remove animations" setting.
    final bool animate =
        widget.shimmer && !MediaQuery.of(context).disableAnimations;

    if (animate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!animate) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool gold = widget.tone == NubifySealTone.gold;

    Widget seal = CustomPaint(
      size: Size.square(widget.size),
      painter: _SealPainter(
        colors: gold
            ? NubifyHonorColors.goldGradient
            : NubifyHonorColors.emeraldGradient,
        tickColor: gold ? const Color(0xFF2B1F02) : Colors.white,
      ),
    );

    if (widget.shimmer) {
      seal = AnimatedBuilder(
        animation: _controller,
        child: seal,
        builder: (context, child) {
          final double shift = -2 + 4 * _controller.value;

          return ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (Rect bounds) => LinearGradient(
              begin: Alignment(shift - 1, -1),
              end: Alignment(shift + 1, 1),
              colors: [
                Colors.white.withValues(alpha: 0),
                Colors.white.withValues(alpha: .65),
                Colors.white.withValues(alpha: 0),
              ],
              stops: const [.35, .5, .65],
            ).createShader(bounds),
            child: child,
          );
        },
      );
    }

    return Tooltip(
      message: widget.message ?? 'Verified',
      triggerMode: TooltipTriggerMode.tap,
      child: seal,
    );
  }
}

class _SealPainter extends CustomPainter {
  const _SealPainter({required this.colors, required this.tickColor});

  final List<Color> colors;
  final Color tickColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = size.shortestSide / 2;

    // Scalloped edge: a circle with 12 soft bumps.
    final Path seal = Path();

    for (int degree = 0; degree <= 360; degree += 2) {
      final double angle = degree * math.pi / 180;
      final double r = radius * (0.9 + 0.1 * math.cos(12 * angle));
      final Offset point =
          center + Offset(math.cos(angle), math.sin(angle)) * r;

      if (degree == 0) {
        seal.moveTo(point.dx, point.dy);
      } else {
        seal.lineTo(point.dx, point.dy);
      }
    }

    seal.close();

    canvas.drawPath(
      seal,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ).createShader(Offset.zero & size),
    );

    // The tick.
    final Path tick = Path()
      ..moveTo(size.width * .29, size.height * .52)
      ..lineTo(size.width * .44, size.height * .66)
      ..lineTo(size.width * .72, size.height * .37);

    canvas.drawPath(
      tick,
      Paint()
        ..color = tickColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.shortestSide * .11
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_SealPainter oldDelegate) =>
      oldDelegate.colors != colors || oldDelegate.tickColor != tickColor;
}

//===================================================
// 3. AVATAR WITH GRADIENT RING
//===================================================

class NubifyHonorAvatar extends StatefulWidget {
  const NubifyHonorAvatar({
    super.key,
    required this.name,
    required this.photo,
    required this.ringColors,
    this.size = 64,
    this.spinRing = false,
    this.gapColor,
  });

  final String name;

  // An https link, an asset path like 'assets/team/me.jpg',
  // or '' to show initials.
  final String photo;

  final List<Color> ringColors;
  final double size;

  // Slowly rotates the ring.
  final bool spinRing;

  // Colour of the thin gap between ring and photo. Match the
  // colour behind the avatar.
  final Color? gapColor;

  @override
  State<NubifyHonorAvatar> createState() => _NubifyHonorAvatarState();
}

class _NubifyHonorAvatarState extends State<NubifyHonorAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final bool animate =
        widget.spinRing && !MediaQuery.of(context).disableAnimations;

    if (animate && !_spin.isAnimating) {
      _spin.repeat();
    } else if (!animate) {
      _spin.stop();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  static String _initialsOf(String name) {
    return name
        .split(RegExp(r'\s+'))
        .map((word) => RegExp(r'[A-Za-z]').firstMatch(word)?.group(0) ?? '')
        .where((letter) => letter.isNotEmpty)
        .take(2)
        .join()
        .toUpperCase();
  }

  Widget _initials() {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [widget.ringColors.last, NubifyHonorColors.ink],
        ),
      ),
      child: Center(
        child: Text(
          _initialsOf(widget.name),
          style: TextStyle(
            color: Colors.white,
            fontSize: widget.size * .3,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  Widget _photoOrInitials() {
    final String photo = widget.photo.trim();

    if (photo.isEmpty) {
      return _initials();
    }

    final ImageProvider<Object> image = photo.startsWith('http')
        ? CachedNetworkImageProvider(photo)
        : AssetImage(photo);

    return Image(
      image: image,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _initials(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double size = widget.size;
    final double ring = math.max(2.5, size * .04);
    final double gap = math.max(2, size * .03);

    final Widget ringCircle = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(
          colors: [...widget.ringColors, widget.ringColors.first],
        ),
      ),
    );

    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          widget.spinRing
              ? RotationTransition(turns: _spin, child: ringCircle)
              : ringCircle,
          Container(
            width: size - ring * 2,
            height: size - ring * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.gapColor ?? NubifyHonorColors.card(context),
            ),
          ),
          ClipOval(
            child: SizedBox.square(
              dimension: size - ring * 2 - gap * 2,
              child: _photoOrInitials(),
            ),
          ),
        ],
      ),
    );
  }
}

//===================================================
// 4. FADE + SLIDE-UP ENTRANCE
//===================================================

class NubifyReveal extends StatefulWidget {
  const NubifyReveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
  });

  final Widget child;
  final Duration delay;

  @override
  State<NubifyReveal> createState() => _NubifyRevealState();
}

class _NubifyRevealState extends State<NubifyReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );

  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_started) {
      return;
    }

    _started = true;

    if (MediaQuery.of(context).disableAnimations) {
      _controller.value = 1;
      return;
    }

    Future<void>.delayed(widget.delay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, .06),
          end: Offset.zero,
        ).animate(_curve),
        child: widget.child,
      ),
    );
  }
}

//===================================================
// 5. SECTION LABEL
//===================================================

class NubifySectionLabel extends StatelessWidget {
  const NubifySectionLabel({
    super.key,
    required this.text,
    required this.accent,
  });

  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 26, 4, 12),
      child: Row(
        children: [
          Container(
            width: 18,
            height: 3,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              text.toUpperCase(),
              style: TextStyle(
                color: NubifyHonorColors.muted(context),
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

//===================================================
// 6. HEADER BAR (back button + title on dark hero)
//===================================================

class NubifyHeaderBar extends StatelessWidget {
  const NubifyHeaderBar({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Material(
          color: Colors.white.withValues(alpha: .1),
          shape: const CircleBorder(),
          child: IconButton(
            tooltip: context.tr('Back'),
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: .2,
            ),
          ),
        ),
      ],
    );
  }
}

//===================================================
// 7. SOFT GLOW (decorative light in the hero)
//===================================================

class NubifyGlow extends StatelessWidget {
  const NubifyGlow({super.key, required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: .38),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}