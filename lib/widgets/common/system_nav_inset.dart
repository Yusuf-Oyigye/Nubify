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
//
// A screen with its own background (login, signup) can
// colour the strip while it is open with setColor and
// clearColor; the one opened last wins.
//===================================================

class NubifySystemNavInset extends StatelessWidget {
  const NubifySystemNavInset({super.key, required this.child, this.color});

  final Widget child;

  // Strip colour; the theme background when null.
  final Color? color;

  // Screens asking for a strip colour, oldest first.
  static final List<(Object, Color)> _requests = <(Object, Color)>[];

  static final ValueNotifier<Color?> _requested = ValueNotifier<Color?>(null);

  /// Colours the strip for [owner] until [clearColor].
  /// Asking again keeps the owner's place in line.
  static void setColor(Object owner, Color color) {
    final int index = _requests.indexWhere(
      ((Object, Color) request) => request.$1 == owner,
    );

    if (index == -1) {
      _requests.add((owner, color));
    } else {
      _requests[index] = (owner, color);
    }

    _publish();
  }

  static void clearColor(Object owner) {
    _requests.removeWhere(((Object, Color) request) => request.$1 == owner);
    _publish();
  }

  static void _publish() {
    // After the frame: the strip sits above every screen,
    // so it must not change while a screen is building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requested.value = _requests.isEmpty ? null : _requests.last.$2;
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color?>(
      valueListenable: _requested,
      builder: (BuildContext context, Color? requested, Widget? _) {
        return _strip(context, requested ?? color);
      },
    );
  }

  Widget _strip(BuildContext context, Color? stripColor) {
    final ThemeData theme = Theme.of(context);
    final Color background = stripColor ?? theme.scaffoldBackgroundColor;
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
