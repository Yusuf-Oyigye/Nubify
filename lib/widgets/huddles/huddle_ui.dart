import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/huddles/huddle.dart';
import '../../l10n/nubify_text.dart';

//===================================================
// NUB HUDDLES — COLOURS (Nubify sky blue)
//===================================================

class HuddleColors {
  static const Color sky = Color(0xFF29B6F6);
  static const Color skyDeep = Color(0xFF0B7FC1);

  // The live room is always dark, like a stage.
  static const Color stage = Color(0xFF0A1220);
  static const Color stageSoft = Color(0xFF131E31);
  static const Color stageCard = Color(0xFF1A2740);
  static const Color stageLine = Color(0xFF26364F);

  static const Color live = Color(0xFFFF4D5E);
  static const Color speaking = Color(0xFF3DD9A8);
  static const Color host = Color(0xFFE7B53C);
  static const Color coHost = Color(0xFFA48BFF);
  static const Color listener = Color(0xFF8A9BB4);

  static Color role(HuddleRole role) => switch (role) {
    HuddleRole.host => host,
    HuddleRole.coHost => coHost,
    HuddleRole.speaker => sky,
    HuddleRole.listener => listener,
  };
}

String formatHuddleDuration(Duration value) {
  final int hours = value.inHours;
  final String minutes = (value.inMinutes % 60).toString().padLeft(2, '0');
  final String seconds = (value.inSeconds % 60).toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
}

//===================================================
// AVATAR WITH A CALM "SPEAKING" RING
//===================================================

class HuddleAvatar extends StatelessWidget {
  const HuddleAvatar({
    super.key,
    required this.name,
    required this.photoUrl,
    this.size = 56,
    this.speaking = false,
    this.muted = false,
    this.handRaised = false,
  });

  final String name;
  final String photoUrl;
  final double size;
  final bool speaking;
  final bool muted;
  final bool handRaised;

  String get _initials => name
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .take(2)
      .map((word) => word[0].toUpperCase())
      .join();

  @override
  Widget build(BuildContext context) {
    final Widget face = photoUrl.startsWith('http')
        ? CachedNetworkImage(
      imageUrl: photoUrl,
      fit: BoxFit.cover,
      errorWidget: (_, _, _) => _fallback(),
    )
        : _fallback();

    return SizedBox.square(
      dimension: size + 8,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: speaking ? HuddleColors.speaking : Colors.transparent,
                width: 2.5,
              ),
              boxShadow: speaking
                  ? [
                BoxShadow(
                  color: HuddleColors.speaking.withValues(alpha: .35),
                  blurRadius: 14,
                ),
              ]
                  : const [],
            ),
            child: ClipOval(
              child: SizedBox.square(dimension: size, child: face),
            ),
          ),
          if (muted)
            Positioned(
              right: 0,
              bottom: 0,
              child: _badge(Icons.mic_off_rounded, const Color(0xFF3A4A63)),
            ),
          if (handRaised)
            Positioned(
              right: 0,
              top: 0,
              child: _badge(Icons.back_hand_rounded, HuddleColors.host),
            ),
        ],
      ),
    );
  }

  Widget _fallback() => ColoredBox(
    color: HuddleColors.skyDeep,
    child: Center(
      child: Text(
        _initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * .34,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );

  Widget _badge(IconData icon, Color color) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: HuddleColors.stage, width: 2),
    ),
    child: Icon(icon, size: size * .2 + 2, color: Colors.white),
  );
}

//===================================================
// ROLE BADGE
//===================================================

class HuddleRoleBadge extends StatelessWidget {
  const HuddleRoleBadge({super.key, required this.role});

  final HuddleRole role;

  @override
  Widget build(BuildContext context) {
    final Color color = HuddleColors.role(role);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: .45)),
      ),
      child: Text(
        role.label,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

//===================================================
// LIVE PILL
//===================================================

class HuddleLivePill extends StatelessWidget {
  const HuddleLivePill({super.key, this.small = false});

  final bool small;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 7 : 9,
        vertical: small ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: HuddleColors.live,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: small ? 5 : 6,
            height: small ? 5 : 6,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: small ? 4 : 5),
          Text(context.tr('LIVE'),
            style: TextStyle(
              color: Colors.white,
              fontSize: small ? 10 : 11,
              fontWeight: FontWeight.w800,
              letterSpacing: .8,
            ),
          ),
        ],
      ),
    );
  }
}