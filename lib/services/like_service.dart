import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LikeService {
  // ============================================================
  // FIREBASE
  // ============================================================

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  // ============================================================
  // LIKE POST
  // ============================================================

  Future<void> likePost(String postId) async {
    final User? currentUser = _auth.currentUser;

    if (currentUser == null) {
      throw Exception('User is not logged in.');
    }

    final String uid = currentUser.uid;

    final DocumentReference postRef =
    _firestore.collection('posts').doc(postId);

    final DocumentReference likeRef =
    postRef.collection('likes').doc(uid);

    await _firestore.runTransaction((transaction) async {
      final DocumentSnapshot postSnapshot =
      await transaction.get(postRef);

      final DocumentSnapshot likeSnapshot =
      await transaction.get(likeRef);

      if (!postSnapshot.exists) {
        throw Exception('Post does not exist.');
      }

      // Already liked
      if (likeSnapshot.exists) {
        return;
      }

      transaction.set(
        likeRef,
        {
          'uid': uid,
          'createdAt': FieldValue.serverTimestamp(),
        },
      );

      transaction.update(
        postRef,
        {
          'likeCount': FieldValue.increment(1),
        },
      );
    });
  }

  // ============================================================
  // UNLIKE POST
  // ============================================================

  Future<void> unlikePost(String postId) async {
    final User? currentUser = _auth.currentUser;

    if (currentUser == null) {
      throw Exception('User is not logged in.');
    }

    final String uid = currentUser.uid;

    final DocumentReference postRef =
    _firestore.collection('posts').doc(postId);

    final DocumentReference likeRef =
    postRef.collection('likes').doc(uid);

    await _firestore.runTransaction((transaction) async {
      final DocumentSnapshot likeSnapshot =
      await transaction.get(likeRef);

      if (!likeSnapshot.exists) {
        return;
      }

      transaction.delete(likeRef);

      transaction.update(
        postRef,
        {
          'likeCount': FieldValue.increment(-1),
        },
      );
    });
  }

  // ============================================================
  // CHECK IF CURRENT USER LIKED
  // ============================================================

  Future<bool> hasLiked(String postId) async {
    final User? currentUser = _auth.currentUser;

    if (currentUser == null) {
      return false;
    }

    final String uid = currentUser.uid;

    final DocumentSnapshot snapshot =
    await _firestore
        .collection('posts')
        .doc(postId)
        .collection('likes')
        .doc(uid)
        .get();

    return snapshot.exists;
  }

  // ============================================================
  // GET LIKE COUNT
  // ============================================================

  Future<int> getLikeCount(String postId) async {
    final DocumentSnapshot snapshot =
    await _firestore
        .collection('posts')
        .doc(postId)
        .get();

    if (!snapshot.exists) {
      return 0;
    }

    final Map<String, dynamic> data =
    snapshot.data() as Map<String, dynamic>;

    return (data['likeCount'] ?? 0) as int;
  }
}