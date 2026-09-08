import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CommentService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  String get _uid {
    final User? user = _auth.currentUser;

    if (user == null) {
      throw Exception(
        'User is not logged in.',
      );
    }

    return user.uid;
  }

  // ============================================================
  // GET CURRENT USER PROFILE
  //
  // IMPORTANT:
  // Nubify stores username, fullName and photoUrl in Firestore,
  // not in FirebaseAuth displayName.
  // ============================================================

  Future<Map<String, String>> _getCurrentUserProfile() async {
    final User? user = _auth.currentUser;

    if (user == null) {
      throw Exception(
        'User is not logged in.',
      );
    }

    final DocumentSnapshot<
        Map<String, dynamic>> userSnapshot =
    await _firestore
        .collection('users')
        .doc(user.uid)
        .get();

    if (!userSnapshot.exists) {
      return <String, String>{
        'username': '',
        'fullName': '',
        'photoUrl': '',
      };
    }

    final Map<String, dynamic> data =
        userSnapshot.data() ??
            <String, dynamic>{};

    return <String, String>{
      'username':
      (data['username'] ?? '')
          .toString()
          .trim(),
      'fullName':
      (data['fullName'] ?? '')
          .toString()
          .trim(),
      'photoUrl':
      (data['photoUrl'] ?? '')
          .toString()
          .trim(),
    };
  }

  // ============================================================
  // GET USER PROFILE BY UID
  // ============================================================

  Future<Map<String, String>> getUserProfile(
      String uid,
      ) async {
    if (uid.trim().isEmpty) {
      return <String, String>{
        'username': '',
        'fullName': '',
        'photoUrl': '',
      };
    }

    try {
      final DocumentSnapshot<
          Map<String, dynamic>> snapshot =
      await _firestore
          .collection('users')
          .doc(uid)
          .get();

      if (!snapshot.exists) {
        return <String, String>{
          'username': '',
          'fullName': '',
          'photoUrl': '',
        };
      }

      final Map<String, dynamic> data =
          snapshot.data() ??
              <String, dynamic>{};

      return <String, String>{
        'username':
        (data['username'] ?? '')
            .toString()
            .trim(),
        'fullName':
        (data['fullName'] ?? '')
            .toString()
            .trim(),
        'photoUrl':
        (data['photoUrl'] ?? '')
            .toString()
            .trim(),
      };
    } catch (e) {
      return <String, String>{
        'username': '',
        'fullName': '',
        'photoUrl': '',
      };
    }
  }

  // ============================================================
  // GET COMMENTS
  // ============================================================

  Stream<QuerySnapshot<Map<String, dynamic>>> getComments(
      String postId,
      ) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy(
      'createdAt',
      descending: false,
    )
        .snapshots();
  }

  // ============================================================
  // GET REPLIES
  // ============================================================

  Stream<QuerySnapshot<Map<String, dynamic>>> getReplies({
    required String postId,
    required String commentId,
  }) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .collection('replies')
        .orderBy(
      'createdAt',
      descending: true,
    )
        .snapshots();
  }

  // ============================================================
  // ADD COMMENT
  // ============================================================

  Future<void> addComment({
    required String postId,
    required String text,
  }) async {
    final String cleanText =
    text.trim();

    if (cleanText.isEmpty) {
      return;
    }

    final User? user =
        _auth.currentUser;

    if (user == null) {
      throw Exception(
        'User is not logged in.',
      );
    }

    // Get the REAL Nubify profile.
    final Map<String, String> profile =
    await _getCurrentUserProfile();

    final String username =
        profile['username'] ?? '';

    final String fullName =
        profile['fullName'] ?? '';

    final String photoUrl =
        profile['photoUrl'] ?? '';

    final DocumentReference<
        Map<String, dynamic>> postRef =
    _firestore
        .collection('posts')
        .doc(postId);

    final DocumentReference<
        Map<String, dynamic>> commentRef =
    postRef
        .collection('comments')
        .doc();

    await commentRef.set(
      <String, dynamic>{
        'commentId':
        commentRef.id,
        'postId':
        postId,
        'uid':
        user.uid,

        // REAL USER DETAILS
        'username':
        username,
        'fullName':
        fullName,
        'photoUrl':
        photoUrl,

        'text':
        cleanText,
        'likeCount':
        0,
        'replyCount':
        0,
        'createdAt':
        FieldValue.serverTimestamp(),
      },
    );

    await postRef.update(
      <String, dynamic>{
        'commentCount':
        FieldValue.increment(1),
      },
    );
  }

  // ============================================================
  // LIKE / UNLIKE COMMENT
  // ============================================================

  Future<void> toggleCommentLike({
    required String postId,
    required String commentId,
  }) async {
    final String uid =
        _uid;

    final DocumentReference<
        Map<String, dynamic>> commentRef =
    _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId);

    final DocumentReference<
        Map<String, dynamic>> likeRef =
    commentRef
        .collection('likes')
        .doc(uid);

    await _firestore.runTransaction(
          (Transaction transaction) async {
        final DocumentSnapshot<
            Map<String, dynamic>> likeSnapshot =
        await transaction.get(
          likeRef,
        );

        if (likeSnapshot.exists) {
          transaction.delete(
            likeRef,
          );

          transaction.update(
            commentRef,
            <String, dynamic>{
              'likeCount':
              FieldValue.increment(-1),
            },
          );
        } else {
          transaction.set(
            likeRef,
            <String, dynamic>{
              'uid':
              uid,
              'createdAt':
              FieldValue.serverTimestamp(),
            },
          );

          transaction.update(
            commentRef,
            <String, dynamic>{
              'likeCount':
              FieldValue.increment(1),
            },
          );
        }
      },
    );
  }

  // ============================================================
  // CHECK COMMENT LIKE
  // ============================================================

  Future<bool> hasLikedComment({
    required String postId,
    required String commentId,
  }) async {
    final String uid =
        _uid;

    final DocumentSnapshot<
        Map<String, dynamic>> snapshot =
    await _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .collection('likes')
        .doc(uid)
        .get();

    return snapshot.exists;
  }

  // ============================================================
  // ADD REPLY
  // ============================================================

  Future<void> addReply({
    required String postId,
    required String commentId,
    required String text,
  }) async {
    final String cleanText =
    text.trim();

    if (cleanText.isEmpty) {
      return;
    }

    final User? user =
        _auth.currentUser;

    if (user == null) {
      throw Exception(
        'User is not logged in.',
      );
    }

    // Get the REAL Nubify profile.
    final Map<String, String> profile =
    await _getCurrentUserProfile();

    final String username =
        profile['username'] ?? '';

    final String fullName =
        profile['fullName'] ?? '';

    final String photoUrl =
        profile['photoUrl'] ?? '';

    final DocumentReference<
        Map<String, dynamic>> commentRef =
    _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId);

    final DocumentReference<
        Map<String, dynamic>> replyRef =
    commentRef
        .collection('replies')
        .doc();

    await replyRef.set(
      <String, dynamic>{
        'replyId':
        replyRef.id,
        'commentId':
        commentId,
        'postId':
        postId,
        'uid':
        user.uid,

        // REAL USER DETAILS
        'username':
        username,
        'fullName':
        fullName,
        'photoUrl':
        photoUrl,

        'text':
        cleanText,
        'likeCount':
        0,
        'createdAt':
        FieldValue.serverTimestamp(),
      },
    );

    await commentRef.update(
      <String, dynamic>{
        'replyCount':
        FieldValue.increment(1),
      },
    );
  }

  // ============================================================
  // LIKE / UNLIKE REPLY
  // ============================================================

  Future<void> toggleReplyLike({
    required String postId,
    required String commentId,
    required String replyId,
  }) async {
    final String uid =
        _uid;

    final DocumentReference<
        Map<String, dynamic>> replyRef =
    _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .collection('replies')
        .doc(replyId);

    final DocumentReference<
        Map<String, dynamic>> likeRef =
    replyRef
        .collection('likes')
        .doc(uid);

    await _firestore.runTransaction(
          (Transaction transaction) async {
        final DocumentSnapshot<
            Map<String, dynamic>> likeSnapshot =
        await transaction.get(
          likeRef,
        );

        if (likeSnapshot.exists) {
          transaction.delete(
            likeRef,
          );

          transaction.update(
            replyRef,
            <String, dynamic>{
              'likeCount':
              FieldValue.increment(-1),
            },
          );
        } else {
          transaction.set(
            likeRef,
            <String, dynamic>{
              'uid':
              uid,
              'createdAt':
              FieldValue.serverTimestamp(),
            },
          );

          transaction.update(
            replyRef,
            <String, dynamic>{
              'likeCount':
              FieldValue.increment(1),
            },
          );
        }
      },
    );
  }

  // ============================================================
  // CHECK REPLY LIKE
  // ============================================================

  Future<bool> hasLikedReply({
    required String postId,
    required String commentId,
    required String replyId,
  }) async {
    final String uid =
        _uid;

    final DocumentSnapshot<
        Map<String, dynamic>> snapshot =
    await _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .collection('replies')
        .doc(replyId)
        .collection('likes')
        .doc(uid)
        .get();

    return snapshot.exists;
  }

  // ============================================================
  // REPAIR OLD COMMENT PROFILE DETAILS
  //
  // Old comments were saved using FirebaseAuth.displayName,
  // which is why their names may currently be blank.
  //
  // This updates those OLD comments using users/{uid}.
  // ============================================================

  Future<void> repairMissingCommentProfiles(
      String postId,
      ) async {
    try {
      final QuerySnapshot<
          Map<String, dynamic>> commentsSnapshot =
      await _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .get();

      for (final QueryDocumentSnapshot<
          Map<String, dynamic>>
      commentDoc
      in commentsSnapshot.docs) {
        final Map<String, dynamic> commentData =
        commentDoc.data();

        final String uid =
        (commentData['uid'] ?? '')
            .toString()
            .trim();

        if (uid.isEmpty) {
          continue;
        }

        final String oldUsername =
        (commentData['username'] ?? '')
            .toString()
            .trim();

        final String oldFullName =
        (commentData['fullName'] ?? '')
            .toString()
            .trim();

        final String oldPhotoUrl =
        (commentData['photoUrl'] ?? '')
            .toString()
            .trim();

        if (oldUsername.isEmpty ||
            oldFullName.isEmpty ||
            oldPhotoUrl.isEmpty) {
          final Map<String, String> profile =
          await getUserProfile(
            uid,
          );

          final Map<String, dynamic> updateData =
          <String, dynamic>{};

          if (oldUsername.isEmpty &&
              (profile['username'] ?? '')
                  .isNotEmpty) {
            updateData['username'] =
            profile['username'];
          }

          if (oldFullName.isEmpty &&
              (profile['fullName'] ?? '')
                  .isNotEmpty) {
            updateData['fullName'] =
            profile['fullName'];
          }

          if (oldPhotoUrl.isEmpty &&
              (profile['photoUrl'] ?? '')
                  .isNotEmpty) {
            updateData['photoUrl'] =
            profile['photoUrl'];
          }

          if (updateData.isNotEmpty) {
            await commentDoc.reference.update(
              updateData,
            );
          }
        }

        // ========================================================
        // REPAIR REPLIES UNDER THIS COMMENT
        // ========================================================

        final QuerySnapshot<
            Map<String, dynamic>> repliesSnapshot =
        await commentDoc.reference
            .collection('replies')
            .get();

        for (final QueryDocumentSnapshot<
            Map<String, dynamic>>
        replyDoc
        in repliesSnapshot.docs) {
          final Map<String, dynamic> replyData =
          replyDoc.data();

          final String replyUid =
          (replyData['uid'] ?? '')
              .toString()
              .trim();

          if (replyUid.isEmpty) {
            continue;
          }

          final String oldReplyUsername =
          (replyData['username'] ?? '')
              .toString()
              .trim();

          final String oldReplyFullName =
          (replyData['fullName'] ?? '')
              .toString()
              .trim();

          final String oldReplyPhotoUrl =
          (replyData['photoUrl'] ?? '')
              .toString()
              .trim();

          if (oldReplyUsername.isEmpty ||
              oldReplyFullName.isEmpty ||
              oldReplyPhotoUrl.isEmpty) {
            final Map<String, String> replyProfile =
            await getUserProfile(
              replyUid,
            );

            final Map<String, dynamic> replyUpdate =
            <String, dynamic>{};

            if (oldReplyUsername.isEmpty &&
                (replyProfile['username'] ?? '')
                    .isNotEmpty) {
              replyUpdate['username'] =
              replyProfile['username'];
            }

            if (oldReplyFullName.isEmpty &&
                (replyProfile['fullName'] ?? '')
                    .isNotEmpty) {
              replyUpdate['fullName'] =
              replyProfile['fullName'];
            }

            if (oldReplyPhotoUrl.isEmpty &&
                (replyProfile['photoUrl'] ?? '')
                    .isNotEmpty) {
              replyUpdate['photoUrl'] =
              replyProfile['photoUrl'];
            }

            if (replyUpdate.isNotEmpty) {
              await replyDoc.reference.update(
                replyUpdate,
              );
            }
          }
        }
      }
    } catch (e) {
      // Do not crash the comments page if an old
      // comment cannot be repaired.
    }
  }

  // ============================================================
  // DELETE COMMENT
  // ============================================================

  Future<void> deleteComment({
    required String postId,
    required String commentId,
  }) async {
    final String uid =
        _uid;

    final DocumentReference<
        Map<String, dynamic>> commentRef =
    _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId);

    final DocumentSnapshot<
        Map<String, dynamic>> snapshot =
    await commentRef.get();

    if (!snapshot.exists) {
      return;
    }

    final Map<String, dynamic> data =
        snapshot.data() ??
            <String, dynamic>{};

    if ((data['uid'] ?? '').toString() !=
        uid) {
      throw Exception(
        'You can only delete your own comment.',
      );
    }

    await commentRef.delete();

    await _firestore
        .collection('posts')
        .doc(postId)
        .update(
      <String, dynamic>{
        'commentCount':
        FieldValue.increment(-1),
      },
    );
  }
}