import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/auth/auth_method.dart';
import '../../responsive/mobile_screen_layout.dart';
import '../../responsive/responsive_layout_screen.dart';
import '../../responsive/web_screen_layout.dart';
import '../../utils/common/utils.dart';
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

    // The logo shrinks on short phones so the form fits.
    final double logoWidth = math.min(
      math.min(size.width * 0.52, 230),
      size.height * 0.27,
    );

    return NubifyAuthTheme(
      child: Scaffold(
        body: NubifyAuthBackground(
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: AutofillGroup(
                    child: Column(
                      children: <Widget>[
                        NubifyAuthLogo(width: logoWidth),

                        const SizedBox(height: 28),

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
                                  icon: Icons.alternate_email_rounded,
                                  keyboardType: TextInputType.emailAddress,
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
                                style: TextStyle(color: NubifyAuthColors.muted),
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
