import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:nubify/models/user.dart' as model;
import 'package:nubify/resources/storage_methods.dart';

class AuthMethods {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  Future<model.User> getUserDetails() async {
    User currentUser = _auth.currentUser!;

    DocumentSnapshot snap = await _firestore
        .collection('users')
        .doc(currentUser.uid)
        .get();

    return model.User.fromSnap(snap);
  }

  // Sign up user
  Future<String> signUpUser({
    required String email,
    required String password,
    required String username,
    required String fullName,
    required String faculty,
    required String hobbies,
    required String favoriteQuote,
    Uint8List? file,
  }) async {
    String res = "Some error occurred";

    try {
      if (email.isNotEmpty &&
          password.isNotEmpty &&
          username.isNotEmpty &&
          fullName.isNotEmpty &&
          faculty.isNotEmpty) {
        UserCredential cred =
        await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        String photoUrl = '';

        if (file != null) {
          photoUrl = await StorageMethods()
              .uploadImageToStorage(
            'profilePics',
            file,
            false,
          );
        }

        model.User user = model.User(
          username: username,
          fullName: fullName,
          uid: cred.user!.uid,
          email: email,
          faculty: faculty,
          hobbies: hobbies,
          favoriteQuote: favoriteQuote,
          followers: [],
          following: [],
          photoUrl: photoUrl,
        );

        await _firestore
            .collection('users')
            .doc(cred.user!.uid)
            .set(user.toJson());

        res = "success";
      } else {
        res = "Please fill all required fields";
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        res = "Email already in use";
      } else if (e.code == 'invalid-email') {
        res = "Invalid email address";
      } else if (e.code == 'weak-password') {
        res =
        "Password should be at least 6 characters";
      } else {
        res = e.message ?? "Sign up failed";
      }
    } catch (e) {
      res = e.toString();
    }

    return res;
  }

  // Login user
  Future<String> loginUser({
    required String email,
    required String password,
  }) async {
    String res = "Some error occurred";

    try {
      if (email.isNotEmpty &&
          password.isNotEmpty) {
        await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        res = "success";
      } else {
        res = "Please enter all the fields";
      }
    } on FirebaseAuthException catch (e) {
      print(
        "Firebase Error Code: ${e.code}",
      );

      if (e.code == 'invalid-email') {
        res = "Invalid email address";
      } else if (e.code ==
          'invalid-credential') {
        res =
        "Incorrect email or password";
      } else if (e.code ==
          'user-not-found') {
        res = "User not found";
      } else if (e.code ==
          'wrong-password') {
        res = "Incorrect password";
      } else {
        res = e.message ?? "Login failed";
      }
    } catch (e) {
      res = e.toString();
    }

    return res;
  }
}