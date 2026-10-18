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
    final User currentUser = _auth.currentUser!;

    final DocumentSnapshot<Map<String, dynamic>> snap = await _firestore
        .collection('users')
        .doc(currentUser.uid)
        .get();

    return model.User.fromSnap(snap);
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

      final WriteBatch batch = _firestore.batch();
      final DocumentReference<Map<String, dynamic>> publicUser = _firestore
          .collection('users')
          .doc(cred.user!.uid);
      final DocumentReference<Map<String, dynamic>> privateUser = _firestore
          .collection('userPrivate')
          .doc(cred.user!.uid);

      batch.set(publicUser, user.toJson());
      batch.set(privateUser, <String, dynamic>{
        'uid': cred.user!.uid,
        'phoneE164': phoneE164,
        'allowMarketplaceCalls': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();

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
