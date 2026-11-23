import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/auth/auth_method.dart';
import '../../services/common/language_preference.dart';
import '../../responsive/mobile_screen_layout.dart';
import '../../responsive/responsive_layout_screen.dart';
import '../../responsive/web_screen_layout.dart';
import '../../utils/common/utils.dart';
import '../../widgets/auth/language_picker.dart';
import '../../widgets/auth/nubify_auth_style.dart';

import 'signup_screen.dart';

//===================================================
// LOGIN SCREEN
//
// Premium blue & black: the Nubify logo card floats on
// a dark animated background, then the welcome text,
// the login panel and the sign-up link slide in.
//===================================================

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

//===================================================
// LOGIN STATE
//===================================================

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();

  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;

  String _language = 'en';

  // Set when the language is changed here, so it is saved
  // to the profile once logged in.
  bool _languageChanged = false;

  @override
  void initState() {
    super.initState();

    LanguagePreference.load().then((String code) {
      if (mounted) setState(() => _language = code);
    });
  }

  void _setLanguage(String code) {
    setState(() {
      _language = code;
      _languageChanged = true;
    });
    LanguagePreference.save(code);
  }

  //===================================================
  // LOGIN
  //===================================================

  Future<void> _loginUser() async {
    if (_isLoading) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
    });

    final String res = await AuthMethods().loginUser(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) {
      return;
    }

    if (res == 'success') {
      if (_languageChanged) {
        await LanguagePreference.save(_language);
        if (!mounted) return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => const ResponsiveLayout(
            mobileScreenLayout: MobileScreenLayout(),
            webScreenLayout: WebScreenLayout(),
          ),
        ),
      );
    } else {
      showSnackBar(res, context);
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  //===================================================
  // FORGOT PASSWORD
  //===================================================

  Future<void> _forgotPassword() async {
    final String email = _emailController.text.trim();

    if (email.isEmpty) {
      showSnackBar('Please enter your email first', context);

      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      if (!mounted) {
        return;
      }

      showSnackBar(
        'A password reset link has been sent to your email.',
        context,
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) {
        return;
      }

      showSnackBar(
        error.message ?? 'Unable to send password reset email.',
        context,
      );
    }
  }

  //===================================================
  // SIGNUP
  //===================================================

  void _navigateToSignup() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const SignupScreen()));
  }

  //===================================================
  // BUILD
  //===================================================

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final double safeTop = MediaQuery.paddingOf(context).top;

    // The hero logo shrinks on short phones so the form fits.
    final double logoHeight = math.min(
      size.height * (size.height < 760 ? 0.28 : 0.34),
      (math.min(size.width, 440) - 44) / _LoginHeroLogo.aspectRatio,
    );

    // Where the logo starts: under the language pill.
    final double logoTop = safeTop + 12 + 40 + 6;

    return NubifyAuthTheme(
      child: Scaffold(
        body: NubifyAuthBackground(
          // The blue backdrop scrolls with the form, so the
          // logo always sits on its matching blue.
          child: SingleChildScrollView(
            child: Stack(
              children: <Widget>[
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: logoTop + logoHeight + 170,
                  child: _LoginBackdrop(
                    logoTop: logoTop,
                    logoHeight: logoHeight,
                  ),
                ),
                SafeArea(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: AutofillGroup(
                          child: Column(
                            children: <Widget>[
                              SizedBox(
                                height: 40,
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: NubifyLanguagePicker(
                                    code: _language,
                                    onChanged: _setLanguage,
                                    compact: true,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 6),

                              NubifyAuthEntrance(
                                delay: const Duration(milliseconds: 100),
                                child: _LoginHeroLogo(height: logoHeight),
                              ),

                              const SizedBox(height: 10),

                              //===================================================
                              // WELCOME
                              //===================================================
                              const NubifyAuthEntrance(
                                delay: Duration(milliseconds: 250),
                                child: Column(
                                  children: <Widget>[
                                    Text(
                                      'Welcome back',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: NubifyAuthColors.text,
                                        fontSize: 28,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.4,
                                      ),
                                    ),
                                    SizedBox(height: 6),
                                    Text(
                                      'Log in to your campus, your people, your vibe.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: NubifyAuthColors.muted,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 24),

                              //===================================================
                              // LOGIN PANEL
                              //===================================================
                              NubifyAuthEntrance(
                                delay: const Duration(milliseconds: 400),
                                child: NubifyAuthPanel(
                                  child: Column(
                                    children: <Widget>[
                                      NubifyAuthField(
                                        controller: _emailController,
                                        label: 'Email',
                                        hint: 'you@example.com',
                                        icon: Icons.email_outlined,
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        textInputAction: TextInputAction.next,
                                        autofillHints: const <String>[
                                          AutofillHints.email,
                                        ],
                                      ),

                                      const SizedBox(height: 14),

                                      NubifyAuthField(
                                        controller: _passwordController,
                                        label: 'Password',
                                        icon: Icons.lock_outline_rounded,
                                        isPassword: true,
                                        textInputAction: TextInputAction.done,
                                        autofillHints: const <String>[
                                          AutofillHints.password,
                                        ],
                                        onSubmitted: (_) {
                                          _loginUser();
                                        },
                                      ),

                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton(
                                          onPressed: _forgotPassword,
                                          child: const Text('Forgot password?'),
                                        ),
                                      ),

                                      const SizedBox(height: 4),

                                      NubifyAuthButton(
                                        label: 'Log in',
                                        icon: Icons.arrow_forward_rounded,
                                        loading: _isLoading,
                                        onPressed: _loginUser,
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(height: 22),

                              //===================================================
                              // SIGN UP
                              //===================================================
                              NubifyAuthEntrance(
                                delay: const Duration(milliseconds: 550),
                                child: Wrap(
                                  alignment: WrapAlignment.center,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: <Widget>[
                                    const Text(
                                      'New to Nubify?',
                                      style: TextStyle(
                                        color: NubifyAuthColors.muted,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: _navigateToSignup,
                                      child: const Text('Create an account'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  //===================================================
  // DISPOSE
  //===================================================

  @override
  void dispose() {
    _emailController.dispose();

    _passwordController.dispose();

    super.dispose();
  }
}

//===================================================
// HERO LOGO
//
// The Nubify logo picture with softly faded edges, so it
// melts into the blue backdrop behind it.
//===================================================

class _LoginHeroLogo extends StatelessWidget {
  const _LoginHeroLogo({required this.height});

  final double height;

  static const String asset = 'assets/images/nubify_login_hero.jpg';

  // Width / height of the picture.
  static const double aspectRatio = 1086 / 1190;

  static Shader _fade(Rect rect, Alignment begin, Alignment end, double edge) {
    return LinearGradient(
      begin: begin,
      end: end,
      colors: const <Color>[
        Colors.transparent,
        Colors.white,
        Colors.white,
        Colors.transparent,
      ],
      stops: <double>[0, edge, 1 - edge, 1],
    ).createShader(rect);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: height * aspectRatio,
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (Rect rect) =>
            _fade(rect, Alignment.centerLeft, Alignment.centerRight, 0.04),
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (Rect rect) =>
              _fade(rect, Alignment.topCenter, Alignment.bottomCenter, 0.02),
          child: Image.asset(
            asset,
            fit: BoxFit.cover,
            semanticLabel: 'Nubify, Campus Social. Powered by Digitaldoc',
          ),
        ),
      ),
    );
  }
}

//===================================================
// BLUE BACKDROP
//
// Blue at the top, following the logo picture's own
// edge colours, then fading into the black background.
// A soft glow matches the brighter middle of the picture
// so its edges disappear.
//===================================================

class _LoginBackdrop extends StatelessWidget {
  const _LoginBackdrop({required this.logoTop, required this.logoHeight});

  final double logoTop;
  final double logoHeight;

  @override
  Widget build(BuildContext context) {
    final double total = logoTop + logoHeight + 170;
    final double glow = logoHeight * _LoginHeroLogo.aspectRatio;

    final Widget base = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const <Color>[
            Color(0xFF0544A1),
            Color(0xFF0544A1),
            Color(0xFF003487),
            Color(0xFF002F7E),
            Color(0x00002F7E),
          ],
          stops: <double>[
            0,
            logoTop / total,
            (logoTop + logoHeight / 2) / total,
            (logoTop + logoHeight) / total,
            1,
          ],
        ),
      ),
    );

    return Stack(
      children: <Widget>[
        Positioned.fill(child: base),
        Positioned(
          top: logoTop - glow * 0.45,
          left: 0,
          right: 0,
          height: glow * 0.9,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: <Color>[Color(0xFF0254C0), Color(0x000254C0)],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
