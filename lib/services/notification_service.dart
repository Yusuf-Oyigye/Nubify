import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  final FirebaseFirestore
  _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  //===========================================================
  // CREATE NOTIFICATION
  //===========================================================

  Future<void>
  createNotification({
    required String receiverId,
    required String type,
    required String message,
    String? postId,
    String? commentId,
    String? storyId,
  }) async {
    final User? user =
        _auth.currentUser;

    if (user == null) {
      return;
    }

    if (receiverId ==
        user.uid) {
      return;
    }

    await _firestore
        .collection(
      'notifications',
    )
        .add({
      'receiverId':
      receiverId,

      'senderId':
      user.uid,

      'type':
      type,

      'message':
      message,

      'postId':
      postId,

      'commentId':
      commentId,

      'storyId':
      storyId,

      'isRead':
      false,

      'createdAt':
      FieldValue
          .serverTimestamp(),
    });
  }

  //===========================================================
  // LIKE
  //===========================================================

  Future<void> notifyLike({
    required String postOwnerId,
    required String postId,
  }) async {
    await createNotification(
      receiverId:
      postOwnerId,

      type:
      'like',

      message:
      'liked your post',

      postId:
      postId,
    );
  }

  //===========================================================
  // COMMENT
  //===========================================================

  Future<void>
  notifyComment({
    required String postOwnerId,
    required String postId,
    required String commentId,
  }) async {
    await createNotification(
      receiverId:
      postOwnerId,

      type:
      'comment',

      message:
      'commented on your post',

      postId:
      postId,

      commentId:
      commentId,
    );
  }

  //===========================================================
  // REPLY
  //===========================================================

  Future<void> notifyReply({
    required String receiverId,
    required String postId,
    required String commentId,
  }) async {
    await createNotification(
      receiverId:
      receiverId,

      type:
      'reply',

      message:
      'replied to your comment',

      postId:
      postId,

      commentId:
      commentId,
    );
  }

  //===========================================================
  // REPOST
  //===========================================================

  Future<void> notifyRepost({
    required String postOwnerId,
    required String postId,
  }) async {
    await createNotification(
      receiverId:
      postOwnerId,

      type:
      'repost',

      message:
      'reposted your post',

      postId:
      postId,
    );
  }

  //===========================================================
  // QUOTE REPOST
  //===========================================================

  Future<void>
  notifyQuoteRepost({
    required String postOwnerId,
    required String postId,
  }) async {
    await createNotification(
      receiverId:
      postOwnerId,

      type:
      'quoteRepost',

      message:
      'quoted your post',

      postId:
      postId,
    );
  }

  //===========================================================
  // TAG IN POST
  //===========================================================

  Future<void> notifyTag({
    required String taggedUserId,
    required String postId,
  }) async {
    await createNotification(
      receiverId:
      taggedUserId,

      type:
      'tag',

      message:
      'tagged you in a post',

      postId:
      postId,
    );
  }

  //===========================================================
  // FOLLOW
  //===========================================================

  Future<void> notifyFollow({
    required String receiverId,
  }) async {
    await createNotification(
      receiverId:
      receiverId,

      type:
      'follow',

      message:
      'started following you',
    );
  }

  //===========================================================
  // STORY TAG
  //===========================================================

  Future<void>
  notifyStoryTag({
    required String taggedUserId,
    required String storyId,
  }) async {
    await createNotification(
      receiverId:
      taggedUserId,

      type:
      'storyTag',

      message:
      'tagged you in a story',

      storyId:
      storyId,
    );
  }

  //===========================================================
  // STORY LIKE
  //===========================================================

  Future<void>
  notifyStoryLike({
    required String storyOwnerId,
    required String storyId,
  }) async {
    await createNotification(
      receiverId:
      storyOwnerId,

      type:
      'storyLike',

      message:
      'liked your story',

      storyId:
      storyId,
    );
  }

  //===========================================================
  // STORY REPLY
  //===========================================================

  Future<void>
  notifyStoryReply({
    required String storyOwnerId,
    required String storyId,
  }) async {
    await createNotification(
      receiverId:
      storyOwnerId,

      type:
      'storyReply',

      message:
      'replied to your story',

      storyId:
      storyId,
    );
  }

  //===========================================================
  // GET NOTIFICATIONS
  //===========================================================

  Stream<QuerySnapshot>
  getNotifications() {
    final String? uid =
        _auth
            .currentUser
            ?.uid;

    if (uid == null) {
      return const Stream
          .empty();
    }

    return _firestore
        .collection(
      'notifications',
    )
        .where(
      'receiverId',
      isEqualTo:
      uid,
    )
        .orderBy(
      'createdAt',
      descending:
      true,
    )
        .snapshots();
  }

  //===========================================================
  // UNREAD NOTIFICATIONS
  //===========================================================

  Stream<QuerySnapshot>
  getUnreadNotifications() {
    final String? uid =
        _auth
            .currentUser
            ?.uid;

    if (uid == null) {
      return const Stream
          .empty();
    }

    return _firestore
        .collection(
      'notifications',
    )
        .where(
      'receiverId',
      isEqualTo:
      uid,
    )
        .where(
      'isRead',
      isEqualTo:
      false,
    )
        .snapshots();
  }

  //===========================================================
  // MARK AS READ
  //===========================================================

  Future<void> markAsRead(
      String notificationId,
      ) async {
    await _firestore
        .collection(
      'notifications',
    )
        .doc(
      notificationId,
    )
        .update({
      'isRead':
      true,
    });
  }

  //===========================================================
  // MARK ALL AS READ
  //===========================================================

  Future<void>
  markAllAsRead() async {
    final String? uid =
        _auth
            .currentUser
            ?.uid;

    if (uid == null) {
      return;
    }

    final QuerySnapshot
    snapshot =
    await _firestore
        .collection(
      'notifications',
    )
        .where(
      'receiverId',
      isEqualTo:
      uid,
    )
        .where(
      'isRead',
      isEqualTo:
      false,
    )
        .get();

    final WriteBatch batch =
    _firestore.batch();

    for (final QueryDocumentSnapshot
    doc
    in snapshot.docs) {
      batch.update(
        doc.reference,
        {
          'isRead':
          true,
        },
      );
    }

    await batch.commit();
  }
}