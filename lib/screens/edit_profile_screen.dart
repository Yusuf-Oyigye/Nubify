import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/profile_service.dart';
import '../services/private_profile_service.dart';
import '../utils/egyptian_phone.dart';
import '../utils/utils.dart';

//===================================================
// EDIT PROFILE SCREEN
//===================================================

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

//===================================================
// EDIT PROFILE STATE
//===================================================

class _EditProfileScreenState extends State<EditProfileScreen> {
  //===================================================
  // FIREBASE
  //===================================================

  final FirebaseAuth _auth = FirebaseAuth.instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  //===================================================
  // PROFILE SERVICE
  //===================================================

  final ProfileService _profileService = ProfileService();

  final PrivateProfileService _privateProfileService = PrivateProfileService();

  //===================================================
  // CONTROLLERS
  //===================================================

  final TextEditingController _fullNameController = TextEditingController();

  final TextEditingController _usernameController = TextEditingController();

  final TextEditingController _facultyController = TextEditingController();

  final TextEditingController _hobbiesController = TextEditingController();

  final TextEditingController _quoteController = TextEditingController();

  final TextEditingController _phoneController = TextEditingController();

  //===================================================
  // PROFILE PHOTO
  //===================================================

  Uint8List? _newImage;

  String _currentPhotoUrl = '';

  bool _removePhoto = false;

  //===================================================
  // STATE
  //===================================================

  bool _loading = true;

  bool _saving = false;

  bool _allowMarketplaceCalls = false;

  //===================================================
  // COLOR
  //===================================================

  static const Color _blue = Color(0xFF29B6F6);

  //===================================================
  // INIT
  //===================================================

  @override
  void initState() {
    super.initState();

    _loadProfile();
  }

  //===================================================
  // LOAD PROFILE
  //===================================================

  Future<void> _loadProfile() async {
    final String? uid = _auth.currentUser?.uid;

    if (uid == null) {
      if (mounted) {
        Navigator.pop(context);
      }

      return;
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .get();

      final Map<String, dynamic> data = snapshot.data() ?? <String, dynamic>{};

      _fullNameController.text = (data['fullName'] ?? '').toString();

      _usernameController.text = (data['username'] ?? '').toString();

      _facultyController.text = (data['faculty'] ?? '').toString();

      _hobbiesController.text = (data['hobbies'] ?? '').toString();

      _quoteController.text = (data['favoriteQuote'] ?? '').toString();

      _currentPhotoUrl = (data['photoUrl'] ?? '').toString();

      final privateProfile = await _privateProfileService.getMine();
      _phoneController.text = privateProfile.phoneE164;
      _allowMarketplaceCalls = privateProfile.allowMarketplaceCalls;
    } catch (error) {
      if (mounted) {
        _showMessage('Unable to load your profile.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  //===================================================
  // PICK PROFILE PHOTO
  //===================================================

  Future<void> _pickProfilePhoto() async {
    final Uint8List? image = await pickImage(ImageSource.gallery);

    if (image == null || !mounted) {
      return;
    }

    setState(() {
      _newImage = image;

      _removePhoto = false;
    });
  }

  //===================================================
  // PROFILE PHOTO OPTIONS
  //===================================================

  Future<void> _showProfilePhotoOptions() async {
    final bool hasPhoto =
        _newImage != null || _currentPhotoUrl.trim().isNotEmpty;

    await showModalBottomSheet<void>(
      context: context,

      showDragHandle: true,

      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,

            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: _blue),

                title: const Text('Change profile picture'),

                onTap: () async {
                  Navigator.pop(sheetContext);

                  await _pickProfilePhoto();
                },
              ),

              ListTile(
                enabled: hasPhoto,

                leading: Icon(
                  Icons.delete_outline_rounded,

                  color: hasPhoto ? Colors.redAccent : null,
                ),

                title: const Text('Remove profile picture'),

                subtitle: const Text('Tap Save to apply this change'),

                onTap: !hasPhoto
                    ? null
                    : () {
                        Navigator.pop(sheetContext);

                        setState(() {
                          _newImage = null;

                          _currentPhotoUrl = '';

                          _removePhoto = true;
                        });
                      },
              ),

              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  //===================================================
  // SAVE PROFILE
  //===================================================

  Future<void> _saveProfile() async {
    if (_saving) {
      return;
    }

    final String fullName = _fullNameController.text.trim();

    final String username = _usernameController.text.trim();

    final String faculty = _facultyController.text.trim();

    final String hobbies = _hobbiesController.text.trim();

    final String favoriteQuote = _quoteController.text.trim();

    final String phone = _phoneController.text.trim();

    //===================================================
    // VALIDATION
    //===================================================

    if (fullName.isEmpty) {
      _showMessage('Please enter your full name.');

      return;
    }

    if (username.isEmpty) {
      _showMessage('Please enter your username.');

      return;
    }

    if (faculty.isEmpty) {
      _showMessage('Please enter your faculty.');

      return;
    }

    if (phone.isNotEmpty && !EgyptianPhone.isValid(phone)) {
      _showMessage(
        'Enter a valid Egyptian number beginning 010, 011, 012, or 015.',
      );
      return;
    }

    //===================================================
    // START SAVING
    //===================================================

    setState(() {
      _saving = true;
    });

    try {
      await _profileService.updateProfile(
        fullName: fullName,

        username: username,

        faculty: faculty,

        hobbies: hobbies,

        favoriteQuote: favoriteQuote,

        newPhoto: _newImage,

        removePhoto: _removePhoto,
      );

      if (phone.isEmpty) {
        await _privateProfileService.clearPhone();
      } else {
        await _privateProfileService.savePhone(
          phone: phone,
          allowMarketplaceCalls: _allowMarketplaceCalls,
        );
      }

      if (!mounted) {
        return;
      }

      _showMessage('Profile updated.');

      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  //===================================================
  // CHANGE PASSWORD
  //===================================================

  Future<void> _showChangePasswordDialog() async {
    final TextEditingController currentController = TextEditingController();

    final TextEditingController newController = TextEditingController();

    final TextEditingController confirmController = TextEditingController();

    bool obscureCurrent = true;

    bool obscureNew = true;

    bool obscureConfirm = true;

    bool changing = false;

    bool dialogClosed = false;

    //===================================================
    // OPEN DIALOG
    //===================================================

    await showDialog<void>(
      context: context,

      barrierDismissible: false,

      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder:
              (BuildContext dialogBuilderContext, StateSetter setDialogState) {
                //===================================================
                // SUBMIT PASSWORD CHANGE
                //===================================================

                Future<void> submit() async {
                  if (changing) {
                    return;
                  }

                  final String currentPassword = currentController.text;

                  final String newPassword = newController.text;

                  final String confirmPassword = confirmController.text;

                  //===================================================
                  // VALIDATION
                  //===================================================

                  if (currentPassword.isEmpty ||
                      newPassword.isEmpty ||
                      confirmPassword.isEmpty) {
                    _showMessage('Fill all password fields.');

                    return;
                  }

                  if (newPassword != confirmPassword) {
                    _showMessage('New passwords do not match.');

                    return;
                  }

                  if (newPassword.length < 6) {
                    _showMessage('Password must be at least 6 characters.');

                    return;
                  }

                  //===================================================
                  // START CHANGING
                  //===================================================

                  setDialogState(() {
                    changing = true;
                  });

                  try {
                    await _profileService.changePassword(
                      currentPassword: currentPassword,

                      newPassword: newPassword,
                    );

                    if (!mounted) {
                      return;
                    }

                    //===================================================
                    // CLOSE DIALOG
                    //===================================================

                    dialogClosed = true;

                    Navigator.of(dialogContext).pop();

                    _showMessage('Password changed successfully.');
                  } on FirebaseAuthException catch (error) {
                    if (!mounted) {
                      return;
                    }

                    String message =
                        error.message ?? 'Unable to change password.';

                    if (error.code == 'wrong-password' ||
                        error.code == 'invalid-credential') {
                      message = 'Your current password is incorrect.';
                    }

                    _showMessage(message);
                  } catch (error) {
                    if (!mounted) {
                      return;
                    }

                    _showMessage(
                      error.toString().replaceFirst('Exception: ', ''),
                    );
                  } finally {
                    //===================================================
                    // IMPORTANT
                    //
                    // Do not call setDialogState after Navigator.pop().
                    // This prevents setState-after-dispose errors.
                    //===================================================

                    if (!dialogClosed) {
                      setDialogState(() {
                        changing = false;
                      });
                    }
                  }
                }

                //===================================================
                // PASSWORD DIALOG
                //===================================================

                return PopScope(
                  canPop: !changing,

                  child: AlertDialog(
                    title: const Row(
                      children: <Widget>[
                        Icon(Icons.lock_reset_rounded, color: _blue),

                        SizedBox(width: 10),

                        Text('Change Password'),
                      ],
                    ),

                    //===================================================
                    // PASSWORD FIELDS
                    //===================================================
                    content: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,

                        children: <Widget>[
                          //===================================================
                          // CURRENT PASSWORD
                          //===================================================

                          TextField(
                            controller: currentController,

                            obscureText: obscureCurrent,

                            enabled: !changing,

                            textInputAction: TextInputAction.next,

                            decoration: InputDecoration(
                              labelText: 'Current password',

                              prefixIcon: const Icon(
                                Icons.lock_outline_rounded,
                              ),

                              border: const OutlineInputBorder(),

                              suffixIcon: IconButton(
                                onPressed: changing
                                    ? null
                                    : () {
                                        setDialogState(() {
                                          obscureCurrent = !obscureCurrent;
                                        });
                                      },

                                icon: Icon(
                                  obscureCurrent
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          //===================================================
                          // NEW PASSWORD
                          //===================================================
                          TextField(
                            controller: newController,

                            obscureText: obscureNew,

                            enabled: !changing,

                            textInputAction: TextInputAction.next,

                            decoration: InputDecoration(
                              labelText: 'New password',

                              prefixIcon: const Icon(Icons.password_rounded),

                              border: const OutlineInputBorder(),

                              suffixIcon: IconButton(
                                onPressed: changing
                                    ? null
                                    : () {
                                        setDialogState(() {
                                          obscureNew = !obscureNew;
                                        });
                                      },

                                icon: Icon(
                                  obscureNew
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          //===================================================
                          // CONFIRM PASSWORD
                          //===================================================
                          TextField(
                            controller: confirmController,

                            obscureText: obscureConfirm,

                            enabled: !changing,

                            textInputAction: TextInputAction.done,

                            onSubmitted: changing
                                ? null
                                : (_) {
                                    submit();
                                  },

                            decoration: InputDecoration(
                              labelText: 'Confirm new password',

                              prefixIcon: const Icon(
                                Icons.verified_user_outlined,
                              ),

                              border: const OutlineInputBorder(),

                              suffixIcon: IconButton(
                                onPressed: changing
                                    ? null
                                    : () {
                                        setDialogState(() {
                                          obscureConfirm = !obscureConfirm;
                                        });
                                      },

                                icon: Icon(
                                  obscureConfirm
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    //===================================================
                    // ACTIONS
                    //===================================================
                    actions: <Widget>[
                      TextButton(
                        onPressed: changing
                            ? null
                            : () {
                                dialogClosed = true;

                                Navigator.of(dialogContext).pop();
                              },

                        child: const Text('Cancel'),
                      ),

                      FilledButton(
                        onPressed: changing ? null : submit,

                        child: changing
                            ? const SizedBox(
                                width: 18,

                                height: 18,

                                child: CircularProgressIndicator(
                                  strokeWidth: 2,

                                  color: Colors.white,
                                ),
                              )
                            : const Text('Change'),
                      ),
                    ],
                  ),
                );
              },
        );
      },
    );

    //===================================================
    // DISPOSE DIALOG CONTROLLERS
    //===================================================

    currentController.dispose();

    newController.dispose();

    confirmController.dispose();
  }

  //===================================================
  // PROFILE PHOTO
  //===================================================

  Widget _buildPhoto() {
    ImageProvider<Object>? imageProvider;

    if (_newImage != null) {
      imageProvider = MemoryImage(_newImage!);
    } else if (_currentPhotoUrl.trim().isNotEmpty) {
      imageProvider = NetworkImage(_currentPhotoUrl.trim());
    }

    return Center(
      child: Stack(
        clipBehavior: Clip.none,

        children: <Widget>[
          //===================================================
          // PROFILE IMAGE
          //===================================================

          CircleAvatar(
            radius: 58,

            backgroundColor: _blue.withValues(alpha: 0.20),

            backgroundImage: imageProvider,

            child: imageProvider == null
                ? const Icon(
                    Icons.person_rounded,

                    size: 58,

                    color: Colors.white70,
                  )
                : null,
          ),

          //===================================================
          // CHANGE PHOTO BUTTON
          //===================================================
          Positioned(
            right: -3,

            bottom: 2,

            child: Material(
              color: _blue,

              shape: const CircleBorder(),

              child: InkWell(
                customBorder: const CircleBorder(),

                onTap: _saving ? null : _showProfilePhotoOptions,

                child: const Padding(
                  padding: EdgeInsets.all(9),

                  child: Icon(
                    Icons.add_a_photo_outlined,

                    color: Colors.white,

                    size: 21,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  //===================================================
  // PROFILE FIELD
  //
  // IMPORTANT:
  //
  // Multiline fields use TextInputType.multiline.
  // No TextInputAction.newline is forced here.
  // This fixes the Favourite Quote/Hobbies crash.
  //===================================================

  Widget _field({
    required TextEditingController controller,

    required String label,

    required IconData icon,

    int maxLines = 1,

    TextInputType keyboardType = TextInputType.text,
  }) {
    final bool isMultiline = maxLines > 1;

    return TextField(
      controller: controller,

      maxLines: maxLines,

      keyboardType: isMultiline ? TextInputType.multiline : keyboardType,

      decoration: InputDecoration(
        labelText: label,

        alignLabelWithHint: isMultiline,

        prefixIcon: Icon(icon),

        border: const OutlineInputBorder(),

        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: _blue, width: 1.5),
        ),
      ),
    );
  }

  //===================================================
  // BUILD
  //===================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //===================================================
      // APP BAR
      //===================================================

      appBar: AppBar(
        title: const Text(
          'Edit Profile',

          style: TextStyle(fontWeight: FontWeight.bold),
        ),

        actions: <Widget>[
          TextButton(
            onPressed: _saving ? null : _saveProfile,

            child: const Text(
              'Save',

              style: TextStyle(color: _blue, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),

      //===================================================
      // BODY
      //===================================================
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _blue))
          : AbsorbPointer(
              absorbing: _saving,

              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,

                padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),

                children: <Widget>[
                  //===================================================
                  // PHOTO
                  //===================================================

                  _buildPhoto(),

                  const SizedBox(height: 28),

                  //===================================================
                  // FULL NAME
                  //===================================================
                  _field(
                    controller: _fullNameController,

                    label: 'Full name',

                    icon: Icons.badge_outlined,
                  ),

                  const SizedBox(height: 14),

                  //===================================================
                  // USERNAME
                  //===================================================
                  _field(
                    controller: _usernameController,

                    label: 'Username',

                    icon: Icons.alternate_email_rounded,
                  ),

                  const SizedBox(height: 14),

                  //===================================================
                  // FACULTY
                  //===================================================
                  _field(
                    controller: _facultyController,

                    label: 'Faculty',

                    icon: Icons.school_outlined,
                  ),

                  const SizedBox(height: 14),

                  //===================================================
                  // PRIVATE MOBILE NUMBER + CALL PERMISSION
                  //===================================================
                  _field(
                    controller: _phoneController,
                    label: 'Egyptian mobile number',
                    icon: Icons.phone_android_rounded,
                    keyboardType: TextInputType.phone,
                  ),

                  const SizedBox(height: 8),

                  Card(
                    margin: EdgeInsets.zero,
                    child: SwitchListTile.adaptive(
                      value: _allowMarketplaceCalls,
                      onChanged: (bool value) {
                        setState(() {
                          _allowMarketplaceCalls = value;
                        });
                      },
                      secondary: const Icon(Icons.call_outlined),
                      title: const Text('Allow Marketplace calls'),
                      subtitle: const Text(
                        'Your number remains private. Nubify only returns it when an eligible buyer taps Call Seller.',
                      ),
                      activeThumbColor: _blue,
                    ),
                  ),

                  const SizedBox(height: 14),

                  //===================================================
                  // HOBBIES
                  //===================================================
                  _field(
                    controller: _hobbiesController,

                    label: 'Hobbies',

                    icon: Icons.interests_outlined,

                    maxLines: 2,
                  ),

                  const SizedBox(height: 14),

                  //===================================================
                  // FAVOURITE QUOTE
                  //===================================================
                  _field(
                    controller: _quoteController,

                    label: 'Favourite quote',

                    icon: Icons.format_quote_rounded,

                    maxLines: 3,
                  ),

                  const SizedBox(height: 20),

                  //===================================================
                  // CHANGE PASSWORD
                  //
                  // CONTAINS:
                  // CURRENT PASSWORD
                  // NEW PASSWORD
                  // CONFIRM NEW PASSWORD
                  //===================================================
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _showChangePasswordDialog,

                    icon: const Icon(Icons.lock_reset_rounded),

                    label: const Text('Change Password'),

                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                  ),

                  const SizedBox(height: 18),

                  //===================================================
                  // SAVE BUTTON
                  //===================================================
                  FilledButton.icon(
                    onPressed: _saving ? null : _saveProfile,

                    icon: _saving
                        ? const SizedBox(
                            width: 18,

                            height: 18,

                            child: CircularProgressIndicator(
                              strokeWidth: 2,

                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_outlined),

                    label: Text(_saving ? 'Saving...' : 'Save Changes'),

                    style: FilledButton.styleFrom(
                      backgroundColor: _blue,

                      minimumSize: const Size.fromHeight(52),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  //===================================================
  // MESSAGE
  //===================================================

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  //===================================================
  // DISPOSE
  //===================================================

  @override
  void dispose() {
    _fullNameController.dispose();

    _usernameController.dispose();

    _facultyController.dispose();

    _hobbiesController.dispose();

    _quoteController.dispose();

    _phoneController.dispose();

    super.dispose();
  }
}
