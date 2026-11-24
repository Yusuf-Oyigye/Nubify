import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../notifications/push_notifications.dart';

//===================================================
// NUBIFY — ACCOUNT DELETION SERVICE
//===================================================

class AccountDeletionService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<void> deleteAccount({required String password}) async {
    final User? user = _auth.currentUser;

    if (user == null || user.email == null) {
      throw Exception('Please log in again.');
    }

    final String uid = user.uid;

    //===================================================
    // 1. CONFIRM THE PASSWORD
    //
    // Firebase only deletes accounts that signed in
    // recently, so we sign in again quietly first.
    //===================================================

    final AuthCredential credential = EmailAuthProvider.credential(
      email: user.email!,
      password: password,
    );

    await user.reauthenticateWithCredential(credential);

    //===================================================
    // 2. DELETE PROFILE PICTURE (IF THERE IS ONE)
    //===================================================

    try {
      await _storage.ref().child('profilePics').child(uid).delete();
    } on FirebaseException catch (error) {
      if (error.code != 'object-not-found') rethrow;
    }

    //===================================================
    // 3. DELETE PRIVATE DETAILS (PHONE NUMBER)
    //===================================================

    final DocumentReference<Map<String, dynamic>> privateRef = _firestore
        .collection('userPrivate')
        .doc(uid);

    final DocumentSnapshot<Map<String, dynamic>> privateDoc = await privateRef
        .get();

    if (privateDoc.exists) {
      await privateRef.delete();
    }

    // No more phone notifications for this account.
    await PushNotifications.instance.stop();
    try {
      await _firestore.collection('pushTokens').doc(uid).delete();
    } on FirebaseException {
      // Phone notification rules not deployed yet.
    }

    //===================================================
    // 4. DELETE PUBLIC PROFILE + FREE THE USERNAME
    //
    // Both in one write, so the username lock is released
    // together with the profile.
    //===================================================

    final DocumentReference<Map<String, dynamic>> profileRef = _firestore
        .collection('users')
        .doc(uid);

    final String usernameLower =
        ((await profileRef.get()).data()?['usernameLower'] ?? '').toString();

    final WriteBatch batch = _firestore.batch()..delete(profileRef);

    if (usernameLower.isNotEmpty && !usernameLower.contains('/')) {
      try {
        final DocumentSnapshot<Map<String, dynamic>> lock = await _firestore
            .collection('usernames')
            .doc(usernameLower)
            .get();

        if (lock.exists && lock.data()?['uid'] == uid) {
          batch.delete(lock.reference);
        }
      } on FirebaseException {
        // Username rules not deployed yet: there is no lock.
      }
    }

    await batch.commit();

    //===================================================
    // 5. DELETE THE LOGIN ITSELF
    //
    // This signs the user out, and main.dart shows
    // the LoginScreen automatically.
    //===================================================

    await user.delete();
  }
}
