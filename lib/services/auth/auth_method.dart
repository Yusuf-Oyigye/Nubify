import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../models/profile/user.dart' as model;
import '../../utils/common/egyptian_phone.dart';
import '../../utils/common/email_check.dart';
import '../../utils/profile/username_rules.dart';
import '../../widgets/profile/nubify_avatar.dart';

import '../common/storage_methods.dart';
import '../profile/username_service.dart';

//===================================================
// AUTH METHODS
//===================================================

class AuthMethods {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final UsernameService _usernames = UsernameService();

  //===================================================
  // GET CURRENT USER
  //===================================================

  Future<model.User> getUserDetails() async {
    return ensureCurrentUserProfile();
  }

  //===================================================
  // ENSURE CURRENT USER PROFILE
  //
  // Firebase Authentication and Firestore are separate
  // systems. A network/rules failure can create the Auth
  // account before users/{uid} is saved. This method repairs
  // that partial signup without overwriting an existing
  // profile. The repaired profile gets a valid, free
  // username and its lock, like a normal signup.
  //===================================================

  Future<model.User> ensureCurrentUserProfile({
    String? username,
    String? fullName,
    String? faculty,
    String? hobbies,
    String? favoriteQuote,
    String? photoUrl,
  }) async {
    final User? currentUser = _auth.currentUser;

    if (currentUser == null) {
      throw StateError('No signed-in user is available.');
    }

    final DocumentReference<Map<String, dynamic>> userRef = _firestore
        .collection('users')
        .doc(currentUser.uid);

    final DocumentSnapshot<Map<String, dynamic>> existing = await userRef.get();

    if (existing.exists && existing.data() != null) {
      return model.User.fromSnap(existing);
    }

    final String email = (currentUser.email ?? '').trim();

    final String emailName = email.contains('@')
        ? email.substring(0, email.indexOf('@')).trim()
        : '';

    final String requested = username?.trim() ?? '';
    final String cleanUsername = UsernameRules.isValid(requested)
        ? UsernameRules.clean(requested)
        : await _usernames.freeUsernameFrom(
            requested.isNotEmpty ? requested : emailName,
            uid: currentUser.uid,
          );

    final String cleanFullName = _firstNonEmpty(<String?>[
      fullName,
      currentUser.displayName,
      cleanUsername,
    ]);

    final String cleanPhotoUrl = _firstNonEmpty(<String?>[
      photoUrl,
      currentUser.photoURL,
    ]);

    final model.User repairedUser = model.User(
      email: email,
      uid: currentUser.uid,
      photoUrl: cleanPhotoUrl,
      username: cleanUsername,
      fullName: cleanFullName,
      faculty: faculty?.trim() ?? '',
      hobbies: hobbies?.trim() ?? '',
      favoriteQuote: favoriteQuote?.trim() ?? '',
      followers: const <String>[],
      following: const <String>[],
      pinnedPostIds: const <String>[],
    );

    await _createProfile(userRef, repairedUser);

    final DocumentSnapshot<Map<String, dynamic>> repaired = await userRef.get();

    if (!repaired.exists || repaired.data() == null) {
      throw StateError('Nubify could not create the missing profile document.');
    }

    return model.User.fromSnap(repaired);
  }

  //===================================================
  // CREATE PROFILE + CLAIM USERNAME (ONE TRANSACTION)
  //
  // Throws UsernameTakenException if someone claimed the
  // name first. Never overwrites an existing profile.
  //===================================================

  Future<void> _createProfile(
    DocumentReference<Map<String, dynamic>> userRef,
    model.User user, {
    Map<String, dynamic> extra = const <String, dynamic>{},
  }) async {
    final Map<String, dynamic> data = <String, dynamic>{
      ...user.toJson(),
      ...extra,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      await _firestore.runTransaction<void>((Transaction transaction) async {
        final DocumentSnapshot<Map<String, dynamic>> latest = await transaction
            .get(userRef);

        if (latest.exists) return;

        await _usernames.claimInTransaction(
          transaction,
          uid: user.uid,
          username: user.username,
        );

        transaction.set(userRef, data);
      });
    } on FirebaseException catch (error) {
      if (error.code != 'permission-denied') rethrow;

      // The username rules are not deployed yet, so the lock
      // collection cannot be written. Save the profile the
      // old way; the lock is claimed at the next login after
      // the rules are deployed.
      debugPrint('Username lock unavailable, saving profile only: $error');

      await _firestore.runTransaction<void>((Transaction transaction) async {
        final DocumentSnapshot<Map<String, dynamic>> latest = await transaction
            .get(userRef);

        if (!latest.exists) transaction.set(userRef, data);
      });
    }
  }

  String _firstNonEmpty(List<String?> values) {
    for (final String? value in values) {
      final String cleanValue = value?.trim() ?? '';

      if (cleanValue.isNotEmpty) {
        return cleanValue;
      }
    }

    return '';
  }

  //===================================================
  // SIGN UP
  //
  // Returns 'success' or a message for the user. The
  // username messages start with UsernameRules texts so
  // the signup screen can send people back to that step.
  //===================================================

  Future<String> signUpUser({
    required String email,
    required String password,
    required String username,
    required String fullName,
    required String faculty,
    required String phone,
    required String hobbies,
    required String favoriteQuote,
    required String gender,
    // NubifyAvatarStyle: male, female or hijab.
    required String avatarStyle,
    required String languagePreference,
    Uint8List? file,
  }) async {
    String res = 'Some error occurred';
    UserCredential? cred;

    try {
      final String cleanEmail = email.trim();

      final String cleanUsername = UsernameRules.clean(username);

      final String cleanFullName = fullName.trim();

      final String cleanFaculty = faculty.trim();

      // The phone number is optional; when given it must be
      // a valid Egyptian mobile number.
      final String cleanPhone = phone.trim();

      final String? phoneE164 = cleanPhone.isEmpty
          ? ''
          : EgyptianPhone.normalize(cleanPhone);

      if (cleanEmail.isEmpty ||
          password.isEmpty ||
          cleanUsername.isEmpty ||
          cleanFullName.isEmpty ||
          cleanFaculty.isEmpty) {
        return 'Please fill all required fields';
      }

      final String? emailError = EmailCheck.validateFormat(cleanEmail);

      if (emailError != null) {
        return emailError;
      }

      if (phoneE164 == null) {
        return 'Enter a valid Egyptian number beginning 010, 011, 012, or 015';
      }

      if (!NubifyGender.isValid(gender) ||
          NubifyAvatarStyle.genderFor(avatarStyle) != gender) {
        return 'Please choose male or female';
      }

      final String? usernameError = UsernameRules.validate(cleanUsername);

      if (usernameError != null) {
        return usernameError;
      }

      if (password.length < 6) {
        return 'Password should be at least 6 characters';
      }

      // Quick check before making the account.
      final UsernameCheck early = await _usernames.check(cleanUsername);

      if (early.isTaken) {
        return UsernameRules.taken;
      }

      cred = await _auth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );

      final String uid = cred.user!.uid;

      await cred.user!.updateDisplayName(cleanFullName);

      // Signed in now: also check profiles from before the
      // lock collection existed.
      await _usernames.ensureAvailable(cleanUsername, uid: uid);

      final model.User user = model.User(
        username: cleanUsername,
        fullName: cleanFullName,
        uid: uid,
        email: cleanEmail,
        faculty: cleanFaculty,
        hobbies: hobbies.trim(),
        favoriteQuote: favoriteQuote.trim(),
        followers: const <String>[],
        following: const <String>[],
        pinnedPostIds: const <String>[],
        photoUrl: '',
        gender: gender,
      );

      final DocumentReference<Map<String, dynamic>> publicUser = _firestore
          .collection('users')
          .doc(uid);

      // Profile and username lock are saved together, so the
      // username is claimed atomically.
      await _createProfile(
        publicUser,
        user,
        extra: <String, dynamic>{
          'avatarStyle': avatarStyle,
          'languagePreference': languagePreference,
        },
      );

      //===================================================
      // PROFILE PICTURE
      //
      // The chosen photo, or the faculty-coloured avatar
      // when none was chosen. A failed upload never undoes
      // the account; the app adds the avatar later instead.
      //===================================================

      try {
        final Uint8List picture =
            file ??
            await NubifyAvatarPainter.renderPng(
              style: avatarStyle,
              color: NubifyAvatarColors.forFaculty(cleanFaculty),
            );

        final String photoUrl = await StorageMethods().uploadImageToStorage(
          'profilePics',
          picture,
          false,
        );

        await publicUser.update(<String, dynamic>{
          'photoUrl': photoUrl,
          // True when the picture is the generated avatar, so it
          // can be redrawn if the faculty or avatar changes.
          'avatarPhoto': file == null,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (error) {
        debugPrint('Profile picture not saved: $error');
      }

      await _firestore.collection('userPrivate').doc(uid).set(<String, dynamic>{
        'uid': uid,
        'phoneE164': phoneE164,
        'allowMarketplaceCalls': phoneE164.isNotEmpty,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      res = 'success';
    } on UsernameTakenException {
      // Someone claimed the name a moment earlier: remove
      // the new login so the person can pick another name.
      await _deleteUnfinishedAccount(cred);
      res = UsernameRules.taken;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        res = 'Email already in use';
      } else if (e.code == 'invalid-email') {
        res = 'Invalid email address';
      } else if (e.code == 'weak-password') {
        res = 'Password should be at least 6 characters';
      } else {
        res = e.message ?? 'Sign up failed';
      }
    } catch (e) {
      res = e.toString();
    }

    return res;
  }

  Future<void> _deleteUnfinishedAccount(UserCredential? cred) async {
    try {
      await cred?.user?.delete();
    } catch (error) {
      debugPrint('Could not remove the unfinished account: $error');
      await _auth.signOut();
    }
  }

  //===================================================
  // LOGIN
  //===================================================

  Future<String> loginUser({
    required String email,
    required String password,
  }) async {
    String res = 'Some error occurred';

    try {
      if (email.trim().isEmpty || password.isEmpty) {
        return 'Please enter all the fields';
      }

      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      await ensureCurrentUserProfile();

      // People who joined before usernames were locked get a
      // lock for their current username now. Never blocks login.
      await _usernames.claimMyCurrentUsername();

      res = 'success';
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-email') {
        res = 'Invalid email address';
      } else if (e.code == 'invalid-credential' || e.code == 'wrong-password') {
        res = 'Incorrect email or password';
      } else if (e.code == 'user-not-found') {
        res = 'User not found';
      } else {
        res = e.message ?? 'Login failed';
      }
    } catch (e) {
      res = e.toString();
    }

    return res;
  }
}
