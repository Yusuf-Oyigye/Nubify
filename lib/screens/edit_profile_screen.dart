import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/profile_service.dart';
import '../utils/utils.dart';

//===================================================
// EDIT PROFILE SCREEN
//===================================================

class EditProfileScreen
    extends StatefulWidget {
  const EditProfileScreen({
    super.key,
  });

  @override
  State<EditProfileScreen>
  createState() =>
      _EditProfileScreenState();
}

//===================================================
// EDIT PROFILE STATE
//===================================================

class _EditProfileScreenState
    extends State<
        EditProfileScreen> {
  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  final FirebaseFirestore
  _firestore =
      FirebaseFirestore.instance;

  final ProfileService
  _profileService =
  ProfileService();

  final TextEditingController
  _fullNameController =
  TextEditingController();

  final TextEditingController
  _usernameController =
  TextEditingController();

  final TextEditingController
  _facultyController =
  TextEditingController();

  final TextEditingController
  _hobbiesController =
  TextEditingController();

  final TextEditingController
  _quoteController =
  TextEditingController();

  Uint8List? _newImage;

  String _currentPhotoUrl =
      '';

  bool _loading =
  true;

  bool _saving =
  false;

  static const Color _blue =
  Color(
    0xFF29B6F6,
  );

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

  Future<void>
  _loadProfile() async {
    final String? uid =
        _auth.currentUser?.uid;

    if (uid == null) {
      if (mounted) {
        Navigator.pop(
          context,
        );
      }

      return;
    }

    try {
      final DocumentSnapshot<
          Map<String, dynamic>>
      snapshot =
      await _firestore
          .collection('users')
          .doc(uid)
          .get();

      final Map<String, dynamic>
      data =
          snapshot.data() ??
              <String, dynamic>{};

      _fullNameController.text =
          (data['fullName'] ?? '')
              .toString();

      _usernameController.text =
          (data['username'] ?? '')
              .toString();

      _facultyController.text =
          (data['faculty'] ?? '')
              .toString();

      _hobbiesController.text =
          (data['hobbies'] ?? '')
              .toString();

      _quoteController.text =
          (data['favoriteQuote'] ??
              '')
              .toString();

      _currentPhotoUrl =
          (data['photoUrl'] ?? '')
              .toString();
    } catch (error) {
      if (mounted) {
        _showMessage(
          'Unable to load your profile.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading =
          false;
        });
      }
    }
  }

  //===================================================
  // PICK PHOTO
  //===================================================

  Future<void>
  _pickProfilePhoto() async {
    final Uint8List? image =
    await pickImage(
      ImageSource.gallery,
    );

    if (image == null ||
        !mounted) {
      return;
    }

    setState(() {
      _newImage =
          image;
    });
  }

  //===================================================
  // SAVE PROFILE
  //===================================================

  Future<void>
  _saveProfile() async {
    if (_saving) {
      return;
    }

    final String fullName =
    _fullNameController.text
        .trim();

    final String username =
    _usernameController.text
        .trim();

    final String faculty =
    _facultyController.text
        .trim();

    if (fullName.isEmpty) {
      _showMessage(
        'Please enter your full name.',
      );

      return;
    }

    if (username.isEmpty) {
      _showMessage(
        'Please enter your username.',
      );

      return;
    }

    if (faculty.isEmpty) {
      _showMessage(
        'Please enter your faculty.',
      );

      return;
    }

    setState(() {
      _saving =
      true;
    });

    try {
      await _profileService
          .updateProfile(
        fullName:
        fullName,

        username:
        username,

        faculty:
        faculty,

        hobbies:
        _hobbiesController.text
            .trim(),

        favoriteQuote:
        _quoteController.text
            .trim(),

        newPhoto:
        _newImage,
      );

      if (!mounted) {
        return;
      }

      _showMessage(
        'Profile updated.',
      );

      Navigator.pop(
        context,
        true,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        error
            .toString()
            .replaceFirst(
          'Exception: ',
          '',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving =
          false;
        });
      }
    }
  }

  //===================================================
  // CHANGE PASSWORD
  //===================================================

  Future<void>
  _showChangePasswordDialog() async {
    final TextEditingController
    currentController =
    TextEditingController();

    final TextEditingController
    newController =
    TextEditingController();

    final TextEditingController
    confirmController =
    TextEditingController();

    bool obscureCurrent =
    true;

    bool obscureNew =
    true;

    bool obscureConfirm =
    true;

    bool changing =
    false;

    await showDialog<void>(
      context:
      context,

      barrierDismissible:
      !changing,

      builder:
          (
          BuildContext dialogContext,
          ) {
        return StatefulBuilder(
          builder:
              (
              BuildContext context,

              void Function(
                  void Function(),
                  )
              setDialogState,
              ) {
            Future<void>
            submit() async {
              final String
              currentPassword =
                  currentController
                      .text;

              final String
              newPassword =
                  newController.text;

              final String
              confirmPassword =
                  confirmController
                      .text;

              if (currentPassword
                  .isEmpty ||
                  newPassword
                      .isEmpty ||
                  confirmPassword
                      .isEmpty) {
                _showMessage(
                  'Fill all password fields.',
                );

                return;
              }

              if (newPassword !=
                  confirmPassword) {
                _showMessage(
                  'New passwords do not match.',
                );

                return;
              }

              if (newPassword.length <
                  6) {
                _showMessage(
                  'Password must be at least 6 characters.',
                );

                return;
              }

              setDialogState(
                    () {
                  changing =
                  true;
                },
              );

              try {
                await _profileService
                    .changePassword(
                  currentPassword:
                  currentPassword,

                  newPassword:
                  newPassword,
                );

                if (!mounted) {
                  return;
                }

                Navigator.pop(
                  dialogContext,
                );

                _showMessage(
                  'Password changed successfully.',
                );
              } on FirebaseAuthException catch (
              error
              ) {
              if (!mounted) {
              return;
              }

              String message =
              error.message ??
              'Unable to change password.';

              if (error.code ==
              'wrong-password' ||
              error.code ==
              'invalid-credential') {
              message =
              'Your current password is incorrect.';
              }

              _showMessage(
              message,
              );
              } catch (error) {
              if (!mounted) {
              return;
              }

              _showMessage(
              error
                  .toString()
                  .replaceFirst(
              'Exception: ',
              '',
              ),
              );
              } finally {
              if (dialogContext
                  .mounted) {
              setDialogState(
              () {
              changing =
              false;
              },
              );
              }
              }
            }

            return AlertDialog(
              title:
              const Row(
                children:
                <Widget>[
                  Icon(
                    Icons
                        .lock_reset_rounded,
                    color:
                    _blue,
                  ),
                  SizedBox(
                    width:
                    10,
                  ),
                  Text(
                    'Change Password',
                  ),
                ],
              ),

              content:
              SingleChildScrollView(
                child:
                Column(
                  mainAxisSize:
                  MainAxisSize.min,
                  children:
                  <Widget>[
                    TextField(
                      controller:
                      currentController,
                      obscureText:
                      obscureCurrent,
                      decoration:
                      InputDecoration(
                        labelText:
                        'Current password',
                        prefixIcon:
                        const Icon(
                          Icons
                              .lock_outline_rounded,
                        ),
                        border:
                        const OutlineInputBorder(),
                        suffixIcon:
                        IconButton(
                          onPressed:
                              () {
                            setDialogState(
                                  () {
                                obscureCurrent =
                                !obscureCurrent;
                              },
                            );
                          },
                          icon:
                          Icon(
                            obscureCurrent
                                ? Icons
                                .visibility_off_outlined
                                : Icons
                                .visibility_outlined,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(
                      height:
                      12,
                    ),

                    TextField(
                      controller:
                      newController,
                      obscureText:
                      obscureNew,
                      decoration:
                      InputDecoration(
                        labelText:
                        'New password',
                        prefixIcon:
                        const Icon(
                          Icons
                              .password_rounded,
                        ),
                        border:
                        const OutlineInputBorder(),
                        suffixIcon:
                        IconButton(
                          onPressed:
                              () {
                            setDialogState(
                                  () {
                                obscureNew =
                                !obscureNew;
                              },
                            );
                          },
                          icon:
                          Icon(
                            obscureNew
                                ? Icons
                                .visibility_off_outlined
                                : Icons
                                .visibility_outlined,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(
                      height:
                      12,
                    ),

                    TextField(
                      controller:
                      confirmController,
                      obscureText:
                      obscureConfirm,
                      decoration:
                      InputDecoration(
                        labelText:
                        'Confirm new password',
                        prefixIcon:
                        const Icon(
                          Icons
                              .verified_user_outlined,
                        ),
                        border:
                        const OutlineInputBorder(),
                        suffixIcon:
                        IconButton(
                          onPressed:
                              () {
                            setDialogState(
                                  () {
                                obscureConfirm =
                                !obscureConfirm;
                              },
                            );
                          },
                          icon:
                          Icon(
                            obscureConfirm
                                ? Icons
                                .visibility_off_outlined
                                : Icons
                                .visibility_outlined,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              actions:
              <Widget>[
                TextButton(
                  onPressed:
                  changing
                      ? null
                      : () {
                    Navigator.pop(
                      dialogContext,
                    );
                  },
                  child:
                  const Text(
                    'Cancel',
                  ),
                ),

                FilledButton(
                  onPressed:
                  changing
                      ? null
                      : submit,
                  child:
                  changing
                      ? const SizedBox(
                    width:
                    18,
                    height:
                    18,
                    child:
                    CircularProgressIndicator(
                      strokeWidth:
                      2,
                    ),
                  )
                      : const Text(
                    'Change',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    currentController.dispose();

    newController.dispose();

    confirmController.dispose();
  }

  //===================================================
  // PHOTO
  //===================================================

  Widget _buildPhoto() {
    ImageProvider? imageProvider;

    if (_newImage != null) {
      imageProvider =
          MemoryImage(
            _newImage!,
          );
    } else if (_currentPhotoUrl
        .trim()
        .isNotEmpty) {
      imageProvider =
          NetworkImage(
            _currentPhotoUrl.trim(),
          );
    }

    return Center(
      child:
      Stack(
        clipBehavior:
        Clip.none,
        children:
        <Widget>[
          CircleAvatar(
            radius:
            58,
            backgroundColor:
            _blue.withOpacity(
              0.20,
            ),
            backgroundImage:
            imageProvider,
            child:
            imageProvider == null
                ? const Icon(
              Icons
                  .person_rounded,
              size:
              58,
              color:
              Colors.white70,
            )
                : null,
          ),

          Positioned(
            right:
            -3,
            bottom:
            2,
            child:
            Material(
              color:
              _blue,
              shape:
              const CircleBorder(),
              child:
              InkWell(
                customBorder:
                const CircleBorder(),
                onTap:
                _pickProfilePhoto,
                child:
                const Padding(
                  padding:
                  EdgeInsets.all(
                    9,
                  ),
                  child:
                  Icon(
                    Icons
                        .add_a_photo_outlined,
                    color:
                    Colors.white,
                    size:
                    21,
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
  // FIELD
  //===================================================

  Widget _field({
    required TextEditingController
    controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType =
        TextInputType.text,
  }) {
    return TextField(
      controller:
      controller,

      maxLines:
      maxLines,

      keyboardType:
      keyboardType,

      decoration:
      InputDecoration(
        labelText:
        label,

        prefixIcon:
        Icon(
          icon,
        ),

        border:
        const OutlineInputBorder(),

        focusedBorder:
        const OutlineInputBorder(
          borderSide:
          BorderSide(
            color:
            _blue,
            width:
            1.5,
          ),
        ),
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
      appBar:
      AppBar(
        title:
        const Text(
          'Edit Profile',
          style:
          TextStyle(
            fontWeight:
            FontWeight.bold,
          ),
        ),

        actions:
        <Widget>[
          TextButton(
            onPressed:
            _saving
                ? null
                : _saveProfile,
            child:
            const Text(
              'Save',
              style:
              TextStyle(
                color:
                _blue,
                fontWeight:
                FontWeight.bold,
              ),
            ),
          ),
        ],
      ),

      body:
      _loading
          ? const Center(
        child:
        CircularProgressIndicator(
          color:
          _blue,
        ),
      )
          : AbsorbPointer(
        absorbing:
        _saving,
        child:
        ListView(
          padding:
          const EdgeInsets
              .fromLTRB(
            18,
            18,
            18,
            30,
          ),
          children:
          <Widget>[
            _buildPhoto(),

            const SizedBox(
              height:
              28,
            ),

            _field(
              controller:
              _fullNameController,
              label:
              'Full name',
              icon:
              Icons
                  .badge_outlined,
            ),

            const SizedBox(
              height:
              14,
            ),

            _field(
              controller:
              _usernameController,
              label:
              'Username',
              icon:
              Icons
                  .alternate_email_rounded,
            ),

            const SizedBox(
              height:
              14,
            ),

            _field(
              controller:
              _facultyController,
              label:
              'Faculty',
              icon:
              Icons
                  .school_outlined,
            ),

            const SizedBox(
              height:
              14,
            ),

            _field(
              controller:
              _hobbiesController,
              label:
              'Hobbies',
              icon:
              Icons
                  .interests_outlined,
              maxLines:
              2,
            ),

            const SizedBox(
              height:
              14,
            ),

            _field(
              controller:
              _quoteController,
              label:
              'Favourite quote',
              icon:
              Icons
                  .format_quote_rounded,
              maxLines:
              3,
            ),

            const SizedBox(
              height:
              20,
            ),

            OutlinedButton.icon(
              onPressed:
              _showChangePasswordDialog,
              icon:
              const Icon(
                Icons
                    .lock_reset_rounded,
              ),
              label:
              const Text(
                'Change Password',
              ),
              style:
              OutlinedButton
                  .styleFrom(
                minimumSize:
                const Size
                    .fromHeight(
                  50,
                ),
              ),
            ),

            const SizedBox(
              height:
              18,
            ),

            FilledButton.icon(
              onPressed:
              _saveProfile,
              icon:
              _saving
                  ? const SizedBox(
                width:
                18,
                height:
                18,
                child:
                CircularProgressIndicator(
                  strokeWidth:
                  2,
                  color:
                  Colors.white,
                ),
              )
                  : const Icon(
                Icons
                    .save_outlined,
              ),
              label:
              Text(
                _saving
                    ? 'Saving...'
                    : 'Save Changes',
              ),
              style:
              FilledButton
                  .styleFrom(
                backgroundColor:
                _blue,
                minimumSize:
                const Size
                    .fromHeight(
                  52,
                ),
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

  void _showMessage(
      String message,
      ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content:
        Text(
          message,
        ),
      ),
    );
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

    super.dispose();
  }
}