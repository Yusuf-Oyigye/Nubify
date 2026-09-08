import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class PostActionsService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  // ==========================================================
  // DELETE POST
  // ==========================================================

  Future<void> deletePost(String postId) async {
    await _firestore
        .collection('posts')
        .doc(postId)
        .delete();
  }

  // ==========================================================
  // HIDE POST
  // ==========================================================

  Future<void> hidePost(
      String postId,
      String uid,
      ) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('hiddenPosts')
        .doc(postId)
        .set({
      'postId': postId,
      'hiddenAt': FieldValue.serverTimestamp(),
    });
  }

  // ==========================================================
  // REPORT POST
  // ==========================================================

  Future<void> reportPost(
      String postId,
      String uid,
      ) async {
    await _firestore
        .collection('reports')
        .add({
      'postId': postId,
      'reportedBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ==========================================================
  // BLOCK USER
  // ==========================================================

  Future<void> blockUser(
      String currentUid,
      String blockedUid,
      ) async {
    await _firestore
        .collection('users')
        .doc(currentUid)
        .collection('blockedUsers')
        .doc(blockedUid)
        .set({
      'uid': blockedUid,
      'blockedAt': FieldValue.serverTimestamp(),
    });
  }
}