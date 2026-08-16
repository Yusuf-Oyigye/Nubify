import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:nubify/resources/auth_method.dart';
import 'package:nubify/responsive/mobile_screen_layout.dart';
import 'package:nubify/responsive/responsive_layout_screen.dart';
import 'package:nubify/responsive/web_screen_layout.dart';
import 'package:nubify/screens/signup_screen.dart';
import 'package:nubify/utils/color.dart';
import 'package:nubify/utils/utils.dart';
import 'package:nubify/widgets/text_field_input.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController =
  TextEditingController();

  final TextEditingController _passwordController =
  TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    super.dispose();
    _emailController.dispose();
    _passwordController.dispose();
  }

  void loginUser() async {
    setState(() {
      _isLoading = true;
    });

    String res = await AuthMethods().loginUser(
      email: _emailController.text,
      password: _passwordController.text,
    );

    if (res == "success") {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const ResponsiveLayout(
            mobileScreenLayout: MobileScreenLayout(),
            webScreenLayout: WebScreenLayout(),
          ),
        ),
      );
    } else {
      showSnackBar(res, context);
    }

    setState(() {
      _isLoading = false;
    });
  }

  void navigateToSignup() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SignupScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 32,
          ),
          width: double.infinity,
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Container(),
                flex: 2,
              ),

              // svg image
              SvgPicture.asset(
                'assets/ic_nubify.svg',
                colorFilter: const ColorFilter.mode(
                  primaryColor,
                  BlendMode.srcIn,
                ),
                height: 64,
              ),

              const SizedBox(
                height: 64,
              ),

              // text field input for email
              TextFieldInput(
                hintText: 'Enter your email',
                textInputType:
                TextInputType.emailAddress,
                textEditingController:
                _emailController,
              ),

              const SizedBox(
                height: 24,
              ),

              // text field input for password
              TextFieldInput(
                hintText: 'Enter your password',
                textInputType: TextInputType.text,
                textEditingController:
                _passwordController,
                isPass: true,
              ),

              const SizedBox(
                height: 8,
              ),

              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () async {
                    if (_emailController.text.trim().isEmpty) {
                      showSnackBar(
                        'Please enter your email first',
                        context,
                      );
                      return;
                    }

                    try {
                      await  FirebaseAuth.instance.sendPasswordResetEmail(
                        email: _emailController.text.trim(),
                      );

                      showSnackBar(
                        'A password reset link has been sent to your email.',
                        context,
                      );
                    } catch (e) {
                      showSnackBar(
                        e.toString(),
                        context,
                      );
                    }
                  },
                  child: const Text(
                    'Forgot password?',
                    style: TextStyle(
                      color: blueColor,
                      fontWeight:
                      FontWeight.w500,
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height: 24,
              ),

              // button login
              InkWell(
                onTap: loginUser,
                child: Container(
                  width: double.infinity,
                  alignment: Alignment.center,
                  padding:
                  const EdgeInsets.symmetric(
                    vertical: 12,
                  ),
                  decoration:
                  const ShapeDecoration(
                    shape:
                    RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.all(
                        Radius.circular(4),
                      ),
                    ),
                    color: blueColor,
                  ),
                  child: _isLoading
                      ? const Center(
                    child:
                    CircularProgressIndicator(
                      color:
                      primaryColor,
                    ),
                  )
                      : const Text(
                    'Log in',
                  ),
                ),
              ),

              Flexible(
                child: Container(),
                flex: 2,
              ),

              // Transitioning to signing up
              Row(
                mainAxisAlignment:
                MainAxisAlignment.center,
                children: [
                  Container(
                    padding:
                    const EdgeInsets.symmetric(
                      vertical: 8,
                    ),
                    child: const Text(
                      "Don't have an account?",
                    ),
                  ),

                  GestureDetector(
                    onTap: navigateToSignup,
                    child: Container(
                      padding:
                      const EdgeInsets.symmetric(
                        vertical: 8,
                      ),
                      child: const Text(
                        "Sign up",
                        style: TextStyle(
                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}