import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ViewService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  // ============================================================
  // RECORD POST VIEW
  // ============================================================

  Future<void> recordPostView(
      String postId,
      ) async {
    final User? user =
        _auth.currentUser;

    if (user == null) return;

    final DocumentReference postRef =
    _firestore
        .collection('posts')
        .doc(postId);

    final DocumentReference viewerRef =
    postRef
        .collection('views')
        .doc(user.uid);

    final DocumentSnapshot viewer =
    await viewerRef.get();

    // Already counted this user.
    if (viewer.exists) {
      return;
    }

    await viewerRef.set({
      'uid': user.uid,
      'createdAt':
      FieldValue.serverTimestamp(),
    });

    await postRef.update({
      'viewCount':
      FieldValue.increment(1),
    });
  }

  // ============================================================
  // GET VIEW COUNT
  // ============================================================

  Stream<int> getViewCount(
      String postId,
      ) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .snapshots()
        .map((snapshot) {
      final data =
      snapshot.data();

      if (data == null) {
        return 0;
      }

      return data['viewCount'] ?? 0;
    });
  }

  // ============================================================
  // RECORD NUBUZZ VIEW
  // ============================================================

  Future<void> recordNUBuzzView(
      String postId,
      ) async {
    await recordPostView(
      postId,
    );
  }
}