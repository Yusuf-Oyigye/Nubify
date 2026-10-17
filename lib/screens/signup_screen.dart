import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';

import '../resources/auth_method.dart';
import '../utils/color.dart';
import '../utils/egyptian_phone.dart';
import '../utils/utils.dart';

import 'login_screen.dart';

//===================================================
// SIGNUP SCREEN
//===================================================

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

//===================================================
// SIGNUP STATE
//===================================================

class _SignupScreenState extends State<SignupScreen> {
  int _currentStep = 0;

  final TextEditingController _emailController = TextEditingController();

  final TextEditingController _fullNameController = TextEditingController();

  final TextEditingController _usernameController = TextEditingController();

  final TextEditingController _passwordController = TextEditingController();

  final TextEditingController _facultyController = TextEditingController();

  final TextEditingController _phoneController = TextEditingController();

  final TextEditingController _hobbiesController = TextEditingController();

  final TextEditingController _quoteController = TextEditingController();

  Uint8List? _image;

  bool _isLoading = false;

  bool _obscurePassword = true;

  static const Color _blue = Color(0xFF29B6F6);

  //===================================================
  // STEP TITLES
  //===================================================

  final List<String> _stepTitles = const <String>[
    'Your email',
    'Your full name',
    'Choose a username',
    'Create a password',
    'Your faculty',
    'Your mobile number',
    'Your hobbies',
    'Favourite quote',
    'Profile picture',
  ];

  //===================================================
  // STEP ICONS
  //===================================================

  final List<IconData> _stepIcons = const <IconData>[
    Icons.email_outlined,
    Icons.badge_outlined,
    Icons.alternate_email_rounded,
    Icons.lock_outline_rounded,
    Icons.school_outlined,
    Icons.phone_android_rounded,
    Icons.interests_outlined,
    Icons.format_quote_rounded,
    Icons.add_a_photo_outlined,
  ];

  //===================================================
  // PICK IMAGE
  //===================================================

  Future<void> _selectImage() async {
    final Uint8List? image = await pickImage(ImageSource.gallery);

    if (image == null || !mounted) {
      return;
    }

    setState(() {
      _image = image;
    });
  }

  //===================================================
  // NEXT
  //===================================================

  void _nextStep() {
    if (_currentStep == 0 && _emailController.text.trim().isEmpty) {
      showSnackBar('Please enter your email', context);

      return;
    }

    if (_currentStep == 1 && _fullNameController.text.trim().isEmpty) {
      showSnackBar('Please enter your full name', context);

      return;
    }

    if (_currentStep == 2 && _usernameController.text.trim().isEmpty) {
      showSnackBar('Please enter your username', context);

      return;
    }

    if (_currentStep == 3) {
      final String password = _passwordController.text;

      if (password.isEmpty) {
        showSnackBar('Please enter your password', context);

        return;
      }

      if (password.length < 6) {
        showSnackBar('Password must be at least 6 characters', context);

        return;
      }
    }

    if (_currentStep == 4 && _facultyController.text.trim().isEmpty) {
      showSnackBar('Please enter your faculty', context);

      return;
    }

    if (_currentStep == 5 && !EgyptianPhone.isValid(_phoneController.text)) {
      showSnackBar(
        'Enter a valid Egyptian number beginning 010, 011, 012, or 015',
        context,
      );

      return;
    }

    if (_currentStep < 8) {
      setState(() {
        _currentStep++;
      });
    }
  }

  //===================================================
  // PREVIOUS
  //===================================================

  void _previousStep() {
    if (_currentStep <= 0) {
      return;
    }

    setState(() {
      _currentStep--;
    });
  }

  //===================================================
  // SIGN UP
  //===================================================

  Future<void> _signUpUser() async {
    if (_isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final String res = await AuthMethods().signUpUser(
      email: _emailController.text.trim(),

      password: _passwordController.text,

      username: _usernameController.text.trim(),

      fullName: _fullNameController.text.trim(),

      faculty: _facultyController.text.trim(),

      phone: _phoneController.text.trim(),

      hobbies: _hobbiesController.text.trim(),

      favoriteQuote: _quoteController.text.trim(),

      file: _image,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = false;
    });

    if (res == 'success') {
      //=================================================
      // FIREBASE CREATES + SIGNS USER IN.
      // SIGN OUT SO LOGIN PAGE IS REAL LOGIN.
      //=================================================

      await FirebaseAuth.instance.signOut();

      if (!mounted) {
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      );
    } else {
      showSnackBar(res, context);
    }
  }

  //===================================================
  // INPUT FIELD
  //===================================================

  Widget _field({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool optional = false,
    bool multiline = false,
  }) {
    return TextField(
      controller: controller,

      keyboardType: keyboardType,

      maxLines: multiline ? 3 : 1,

      decoration: InputDecoration(
        hintText: hintText,

        labelText: optional ? '$hintText (optional)' : hintText,

        prefixIcon: Icon(icon, color: _blue),

        border: const OutlineInputBorder(),

        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: _blue, width: 1.5),
        ),
      ),
    );
  }

  //===================================================
  // STEP CONTENT
  //===================================================

  Widget _getStepContent() {
    switch (_currentStep) {
      case 0:
        return _field(
          controller: _emailController,
          hintText: 'Email',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        );

      case 1:
        return _field(
          controller: _fullNameController,
          hintText: 'Full name',
          icon: Icons.badge_outlined,
        );

      case 2:
        return _field(
          controller: _usernameController,
          hintText: 'Username',
          icon: Icons.alternate_email_rounded,
        );

      case 3:
        return TextField(
          controller: _passwordController,

          obscureText: _obscurePassword,

          decoration: InputDecoration(
            hintText: 'Password',

            labelText: 'Password',

            prefixIcon: const Icon(Icons.lock_outline_rounded, color: _blue),

            border: const OutlineInputBorder(),

            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: _blue, width: 1.5),
            ),

            suffixIcon: IconButton(
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
          ),
        );

      case 4:
        return _field(
          controller: _facultyController,
          hintText: 'Faculty',
          icon: Icons.school_outlined,
        );

      case 5:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _field(
              controller: _phoneController,
              hintText: 'Egyptian mobile number',
              icon: Icons.phone_android_rounded,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 10),
            Text(
              'Use 010, 011, 012, 015 or the equivalent +20 format. Your number stays private.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ],
        );

      case 6:
        return _field(
          controller: _hobbiesController,
          hintText: 'Hobbies',
          icon: Icons.interests_outlined,
          optional: true,
          multiline: true,
        );

      case 7:
        return _field(
          controller: _quoteController,
          hintText: 'Favourite quote',
          icon: Icons.format_quote_rounded,
          optional: true,
          multiline: true,
        );

      case 8:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CircleAvatar(
              radius: 62,

              backgroundColor: _blue.withValues(alpha: 0.18),

              backgroundImage: _image == null ? null : MemoryImage(_image!),

              child: _image == null
                  ? const Icon(
                      Icons.person_rounded,
                      size: 62,
                      color: Colors.white70,
                    )
                  : null,
            ),

            const SizedBox(height: 14),

            OutlinedButton.icon(
              onPressed: _selectImage,

              icon: const Icon(Icons.add_a_photo_outlined),

              label: Text(
                _image == null ? 'Choose profile picture' : 'Change picture',
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Optional — you can change it later from Edit Profile.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }

  //===================================================
  // BUILD
  //===================================================

  @override
  Widget build(BuildContext context) {
    final double progress = (_currentStep + 1) / 9;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: <Widget>[
              const SizedBox(height: 24),

              SvgPicture.asset(
                'assets/ic_nubify.svg',
                colorFilter: const ColorFilter.mode(
                  primaryColor,
                  BlendMode.srcIn,
                ),
                height: 54,
              ),

              const SizedBox(height: 18),

              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  backgroundColor: Colors.white12,
                  color: _blue,
                ),
              ),

              const SizedBox(height: 24),

              Icon(_stepIcons[_currentStep], color: _blue, size: 34),

              const SizedBox(height: 8),

              Text(
                _stepTitles[_currentStep],
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                'Step ${_currentStep + 1} of 9',
                style: TextStyle(color: Colors.grey.shade500),
              ),

              const SizedBox(height: 24),

              Expanded(
                child: Center(
                  child: SingleChildScrollView(child: _getStepContent()),
                ),
              ),

              const SizedBox(height: 16),

              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _currentStep == 0 ? null : _previousStep,
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text('Previous'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isLoading
                          ? null
                          : _currentStep == 8
                          ? _signUpUser
                          : _nextStep,

                      icon: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              _currentStep == 8
                                  ? Icons.person_add_alt_1_rounded
                                  : Icons.arrow_forward_rounded,
                            ),

                      label: Text(_currentStep == 8 ? 'Sign Up' : 'Next'),

                      style: FilledButton.styleFrom(
                        backgroundColor: _blue,
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ),
                ],
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const Text('Already have an account?'),

                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const LoginScreen(),
                        ),
                      );
                    },

                    icon: const Icon(Icons.login_rounded, size: 18),

                    label: const Text('Log in'),
                  ),
                ],
              ),
            ],
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

    _fullNameController.dispose();

    _usernameController.dispose();

    _passwordController.dispose();

    _facultyController.dispose();

    _phoneController.dispose();

    _hobbiesController.dispose();

    _quoteController.dispose();

    super.dispose();
  }
}
