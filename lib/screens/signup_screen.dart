import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nubify/resources/auth_method.dart';
import 'package:nubify/screens/login_screen.dart';
import 'package:nubify/utils/color.dart';
import 'package:nubify/utils/utils.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  int _currentStep = 0;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _facultyController = TextEditingController();
  final TextEditingController _hobbiesController = TextEditingController();
  final TextEditingController _quoteController = TextEditingController();

  Uint8List? _image;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _fullNameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _facultyController.dispose();
    _hobbiesController.dispose();
    _quoteController.dispose();
    super.dispose();
  }

  Future<void> selectImage() async {
    Uint8List? im = await pickImage(ImageSource.gallery);
    if (im != null) {
      setState(() {
        _image = im;
      });
    }
  }

  void nextStep() {
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
    if (_currentStep == 3 && _passwordController.text.trim().isEmpty) {
      showSnackBar('Please enter your password', context);
      return;
    }
    if (_currentStep == 4 && _facultyController.text.trim().isEmpty) {
      showSnackBar('Please enter your faculty', context);
      return;
    }

    setState(() {
      _currentStep++;
    });
  }

  Future<void> signUpUser() async {
    setState(() => _isLoading = true);

    String res = await AuthMethods().signUpUser(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      username: _usernameController.text.trim(),
      fullName: _fullNameController.text.trim(),
      faculty: _facultyController.text.trim(),
      hobbies: _hobbiesController.text.trim(),
      favoriteQuote: _quoteController.text.trim(),
      file: _image,
    );

    setState(() => _isLoading = false);

    if (res == "success") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const LoginScreen(),
        ),
      );
    } else {
      showSnackBar(res, context);
    }
  }

  Widget getStepContent() {
    switch (_currentStep) {
      case 0:
        return TextField(
          controller: _emailController,
          decoration: const InputDecoration(
            hintText: 'Enter your email',
            border: OutlineInputBorder(),
          ),
        );

      case 1:
        return TextField(
          controller: _fullNameController,
          decoration: const InputDecoration(
            hintText: 'Enter your full name',
            border: OutlineInputBorder(),
          ),
        );

      case 2:
        return TextField(
          controller: _usernameController,
          decoration: const InputDecoration(
            hintText: 'Enter username',
            border: OutlineInputBorder(),
          ),
        );

      case 3:
        return TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            hintText: 'Enter password',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off
                    : Icons.visibility,
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
          ),
        );

      case 4:
        return TextField(
          controller: _facultyController,
          decoration: const InputDecoration(
            hintText: 'Enter faculty',
            border: OutlineInputBorder(),
          ),
        );

      case 5:
        return TextField(
          controller: _hobbiesController,
          decoration: const InputDecoration(
            hintText: 'Enter hobbies (optional)',
            border: OutlineInputBorder(),
          ),
        );

      case 6:
        return TextField(
          controller: _quoteController,
          decoration: const InputDecoration(
            hintText: 'Favourite quote (optional)',
            border: OutlineInputBorder(),
          ),
        );

      case 7:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 60,
              backgroundImage:
                  _image != null ? MemoryImage(_image!) : null,
              child: _image == null
                  ? const Icon(Icons.person, size: 60)
                  : null,
            ),
            IconButton(
              onPressed: selectImage,
              icon: const Icon(Icons.add_a_photo),
            ),
          ],
        );

      default:
        return const SizedBox();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const SizedBox(height: 40),
              SvgPicture.asset(
                'assets/ic_nubify.svg',
                colorFilter: const ColorFilter.mode(
                  primaryColor,
                  BlendMode.srcIn,
                ),
                height: 64,
              ),
              const SizedBox(height: 40),
              Expanded(child: Center(child: getStepContent())),
              if (_currentStep == 7)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Add profile picture (optional)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      _currentStep == 7 ? signUpUser : nextStep,
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : Text(_currentStep == 7
                          ? 'Sign Up'
                          : 'Next'),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Already have an account?'),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const LoginScreen(),
                        ),
                      );
                    },
                    child: const Text('Log in'),
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