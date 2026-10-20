import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/private_user_profile.dart';
import '../utils/egyptian_phone.dart';

//===================================================
// PRIVATE PROFILE SERVICE
//===================================================

class PrivateProfileService {
  PrivateProfileService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _reference(String uid) {
    return _firestore.collection('userPrivate').doc(uid);
  }

  Stream<PrivateUserProfile> watchMine() {
    final String? uid = _auth.currentUser?.uid;
    if (uid == null) {
      return const Stream<PrivateUserProfile>.empty();
    }
    return _reference(uid).snapshots().map(
      (DocumentSnapshot<Map<String, dynamic>> snapshot) => snapshot.exists
          ? PrivateUserProfile.fromFirestore(snapshot)
          : PrivateUserProfile.empty(uid),
    );
  }

  Future<PrivateUserProfile> getMine() async {
    final String? uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('Sign in to manage your private contact details.');
    }
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await _reference(
      uid,
    ).get();
    return snapshot.exists
        ? PrivateUserProfile.fromFirestore(snapshot)
        : PrivateUserProfile.empty(uid);
  }

  Future<void> savePhone({
    required String phone,
    required bool allowMarketplaceCalls,
  }) async {
    final String? uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('Sign in to save your mobile number.');
    }
    final String? normalized = EgyptianPhone.normalize(phone);
    if (normalized == null) {
      throw const FormatException(
        'Enter a valid Egyptian number starting with 010, 011, 012 or 015.',
      );
    }
    await _saveContact(
      uid: uid,
      phoneE164: normalized,
      allowMarketplaceCalls: allowMarketplaceCalls,
    );
  }

  Future<void> clearPhone() async {
    final String? uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('Sign in to update your mobile number.');
    }
    await _saveContact(uid: uid, phoneE164: '', allowMarketplaceCalls: false);
  }

  Future<void> _saveContact({
    required String uid,
    required String phoneE164,
    required bool allowMarketplaceCalls,
  }) async {
    final DocumentReference<Map<String, dynamic>> reference = _reference(uid);

    await _firestore.runTransaction<void>((Transaction transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await transaction
          .get(reference);
      final Map<String, dynamic> data = <String, dynamic>{
        'uid': uid,
        'phoneE164': phoneE164,
        'allowMarketplaceCalls': allowMarketplaceCalls,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (!snapshot.exists) {
        data['createdAt'] = FieldValue.serverTimestamp();
      }

      transaction.set(reference, data, SetOptions(merge: true));
    });
  }
}
