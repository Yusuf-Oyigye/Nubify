import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../resources/auth_method.dart';
import '../responsive/mobile_screen_layout.dart';
import '../responsive/responsive_layout_screen.dart';
import '../responsive/web_screen_layout.dart';
import '../utils/color.dart';
import '../utils/utils.dart';
import '../widgets/text_field_input.dart';

import 'signup_screen.dart';

//===================================================
// LOGIN SCREEN
//===================================================

class LoginScreen
    extends StatefulWidget {
  const LoginScreen({
    super.key,
  });

  @override
  State<LoginScreen>
  createState() =>
      _LoginScreenState();
}

//===================================================
// LOGIN STATE
//===================================================

class _LoginScreenState
    extends State<LoginScreen> {
  final TextEditingController
  _emailController =
  TextEditingController();

  final TextEditingController
  _passwordController =
  TextEditingController();

  bool _isLoading =
  false;

  //===================================================
  // LOGIN
  //===================================================

  Future<void> _loginUser() async {
    if (_isLoading) {
      return;
    }

    FocusScope.of(
      context,
    ).unfocus();

    setState(() {
      _isLoading =
      true;
    });

    final String res =
    await AuthMethods()
        .loginUser(
      email:
      _emailController.text
          .trim(),

      password:
      _passwordController.text,
    );

    if (!mounted) {
      return;
    }

    if (res ==
        'success') {
      Navigator.of(
        context,
      ).pushReplacement(
        MaterialPageRoute<void>(
          builder:
              (_) =>
          const ResponsiveLayout(
            mobileScreenLayout:
            MobileScreenLayout(),
            webScreenLayout:
            WebScreenLayout(),
          ),
        ),
      );
    } else {
      showSnackBar(
        res,
        context,
      );
    }

    if (mounted) {
      setState(() {
        _isLoading =
        false;
      });
    }
  }

  //===================================================
  // FORGOT PASSWORD
  //===================================================

  Future<void>
  _forgotPassword() async {
    final String email =
    _emailController.text
        .trim();

    if (email.isEmpty) {
      showSnackBar(
        'Please enter your email first',
        context,
      );

      return;
    }

    try {
      await FirebaseAuth.instance
          .sendPasswordResetEmail(
        email:
        email,
      );

      if (!mounted) {
        return;
      }

      showSnackBar(
        'A password reset link has been sent to your email.',
        context,
      );
    } on FirebaseAuthException catch (
    error
    ) {
    if (!mounted) {
    return;
    }

    showSnackBar(
    error.message ??
    'Unable to send password reset email.',
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
    ).push(
      MaterialPageRoute<void>(
        builder:
            (_) =>
        const SignupScreen(),
      ),
    );
  }

  //===================================================
  // BUILD
  //===================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      body:
      SafeArea(
        child:
        SingleChildScrollView(
          padding:
          const EdgeInsets
              .symmetric(
            horizontal:
            32,
          ),
          child:
          ConstrainedBox(
            constraints:
            BoxConstraints(
              minHeight:
              MediaQuery.of(
                context,
              )
                  .size
                  .height -
                  MediaQuery.of(
                    context,
                  )
                      .padding
                      .vertical,
            ),
            child:
            Column(
              crossAxisAlignment:
              CrossAxisAlignment
                  .center,
              children:
              <Widget>[
                const SizedBox(
                  height:
                  80,
                ),

                SvgPicture.asset(
                  'assets/ic_nubify.svg',
                  colorFilter:
                  const ColorFilter
                      .mode(
                    primaryColor,
                    BlendMode.srcIn,
                  ),
                  height:
                  64,
                ),

                const SizedBox(
                  height:
                  14,
                ),

                const Text(
                  'Welcome back',
                  style:
                  TextStyle(
                    fontSize:
                    23,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height:
                  6,
                ),

                Text(
                  'Log in to continue to Nubify',
                  style:
                  TextStyle(
                    color:
                    Colors.grey
                        .shade500,
                  ),
                ),

                const SizedBox(
                  height:
                  42,
                ),

                TextFieldInput(
                  hintText:
                  'Enter your email',

                  textInputType:
                  TextInputType
                      .emailAddress,

                  textEditingController:
                  _emailController,

                  prefixIcon:
                  Icons
                      .email_outlined,

                  textInputAction:
                  TextInputAction
                      .next,
                ),

                const SizedBox(
                  height:
                  18,
                ),

                TextFieldInput(
                  hintText:
                  'Enter your password',

                  textInputType:
                  TextInputType.text,

                  textEditingController:
                  _passwordController,

                  prefixIcon:
                  Icons
                      .lock_outline_rounded,

                  isPass:
                  true,

                  textInputAction:
                  TextInputAction
                      .done,

                  onSubmitted:
                      (_) {
                    _loginUser();
                  },
                ),

                const SizedBox(
                  height:
                  10,
                ),

                Align(
                  alignment:
                  Alignment
                      .centerRight,
                  child:
                  TextButton.icon(
                    onPressed:
                    _forgotPassword,

                    icon:
                    const Icon(
                      Icons
                          .lock_reset_rounded,
                      size:
                      18,
                    ),

                    label:
                    const Text(
                      'Forgot password?',
                    ),
                  ),
                ),

                const SizedBox(
                  height:
                  18,
                ),

                InkWell(
                  onTap:
                  _isLoading
                      ? null
                      : _loginUser,

                  borderRadius:
                  BorderRadius.circular(
                    10,
                  ),

                  child:
                  Container(
                    width:
                    double.infinity,

                    alignment:
                    Alignment.center,

                    padding:
                    const EdgeInsets
                        .symmetric(
                      vertical:
                      14,
                    ),

                    decoration:
                    const ShapeDecoration(
                      shape:
                      RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.all(
                          Radius.circular(
                            10,
                          ),
                        ),
                      ),
                      color:
                      blueColor,
                    ),

                    child:
                    _isLoading
                        ? const SizedBox(
                      width:
                      22,
                      height:
                      22,
                      child:
                      CircularProgressIndicator(
                        strokeWidth:
                        2.5,
                        color:
                        Colors.white,
                      ),
                    )
                        : const Row(
                      mainAxisAlignment:
                      MainAxisAlignment.center,
                      mainAxisSize:
                      MainAxisSize.min,
                      children:
                      <Widget>[
                        Icon(
                          Icons.login_rounded,
                          size: 20,
                        ),
                        SizedBox(
                          width: 8,
                        ),
                        Text(
                          'Log in',
                          style:
                          TextStyle(
                            fontWeight:
                            FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(
                  height:
                  40,
                ),

                Row(
                  mainAxisAlignment:
                  MainAxisAlignment
                      .center,
                  children:
                  <Widget>[
                    const Text(
                      "Don't have an account?",
                    ),

                    TextButton.icon(
                      onPressed:
                      _navigateToSignup,

                      icon:
                      const Icon(
                        Icons
                            .person_add_alt_1_rounded,
                        size:
                        18,
                      ),

                      label:
                      const Text(
                        'Sign up',
                        style:
                        TextStyle(
                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height:
                  30,
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