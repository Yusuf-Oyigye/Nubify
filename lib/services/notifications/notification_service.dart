import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

//===================================================
// NOTIFICATION SERVICE
//===================================================

class NotificationService {
  //===================================================
  // FIREBASE
  //===================================================

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  //===================================================
  // NOTIFICATIONS COLLECTION
  //===================================================

  CollectionReference<Map<String, dynamic>>
  get _notifications =>
      _firestore.collection(
        'notifications',
      );

  //===================================================
  // CREATE NOTIFICATION
  //
  // MAIN NUBIFY FORMAT:
  //
  // receiverId
  // senderId
  // type
  // message
  // postId
  // repostPostId
  // commentId
  // replyId
  // storyId
  // isRead
  // createdAt
  //===================================================

  Future<void> createNotification({
    required String receiverId,
    required String type,
    required String message,
    String? postId,
    String? repostPostId,
    String? commentId,
    String? replyId,
    String? storyId,
  }) async {
    final User? user =
        _auth.currentUser;

    if (user == null) {
      return;
    }

    final String cleanReceiverId =
    receiverId.trim();

    if (cleanReceiverId.isEmpty) {
      return;
    }

    //===================================================
    // DON'T NOTIFY YOURSELF
    //===================================================

    if (cleanReceiverId ==
        user.uid) {
      return;
    }

    final DocumentReference<
        Map<String, dynamic>>
    notificationRef =
    _notifications.doc();

    await notificationRef.set(
      <String, dynamic>{
        'notificationId':
        notificationRef.id,

        'receiverId':
        cleanReceiverId,

        'senderId':
        user.uid,

        'type':
        type.trim(),

        'message':
        message.trim(),

        'postId':
        _nullableString(
          postId,
        ),

        'repostPostId':
        _nullableString(
          repostPostId,
        ),

        'commentId':
        _nullableString(
          commentId,
        ),

        'replyId':
        _nullableString(
          replyId,
        ),

        'storyId':
        _nullableString(
          storyId,
        ),

        'isRead':
        false,

        'createdAt':
        FieldValue
            .serverTimestamp(),
      },
    );
  }

  //===================================================
  // LIKE
  //===================================================

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

  //===================================================
  // COMMENT
  //===================================================

  Future<void> notifyComment({
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

  //===================================================
  // REPLY
  //===================================================

  Future<void> notifyReply({
    required String receiverId,
    required String postId,
    required String commentId,
    String? replyId,
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

      replyId:
      replyId,
    );
  }

  //===================================================
  // REPOST
  //
  // postId = ROOT ORIGINAL
  //
  // repostPostId = ACTUAL REPOST WRAPPER
  //===================================================

  Future<void> notifyRepost({
    required String postOwnerId,
    required String postId,
    String? repostPostId,
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

      repostPostId:
      repostPostId,
    );
  }

  //===================================================
  // QUOTE REPOST
  //===================================================

  Future<void> notifyQuoteRepost({
    required String postOwnerId,
    required String postId,
    String? repostPostId,
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

      repostPostId:
      repostPostId,
    );
  }

  //===================================================
  // TAG IN POST
  //===================================================

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

  //===================================================
  // FOLLOW
  //===================================================

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

  //===================================================
  // STORY TAG
  //===================================================

  Future<void> notifyStoryTag({
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

  //===================================================
  // STORY LIKE
  //===================================================

  Future<void> notifyStoryLike({
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

  //===================================================
  // STORY REPLY
  //===================================================

  Future<void> notifyStoryReply({
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

  //===================================================
  // STORY RESHARE
  //===================================================

  Future<void> notifyStoryReshare({
    required String storyOwnerId,
    required String storyId,
  }) async {
    await createNotification(
      receiverId:
      storyOwnerId,

      type:
      'storyReshare',

      message:
      'shared your story',

      storyId:
      storyId,
    );
  }

  //===================================================
  // GET ALL NOTIFICATIONS
  //
  // NO orderBy HERE.
  //
  // NotificationsScreen sorts client-side.
  // This avoids requiring an extra Firestore index just
  // for receiverId + createdAt.
  //===================================================

  Stream<QuerySnapshot<Map<String, dynamic>>>
  getNotifications() {
    final String? uid =
        _auth.currentUser
            ?.uid;

    if (uid == null ||
        uid.trim().isEmpty) {
      return const Stream<
          QuerySnapshot<
              Map<String, dynamic>>>.empty();
    }

    return _notifications
        .where(
      'receiverId',
      isEqualTo:
      uid,
    )
        .snapshots();
  }

  //===================================================
  // GET UNREAD NOTIFICATIONS
  //===================================================

  Stream<QuerySnapshot<Map<String, dynamic>>>
  getUnreadNotifications() {
    final String? uid =
        _auth.currentUser
            ?.uid;

    if (uid == null ||
        uid.trim().isEmpty) {
      return const Stream<
          QuerySnapshot<
              Map<String, dynamic>>>.empty();
    }

    return _notifications
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

  //===================================================
  // UNREAD COUNT
  //===================================================

  Stream<int> unreadCountStream() {
    return getNotifications()
        .map(
          (
          QuerySnapshot<
              Map<String, dynamic>>
          snapshot,
          ) {
        int count =
        0;

        for (
        final QueryDocumentSnapshot<
            Map<String, dynamic>>
        document
        in snapshot.docs
        ) {
          if (document.data()[
          'isRead'] !=
              true) {
            count++;
          }
        }

        return count;
      },
    );
  }

  //===================================================
  // MARK ONE AS READ
  //===================================================

  Future<void> markAsRead(
      String notificationId,
      ) async {
    final User? user =
        _auth.currentUser;

    if (user == null) {
      return;
    }

    final String cleanId =
    notificationId.trim();

    if (cleanId.isEmpty) {
      return;
    }

    final DocumentReference<
        Map<String, dynamic>>
    reference =
    _notifications.doc(
      cleanId,
    );

    final DocumentSnapshot<
        Map<String, dynamic>>
    snapshot =
    await reference.get();

    if (!snapshot.exists ||
        snapshot.data() ==
            null) {
      return;
    }

    if ((snapshot.data()![
    'receiverId'] ??
        '')
        .toString() !=
        user.uid) {
      return;
    }

    if (snapshot.data()![
    'isRead'] ==
        true) {
      return;
    }

    await reference.update(
      <String, dynamic>{
        'isRead':
        true,

        'readAt':
        FieldValue
            .serverTimestamp(),
      },
    );
  }

  //===================================================
  // MARK ALL AS READ
  //===================================================

  Future<void> markAllAsRead() async {
    final User? user =
        _auth.currentUser;

    if (user == null) {
      return;
    }

    final QuerySnapshot<
        Map<String, dynamic>>
    snapshot =
    await _notifications
        .where(
      'receiverId',
      isEqualTo:
      user.uid,
    )
        .get();

    final List<
        QueryDocumentSnapshot<
            Map<String, dynamic>>>
    unread =
    snapshot.docs
        .where(
          (
          QueryDocumentSnapshot<
              Map<String, dynamic>>
          document,
          ) =>
      document.data()[
      'isRead'] !=
          true,
    )
        .toList();

    if (unread.isEmpty) {
      return;
    }

    //===================================================
    // BATCH SAFETY
    //===================================================

    const int batchSize =
    400;

    for (
    int start = 0;
    start < unread.length;
    start += batchSize
    ) {
      final int end =
      start + batchSize >
          unread.length
          ? unread.length
          : start +
          batchSize;

      final WriteBatch batch =
      _firestore.batch();

      for (
      int index = start;
      index < end;
      index++
      ) {
        batch.update(
          unread[index].reference,
          <String, dynamic>{
            'isRead':
            true,

            'readAt':
            FieldValue
                .serverTimestamp(),
          },
        );
      }

      await batch.commit();
    }
  }

  //===================================================
  // DELETE ONE NOTIFICATION
  //===================================================

  Future<void> deleteNotification(
      String notificationId,
      ) async {
    final User? user =
        _auth.currentUser;

    if (user == null) {
      return;
    }

    final String cleanId =
    notificationId.trim();

    if (cleanId.isEmpty) {
      return;
    }

    final DocumentReference<
        Map<String, dynamic>>
    reference =
    _notifications.doc(
      cleanId,
    );

    final DocumentSnapshot<
        Map<String, dynamic>>
    snapshot =
    await reference.get();

    if (!snapshot.exists ||
        snapshot.data() ==
            null) {
      return;
    }

    if ((snapshot.data()![
    'receiverId'] ??
        '')
        .toString() !=
        user.uid) {
      return;
    }

    await reference.delete();
  }

  //===================================================
  // DELETE ALL MY NOTIFICATIONS
  //===================================================

  Future<void> deleteAllNotifications() async {
    final User? user =
        _auth.currentUser;

    if (user == null) {
      return;
    }

    final QuerySnapshot<
        Map<String, dynamic>>
    snapshot =
    await _notifications
        .where(
      'receiverId',
      isEqualTo:
      user.uid,
    )
        .get();

    if (snapshot.docs.isEmpty) {
      return;
    }

    const int batchSize =
    400;

    for (
    int start = 0;
    start < snapshot.docs.length;
    start += batchSize
    ) {
      final int end =
      start + batchSize >
          snapshot.docs.length
          ? snapshot.docs.length
          : start +
          batchSize;

      final WriteBatch batch =
      _firestore.batch();

      for (
      int index = start;
      index < end;
      index++
      ) {
        batch.delete(
          snapshot.docs[index]
              .reference,
        );
      }

      await batch.commit();
    }
  }

  //===================================================
  // NULLABLE STRING
  //===================================================

  String? _nullableString(
      String? value,
      ) {
    final String clean =
        value?.trim() ??
            '';

    return clean.isEmpty
        ? null
        : clean;
  }
}