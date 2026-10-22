import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/post.dart';

//===================================================
// PROFILE COMMENT ACTIVITY
//===================================================

class ProfileCommentActivity {
  final String activityId;
  final String postId;
  final String commentId;
  final String replyId;
  final bool isReply;
  final String replyToUsername;
  final String text;
  final String imageUrl;
  final DateTime? createdAt;

  const ProfileCommentActivity({
    required this.activityId,
    required this.postId,
    required this.commentId,
    required this.replyId,
    required this.isReply,
    this.replyToUsername = '',
    required this.text,
    required this.imageUrl,
    required this.createdAt,
  });

  //===================================================
  // FROM FIRESTORE
  //===================================================

  factory ProfileCommentActivity.fromDocument(
      QueryDocumentSnapshot<
          Map<String, dynamic>>
      document,
      ) {
    final Map<String, dynamic> data =
    document.data();

    return ProfileCommentActivity(
      activityId:
      document.id,

      postId:
      (data['postId'] ?? '')
          .toString()
          .trim(),

      commentId:
      (data['commentId'] ?? '')
          .toString()
          .trim(),

      replyId:
      (data['replyId'] ?? '')
          .toString()
          .trim(),

      isReply:
      data['isReply'] ==
          true,

      replyToUsername:
      (data['replyToUsername'] ?? '')
          .toString()
          .trim(),

      text:
      (data['text'] ?? '')
          .toString(),

      imageUrl:
      (data['imageUrl'] ??
          data['mediaUrl'] ??
          '')
          .toString()
          .trim(),

      createdAt:
      _dateValue(
        data['createdAt'],
      ),
    );
  }
}

//===================================================
// PROFILE ACTIVITY SERVICE
//===================================================

class ProfileActivityService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  //===================================================
  // COMMENTS / REPLIES
  //
  // IMPORTANT:
  //
  // THIS IS A FIRESTORE STREAM + map().
  //
  // IT IS NOT AN async* GENERATOR.
  //
  // EACH CALL CREATES ITS OWN STREAM AND WE DO NOT
  // REUSE ONE SINGLE-SUBSCRIPTION STREAM IN MULTIPLE
  // StreamBuilders.
  //===================================================

  Stream<List<ProfileCommentActivity>>
  commentsStream(
      String uid,
      ) {
    return _firestore
        .collection(
      'users',
    )
        .doc(
      uid,
    )
        .collection(
      'commentActivity',
    )
        .snapshots()
        .map(
          (
          QuerySnapshot<
              Map<String, dynamic>>
          snapshot,
          ) {
        final List<
            ProfileCommentActivity>
        activities =
        snapshot.docs
            .map(
          ProfileCommentActivity
              .fromDocument,
        )
            .toList();

        activities.sort(
              (
              ProfileCommentActivity a,
              ProfileCommentActivity b,
              ) {
            final DateTime aDate =
                a.createdAt ??
                    DateTime
                        .fromMillisecondsSinceEpoch(
                      0,
                    );

            final DateTime bDate =
                b.createdAt ??
                    DateTime
                        .fromMillisecondsSinceEpoch(
                      0,
                    );

            return bDate.compareTo(
              aDate,
            );
          },
        );

        return activities;
      },
    );
  }

  //===================================================
  // LIKED POSTS STREAM
  //
  // users/{uid}/likedPosts/{postId}
  //
  // THIS RETURNS THE REAL POST OBJECTS, SO PROFILE
  // LIKES TAB SHOWS:
  //
  // - author
  // - caption
  // - media
  // - poll
  // - repost
  // - quote repost
  // - actions
  //
  // NOT JUST A LIST OF POST IDS.
  //===================================================

  Stream<List<Post>> likedPostsStream(
      String uid,
      ) {
    return _firestore
        .collection(
      'users',
    )
        .doc(
      uid,
    )
        .collection(
      'likedPosts',
    )
        .snapshots()
        .asyncMap(
          (
          QuerySnapshot<
              Map<String, dynamic>>
          snapshot,
          ) async {
        final List<
            QueryDocumentSnapshot<
                Map<String, dynamic>>>
        references =
        List<
            QueryDocumentSnapshot<
                Map<String, dynamic>>>.from(
          snapshot.docs,
        );

        //===================================================
        // NEWEST LIKE FIRST
        //===================================================

        references.sort(
              (
              QueryDocumentSnapshot<
                  Map<String, dynamic>>
              a,
              QueryDocumentSnapshot<
                  Map<String, dynamic>>
              b,
              ) {
            final DateTime aDate =
                _dateValue(
                  a.data()['likedAt'],
                ) ??
                    DateTime
                        .fromMillisecondsSinceEpoch(
                      0,
                    );

            final DateTime bDate =
                _dateValue(
                  b.data()['likedAt'],
                ) ??
                    DateTime
                        .fromMillisecondsSinceEpoch(
                      0,
                    );

            return bDate.compareTo(
              aDate,
            );
          },
        );

        final List<Post> posts =
        <Post>[];

        for (
        final QueryDocumentSnapshot<
            Map<String, dynamic>>
        reference
        in references
        ) {
          final String postId =
          (reference.data()['postId'] ??
              reference.id)
              .toString()
              .trim();

          if (postId.isEmpty) {
            continue;
          }

          try {
            final DocumentSnapshot<
                Map<String, dynamic>>
            postSnapshot =
            await _firestore
                .collection(
              'posts',
            )
                .doc(
              postId,
            )
                .get();

            if (!postSnapshot.exists ||
                postSnapshot.data() ==
                    null) {
              continue;
            }

            final Post post =
            Post.fromFirestore(
              postSnapshot,
            );

            //===================================================
            // GLOBALLY HIDDEN POSTS DO NOT SHOW IN LIKES TAB
            //===================================================

            if (!post
                .isPubliclyVisible) {
              continue;
            }

            posts.add(
              post,
            );
          } catch (error) {
            debugPrint(
              'Liked post load error $postId: $error',
            );
          }
        }

        return posts;
      },
    );
  }

  //===================================================
  // PREPARE OLD HISTORY
  //
  // NEW LIKES/COMMENTS WILL BE SAVED DIRECTLY BY
  // LikeService + CommentService.
  //
  // THIS BACKFILLS OLDER NUBIFY DATA.
  //===================================================

  Future<void> prepareOwnerHistory(
      String uid,
      ) async {
    final String cleanUid =
    uid.trim();

    if (cleanUid.isEmpty) {
      return;
    }

    await Future.wait(
      <Future<void>>[
        backfillLikes(
          cleanUid,
        ),

        backfillComments(
          cleanUid,
        ),
      ],
    );
  }

  //===================================================
  // BACKFILL LIKES
  //
  // SUPPORT:
  // likes[]
  // likedUserIds[]
  //===================================================

  Future<void> backfillLikes(
      String uid,
      ) async {
    final Set<String> postIds =
    <String>{};

    //===================================================
    // OLD likes[]
    //===================================================

    try {
      final QuerySnapshot<
          Map<String, dynamic>>
      snapshot =
      await _firestore
          .collection(
        'posts',
      )
          .where(
        'likes',
        arrayContains:
        uid,
      )
          .get();

      for (
      final QueryDocumentSnapshot<
          Map<String, dynamic>>
      document
      in snapshot.docs
      ) {
        postIds.add(
          document.id,
        );
      }
    } catch (error) {
      debugPrint(
        'Old likes backfill error: $error',
      );
    }

    //===================================================
    // NEWER likedUserIds[]
    //===================================================

    try {
      final QuerySnapshot<
          Map<String, dynamic>>
      snapshot =
      await _firestore
          .collection(
        'posts',
      )
          .where(
        'likedUserIds',
        arrayContains:
        uid,
      )
          .get();

      for (
      final QueryDocumentSnapshot<
          Map<String, dynamic>>
      document
      in snapshot.docs
      ) {
        postIds.add(
          document.id,
        );
      }
    } catch (error) {
      debugPrint(
        'likedUserIds backfill error: $error',
      );
    }

    if (postIds.isEmpty) {
      return;
    }

    final List<String> ids =
    postIds.toList();

    const int batchSize =
    400;

    for (
    int start = 0;
    start < ids.length;
    start += batchSize
    ) {
      final int end =
      start + batchSize >
          ids.length
          ? ids.length
          : start +
          batchSize;

      final WriteBatch batch =
      _firestore.batch();

      for (
      int index = start;
      index < end;
      index++
      ) {
        final String postId =
        ids[index];

        final DocumentReference<
            Map<String, dynamic>>
        ref =
        _firestore
            .collection(
          'users',
        )
            .doc(
          uid,
        )
            .collection(
          'likedPosts',
        )
            .doc(
          postId,
        );

        batch.set(
          ref,

          <String, dynamic>{
            'postId':
            postId,

            //===================================================
            // DON'T OVERWRITE THE REAL likedAt IF A NEWER
            // LikeService ALREADY CREATED THIS DOCUMENT.
            //===================================================

            'backfilled':
            true,

            'backfilledAt':
            FieldValue
                .serverTimestamp(),
          },

          SetOptions(
            merge:
            true,
          ),
        );
      }

      try {
        await batch.commit();
      } catch (error) {
        debugPrint(
          'Like history batch error: $error',
        );
      }
    }
  }

  //===================================================
  // BACKFILL COMMENTS + REPLIES
  //===================================================

  Future<void> backfillComments(
      String uid,
      ) async {
    final List<
        _CommentBackfillItem>
    items =
    <_CommentBackfillItem>[];

    //===================================================
    // COMMENTS
    //===================================================

    try {
      final QuerySnapshot<
          Map<String, dynamic>>
      comments =
      await _firestore
          .collectionGroup(
        'comments',
      )
          .where(
        'uid',
        isEqualTo:
        uid,
      )
          .get();

      for (
      final QueryDocumentSnapshot<
          Map<String, dynamic>>
      document
      in comments.docs
      ) {
        final String postId =
        _postIdFromPath(
          document.reference.path,
        );

        if (postId.isEmpty) {
          continue;
        }

        final Map<String, dynamic> data =
        document.data();

        items.add(
          _CommentBackfillItem(
            activityId:
            'comment_${document.id}',

            postId:
            postId,

            commentId:
            document.id,

            replyId:
            '',

            isReply:
            false,

            replyToUsername:
            '',

            text:
            (data['text'] ?? '')
                .toString(),

            imageUrl:
            (data['imageUrl'] ??
                data['mediaUrl'] ??
                '')
                .toString(),

            createdAt:
            data['createdAt'],
          ),
        );
      }
    } catch (error) {
      debugPrint(
        'Comments backfill error: $error',
      );
    }

    //===================================================
    // REPLIES
    //===================================================

    try {
      final QuerySnapshot<
          Map<String, dynamic>>
      replies =
      await _firestore
          .collectionGroup(
        'replies',
      )
          .where(
        'uid',
        isEqualTo:
        uid,
      )
          .get();

      for (
      final QueryDocumentSnapshot<
          Map<String, dynamic>>
      document
      in replies.docs
      ) {
        final String postId =
        _postIdFromPath(
          document.reference.path,
        );

        final String commentId =
        _commentIdFromPath(
          document.reference.path,
        );

        if (postId.isEmpty ||
            commentId.isEmpty) {
          continue;
        }

        final Map<String, dynamic> data =
        document.data();

        items.add(
          _CommentBackfillItem(
            activityId:
            'reply_${document.id}',

            postId:
            postId,

            commentId:
            commentId,

            replyId:
            document.id,

            isReply:
            true,

            replyToUsername:
            (data['replyToUsername'] ?? '')
                .toString()
                .trim(),

            text:
            (data['text'] ?? '')
                .toString(),

            imageUrl:
            (data['imageUrl'] ??
                data['mediaUrl'] ??
                '')
                .toString(),

            createdAt:
            data['createdAt'],
          ),
        );
      }
    } catch (error) {
      debugPrint(
        'Replies backfill error: $error',
      );
    }

    if (items.isEmpty) {
      return;
    }

    const int batchSize =
    400;

    for (
    int start = 0;
    start < items.length;
    start += batchSize
    ) {
      final int end =
      start + batchSize >
          items.length
          ? items.length
          : start +
          batchSize;

      final WriteBatch batch =
      _firestore.batch();

      for (
      int index = start;
      index < end;
      index++
      ) {
        final _CommentBackfillItem item =
        items[index];

        final DocumentReference<
            Map<String, dynamic>>
        ref =
        _firestore
            .collection(
          'users',
        )
            .doc(
          uid,
        )
            .collection(
          'commentActivity',
        )
            .doc(
          item.activityId,
        );

        final Map<String, dynamic> data =
        <String, dynamic>{
          'activityId':
          item.activityId,

          'postId':
          item.postId,

          'commentId':
          item.commentId,

          'replyId':
          item.replyId,

          'isReply':
          item.isReply,

          'replyToUsername':
          item.replyToUsername,

          'text':
          item.text,

          'imageUrl':
          item.imageUrl,

          'backfilled':
          true,
        };

        if (item.createdAt !=
            null) {
          data['createdAt'] =
              item.createdAt;
        }

        batch.set(
          ref,
          data,

          SetOptions(
            merge:
            true,
          ),
        );
      }

      try {
        await batch.commit();
      } catch (error) {
        debugPrint(
          'Comment history batch error: $error',
        );
      }
    }
  }

  //===================================================
  // SAVE COMMENT ACTIVITY
  //
  // CommentService will call this for new comments.
  //===================================================

  Future<void> saveCommentActivity({
    required String uid,
    required String postId,
    required String commentId,
    required String text,
    String imageUrl = '',
    dynamic createdAt,
  }) async {
    if (uid.trim().isEmpty ||
        postId.trim().isEmpty ||
        commentId.trim().isEmpty) {
      return;
    }

    final DocumentReference<
        Map<String, dynamic>>
    ref =
    _firestore
        .collection(
      'users',
    )
        .doc(
      uid,
    )
        .collection(
      'commentActivity',
    )
        .doc(
      'comment_$commentId',
    );

    await ref.set(
      <String, dynamic>{
        'activityId':
        ref.id,

        'postId':
        postId,

        'commentId':
        commentId,

        'replyId':
        '',

        'isReply':
        false,

        'replyToUsername':
        '',

        'text':
        text.trim(),

        'imageUrl':
        imageUrl.trim(),

        'createdAt':
        createdAt ??
            FieldValue
                .serverTimestamp(),
      },

      SetOptions(
        merge:
        true,
      ),
    );
  }

  //===================================================
  // SAVE REPLY ACTIVITY
  //===================================================

  Future<void> saveReplyActivity({
    required String uid,
    required String postId,
    required String commentId,
    required String replyId,
    required String text,
    String replyToUsername = '',
    String imageUrl = '',
    dynamic createdAt,
  }) async {
    if (uid.trim().isEmpty ||
        postId.trim().isEmpty ||
        commentId.trim().isEmpty ||
        replyId.trim().isEmpty) {
      return;
    }

    final DocumentReference<
        Map<String, dynamic>>
    ref =
    _firestore
        .collection(
      'users',
    )
        .doc(
      uid,
    )
        .collection(
      'commentActivity',
    )
        .doc(
      'reply_$replyId',
    );

    await ref.set(
      <String, dynamic>{
        'activityId':
        ref.id,

        'postId':
        postId,

        'commentId':
        commentId,

        'replyId':
        replyId,

        'isReply':
        true,

        'replyToUsername':
        replyToUsername.trim(),

        'text':
        text.trim(),

        'imageUrl':
        imageUrl.trim(),

        'createdAt':
        createdAt ??
            FieldValue
                .serverTimestamp(),
      },

      SetOptions(
        merge:
        true,
      ),
    );
  }

  //===================================================
  // UPDATE COMMENT ACTIVITY
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
      FieldValue
          .serverTimestamp(),
    };

    if (imageUrl !=
        null) {
      update['imageUrl'] =
          imageUrl;
    }

    await _firestore
        .collection(
      'users',
    )
        .doc(
      uid,
    )
        .collection(
      'commentActivity',
    )
        .doc(
      'comment_$commentId',
    )
        .set(
      update,

      SetOptions(
        merge:
        true,
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
      FieldValue
          .serverTimestamp(),
    };

    if (imageUrl !=
        null) {
      update['imageUrl'] =
          imageUrl;
    }

    await _firestore
        .collection(
      'users',
    )
        .doc(
      uid,
    )
        .collection(
      'commentActivity',
    )
        .doc(
      'reply_$replyId',
    )
        .set(
      update,

      SetOptions(
        merge:
        true,
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
          .collection(
        'users',
      )
          .doc(
        uid,
      )
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
          .collection(
        'users',
      )
          .doc(
        uid,
      )
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
  // SAVE LIKE HISTORY
  //===================================================

  Future<void> saveLikeHistory({
    required String uid,
    required String postId,
  }) async {
    await _firestore
        .collection(
      'users',
    )
        .doc(
      uid,
    )
        .collection(
      'likedPosts',
    )
        .doc(
      postId,
    )
        .set(
      <String, dynamic>{
        'postId':
        postId,

        'likedAt':
        FieldValue
            .serverTimestamp(),
      },

      SetOptions(
        merge:
        true,
      ),
    );
  }

  //===================================================
  // REMOVE LIKE HISTORY
  //===================================================

  Future<void> removeLikeHistory({
    required String uid,
    required String postId,
  }) async {
    try {
      await _firestore
          .collection(
        'users',
      )
          .doc(
        uid,
      )
          .collection(
        'likedPosts',
      )
          .doc(
        postId,
      )
          .delete();
    } catch (_) {}
  }

  //===================================================
  // PATH HELPERS
  //===================================================

  String _postIdFromPath(
      String path,
      ) {
    final List<String> parts =
    path.split(
      '/',
    );

    final int index =
    parts.indexOf(
      'posts',
    );

    if (index <
        0 ||
        index + 1 >=
            parts.length) {
      return '';
    }

    return parts[
    index + 1];
  }

  String _commentIdFromPath(
      String path,
      ) {
    final List<String> parts =
    path.split(
      '/',
    );

    final int index =
    parts.indexOf(
      'comments',
    );

    if (index <
        0 ||
        index + 1 >=
            parts.length) {
      return '';
    }

    return parts[
    index + 1];
  }
}

//===================================================
// INTERNAL BACKFILL ITEM
//===================================================

class _CommentBackfillItem {
  final String activityId;
  final String postId;
  final String commentId;
  final String replyId;
  final bool isReply;
  final String replyToUsername;
  final String text;
  final String imageUrl;
  final dynamic createdAt;

  const _CommentBackfillItem({
    required this.activityId,
    required this.postId,
    required this.commentId,
    required this.replyId,
    required this.isReply,
    required this.replyToUsername,
    required this.text,
    required this.imageUrl,
    required this.createdAt,
  });
}

//===================================================
// DATE HELPER
//===================================================

DateTime? _dateValue(
    dynamic value,
    ) {
  if (value is Timestamp) {
    return value.toDate();
  }

  if (value is DateTime) {
    return value;
  }

  if (value is String) {
    return DateTime.tryParse(
      value,
    );
  }

  return null;
}
