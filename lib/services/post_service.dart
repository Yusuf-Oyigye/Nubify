import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PostService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  String get _uid => _auth.currentUser!.uid;

  // ============================================================
  // LIKE / UNLIKE
  // ============================================================

  Future<void> toggleLike(String postId) async {
    final postRef =
    _firestore.collection('posts').doc(postId);

    final likeRef =
    postRef.collection('likes').doc(_uid);

    final likeSnapshot = await likeRef.get();

    if (likeSnapshot.exists) {
      await likeRef.delete();

      await postRef.update({
        'likeCount': FieldValue.increment(-1),
      });
    } else {
      await likeRef.set({
        'uid': _uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await postRef.update({
        'likeCount': FieldValue.increment(1),
      });
    }
  }

  // ============================================================
  // CHECK LIKE
  // ============================================================

  Future<bool> isLiked(String postId) async {
    final snapshot = await _firestore
        .collection('posts')
        .doc(postId)
        .collection('likes')
        .doc(_uid)
        .get();

    return snapshot.exists;
  }

  // ============================================================
  // SAVE / UNSAVE
  // ============================================================

  Future<void> toggleSave(String postId) async {
    final saveRef = _firestore
        .collection('users')
        .doc(_uid)
        .collection('savedPosts')
        .doc(postId);

    final snapshot = await saveRef.get();

    if (snapshot.exists) {
      await saveRef.delete();
    } else {
      await saveRef.set({
        'postId': postId,
        'savedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // ============================================================
  // HIDE POST
  // ============================================================

  Future<void> hidePost(String postId) async {
    await _firestore
        .collection('users')
        .doc(_uid)
        .collection('hiddenPosts')
        .doc(postId)
        .set({
      'postId': postId,
      'hiddenAt': FieldValue.serverTimestamp(),
    });
  }

  // ============================================================
  // REPORT POST
  // ============================================================

  Future<void> reportPost(
      String postId,
      String reason,
      ) async {
    await _firestore
        .collection('reports')
        .add({
      'type': 'post',
      'postId': postId,
      'reportedBy': _uid,
      'reason': reason,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ============================================================
  // DELETE POST
  // ============================================================

  Future<void> deletePost(String postId) async {
    final postRef =
    _firestore.collection('posts').doc(postId);

    final snapshot = await postRef.get();

    if (!snapshot.exists) return;

    final data =
    snapshot.data() as Map<String, dynamic>;

    if (data['uid'] != _uid) {
      throw Exception(
        'You can only delete your own post.',
      );
    }

    await postRef.delete();
  }

  // ============================================================
  // EDIT CAPTION
  // ============================================================

  Future<void> editCaption(
      String postId,
      String caption,
      ) async {
    final postRef =
    _firestore.collection('posts').doc(postId);

    final snapshot = await postRef.get();

    if (!snapshot.exists) return;

    final data =
    snapshot.data() as Map<String, dynamic>;

    if (data['uid'] != _uid) {
      throw Exception(
        'You can only edit your own post.',
      );
    }

    await postRef.update({
      'caption': caption.trim(),
      'edited': true,
      'editedAt': FieldValue.serverTimestamp(),
    });
  }

  // ============================================================
  // BLOCK USER
  // ============================================================

  Future<void> blockUser(String userId) async {
    if (userId == _uid) return;

    await _firestore
        .collection('users')
        .doc(_uid)
        .collection('blockedUsers')
        .doc(userId)
        .set({
      'uid': userId,
      'blockedAt': FieldValue.serverTimestamp(),
    });
  }

  // ============================================================
  // UNBLOCK USER
  // ============================================================

  Future<void> unblockUser(String userId) async {
    await _firestore
        .collection('users')
        .doc(_uid)
        .collection('blockedUsers')
        .doc(userId)
        .delete();
  }

  // ============================================================
  // CHECK BLOCK
  // ============================================================

  Future<bool> isBlocked(String userId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(_uid)
        .collection('blockedUsers')
        .doc(userId)
        .get();

    return snapshot.exists;
  }
}