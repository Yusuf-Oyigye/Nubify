import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../common/system_nav_inset.dart';

//===================================================
// NUBIFY AUTH — PREMIUM BLUE & BLACK
//
// Shared look for the login and signup screens: a deep
// black background with slowly drifting blue glows, the
// Nubify logo card, frosted glass panels, and fields and
// buttons in mature royal blue. Every animation stops
// when the phone asks for reduced motion.
//
// Login is always dark. Signup has a light version too
// and follows the phone (see NubifyAuthTone).
//===================================================

class NubifyAuthColors {
  NubifyAuthColors._();

  static const Color black = Color(0xFF04060C);
  static const Color night = Color(0xFF0A1022);
  static const Color navy = Color(0xFF0B1A3D);

  // The blue of the Nubify logo.
  static const Color royal = Color(0xFF1546C9);
  static const Color electric = Color(0xFF2F6BFF);
  static const Color sky = Color(0xFF5B9BFF);

  static const Color glass = Color(0x14FFFFFF);
  static const Color glassEdge = Color(0x24FFFFFF);
  static const Color text = Color(0xFFF2F5FB);
  static const Color muted = Color(0xFF94A3C0);

  static const LinearGradient button = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[electric, royal, Color(0xFF0E2F8F)],
  );
}

//===================================================
// LIGHT AND DARK TONES
//
// The colours that change between light and dark. The
// widgets below read them with NubifyAuthTone.of(context).
//===================================================

@immutable
class NubifyAuthTone {
  const NubifyAuthTone._({
    required this.background,
    required this.glowStrength,
    required this.text,
    required this.muted,
    required this.accent,
    required this.glass,
    required this.glassEdge,
    required this.selected,
    required this.panel,
    required this.panelShadow,
  });

  // Top, middle and bottom of the page.
  final List<Color> background;

  // How strong the drifting blue glows are.
  final double glowStrength;

  final Color text;
  final Color muted;

  // Links, field labels and focus rings.
  final Color accent;

  // Fill and edge of fields and outline buttons.
  final Color glass;
  final Color glassEdge;

  // Fill of a chosen option (language, male/female).
  final Color selected;

  final List<Color> panel;
  final Color panelShadow;

  static const NubifyAuthTone dark = NubifyAuthTone._(
    background: <Color>[
      NubifyAuthColors.night,
      NubifyAuthColors.black,
      Color(0xFF02040A),
    ],
    glowStrength: 1,
    text: NubifyAuthColors.text,
    muted: NubifyAuthColors.muted,
    accent: NubifyAuthColors.sky,
    glass: NubifyAuthColors.glass,
    glassEdge: NubifyAuthColors.glassEdge,
    selected: Color(0x591546C9),
    panel: <Color>[Color(0x13FFFFFF), Color(0x08FFFFFF)],
    panelShadow: Color(0x73000000),
  );

  static const NubifyAuthTone light = NubifyAuthTone._(
    background: <Color>[
      Color(0xFFE6EEFF),
      Color(0xFFF3F6FF),
      Color(0xFFFFFFFF),
    ],
    glowStrength: 0.4,
    text: Color(0xFF0B1A3D),
    muted: Color(0xFF5A6B8C),
    accent: NubifyAuthColors.royal,
    glass: Color(0xFFF2F5FC),
    glassEdge: Color(0xFFD5DEF0),
    selected: Color(0x1F1546C9),
    panel: <Color>[Color(0xF5FFFFFF), Color(0xEBF8FAFF)],
    panelShadow: Color(0x1F0B1A3D),
  );

  static NubifyAuthTone forBrightness(Brightness brightness) =>
      brightness == Brightness.light ? light : dark;

  /// The tone of the NubifyAuthTheme above [context].
  static NubifyAuthTone of(BuildContext context) =>
      forBrightness(Theme.of(context).brightness);
}

bool _reduceMotion(BuildContext context) =>
    MediaQuery.maybeOf(context)?.disableAnimations ?? false;

//===================================================
// THEME FOR THE AUTH SCREENS
//
// Keeps dropdowns, snack bars and text fields in the
// auth look whatever the app's own theme is. Dark by
// default (login); signup passes the phone's brightness.
// While open, it also colours the strip under the phone's
// navigation buttons to match its background.
//===================================================

class NubifyAuthTheme extends StatefulWidget {
  const NubifyAuthTheme({
    super.key,
    required this.child,
    this.brightness = Brightness.dark,
  });

  final Widget child;
  final Brightness brightness;

  @override
  State<NubifyAuthTheme> createState() => _NubifyAuthThemeState();
}

class _NubifyAuthThemeState extends State<NubifyAuthTheme> {
  NubifyAuthTone get _tone => NubifyAuthTone.forBrightness(widget.brightness);

  @override
  void initState() {
    super.initState();
    NubifySystemNavInset.setColor(this, _tone.background.last);
  }

  @override
  void didUpdateWidget(NubifyAuthTheme oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.brightness != widget.brightness) {
      NubifySystemNavInset.setColor(this, _tone.background.last);
    }
  }

  @override
  void dispose() {
    NubifySystemNavInset.clearColor(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final NubifyAuthTone tone = _tone;
    final bool dark = widget.brightness == Brightness.dark;

    final ThemeData base = ThemeData(
      useMaterial3: true,
      brightness: widget.brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: NubifyAuthColors.royal,
        brightness: widget.brightness,
        primary: tone.accent,
        surface: dark ? NubifyAuthColors.night : Colors.white,
      ),
      scaffoldBackgroundColor: tone.background.last,
      fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
    );

    final OutlineInputBorder border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: tone.glassEdge),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Light status bar icons on dark, dark icons on light.
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: widget.brightness,
      ),
      child: Theme(
        data: base.copyWith(
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: tone.glass,
            hintStyle: TextStyle(color: tone.muted),
            labelStyle: TextStyle(color: tone.muted),
            floatingLabelStyle: TextStyle(color: tone.accent),
            prefixIconColor: tone.accent,
            suffixIconColor: tone.muted,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: border,
            enabledBorder: border,
            focusedBorder: border.copyWith(
              borderSide: BorderSide(color: tone.accent, width: 1.4),
            ),
          ),
          snackBarTheme: const SnackBarThemeData(
            behavior: SnackBarBehavior.floating,
            backgroundColor: NubifyAuthColors.navy,
            contentTextStyle: TextStyle(color: NubifyAuthColors.text),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: tone.accent,
              // Keep the app font; only make the label bolder.
              textStyle: base.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          progressIndicatorTheme: ProgressIndicatorThemeData(
            color: tone.accent,
          ),
        ),
        child: widget.child,
      ),
    );
  }
}

//===================================================
// ANIMATED BACKGROUND
//
// Black with deep blue glows that drift slowly.
//===================================================

class NubifyAuthBackground extends StatefulWidget {
  const NubifyAuthBackground({super.key, required this.child});

  final Widget child;

  @override
  State<NubifyAuthBackground> createState() => _NubifyAuthBackgroundState();
}

class _NubifyAuthBackgroundState extends State<NubifyAuthBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_reduceMotion(context)) {
      _drift.stop();
    } else if (!_drift.isAnimating) {
      _drift.repeat();
    }
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  Widget _glow(Color color, double size, double alpha) {
    alpha *= NubifyAuthTone.of(context).glowStrength;

    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: NubifyAuthTone.of(context).background,
        ),
      ),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _drift,
                builder: (BuildContext context, Widget? child) {
                  final double t = _drift.value * 2 * math.pi;

                  return Stack(
                    children: <Widget>[
                      Align(
                        alignment: Alignment(
                          -0.9 + math.sin(t) * 0.25,
                          -0.85 + math.cos(t) * 0.12,
                        ),
                        child: _glow(NubifyAuthColors.royal, 420, 0.45),
                      ),
                      Align(
                        alignment: Alignment(
                          1.1 + math.cos(t) * 0.2,
                          0.15 + math.sin(t) * 0.2,
                        ),
                        child: _glow(NubifyAuthColors.electric, 360, 0.22),
                      ),
                      Align(
                        alignment: Alignment(
                          -0.6 + math.sin(t + 2) * 0.3,
                          1.15,
                        ),
                        child: _glow(const Color(0xFF1B2F7A), 380, 0.35),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          Positioned.fill(child: widget.child),
        ],
      ),
    );
  }
}

//===================================================
// LOGO CARD
//
// The Nubify logo pops in, floats gently and catches a
// soft light sweep every few seconds.
//===================================================

class NubifyAuthLogo extends StatefulWidget {
  const NubifyAuthLogo({super.key, required this.width});

  final double width;

  static const String asset = 'assets/images/nubify_logo.webp';

  @override
  State<NubifyAuthLogo> createState() => _NubifyAuthLogoState();
}

class _NubifyAuthLogoState extends State<NubifyAuthLogo>
    with TickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  );

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_reduceMotion(context)) {
      _enter.value = 1;
      _loop.stop();
      return;
    }

    if (!_started) {
      _started = true;
      _enter.forward();
      _loop.repeat();
    }
  }

  @override
  void dispose() {
    _enter.dispose();
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double width = widget.width;
    final double height = width * 1448 / 1086;
    final BorderRadius radius = BorderRadius.circular(width * 0.11);

    final Widget card = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: NubifyAuthColors.royal.withValues(alpha: 0.55),
            blurRadius: 46,
            spreadRadius: 2,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Image.asset(
              NubifyAuthLogo.asset,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
              semanticLabel: 'Nubify, campus social. Powered by Digitaldoc.',
            ),

            // A soft light sweep across the card.
            AnimatedBuilder(
              animation: _loop,
              builder: (BuildContext context, Widget? child) {
                final double sweep = (_loop.value * 1.6 - 0.3).clamp(-0.3, 1.3);

                return IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        stops: <double>[
                          (sweep - 0.12).clamp(0.0, 1.0),
                          sweep.clamp(0.0, 1.0),
                          (sweep + 0.12).clamp(0.0, 1.0),
                        ],
                        colors: <Color>[
                          Colors.white.withValues(alpha: 0),
                          Colors.white.withValues(alpha: 0.16),
                          Colors.white.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

            // Thin bright edge.
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[_enter, _loop]),
      child: card,
      builder: (BuildContext context, Widget? child) {
        final double enter = Curves.easeOutBack.transform(_enter.value);
        final double float = math.sin(_loop.value * 2 * math.pi) * 6;

        return Opacity(
          opacity: _enter.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, float + (1 - _enter.value) * 24),
            child: Transform.scale(scale: 0.86 + 0.14 * enter, child: child),
          ),
        );
      },
    );
  }
}

//===================================================
// ENTRANCE: FADE AND SLIDE UP
//
// Wrap pieces of a screen with increasing delays so
// they arrive one after another.
//===================================================

class NubifyAuthEntrance extends StatefulWidget {
  const NubifyAuthEntrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
  });

  final Widget child;
  final Duration delay;

  @override
  State<NubifyAuthEntrance> createState() => _NubifyAuthEntranceState();
}

class _NubifyAuthEntranceState extends State<NubifyAuthEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_started) return;
    _started = true;

    if (_reduceMotion(context)) {
      _controller.value = 1;
      return;
    }

    Future<void>.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Animation<double> curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.18),
          end: Offset.zero,
        ).animate(curve),
        child: widget.child,
      ),
    );
  }
}

//===================================================
// GLASS PANEL
//===================================================

class NubifyAuthPanel extends StatelessWidget {
  const NubifyAuthPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(18, 20, 18, 18),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final NubifyAuthTone tone = NubifyAuthTone.of(context);

    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: tone.panel,
        ),
        border: Border.all(color: tone.glassEdge),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: tone.panelShadow,
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );
  }
}

//===================================================
// TEXT FIELD
//===================================================

class NubifyAuthField extends StatefulWidget {
  const NubifyAuthField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
    this.keyboardType = TextInputType.text,
    this.textInputAction,
    this.onSubmitted,
    this.isPassword = false,
    this.maxLines = 1,
    this.autofillHints,
    this.textCapitalization = TextCapitalization.none,
    this.textDirection,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? hint;
  final TextInputType keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final bool isPassword;
  final int maxLines;
  final Iterable<String>? autofillHints;
  final TextCapitalization textCapitalization;

  // Typing direction, e.g. left to right for an email
  // on an Arabic screen. Follows the screen when null.
  final TextDirection? textDirection;

  @override
  State<NubifyAuthField> createState() => _NubifyAuthFieldState();
}

class _NubifyAuthFieldState extends State<NubifyAuthField> {
  late bool _hidden = widget.isPassword;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      onSubmitted: widget.onSubmitted,
      obscureText: widget.isPassword && _hidden,
      maxLines: widget.isPassword ? 1 : widget.maxLines,
      autofillHints: widget.autofillHints,
      textCapitalization: widget.textCapitalization,
      textDirection: widget.textDirection,
      cursorColor: NubifyAuthTone.of(context).accent,
      style: TextStyle(color: NubifyAuthTone.of(context).text, fontSize: 15.5),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        prefixIcon: Icon(widget.icon),
        suffixIcon: widget.isPassword
            ? IconButton(
                tooltip: _hidden ? 'Show password' : 'Hide password',
                onPressed: () => setState(() => _hidden = !_hidden),
                icon: Icon(
                  _hidden
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              )
            : null,
      ),
    );
  }
}

//===================================================
// BUTTONS
//===================================================

class NubifyAuthButton extends StatefulWidget {
  const NubifyAuthButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  State<NubifyAuthButton> createState() => _NubifyAuthButtonState();
}

class _NubifyAuthButtonState extends State<NubifyAuthButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onPressed != null && !widget.loading;

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: enabled ? widget.onPressed : null,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1,
          duration: const Duration(milliseconds: 120),
          child: AnimatedOpacity(
            opacity: widget.onPressed == null ? 0.55 : 1,
            duration: const Duration(milliseconds: 150),
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                gradient: NubifyAuthColors.button,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: NubifyAuthColors.royal.withValues(alpha: 0.55),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Center(
                child: widget.loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            widget.label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(widget.icon, color: Colors.white, size: 20),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class NubifyAuthGhostButton extends StatelessWidget {
  const NubifyAuthGhostButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final NubifyAuthTone tone = NubifyAuthTone.of(context);

    return SizedBox(
      height: 56,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: tone.text,
          disabledForegroundColor: tone.muted.withValues(alpha: 0.5),
          backgroundColor: tone.glass,
          side: BorderSide(color: tone.glassEdge),
          textStyle: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}
