import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/seller_verification.dart';

typedef UploadProgressCallback = void Function(double progress);

//===================================================
// SELLER VERIFICATION SERVICE
//===================================================

class SellerVerificationService {
  SellerVerificationService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    FirebaseFunctions? functions,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirebaseFunctions _functions;

  Stream<SellerVerification> watchMine() {
    final String? uid = _auth.currentUser?.uid;
    if (uid == null) {
      return const Stream<SellerVerification>.empty();
    }
    return _firestore
        .collection('sellerVerifications')
        .doc(uid)
        .snapshots()
        .map(
          (DocumentSnapshot<Map<String, dynamic>> snapshot) => snapshot.exists
              ? SellerVerification.fromFirestore(snapshot)
              : SellerVerification.notSubmitted(uid),
        );
  }

  Future<SellerVerification> getMine() async {
    final String? uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('Sign in before applying to become a seller.');
    }
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('sellerVerifications')
        .doc(uid)
        .get();
    return snapshot.exists
        ? SellerVerification.fromFirestore(snapshot)
        : SellerVerification.notSubmitted(uid);
  }

  Future<void> submit({
    required String fullName,
    required String studentIdNumber,
    required Uint8List studentIdImage,
    required String fileExtension,
    UploadProgressCallback? onProgress,
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw StateError('Sign in before submitting seller verification.');
    }

    final String cleanName = fullName.trim();
    final String cleanStudentId = studentIdNumber.trim();
    if (cleanName.length < 2 || cleanName.length > 100) {
      throw const FormatException('Enter your full name.');
    }
    if (cleanStudentId.length < 3 || cleanStudentId.length > 40) {
      throw const FormatException('Enter your university student ID number.');
    }
    if (studentIdImage.isEmpty ||
        studentIdImage.lengthInBytes > 10 * 1024 * 1024) {
      throw const FormatException(
        'Choose a clear ID image smaller than 10 MB.',
      );
    }

    final String verificationId = _firestore.collection('_ids').doc().id;
    final String safeExtension = fileExtension.toLowerCase() == 'png'
        ? 'png'
        : 'jpg';
    final String storagePath =
        'seller_verifications/${user.uid}/$verificationId/student_id.$safeExtension';
    final Reference reference = _storage.ref(storagePath);
    final UploadTask task = reference.putData(
      studentIdImage,
      SettableMetadata(
        contentType: safeExtension == 'png' ? 'image/png' : 'image/jpeg',
        customMetadata: <String, String>{
          'ownerUid': user.uid,
          'verificationId': verificationId,
          'privateDocument': 'true',
        },
      ),
    );

    final Stream<TaskSnapshot> snapshots = task.snapshotEvents;
    final StreamSubscription<TaskSnapshot> subscription = snapshots.listen((
      TaskSnapshot snapshot,
    ) {
      final int total = snapshot.totalBytes;
      onProgress?.call(total == 0 ? 0 : snapshot.bytesTransferred / total);
    });

    try {
      await task;
      onProgress?.call(1);
      final HttpsCallable callable = _functions.httpsCallable(
        'submitSellerVerification',
      );
      await callable.call<void>(<String, dynamic>{
        'verificationId': verificationId,
        'fullName': cleanName,
        'studentIdNumber': cleanStudentId,
        'studentIdStoragePath': storagePath,
      });
    } catch (_) {
      try {
        await reference.delete();
      } catch (_) {
        // The backend may already own the uploaded document; cleanup is best effort.
      }
      rethrow;
    } finally {
      await subscription.cancel();
    }
  }

  Future<Uint8List?> loadPrivateIdImage(String storagePath) async {
    if (storagePath.trim().isEmpty) {
      return null;
    }
    return _storage.ref(storagePath).getData(10 * 1024 * 1024);
  }
}
