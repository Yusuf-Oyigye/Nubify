import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import 'notification_service.dart';

class CommentService {
  //===================================================
  // FIREBASE
  //===================================================

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  final FirebaseStorage _storage =
      FirebaseStorage.instance;

  //===================================================
  // NOTIFICATION SERVICE
  //===================================================

  final NotificationService _notificationService =
  NotificationService();

  //===================================================
  // CURRENT UID
  //===================================================

  String get _uid {
    final User? user =
        _auth.currentUser;

    if (user == null) {
      throw Exception(
        'User is not logged in.',
      );
    }

    return user.uid;
  }

  //===================================================
  // GET CURRENT USER PROFILE
  //
  // Nubify stores username, fullName and photoUrl in
  // Firestore users/{uid}.
  //===================================================

  Future<Map<String, String>>
  _getCurrentUserProfile() async {
    final User? user =
        _auth.currentUser;

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
        'username':
        '',
        'fullName':
        '',
        'photoUrl':
        '',
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

  //===================================================
  // GET USER PROFILE BY UID
  //===================================================

  Future<Map<String, String>> getUserProfile(
      String uid,
      ) async {
    if (uid.trim().isEmpty) {
      return <String, String>{
        'username':
        '',
        'fullName':
        '',
        'photoUrl':
        '',
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
          'username':
          '',
          'fullName':
          '',
          'photoUrl':
          '',
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
    } catch (_) {
      return <String, String>{
        'username':
        '',
        'fullName':
        '',
        'photoUrl':
        '',
      };
    }
  }

  //===================================================
  // GET COMMENTS
  //
  // OLDEST FIRST
  //===================================================

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

  //===================================================
  // GET REPLIES
  //
  // OLDEST FIRST
  //===================================================

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
      descending: false,
    )
        .snapshots();
  }

  //===================================================
  // ADD COMMENT
  //
  // USER CAN SEND:
  //
  // TEXT ONLY
  // IMAGE ONLY
  // TEXT + IMAGE
  //===================================================

  Future<void> addComment({
    required String postId,
    required String text,
    String? imagePath,
  }) async {
    final String cleanText =
    text.trim();

    final String cleanImagePath =
        imagePath?.trim() ??
            '';

    if (cleanText.isEmpty &&
        cleanImagePath.isEmpty) {
      return;
    }

    final User? user =
        _auth.currentUser;

    if (user == null) {
      throw Exception(
        'User is not logged in.',
      );
    }

    //===================================================
    // REAL NUBIFY PROFILE
    //===================================================

    final Map<String, String> profile =
    await _getCurrentUserProfile();

    final String username =
        profile['username'] ??
            '';

    final String fullName =
        profile['fullName'] ??
            '';

    final String photoUrl =
        profile['photoUrl'] ??
            '';

    //===================================================
    // REFERENCES
    //===================================================

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

    //===================================================
    // IMAGE
    //===================================================

    String imageUrl =
        '';

    String imageStoragePath =
        '';

    if (cleanImagePath.isNotEmpty) {
      final _UploadedCommentImage uploaded =
      await _uploadCommentImage(
        filePath:
        cleanImagePath,

        postId:
        postId,

        commentId:
        commentRef.id,
      );

      imageUrl =
          uploaded.url;

      imageStoragePath =
          uploaded.storagePath;
    }

    //===================================================
    // PROFILE -> COMMENTS ACTIVITY REFERENCE
    //===================================================

    final DocumentReference<
        Map<String, dynamic>> activityRef =
    _firestore
        .collection('users')
        .doc(user.uid)
        .collection(
      'commentActivity',
    )
        .doc(
      'comment_${commentRef.id}',
    );

    //===================================================
    // CORE COMMENT BATCH
    //
    // ONLY THE COMMENT + POST COUNT ARE REQUIRED HERE.
    // PROFILE HISTORY AND NOTIFICATIONS ARE BEST-EFFORT
    // AFTER THE COMMENT HAS BEEN ACCEPTED.
    //===================================================

    final WriteBatch coreBatch =
    _firestore.batch();

    coreBatch.set(
      commentRef,
      <String, dynamic>{
        'commentId':
        commentRef.id,

        'postId':
        postId,

        'uid':
        user.uid,

        'username':
        username,

        'fullName':
        fullName,

        'photoUrl':
        photoUrl,

        'text':
        cleanText,

        'imageUrl':
        imageUrl,

        'imageStoragePath':
        imageStoragePath,

        'hasImage':
        imageUrl.isNotEmpty,

        'likeCount':
        0,

        'replyCount':
        0,

        'createdAt':
        FieldValue.serverTimestamp(),
      },
    );

    coreBatch.update(
      postRef,
      <String, dynamic>{
        'commentCount':
        FieldValue.increment(
          1,
        ),
      },
    );

    try {
      await coreBatch.commit()
          .timeout(
        const Duration(
          seconds:
          10,
        ),
      );
    } on TimeoutException catch (error) {
      //===================================================
      // FIRESTORE CAN SHOW THE LOCAL COMMENT BEFORE THE
      // SERVER ACKNOWLEDGES IT. DO NOT LEAVE THE SEND
      // ARROW SPINNING FOREVER WHILE THAT WRITE SYNCS.
      //===================================================

      debugPrint(
        'Comment sync timeout: $error',
      );

      return;
    } catch (error) {
      if (imageStoragePath.isNotEmpty) {
        await _deleteStoragePath(
          imageStoragePath,
        );
      }

      rethrow;
    }

    //===================================================
    // PROFILE COMMENT ACTIVITY
    // BEST-EFFORT - NEVER BLOCK SEND BUTTON
    //===================================================

    unawaited(
      activityRef
          .set(
        <String, dynamic>{
          'activityId':
          activityRef.id,

          'postId':
          postId,

          'commentId':
          commentRef.id,

          'replyId':
          '',

          'isReply':
          false,

          'replyToUsername':
          '',

          'text':
          cleanText,

          'imageUrl':
          imageUrl,

          'createdAt':
          FieldValue.serverTimestamp(),
        },
        SetOptions(
          merge:
          true,
        ),
      )
          .timeout(
        const Duration(
          seconds:
          6,
        ),
      )
          .catchError(
        (
        Object error,
        ) {
          debugPrint(
            'Comment activity error: $error',
          );
        },
      ),
    );

    //===================================================
    // COMMENT NOTIFICATION
    // BEST-EFFORT - NEVER BLOCK SEND BUTTON
    //===================================================

    unawaited(
      _notifyPostOwnerAboutComment(
        postId:
        postId,
        commentId:
        commentRef.id,
        senderUid:
        user.uid,
      ),
    );
  }

  //===================================================
  // LIKE / UNLIKE COMMENT
  //===================================================

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

    final DocumentSnapshot<
        Map<String, dynamic>> likeSnapshot =
    await likeRef.get();

    final WriteBatch batch =
    _firestore.batch();

    if (likeSnapshot.exists) {
      batch.delete(
        likeRef,
      );

      batch.update(
        commentRef,
        <String, dynamic>{
          'likeCount':
          FieldValue.increment(
            -1,
          ),
        },
      );
    } else {
      batch.set(
        likeRef,
        <String, dynamic>{
          'uid':
          uid,
          'createdAt':
          FieldValue.serverTimestamp(),
        },
      );

      batch.update(
        commentRef,
        <String, dynamic>{
          'likeCount':
          FieldValue.increment(
            1,
          ),
        },
      );
    }

    await batch.commit();
  }

  //===================================================
  // CHECK COMMENT LIKE
  //===================================================

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

  //===================================================
  // ADD REPLY
  //
  // REPLY CAN ALSO HAVE A PICTURE.
  //===================================================

  Future<void> addReply({
    required String postId,
    required String commentId,
    required String text,
    String parentReplyId = '',
    String replyToUsername = '',
    String? imagePath,
  }) async {
    final String cleanText =
    text.trim();

    final String cleanImagePath =
        imagePath?.trim() ??
            '';

    if (cleanText.isEmpty &&
        cleanImagePath.isEmpty) {
      return;
    }

    final User? user =
        _auth.currentUser;

    if (user == null) {
      throw Exception(
        'User is not logged in.',
      );
    }

    //===================================================
    // REAL USER PROFILE
    //===================================================

    final Map<String, String> profile =
    await _getCurrentUserProfile();

    final String username =
        profile['username'] ??
            '';

    final String fullName =
        profile['fullName'] ??
            '';

    final String photoUrl =
        profile['photoUrl'] ??
            '';

    //===================================================
    // REFERENCES
    //===================================================

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
    final DocumentReference<
        Map<String, dynamic>>
    postRef =
    _firestore
        .collection('posts')
        .doc(postId);

    //===================================================
    // IMAGE
    //===================================================

    String imageUrl =
        '';

    String imageStoragePath =
        '';

    if (cleanImagePath.isNotEmpty) {
      final _UploadedCommentImage uploaded =
      await _uploadReplyImage(
        filePath:
        cleanImagePath,

        postId:
        postId,

        commentId:
        commentId,

        replyId:
        replyRef.id,
      );

      imageUrl =
          uploaded.url;

      imageStoragePath =
          uploaded.storagePath;
    }

    //===================================================
    // PROFILE ACTIVITY
    //===================================================

    final DocumentReference<
        Map<String, dynamic>> activityRef =
    _firestore
        .collection('users')
        .doc(user.uid)
        .collection(
      'commentActivity',
    )
        .doc(
      'reply_${replyRef.id}',
    );

    //===================================================
    // CORE REPLY BATCH
    //===================================================

    final WriteBatch coreBatch =
    _firestore.batch();

    coreBatch.set(
      replyRef,
      <String, dynamic>{
        'replyId':
        replyRef.id,

        'commentId':
        commentId,

        'postId':
        postId,

        'uid':
        user.uid,

        'username':
        username,

        'fullName':
        fullName,

        'photoUrl':
        photoUrl,

        'text':
        cleanText,

        'imageUrl':
        imageUrl,

        'imageStoragePath':
        imageStoragePath,

        'hasImage':
        imageUrl.isNotEmpty,

        'likeCount':
        0,

        'replyCount':
        0,

        'parentReplyId':
        parentReplyId.trim(),

        'replyToUsername':
        replyToUsername.trim(),

        'createdAt':
        FieldValue.serverTimestamp(),
      },
    );

    //===================================================
// DIRECT PARENT REPLY COUNT
//===================================================

    if (parentReplyId
        .trim()
        .isEmpty) {
      // Reply belongs directly to main comment.
      coreBatch.update(
        commentRef,

        <String, dynamic>{
          'replyCount':
          FieldValue.increment(
            1,
          ),
        },
      );
    } else {
      // Reply belongs directly to another reply.
      coreBatch.update(
        commentRef
            .collection('replies')
            .doc(
          parentReplyId.trim(),
        ),

        <String, dynamic>{
          'replyCount':
          FieldValue.increment(
            1,
          ),
        },
      );
    }

//===================================================
// POST TOTAL COMMENTS = COMMENTS + ALL REPLIES
//===================================================

    coreBatch.update(
      postRef,

      <String, dynamic>{
        'commentCount':
        FieldValue.increment(
          1,
        ),
      },
    );
    try {
      await coreBatch.commit()
          .timeout(
        const Duration(
          seconds:
          10,
        ),
      );
    } on TimeoutException catch (error) {
      debugPrint(
        'Reply sync timeout: $error',
      );

      return;
    } catch (error) {
      if (imageStoragePath.isNotEmpty) {
        await _deleteStoragePath(
          imageStoragePath,
        );
      }

      rethrow;
    }

    //===================================================
    // PROFILE REPLY ACTIVITY
    // BEST-EFFORT - NEVER BLOCK SEND BUTTON
    //===================================================

    unawaited(
      activityRef
          .set(
        <String, dynamic>{
          'activityId':
          activityRef.id,

          'postId':
          postId,

          'commentId':
          commentId,

          'replyId':
          replyRef.id,

          'isReply':
          true,

          'replyToUsername':
          replyToUsername.trim(),

          'text':
          cleanText,

          'imageUrl':
          imageUrl,

          'createdAt':
          FieldValue.serverTimestamp(),
        },
        SetOptions(
          merge:
          true,
        ),
      )
          .timeout(
        const Duration(
          seconds:
          6,
        ),
      )
          .catchError(
        (
        Object error,
        ) {
          debugPrint(
            'Reply activity error: $error',
          );
        },
      ),
    );

    //===================================================
    // REPLY NOTIFICATION
    //===================================================

    unawaited(
      _notifyCommentOwnerAboutReply(
        postId:
        postId,
        commentId:
        commentId,
        replyId:
        replyRef.id,
        senderUid:
        user.uid,
      ),
    );
  }

  //===================================================
  // LIKE / UNLIKE REPLY
  //===================================================

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

    final DocumentSnapshot<
        Map<String, dynamic>> likeSnapshot =
    await likeRef.get();

    final WriteBatch batch =
    _firestore.batch();

    if (likeSnapshot.exists) {
      batch.delete(
        likeRef,
      );

      batch.update(
        replyRef,
        <String, dynamic>{
          'likeCount':
          FieldValue.increment(
            -1,
          ),
        },
      );
    } else {
      batch.set(
        likeRef,
        <String, dynamic>{
          'uid':
          uid,
          'createdAt':
          FieldValue.serverTimestamp(),
        },
      );

      batch.update(
        replyRef,
        <String, dynamic>{
          'likeCount':
          FieldValue.increment(
            1,
          ),
        },
      );
    }

    await batch.commit();
  }

  //===================================================
  // CHECK REPLY LIKE
  //===================================================

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

  //===================================================
  // UPDATE COMMENT ACTIVITY
  //
  // Called when owner edits a comment.
  //===================================================

  Future<void> updateCommentActivity({
    required String uid,
    required String commentId,
    required String text,
    String? imageUrl,
  }) async {
    final Map<String, dynamic> update =
    <String, dynamic>{
      'text':
      text.trim(),

      'edited':
      true,

      'editedAt':
      FieldValue.serverTimestamp(),
    };

    if (imageUrl !=
        null) {
      update['imageUrl'] =
          imageUrl;
    }

    await _firestore
        .collection('users')
        .doc(uid)
        .collection(
      'commentActivity',
    )
        .doc(
      'comment_$commentId',
    )
        .set(
      update,
      SetOptions(
        merge: true,
      ),
    );
  }

  //===================================================
  // UPDATE REPLY ACTIVITY
  //===================================================

  Future<void> updateReplyActivity({
    required String uid,
    required String replyId,
    required String text,
    String? imageUrl,
  }) async {
    final Map<String, dynamic> update =
    <String, dynamic>{
      'text':
      text.trim(),

      'edited':
      true,

      'editedAt':
      FieldValue.serverTimestamp(),
    };

    if (imageUrl !=
        null) {
      update['imageUrl'] =
          imageUrl;
    }

    await _firestore
        .collection('users')
        .doc(uid)
        .collection(
      'commentActivity',
    )
        .doc(
      'reply_$replyId',
    )
        .set(
      update,
      SetOptions(
        merge: true,
      ),
    );
  }

  //===================================================
  // REMOVE COMMENT ACTIVITY
  //===================================================

  Future<void> removeCommentActivity({
    required String uid,
    required String commentId,
  }) async {
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection(
        'commentActivity',
      )
          .doc(
        'comment_$commentId',
      )
          .delete();
    } catch (_) {}
  }

  //===================================================
  // REMOVE REPLY ACTIVITY
  //===================================================

  Future<void> removeReplyActivity({
    required String uid,
    required String replyId,
  }) async {
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection(
        'commentActivity',
      )
          .doc(
        'reply_$replyId',
      )
          .delete();
    } catch (_) {}
  }

  //===================================================
  // REPAIR OLD COMMENT PROFILE DETAILS
  //
  // Old comments could have blank fullName/username
  // because they used FirebaseAuth.displayName.
  //===================================================

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

      for (
      final QueryDocumentSnapshot<
          Map<String, dynamic>> commentDoc
      in commentsSnapshot.docs
      ) {
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

        //===================================================
        // REPAIR REPLIES UNDER THIS COMMENT
        //===================================================

        final QuerySnapshot<
            Map<String, dynamic>> repliesSnapshot =
        await commentDoc.reference
            .collection('replies')
            .get();

        for (
        final QueryDocumentSnapshot<
            Map<String, dynamic>> replyDoc
        in repliesSnapshot.docs
        ) {
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
    } catch (_) {
      //===================================================
      // OLD BROKEN COMMENT SHOULD NEVER CRASH SCREEN
      //===================================================
    }
  }

  //===================================================
  // DELETE COMMENT
  //
  // ALSO REMOVES:
  // - uploaded comment picture
  // - uploaded reply pictures
  // - reply activity history
  // - comment activity history
  //===================================================

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

    if (!snapshot.exists ||
        snapshot.data() == null) {
      return;
    }

    final Map<String, dynamic> data =
    snapshot.data()!;

    if ((data['uid'] ?? '')
        .toString() !=
        uid) {
      throw Exception(
        'You can only delete your own comment.',
      );
    }

    //===================================================
    // DELETE REPLIES
    //===================================================

    int deletedReplyCount = 0;

    try {
      final QuerySnapshot<
          Map<String, dynamic>> replies =
      await commentRef
          .collection('replies')
          .get();

      for (
      final QueryDocumentSnapshot<
          Map<String, dynamic>> reply
      in replies.docs
      ) {
        final Map<String, dynamic> replyData =
        reply.data();

        //===================================================
        // REPLY PICTURE
        //===================================================

        final String replyStoragePath =
        (replyData['imageStoragePath'] ?? '')
            .toString()
            .trim();

        if (replyStoragePath.isNotEmpty) {
          await _deleteStoragePath(
            replyStoragePath,
          );
        }

        //===================================================
        // REPLY PROFILE ACTIVITY
        //===================================================

        final String replyOwnerUid =
        (replyData['uid'] ?? '')
            .toString()
            .trim();

        if (replyOwnerUid.isNotEmpty) {
          await removeReplyActivity(
            uid:
            replyOwnerUid,

            replyId:
            reply.id,
          );
        }

        await reply.reference.delete();

        deletedReplyCount++;
      }
    } catch (_) {}

    //===================================================
    // COMMENT PICTURE
    //===================================================

    final String imageStoragePath =
    (data['imageStoragePath'] ?? '')
        .toString()
        .trim();

    if (imageStoragePath.isNotEmpty) {
      await _deleteStoragePath(
        imageStoragePath,
      );
    }

    //===================================================
    // COMMENT DOCUMENT
    //===================================================

    await commentRef.delete();

    //===================================================
    // COMMENT PROFILE ACTIVITY
    //===================================================

    await removeCommentActivity(
      uid:
      uid,

      commentId:
      commentId,
    );

    //===================================================
    // POST COMMENT COUNT
    //===================================================

    final DocumentReference<
        Map<String, dynamic>> postRef =
    _firestore
        .collection('posts')
        .doc(postId);

    try {
      await _firestore.runTransaction(
            (
            Transaction transaction,
            ) async {
          final DocumentSnapshot<
              Map<String, dynamic>> postSnapshot =
          await transaction.get(
            postRef,
          );

          if (!postSnapshot.exists) {
            return;
          }

          final int currentCount =
          _toInt(
            postSnapshot.data()?['commentCount'],
          );

          final int removedItemCount =
              1 + deletedReplyCount;

          transaction.update(
            postRef,
            <String, dynamic>{
              'commentCount':
              currentCount > removedItemCount
                  ? currentCount - removedItemCount
                  : 0,
            },
          );
        },
      );
    } catch (_) {}
  }

  //===================================================
  // DELETE REPLY
  //===================================================

  Future<void> deleteReply({
    required String postId,
    required String commentId,
    required String replyId,
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
        Map<String, dynamic>> replyRef =
    commentRef
        .collection('replies')
        .doc(replyId);

    final DocumentSnapshot<
        Map<String, dynamic>> snapshot =
    await replyRef.get();

    if (!snapshot.exists ||
        snapshot.data() == null) {
      return;
    }

    final Map<String, dynamic> data =
    snapshot.data()!;

    if ((data['uid'] ?? '')
        .toString() !=
        uid) {
      throw Exception(
        'You can only delete your own reply.',
      );
    }

    //===================================================
    // REPLY PICTURE
    //===================================================

    final String storagePath =
    (data['imageStoragePath'] ?? '')
        .toString()
        .trim();

    if (storagePath.isNotEmpty) {
      await _deleteStoragePath(
        storagePath,
      );
    }

    //===================================================
    // DELETE REPLY
    //===================================================

    await replyRef.delete();

    //===================================================
    // PROFILE ACTIVITY
    //===================================================

    await removeReplyActivity(
      uid:
      uid,

      replyId:
      replyId,
    );

    //===================================================
    // SAFE REPLY COUNT + POST TOTAL
    //===================================================

    try {
      final String parentReplyId =
          (data['parentReplyId'] ?? '').toString().trim();

      final DocumentReference<Map<String, dynamic>> countRef =
          parentReplyId.isEmpty
              ? commentRef
              : commentRef.collection('replies').doc(parentReplyId);

      final DocumentReference<Map<String, dynamic>> postRef =
          _firestore.collection('posts').doc(postId);

      await _firestore.runTransaction(
            (
            Transaction transaction,
            ) async {
          final DocumentSnapshot<Map<String, dynamic>> countSnapshot =
          await transaction.get(
            countRef,
          );

          final DocumentSnapshot<Map<String, dynamic>> postSnapshot =
          await transaction.get(
            postRef,
          );

          if (countSnapshot.exists) {
            final int currentReplyCount =
            _toInt(
              countSnapshot.data()?['replyCount'],
            );

            transaction.update(
              countRef,
              <String, dynamic>{
                'replyCount':
                currentReplyCount > 0
                    ? currentReplyCount - 1
                    : 0,
              },
            );
          }

          if (postSnapshot.exists) {
            final int currentPostCommentCount =
            _toInt(
              postSnapshot.data()?['commentCount'],
            );

            transaction.update(
              postRef,
              <String, dynamic>{
                'commentCount':
                currentPostCommentCount > 0
                    ? currentPostCommentCount - 1
                    : 0,
              },
            );
          }
        },
      );
    } catch (_) {}
  }

  //===================================================
  // NOTIFY POST OWNER ABOUT COMMENT
  //===================================================

  Future<void> _notifyPostOwnerAboutComment({
    required String postId,
    required String commentId,
    required String senderUid,
  }) async {
    try {
      final DocumentSnapshot<
          Map<String, dynamic>> snapshot =
      await _firestore
          .collection('posts')
          .doc(postId)
          .get()
          .timeout(
        const Duration(
          seconds:
          6,
        ),
      );

      final String ownerUid =
      (snapshot.data()?['uid'] ?? '')
          .toString()
          .trim();

      if (ownerUid.isEmpty ||
          ownerUid == senderUid) {
        return;
      }

      await _notificationService
          .notifyComment(
        postOwnerId:
        ownerUid,
        postId:
        postId,
        commentId:
        commentId,
      )
          .timeout(
        const Duration(
          seconds:
          6,
        ),
      );
    } catch (error) {
      debugPrint(
        'Comment notification error: $error',
      );
    }
  }

  //===================================================
  // NOTIFY COMMENT OWNER ABOUT REPLY
  //===================================================

  Future<void> _notifyCommentOwnerAboutReply({
    required String postId,
    required String commentId,
    required String replyId,
    required String senderUid,
  }) async {
    try {
      final DocumentSnapshot<
          Map<String, dynamic>> snapshot =
      await _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .doc(commentId)
          .get()
          .timeout(
        const Duration(
          seconds:
          6,
        ),
      );

      final String ownerUid =
      (snapshot.data()?['uid'] ?? '')
          .toString()
          .trim();

      if (ownerUid.isEmpty ||
          ownerUid == senderUid) {
        return;
      }

      await _notificationService
          .notifyReply(
        receiverId:
        ownerUid,
        postId:
        postId,
        commentId:
        commentId,
        replyId:
        replyId,
      )
          .timeout(
        const Duration(
          seconds:
          6,
        ),
      );
    } catch (error) {
      debugPrint(
        'Reply notification error: $error',
      );
    }
  }

  //===================================================
  // UPLOAD COMMENT IMAGE
  //===================================================

  Future<_UploadedCommentImage> _uploadCommentImage({
    required String filePath,
    required String postId,
    required String commentId,
  }) async {
    final String uid =
        _uid;

    final File file =
    File(
      filePath,
    );

    if (!await file.exists()) {
      throw Exception(
        'Selected picture could not be found.',
      );
    }

    final int bytes =
    await file.length();

    //===================================================
    // 15 MB LIMIT
    //===================================================

    if (bytes >
        15 * 1024 * 1024) {
      throw Exception(
        'Comment picture must be 15 MB or smaller.',
      );
    }

    final String extension =
    _fileExtension(
      filePath,
    );

    final String storagePath =
        'comments/$postId/$commentId/'
        '${uid}_${DateTime.now().millisecondsSinceEpoch}.$extension';

    final Reference ref =
    _storage.ref(
      storagePath,
    );

    await ref.putFile(
      file,
      SettableMetadata(
        contentType:
        _contentTypeForExtension(
          extension,
        ),
      ),
    );

    final String url =
    await ref.getDownloadURL();

    return _UploadedCommentImage(
      url:
      url,

      storagePath:
      storagePath,
    );
  }

  //===================================================
  // UPLOAD REPLY IMAGE
  //===================================================

  Future<_UploadedCommentImage> _uploadReplyImage({
    required String filePath,
    required String postId,
    required String commentId,
    required String replyId,
  }) async {
    final String uid =
        _uid;

    final File file =
    File(
      filePath,
    );

    if (!await file.exists()) {
      throw Exception(
        'Selected picture could not be found.',
      );
    }

    final int bytes =
    await file.length();

    if (bytes >
        15 * 1024 * 1024) {
      throw Exception(
        'Reply picture must be 15 MB or smaller.',
      );
    }

    final String extension =
    _fileExtension(
      filePath,
    );

    final String storagePath =
        'comments/$postId/$commentId/replies/$replyId/'
        '${uid}_${DateTime.now().millisecondsSinceEpoch}.$extension';

    final Reference ref =
    _storage.ref(
      storagePath,
    );

    await ref.putFile(
      file,
      SettableMetadata(
        contentType:
        _contentTypeForExtension(
          extension,
        ),
      ),
    );

    final String url =
    await ref.getDownloadURL();

    return _UploadedCommentImage(
      url:
      url,

      storagePath:
      storagePath,
    );
  }

  //===================================================
  // DELETE STORAGE PATH
  //===================================================

  Future<void> _deleteStoragePath(
      String storagePath,
      ) async {
    final String cleanPath =
    storagePath.trim();

    if (cleanPath.isEmpty) {
      return;
    }

    try {
      await _storage
          .ref(
        cleanPath,
      )
          .delete();
    } catch (_) {}
  }

  //===================================================
  // FILE EXTENSION
  //===================================================

  String _fileExtension(
      String filePath,
      ) {
    final String normalized =
        filePath
            .split('?')
            .first;

    final int dotIndex =
    normalized.lastIndexOf(
      '.',
    );

    if (dotIndex < 0 ||
        dotIndex ==
            normalized.length - 1) {
      return 'jpg';
    }

    final String extension =
    normalized
        .substring(
      dotIndex + 1,
    )
        .toLowerCase();

    switch (extension) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'webp':
      case 'gif':
        return extension;

      default:
        return 'jpg';
    }
  }

  //===================================================
  // CONTENT TYPE
  //===================================================

  String _contentTypeForExtension(
      String extension,
      ) {
    switch (extension.toLowerCase()) {
      case 'png':
        return 'image/png';

      case 'webp':
        return 'image/webp';

      case 'gif':
        return 'image/gif';

      case 'jpeg':
      case 'jpg':
      default:
        return 'image/jpeg';
    }
  }

  //===================================================
  // INT HELPER
  //===================================================

  int _toInt(
      dynamic value,
      ) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
      value?.toString() ??
          '',
    ) ??
        0;
  }
}

//===================================================
// UPLOADED COMMENT IMAGE
//===================================================

class _UploadedCommentImage {
  final String url;

  final String storagePath;

  const _UploadedCommentImage({
    required this.url,
    required this.storagePath,
  });
}
