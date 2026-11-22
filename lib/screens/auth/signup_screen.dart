import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/auth/auth_method.dart';
import '../../utils/common/egyptian_phone.dart';
import '../../utils/faculties/faculty_catalog.dart';
import '../../utils/common/utils.dart';
import '../../widgets/auth/nubify_auth_style.dart';
import '../../widgets/faculties/faculty_selector.dart';

import 'login_screen.dart';

//===================================================
// SIGNUP SCREEN
//
// Nine short steps on the same blue & black look as the
// login screen. Each step slides in on its own glass
// card, with a segmented progress bar on top.
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
  static const int _stepCount = 9;

  int _currentStep = 0;

  // True when moving back, so the card slides the other way.
  bool _goingBack = false;

  final TextEditingController _emailController = TextEditingController();

  final TextEditingController _fullNameController = TextEditingController();

  final TextEditingController _usernameController = TextEditingController();

  final TextEditingController _passwordController = TextEditingController();

  final TextEditingController _facultyController = TextEditingController();

  String? _selectedFacultyId;

  final TextEditingController _phoneController = TextEditingController();

  final TextEditingController _hobbiesController = TextEditingController();

  final TextEditingController _quoteController = TextEditingController();

  Uint8List? _image;

  bool _isLoading = false;

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
  // STEP SUBTITLES
  //===================================================

  final List<String> _stepSubtitles = const <String>[
    'You will use it to log in.',
    'This is how classmates will see you.',
    'Your unique @name on Nubify.',
    'Use at least 6 characters.',
    'Pick your faculty at NUB.',
    'Only used to keep your account safe.',
    'Optional: tell people what you love.',
    'Optional: something that inspires you.',
    'Optional: let people recognise you.',
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

    if (_currentStep == 4) {
      if (_selectedFacultyId == null) {
        showSnackBar('Please choose your faculty', context);
        return;
      }

      if (_facultyController.text.trim().isEmpty) {
        showSnackBar('Please type your faculty', context);
        return;
      }
    }

    if (_currentStep == 5 && !EgyptianPhone.isValid(_phoneController.text)) {
      showSnackBar(
        'Enter a valid Egyptian number beginning 010, 011, 012, or 015',
        context,
      );

      return;
    }

    if (_currentStep < _stepCount - 1) {
      setState(() {
        _goingBack = false;
        _currentStep++;
      });
    }
  }

  void _selectFaculty(NubifyFaculty faculty) {
    final bool wasOther = _selectedFacultyId == NubifyFacultyCatalog.other.id;

    setState(() {
      _selectedFacultyId = faculty.id;
      if (faculty.isOther) {
        if (!wasOther) {
          _facultyController.clear();
        }
      } else {
        _facultyController.text = faculty.name;
      }
    });
  }

  //===================================================
  // PREVIOUS
  //===================================================

  void _previousStep() {
    if (_currentStep <= 0) {
      return;
    }

    setState(() {
      _goingBack = true;
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
  // GO TO LOGIN
  //
  // Back to the login screen we came from, or a fresh
  // one if signup was opened directly.
  //===================================================

  void _openLogin() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
    );
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
    Iterable<String>? autofillHints,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return NubifyAuthField(
      controller: controller,
      label: optional ? '$hintText (optional)' : hintText,
      icon: icon,
      keyboardType: multiline ? TextInputType.multiline : keyboardType,
      maxLines: multiline ? 3 : 1,
      autofillHints: autofillHints,
      textCapitalization: textCapitalization,
      textInputAction: multiline
          ? TextInputAction.newline
          : TextInputAction.next,
      onSubmitted: multiline ? null : (_) => _nextStep(),
    );
  }

  Widget _helper(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: NubifyAuthColors.muted, fontSize: 12),
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
          autofillHints: const <String>[AutofillHints.email],
        );

      case 1:
        return _field(
          controller: _fullNameController,
          hintText: 'Full name',
          icon: Icons.badge_outlined,
          autofillHints: const <String>[AutofillHints.name],
          textCapitalization: TextCapitalization.words,
        );

      case 2:
        return _field(
          controller: _usernameController,
          hintText: 'Username',
          icon: Icons.alternate_email_rounded,
          autofillHints: const <String>[AutofillHints.newUsername],
        );

      case 3:
        return NubifyAuthField(
          controller: _passwordController,
          label: 'Password',
          icon: Icons.lock_outline_rounded,
          isPassword: true,
          autofillHints: const <String>[AutofillHints.newPassword],
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _nextStep(),
        );

      case 4:
        return FacultySelectionField(
          selectedId: _selectedFacultyId,
          otherController: _facultyController,
          onSelected: _selectFaculty,
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
              autofillHints: const <String>[AutofillHints.telephoneNumber],
            ),
            _helper(
              'Use 010, 011, 012, 015 or the equivalent +20 format. Your number stays private.',
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
            Semantics(
              button: true,
              label: _image == null
                  ? 'Choose profile picture'
                  : 'Change profile picture',
              child: GestureDetector(
                onTap: _selectImage,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: NubifyAuthColors.button,
                  ),
                  child: CircleAvatar(
                    radius: 60,
                    backgroundColor: NubifyAuthColors.navy,
                    backgroundImage: _image == null
                        ? null
                        : MemoryImage(_image!),
                    child: _image == null
                        ? const Icon(
                            Icons.person_rounded,
                            size: 60,
                            color: NubifyAuthColors.muted,
                          )
                        : null,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            NubifyAuthGhostButton(
              onPressed: _selectImage,
              icon: Icons.add_a_photo_outlined,
              label: _image == null
                  ? 'Choose profile picture'
                  : 'Change picture',
            ),

            _helper('Optional — you can change it later from Edit Profile.'),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }

  //===================================================
  // SEGMENTED PROGRESS
  //===================================================

  Widget _progress() {
    return Semantics(
      label: 'Step ${_currentStep + 1} of $_stepCount',
      child: Row(
        children: <Widget>[
          for (int i = 0; i < _stepCount; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: 5),
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
                height: 5,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  gradient: i <= _currentStep ? NubifyAuthColors.button : null,
                  color: i <= _currentStep ? null : NubifyAuthColors.glass,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  //===================================================
  // STEP CARD
  //===================================================

  Widget _stepCard() {
    final NubifyFaculty? selectedFaculty = NubifyFacultyCatalog.byId(
      _selectedFacultyId,
    );
    final bool facultyIcon = _currentStep == 4 && selectedFaculty != null;
    final IconData currentIcon = facultyIcon
        ? selectedFaculty.icon
        : _stepIcons[_currentStep];

    return NubifyAuthPanel(
      key: ValueKey<int>(_currentStep),
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: facultyIcon ? null : NubifyAuthColors.button,
                color: facultyIcon ? selectedFaculty.color : null,
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color:
                        (facultyIcon
                                ? selectedFaculty.color
                                : NubifyAuthColors.royal)
                            .withValues(alpha: 0.5),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(currentIcon, color: Colors.white, size: 30),
            ),
          ),

          const SizedBox(height: 14),

          Text(
            _stepTitles[_currentStep],
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: NubifyAuthColors.text,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            _stepSubtitles[_currentStep],
            textAlign: TextAlign.center,
            style: const TextStyle(color: NubifyAuthColors.muted, fontSize: 13),
          ),

          const SizedBox(height: 20),

          _getStepContent(),
        ],
      ),
    );
  }

  //===================================================
  // BUILD
  //===================================================

  @override
  Widget build(BuildContext context) {
    final bool lastStep = _currentStep == _stepCount - 1;
    final bool reduceMotion = MediaQuery.of(context).disableAnimations;

    return NubifyAuthTheme(
      child: Scaffold(
        body: NubifyAuthBackground(
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                  child: Column(
                    children: <Widget>[
                      //===================================================
                      // HEADER
                      //===================================================
                      NubifyAuthEntrance(
                        child: Row(
                          children: <Widget>[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.asset(
                                NubifyAuthLogo.asset,
                                width: 44,
                                height: 58,
                                fit: BoxFit.cover,
                                semanticLabel: 'Nubify',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  const Text(
                                    'Join Nubify',
                                    style: TextStyle(
                                      color: NubifyAuthColors.text,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    'Step ${_currentStep + 1} of $_stepCount',
                                    style: const TextStyle(
                                      color: NubifyAuthColors.muted,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      _progress(),

                      const SizedBox(height: 18),

                      //===================================================
                      // STEP CARD
                      //===================================================
                      Expanded(
                        // A little above centre looks more balanced.
                        child: Align(
                          alignment: const Alignment(0, -0.35),
                          child: SingleChildScrollView(
                            child: AnimatedSwitcher(
                              duration: Duration(
                                milliseconds: reduceMotion ? 0 : 320,
                              ),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              transitionBuilder:
                                  (Widget child, Animation<double> animation) {
                                    final bool incoming =
                                        child.key ==
                                        ValueKey<int>(_currentStep);
                                    final double from =
                                        (incoming ? 0.25 : -0.25) *
                                        (_goingBack ? -1 : 1);

                                    return FadeTransition(
                                      opacity: animation,
                                      child: SlideTransition(
                                        position: Tween<Offset>(
                                          begin: Offset(from, 0),
                                          end: Offset.zero,
                                        ).animate(animation),
                                        child: child,
                                      ),
                                    );
                                  },
                              child: _stepCard(),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      //===================================================
                      // BUTTONS
                      //===================================================
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: NubifyAuthGhostButton(
                              onPressed: _currentStep == 0
                                  ? null
                                  : _previousStep,
                              icon: Icons.arrow_back_rounded,
                              label: 'Back',
                            ),
                          ),

                          const SizedBox(width: 12),

                          Expanded(
                            flex: 2,
                            child: NubifyAuthButton(
                              label: lastStep ? 'Create account' : 'Next',
                              icon: lastStep
                                  ? Icons.person_add_alt_1_rounded
                                  : Icons.arrow_forward_rounded,
                              loading: _isLoading,
                              onPressed: lastStep ? _signUpUser : _nextStep,
                            ),
                          ),
                        ],
                      ),

                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          const Text(
                            'Already have an account?',
                            style: TextStyle(color: NubifyAuthColors.muted),
                          ),
                          TextButton(
                            onPressed: _openLogin,
                            child: const Text('Log in'),
                          ),
                        ],
                      ),
                    ],
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
