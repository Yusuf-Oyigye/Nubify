import 'package:flutter/material.dart';

//===================================================
// COUNT BADGE
//
// A red pill with the number of things still waiting,
// e.g. unread messages. Shows 99+ above 99.
//===================================================

class NubifyCountBadge extends StatelessWidget {
  const NubifyCountBadge({super.key, required this.count, this.small = false});

  final int count;

  final bool small;

  static const Color red = Color(0xFFE53935);

  @override
  Widget build(BuildContext context) {
    final double size = small ? 16 : 18;

    return Container(
      constraints: BoxConstraints(minWidth: size, minHeight: size),
      padding: EdgeInsets.symmetric(horizontal: small ? 4 : 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: red,
        borderRadius: BorderRadius.circular(size / 2),
        border: Border.all(
          color: Theme.of(context).scaffoldBackgroundColor,
          width: 1.5,
        ),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        maxLines: 1,
        style: TextStyle(
          color: Colors.white,
          fontSize: small ? 9 : 10,
          fontWeight: FontWeight.w800,
          height: 1.1,
        ),
      ),
    );
  }
}

//===================================================
// ICON WITH COUNT
//
// Puts the count badge on the top right of an icon,
// e.g. Chat and Notifications in the top bar. Nothing
// shows when the count is 0.
//===================================================

class NubifyBadgedIcon extends StatelessWidget {
  const NubifyBadgedIcon({super.key, required this.count, required this.child});

  final int count;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        child,
        if (count > 0)
          Positioned(top: -7, right: -9, child: NubifyCountBadge(count: count)),
      ],
    );
  }
}
