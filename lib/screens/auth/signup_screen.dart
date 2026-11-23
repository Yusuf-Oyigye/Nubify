import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/auth/auth_method.dart';
import '../../services/common/language_preference.dart';
import '../../services/profile/username_service.dart';
import '../../utils/common/egyptian_phone.dart';
import '../../utils/common/email_check.dart';
import '../../utils/faculties/faculty_catalog.dart';
import '../../utils/common/utils.dart';
import '../../utils/profile/username_rules.dart';
import '../../widgets/auth/language_picker.dart';
import '../../widgets/auth/nubify_auth_style.dart';
import '../../widgets/faculties/faculty_selector.dart';
import '../../widgets/profile/nubify_avatar.dart';
import '../../widgets/profile/username_field.dart';

import 'login_screen.dart';

//===================================================
// SIGNUP SCREEN
//
// Five short steps on the blue & black look:
// 1. Contact: email + optional Egyptian mobile
// 2. About you: full name, username, male or female
// 3. Campus life: faculty, hobbies, favourite quote
// 4. Password
// 5. Profile picture (photo, or a faculty avatar)
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
  static const int _stepCount = 5;

  static const int _contactStep = 0;
  static const int _aboutStep = 1;
  static const int _campusStep = 2;
  static const int _passwordStep = 3;
  static const int _pictureStep = 4;

  int _currentStep = 0;

  // True when moving back, so the card slides the other way.
  bool _goingBack = false;

  // True while an async check (email domain, username) runs.
  bool _checking = false;

  final TextEditingController _emailController = TextEditingController();

  final TextEditingController _fullNameController = TextEditingController();

  final TextEditingController _usernameController = TextEditingController();

  final TextEditingController _passwordController = TextEditingController();

  final TextEditingController _facultyController = TextEditingController();

  String? _selectedFacultyId;

  final TextEditingController _phoneController = TextEditingController();

  final TextEditingController _hobbiesController = TextEditingController();

  final TextEditingController _quoteController = TextEditingController();

  // "male" or "female".
  String? _gender;

  // Female students can pick a hijab avatar.
  bool _hijab = false;

  String _language = 'en';

  String get _avatarStyle => _gender == NubifyGender.female
      ? (_hijab ? NubifyAvatarStyle.hijab : NubifyAvatarStyle.female)
      : NubifyAvatarStyle.male;

  String? _emailError;

  UsernameCheck _usernameStatus = UsernameCheck.empty;

  Uint8List? _image;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    LanguagePreference.load().then((String code) {
      if (mounted) setState(() => _language = code);
    });
  }

  void _setLanguage(String code) {
    setState(() => _language = code);
    LanguagePreference.save(code);
  }

  //===================================================
  // STEP TEXT
  //===================================================

  final List<String> _stepTitles = const <String>[
    'How can we reach you?',
    'Tell us about you',
    'Your campus life',
    'Secure your account',
    'Your profile picture',
  ];

  final List<String> _stepSubtitles = const <String>[
    'Use an email you can open. Your number is optional.',
    'Your name, your unique @username and who you are.',
    'Pick your faculty and share a little about you.',
    'Use at least 6 characters.',
    'Add a photo, or keep your Nubify avatar.',
  ];

  final List<IconData> _stepIcons = const <IconData>[
    Icons.mail_outline_rounded,
    Icons.badge_outlined,
    Icons.school_outlined,
    Icons.lock_outline_rounded,
    Icons.add_a_photo_outlined,
  ];

  String get _facultyForAvatar =>
      _selectedFacultyId ?? _facultyController.text.trim();

  //===================================================
  // PICK IMAGE
  //===================================================

  Future<void> _selectImage(ImageSource source) async {
    final Uint8List? image = await pickImage(source);

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

  Future<void> _nextStep() async {
    if (_checking) return;

    switch (_currentStep) {
      case _contactStep:
        if (!await _contactIsValid()) return;
      case _aboutStep:
        if (!await _aboutIsValid()) return;
      case _campusStep:
        if (_selectedFacultyId == null) {
          showSnackBar('Please choose your faculty', context);
          return;
        }
        if (_facultyController.text.trim().isEmpty) {
          showSnackBar('Please type your faculty', context);
          return;
        }
      case _passwordStep:
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

    if (!mounted) return;

    if (_currentStep < _stepCount - 1) {
      FocusScope.of(context).unfocus();
      setState(() {
        _goingBack = false;
        _currentStep++;
      });
    }
  }

  Future<bool> _contactIsValid() async {
    final String email = _emailController.text.trim();
    final String? formatError = EmailCheck.validateFormat(email);

    if (formatError != null) {
      setState(() => _emailError = formatError);
      return false;
    }

    final String phone = _phoneController.text.trim();
    if (phone.isNotEmpty && !EgyptianPhone.isValid(phone)) {
      showSnackBar(
        'Enter a valid Egyptian number beginning 010, 011, 012, or 015, or leave it empty',
        context,
      );
      return false;
    }

    setState(() {
      _emailError = null;
      _checking = true;
    });

    final String? domainError = await EmailCheck.validateDomain(email);

    if (!mounted) return false;

    setState(() {
      _checking = false;
      _emailError = domainError;
    });

    return domainError == null;
  }

  Future<bool> _aboutIsValid() async {
    if (_fullNameController.text.trim().isEmpty) {
      showSnackBar('Please enter your full name', context);
      return false;
    }

    final String username = _usernameController.text;
    final String? usernameError = UsernameRules.validate(username);

    if (usernameError != null) {
      showSnackBar(usernameError, context);
      return false;
    }

    if (_gender == null) {
      showSnackBar('Please choose male or female', context);
      return false;
    }

    // Make sure the result is for the latest text.
    setState(() => _checking = true);
    final UsernameCheck result = await UsernameService().check(username);
    if (!mounted) return false;
    setState(() {
      _checking = false;
      _usernameStatus = result;
    });

    if (result.isTaken) {
      showSnackBar(UsernameRules.taken, context);
      return false;
    }

    return true;
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

  void _goToStep(int step) {
    setState(() {
      _goingBack = step < _currentStep;
      _currentStep = step;
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

      username: _usernameController.text,

      fullName: _fullNameController.text.trim(),

      faculty: _facultyController.text.trim(),

      phone: _phoneController.text.trim(),

      hobbies: _hobbiesController.text.trim(),

      favoriteQuote: _quoteController.text.trim(),

      gender: _gender ?? '',

      avatarStyle: _avatarStyle,

      languagePreference: _language,

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
      return;
    }

    showSnackBar(res, context);

    // Send people back to the step that needs fixing.
    final String lower = res.toLowerCase();
    if (lower.contains('username')) {
      _goToStep(_aboutStep);
    } else if (lower.contains('email') || lower.contains('egyptian')) {
      _goToStep(_contactStep);
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
  // SMALL PIECES
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
    TextInputAction? action,
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
          : action ?? TextInputAction.next,
    );
  }

  Widget _helper(String text, {Color color = NubifyAuthColors.muted}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Text(
        text,
        style: const TextStyle(
          color: NubifyAuthColors.text,
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  //===================================================
  // GENDER CHOICE
  //===================================================

  Widget _avatarChoice({required bool hijab, required String label}) {
    final bool selected = _hijab == hijab;

    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: 'Avatar $label',
        child: GestureDetector(
          onTap: () => setState(() => _hijab = hijab),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: selected
                  ? NubifyAuthColors.royal.withValues(alpha: 0.35)
                  : NubifyAuthColors.glass,
              border: Border.all(
                color: selected
                    ? NubifyAuthColors.sky
                    : NubifyAuthColors.glassEdge,
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Row(
              children: <Widget>[
                ClipOval(
                  child: NubifyAvatar(
                    style: hijab
                        ? NubifyAvatarStyle.hijab
                        : NubifyAvatarStyle.female,
                    faculty: _facultyForAvatar,
                    size: 34,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: NubifyAuthColors.text,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
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

  Widget _genderOption(String value, String label) {
    final bool selected = _gender == value;

    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: GestureDetector(
          onTap: () => setState(() => _gender = value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: selected ? NubifyAuthColors.button : null,
              color: selected ? null : NubifyAuthColors.glass,
              border: Border.all(
                color: selected
                    ? Colors.white.withValues(alpha: 0.2)
                    : NubifyAuthColors.glassEdge,
              ),
              boxShadow: selected
                  ? <BoxShadow>[
                      BoxShadow(
                        color: NubifyAuthColors.royal.withValues(alpha: 0.45),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              children: <Widget>[
                ClipOval(
                  child: NubifyAvatar(
                    style: value == NubifyGender.female
                        ? (_hijab
                              ? NubifyAvatarStyle.hijab
                              : NubifyAvatarStyle.female)
                        : NubifyAvatarStyle.male,
                    faculty: _facultyForAvatar,
                    size: 52,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : NubifyAuthColors.text,
                    fontWeight: FontWeight.w800,
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
  // PROFILE PICTURE STEP
  //===================================================

  Widget _pictureContent() {
    final bool hasPhoto = _image != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: NubifyAuthColors.button,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: NubifyAuthColors.royal.withValues(alpha: 0.5),
                      blurRadius: 28,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    child: hasPhoto
                        ? Image.memory(
                            _image!,
                            key: const ValueKey<String>('photo'),
                            width: 136,
                            height: 136,
                            fit: BoxFit.cover,
                          )
                        : NubifyAvatar(
                            key: const ValueKey<String>('avatar'),
                            style: _avatarStyle,
                            faculty: _facultyForAvatar,
                            size: 136,
                          ),
                  ),
                ),
              ),
              Positioned(
                right: 2,
                bottom: 2,
                child: Semantics(
                  button: true,
                  label: 'Choose a photo from your gallery',
                  child: GestureDetector(
                    onTap: () => _selectImage(ImageSource.gallery),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(
                          color: NubifyAuthColors.black,
                          width: 3,
                        ),
                      ),
                      child: const Icon(
                        Icons.edit_rounded,
                        color: NubifyAuthColors.royal,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        Text(
          hasPhoto ? 'Looking good!' : 'Your Nubify avatar',
          style: const TextStyle(
            color: NubifyAuthColors.text,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),

        _helper(
          hasPhoto
              ? 'This photo will be your profile picture.'
              : 'Coloured for your faculty. Add a photo, or keep this one.',
        ),

        const SizedBox(height: 18),

        Row(
          children: <Widget>[
            Expanded(
              child: NubifyAuthGhostButton(
                onPressed: () => _selectImage(ImageSource.gallery),
                icon: Icons.photo_library_outlined,
                label: 'Gallery',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: NubifyAuthGhostButton(
                onPressed: () => _selectImage(ImageSource.camera),
                icon: Icons.photo_camera_outlined,
                label: 'Camera',
              ),
            ),
          ],
        ),

        if (hasPhoto)
          TextButton.icon(
            onPressed: () => setState(() => _image = null),
            icon: const Icon(Icons.face_rounded, size: 18),
            label: const Text('Use my avatar instead'),
          ),
      ],
    );
  }

  //===================================================
  // STEP CONTENT
  //===================================================

  Widget _getStepContent() {
    switch (_currentStep) {
      case _contactStep:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            NubifyLanguagePicker(code: _language, onChanged: _setLanguage),

            const SizedBox(height: 14),

            NubifyAuthField(
              controller: _emailController,
              label: 'Email',
              hint: 'you@example.com',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const <String>[AutofillHints.email],
              textInputAction: TextInputAction.next,
            ),
            if (_emailError != null)
              _helper(_emailError!, color: const Color(0xFFFF5C6C)),

            const SizedBox(height: 14),

            _field(
              controller: _phoneController,
              hintText: 'Mobile number',
              icon: Icons.phone_android_rounded,
              keyboardType: TextInputType.phone,
              optional: true,
              autofillHints: const <String>[AutofillHints.telephoneNumber],
              action: TextInputAction.done,
            ),
            _helper(
              "Starts with 010, 011, 012, 015 or +20, and stays private. If you don't have an Egyptian number, you can skip this.",
            ),
          ],
        );

      case _aboutStep:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _field(
              controller: _fullNameController,
              hintText: 'Full name',
              icon: Icons.badge_outlined,
              autofillHints: const <String>[AutofillHints.name],
              textCapitalization: TextCapitalization.words,
            ),
            _helper('Emojis are welcome in your name ✨'),

            const SizedBox(height: 14),

            UsernameField(
              controller: _usernameController,
              textInputAction: TextInputAction.done,
              onChanged: (UsernameCheck status) {
                if (status.isTaken != _usernameStatus.isTaken) {
                  setState(() => _usernameStatus = status);
                } else {
                  _usernameStatus = status;
                }
              },
            ),

            const SizedBox(height: 18),

            _label('I am'),
            Row(
              children: <Widget>[
                _genderOption(NubifyGender.male, 'Male'),
                const SizedBox(width: 12),
                _genderOption(NubifyGender.female, 'Female'),
              ],
            ),

            if (_gender == NubifyGender.female) ...<Widget>[
              const SizedBox(height: 16),
              _label('My avatar'),
              Row(
                children: <Widget>[
                  _avatarChoice(hijab: false, label: 'With hair'),
                  const SizedBox(width: 12),
                  _avatarChoice(hijab: true, label: 'With hijab'),
                ],
              ),
            ],
          ],
        );

      case _campusStep:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            FacultySelectionField(
              selectedId: _selectedFacultyId,
              otherController: _facultyController,
              onSelected: _selectFaculty,
            ),

            const SizedBox(height: 14),

            _field(
              controller: _hobbiesController,
              hintText: 'Hobbies',
              icon: Icons.interests_outlined,
              optional: true,
              multiline: true,
            ),

            const SizedBox(height: 14),

            _field(
              controller: _quoteController,
              hintText: 'Favourite quote',
              icon: Icons.format_quote_rounded,
              optional: true,
              multiline: true,
            ),
          ],
        );

      case _passwordStep:
        return NubifyAuthField(
          controller: _passwordController,
          label: 'Password',
          icon: Icons.lock_outline_rounded,
          isPassword: true,
          autofillHints: const <String>[AutofillHints.newPassword],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _nextStep(),
        );

      case _pictureStep:
        return _pictureContent();

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
            if (i > 0) const SizedBox(width: 6),
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
    final bool facultyIcon =
        _currentStep == _campusStep && selectedFaculty != null;
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
              width: 60,
              height: 60,
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
              child: Icon(currentIcon, color: Colors.white, size: 28),
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
                              loading: _isLoading || _checking,
                              onPressed:
                                  _currentStep == _aboutStep &&
                                      _usernameStatus.isTaken
                                  ? null
                                  : lastStep
                                  ? _signUpUser
                                  : _nextStep,
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
