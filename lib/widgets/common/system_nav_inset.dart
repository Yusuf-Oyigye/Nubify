import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

//===================================================
// SPACE FOR THE PHONE'S NAVIGATION BUTTONS
//
// Android 15+ draws every app behind the back / home /
// recent buttons, so the last words on a page could hide
// under them. This wraps the whole app (main.dart) and
// keeps every screen, sheet and dialog above the buttons.
// The space under the buttons is painted in the app
// background (or [color]) so they sit on a clean strip.
//===================================================

class NubifySystemNavInset extends StatelessWidget {
  const NubifySystemNavInset({super.key, required this.child, this.color});

  final Widget child;

  // Strip colour; the theme background when null.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color background = color ?? theme.scaffoldBackgroundColor;
    final bool darkStrip =
        ThemeData.estimateBrightnessForColor(background) == Brightness.dark;

    // Zero while the keyboard is open (it covers the buttons).
    final double buttons = MediaQuery.paddingOf(context).bottom;

    return ColoredBox(
      color: background,
      child: Column(
        children: <Widget>[
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeBottom: true,
              child: child,
            ),
          ),
          AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle(
              systemNavigationBarColor: background,
              systemNavigationBarDividerColor: Colors.transparent,
              systemNavigationBarIconBrightness: darkStrip
                  ? Brightness.light
                  : Brightness.dark,
              // No white film over the buttons.
              systemNavigationBarContrastEnforced: false,
            ),
            child: SizedBox(width: double.infinity, height: buttons),
          ),
        ],
      ),
    );
  }
}
