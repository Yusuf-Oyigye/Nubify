import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user.dart' as model;
import '../utils/egyptian_phone.dart';

import 'storage_methods.dart';

//===================================================
// AUTH METHODS
//===================================================

class AuthMethods {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
  // profile.
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
    final String cleanUsername = _firstNonEmpty(<String?>[
      username,
      emailName,
      'user_${currentUser.uid.substring(0, 6)}',
    ]);
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

    await _firestore.runTransaction<void>((Transaction transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> latest = await transaction
          .get(userRef);

      if (!latest.exists) {
        transaction.set(userRef, <String, dynamic>{
          ...repairedUser.toJson(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });

    final DocumentSnapshot<Map<String, dynamic>> repaired = await userRef.get();

    if (!repaired.exists || repaired.data() == null) {
      throw StateError('Nubify could not create the missing profile document.');
    }

    return model.User.fromSnap(repaired);
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
    Uint8List? file,
  }) async {
    String res = 'Some error occurred';

    try {
      final String cleanEmail = email.trim();

      final String cleanUsername = username.trim();

      final String cleanFullName = fullName.trim();

      final String cleanFaculty = faculty.trim();

      final String? phoneE164 = EgyptianPhone.normalize(phone);

      if (cleanEmail.isEmpty ||
          password.isEmpty ||
          cleanUsername.isEmpty ||
          cleanFullName.isEmpty ||
          cleanFaculty.isEmpty ||
          phoneE164 == null) {
        return 'Please fill all required fields';
      }

      if (password.length < 6) {
        return 'Password should be at least 6 characters';
      }

      final UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: cleanEmail,

        password: password,
      );

      await cred.user!.updateDisplayName(cleanFullName);

      // Save the public profile immediately. Optional photo upload and private
      // contact storage happen afterwards, so either one failing cannot leave
      // a valid Auth account without users/{uid}.
      await ensureCurrentUserProfile(
        username: cleanUsername,
        fullName: cleanFullName,
        faculty: cleanFaculty,
        hobbies: hobbies,
        favoriteQuote: favoriteQuote,
      );

      String photoUrl = '';

      if (file != null) {
        photoUrl = await StorageMethods().uploadImageToStorage(
          'profilePics',
          file,
          false,
        );
      }

      final model.User user = model.User(
        username: cleanUsername,

        fullName: cleanFullName,

        uid: cred.user!.uid,

        email: cleanEmail,

        faculty: cleanFaculty,

        hobbies: hobbies.trim(),

        favoriteQuote: favoriteQuote.trim(),

        followers: const <String>[],

        following: const <String>[],

        pinnedPostIds: const <String>[],

        photoUrl: photoUrl,
      );

      final DocumentReference<Map<String, dynamic>> publicUser = _firestore
          .collection('users')
          .doc(cred.user!.uid);
      final DocumentReference<Map<String, dynamic>> privateUser = _firestore
          .collection('userPrivate')
          .doc(cred.user!.uid);

      await publicUser.set(<String, dynamic>{
        ...user.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await privateUser.set(<String, dynamic>{
        'uid': cred.user!.uid,
        'phoneE164': phoneE164,
        'allowMarketplaceCalls': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      res = 'success';
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
