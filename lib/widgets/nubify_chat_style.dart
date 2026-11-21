import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

//===================================================
// NUBIFY CHAT — PREMIUM STYLE
//
// One place for the colours, gradients and shapes
// shared by the chat list, conversations, groups and
// calls, so every chat screen looks like one family.
//===================================================

class NubifyChatStyle {
  NubifyChatStyle._();

  static const Color sky = Color(0xFF29B6F6);
  static const Color royal = Color(0xFF2F80ED);
  static const Color violet = Color(0xFF6C5CE7);

  // Read receipts are green. The bright one sits on the
  // sky blue bubbles (with tickShadow so it stands out),
  // the deeper one on plain surfaces.
  static const Color readGreen = Color(0xFF00E676);
  static const Color readGreenOnSurface = Color(0xFF22C55E);

  static const List<Shadow> tickShadow = <Shadow>[
    Shadow(color: Color(0x99003A66), blurRadius: 3),
  ];

  // Navy blue: the selected Messages / Groups / Calls tab.
  static const Color navy = Color(0xFF14286B);

  static const LinearGradient navyGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFF1F3A8F), navy],
  );

  static const Color online = Color(0xFF22C55E);
  static const Color danger = Color(0xFFFF4D67);

  // Sky → royal → violet: buttons, badges, rings.
  static const LinearGradient brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[sky, royal, violet],
  );

  // Your own messages: sky blue.
  static const Color skyDeep = Color(0xFF0B8BDD);

  static const LinearGradient outgoing = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFF2EB4F5), skyDeep],
  );

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  // Messages from other people. Kept deep in both
  // themes because their text and cards are white.
  static Color incoming(BuildContext context) =>
      isDark(context) ? const Color(0xFF1D2836) : const Color(0xFF2A3648);

  static BorderRadius bubbleRadius(bool mine) => BorderRadius.only(
    topLeft: const Radius.circular(20),
    topRight: const Radius.circular(20),
    bottomLeft: Radius.circular(mine ? 20 : 6),
    bottomRight: Radius.circular(mine ? 6 : 20),
  );

  static BoxDecoration bubble(BuildContext context, {required bool mine}) {
    final bool dark = isDark(context);

    return BoxDecoration(
      gradient: mine ? outgoing : null,
      color: mine ? null : incoming(context),
      borderRadius: bubbleRadius(mine),
      border: mine
          ? null
          : Border.all(color: Colors.white.withValues(alpha: 0.06)),
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: (mine ? skyDeep : Colors.black).withValues(
            alpha: dark ? 0.30 : 0.16,
          ),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  // Round send / mic / call buttons.
  static BoxDecoration actionCircle({bool enabled = true}) => BoxDecoration(
    gradient: enabled ? brand : null,
    color: enabled ? null : Colors.grey.withValues(alpha: 0.25),
    shape: BoxShape.circle,
    boxShadow: enabled
        ? <BoxShadow>[
            BoxShadow(
              color: royal.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ]
        : null,
  );

  // The floating rounded card that holds the composer.
  static BoxDecoration composerCard(BuildContext context) {
    final bool dark = isDark(context);

    return BoxDecoration(
      color: dark ? const Color(0xFF172130) : Colors.white,
      borderRadius: BorderRadius.circular(26),
      border: Border.all(
        color: dark
            ? Colors.white.withValues(alpha: 0.06)
            : const Color(0xFFE3E9F3),
      ),
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: Colors.black.withValues(alpha: dark ? 0.35 : 0.08),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  // The rounded text box inside the composer.
  static Color fieldFill(BuildContext context) =>
      isDark(context) ? const Color(0xFF223042) : const Color(0xFFF1F5FB);

  static const EdgeInsets composerMargin = EdgeInsets.fromLTRB(8, 4, 8, 8);
}

//===================================================
// CHAT WALLPAPER
//
// A soft two-tone gradient with gentle colour glows
// and a fine dot pattern behind the messages.
//===================================================

class NubifyChatBackground extends StatelessWidget {
  const NubifyChatBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bool dark = NubifyChatStyle.isDark(context);

    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: RepaintBoundary(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: dark
                      ? const <Color>[Color(0xFF0B1320), Color(0xFF101A2C)]
                      : const <Color>[Color(0xFFEAF4FD), Color(0xFFF2EEFD)],
                ),
              ),
              child: Stack(
                children: <Widget>[
                  _glow(
                    alignment: const Alignment(1.2, -0.9),
                    color: NubifyChatStyle.sky,
                    alpha: dark ? 0.16 : 0.20,
                  ),
                  _glow(
                    alignment: const Alignment(-1.2, 0.8),
                    color: NubifyChatStyle.violet,
                    alpha: dark ? 0.16 : 0.14,
                  ),
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _DotPatternPainter(
                        color: dark
                            ? Colors.white.withValues(alpha: 0.045)
                            : NubifyChatStyle.royal.withValues(alpha: 0.07),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }

  Widget _glow({
    required Alignment alignment,
    required Color color,
    required double alpha,
  }) {
    return Positioned.fill(
      child: Align(
        alignment: alignment,
        child: Container(
          width: 340,
          height: 340,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: <Color>[
                color.withValues(alpha: alpha),
                color.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DotPatternPainter extends CustomPainter {
  const _DotPatternPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = color;
    const double gap = 22;

    for (double y = 8; y < size.height; y += gap) {
      final double shift = (y ~/ gap).isOdd ? gap / 2 : 0;
      for (double x = 8 + shift; x < size.width; x += gap) {
        canvas.drawCircle(Offset(x, y), 1.15, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotPatternPainter oldDelegate) =>
      oldDelegate.color != color;
}

//===================================================
// STORY RING
//
// No ring unless the person has a story that is less
// than 24 hours old: blue while it is new to you, grey
// once you have watched it.
//===================================================

enum NubifyStoryRing { none, unviewed, viewed }

//===================================================
// CHAT AVATAR
//===================================================

class NubifyChatAvatar extends StatelessWidget {
  const NubifyChatAvatar({
    super.key,
    required this.photoUrl,
    this.radius = 27,
    this.story = NubifyStoryRing.none,
    this.online = false,
    this.group = false,
  });

  final String photoUrl;
  final double radius;

  final NubifyStoryRing story;

  // A green dot at the bottom right while they are online.
  final bool online;
  final bool group;

  static const LinearGradient _storyBlue = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[NubifyChatStyle.sky, NubifyChatStyle.royal],
  );

  @override
  Widget build(BuildContext context) {
    final bool dark = NubifyChatStyle.isDark(context);
    final String url = photoUrl.trim();
    final Color background = Theme.of(context).scaffoldBackgroundColor;

    final Widget photo = CircleAvatar(
      radius: radius,
      backgroundColor: dark ? const Color(0xFF1E2A3A) : const Color(0xFFE7F0FB),
      backgroundImage: url.isNotEmpty ? CachedNetworkImageProvider(url) : null,
      child: url.isEmpty
          ? Icon(
              group ? Icons.groups_rounded : Icons.person_rounded,
              color: NubifyChatStyle.royal,
              size: radius * 0.95,
            )
          : null,
    );

    final bool hasStory = story != NubifyStoryRing.none;

    // The ring space is always kept, so photos line up
    // whether or not a ring is showing.
    final Widget avatar = Container(
      padding: const EdgeInsets.all(2.4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: story == NubifyStoryRing.unviewed ? _storyBlue : null,
        color: story == NubifyStoryRing.viewed
            ? (dark
                  ? Colors.white.withValues(alpha: 0.30)
                  : const Color(0xFFB4BFCD))
            : null,
      ),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: hasStory ? background : null,
        ),
        child: photo,
      ),
    );

    if (!online) {
      return avatar;
    }

    final double dot = (radius * 0.5).clamp(10, 16).toDouble();

    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        avatar,
        Positioned(
          right: 2,
          bottom: 2,
          child: Semantics(
            label: 'Online',
            child: Container(
              width: dot,
              height: dot,
              decoration: BoxDecoration(
                color: NubifyChatStyle.online,
                shape: BoxShape.circle,
                border: Border.all(color: background, width: 2),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

//===================================================
// UNREAD COUNT BADGE
//===================================================

class NubifyUnreadBadge extends StatelessWidget {
  const NubifyUnreadBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: NubifyChatStyle.brand,
        borderRadius: BorderRadius.circular(11),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: NubifyChatStyle.royal.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        maxLines: 1,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

//===================================================
// GRADIENT FLOATING BUTTON
//===================================================

class NubifyGradientFab extends StatelessWidget {
  const NubifyGradientFab({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final Widget button = DecoratedBox(
      decoration: BoxDecoration(
        gradient: NubifyChatStyle.brand,
        borderRadius: BorderRadius.circular(20),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: NubifyChatStyle.royal.withValues(alpha: 0.40),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onPressed,
          child: SizedBox(
            width: 60,
            height: 60,
            child: Icon(icon, color: Colors.white, size: 26),
          ),
        ),
      ),
    );

    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }
}

//===================================================
// EMPTY STATE ICON
//===================================================

class NubifyChatEmptyIcon extends StatelessWidget {
  const NubifyChatEmptyIcon({super.key, required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        gradient: NubifyChatStyle.brand,
        borderRadius: BorderRadius.circular(28),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: NubifyChatStyle.royal.withValues(alpha: 0.30),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 40),
    );
  }
}
