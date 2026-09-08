import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/post.dart';

class ProfileCommentActivity {
  final String activityId;
  final String postId;
  final String commentId;
  final String replyId;
  final bool isReply;
  final String text;
  final DateTime? createdAt;

  const ProfileCommentActivity({
    required this.activityId,
    required this.postId,
    required this.commentId,
    required this.replyId,
    required this.isReply,
    required this.text,
    required this.createdAt,
  });

  factory ProfileCommentActivity
      .fromDocument(
      QueryDocumentSnapshot<
          Map<String, dynamic>>
      document,
      ) {
    final Map<String, dynamic>
    data =
    document.data();

    return ProfileCommentActivity(
      activityId:
      document.id,
      postId:
      (data['postId'] ?? '')
          .toString(),
      commentId:
      (data['commentId'] ??
          '')
          .toString(),
      replyId:
      (data['replyId'] ?? '')
          .toString(),
      isReply:
      data['isReply'] == true,
      text:
      (data['text'] ?? '')
          .toString(),
      createdAt:
      data['createdAt']
      is Timestamp
          ? (data['createdAt']
      as Timestamp)
          .toDate()
          : null,
    );
  }
}

class ProfileActivityService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  //===================================================
  // USER DOCUMENT
  //===================================================

  Stream<DocumentSnapshot<
      Map<String, dynamic>>>
  userStream(
      String uid,
      ) {
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots();
  }

  //===================================================
  // ORIGINAL POSTS
  //===================================================

  Stream<List<Post>>
  userPostsStream(
      String uid,
      ) {
    return _userPostStream(
      uid: uid,
      repostsOnly: false,
    );
  }

  //===================================================
  // REPOSTS
  //===================================================

  Stream<List<Post>>
  userRepostsStream(
      String uid,
      ) {
    return _userPostStream(
      uid: uid,
      repostsOnly: true,
    );
  }

  Stream<List<Post>>
  _userPostStream({
    required String uid,
    required bool repostsOnly,
  }) {
    return _firestore
        .collection('posts')
        .where(
      'uid',
      isEqualTo: uid,
    )
        .snapshots()
        .map(
          (
          QuerySnapshot<
              Map<String, dynamic>>
          snapshot,
          ) {
        final List<
            QueryDocumentSnapshot<
                Map<String,
                    dynamic>>>
        docs =
        snapshot.docs
            .where(
              (
              QueryDocumentSnapshot<
                  Map<String,
                      dynamic>>
              document,
              ) {
            final bool isRepost =
                document.data()[
                'isRepost'] ==
                    true;

            return repostsOnly
                ? isRepost
                : !isRepost;
          },
        ).toList();

        docs.sort(
              (
              QueryDocumentSnapshot<
                  Map<String,
                      dynamic>>
              a,
              QueryDocumentSnapshot<
                  Map<String,
                      dynamic>>
              b,
              ) =>
              _documentDate(b)
                  .compareTo(
                _documentDate(a),
              ),
        );

        final List<Post> result =
        <Post>[];

        for (final QueryDocumentSnapshot<
            Map<String,
                dynamic>>
        document
        in docs) {
          try {
            result.add(
              Post.fromFirestore(
                document,
              ),
            );
          } catch (_) {}
        }

        return result;
      },
    );
  }

  //===================================================
  // SAVED POSTS
  //===================================================

  Stream<List<Post>>
  savedPostsStream(
      String uid,
      ) {
    return _referencePostsStream(
      uid: uid,
      collectionName:
      'savedPosts',
      dateField: 'savedAt',
    );
  }

  //===================================================
  // LIKED POSTS
  //===================================================

  Stream<List<Post>>
  likedPostsStream(
      String uid,
      ) {
    return _referencePostsStream(
      uid: uid,
      collectionName:
      'likedPosts',
      dateField: 'likedAt',
    );
  }

  //===================================================
  // REFERENCE POSTS STREAM
  //===================================================

  Stream<List<Post>>
  _referencePostsStream({
    required String uid,
    required String collectionName,
    required String dateField,
  }) async* {
    await for (final QuerySnapshot<
        Map<String, dynamic>>
    snapshot
    in _firestore
        .collection('users')
        .doc(uid)
        .collection(
      collectionName,
    )
        .snapshots()) {
      final List<
          QueryDocumentSnapshot<
              Map<String,
                  dynamic>>>
      refs =
      List<
          QueryDocumentSnapshot<
              Map<String,
                  dynamic>>>.from(
        snapshot.docs,
      );

      refs.sort(
            (
            QueryDocumentSnapshot<
                Map<String,
                    dynamic>>
            a,
            QueryDocumentSnapshot<
                Map<String,
                    dynamic>>
            b,
            ) {
          final DateTime ad =
          a.data()[dateField]
          is Timestamp
              ? (a.data()[
          dateField]
          as Timestamp)
              .toDate()
              : DateTime
              .fromMillisecondsSinceEpoch(
            0,
          );

          final DateTime bd =
          b.data()[dateField]
          is Timestamp
              ? (b.data()[
          dateField]
          as Timestamp)
              .toDate()
              : DateTime
              .fromMillisecondsSinceEpoch(
            0,
          );

          return bd.compareTo(
            ad,
          );
        },
      );

      final List<Post> posts =
      <Post>[];

      for (final QueryDocumentSnapshot<
          Map<String,
              dynamic>>
      ref
      in refs) {
        final String postId =
        (ref.data()['postId'] ??
            ref.id)
            .toString();

        try {
          final DocumentSnapshot<
              Map<String,
                  dynamic>>
          postSnapshot =
          await _firestore
              .collection(
            'posts',
          )
              .doc(postId)
              .get();

          if (!postSnapshot
              .exists) {
            continue;
          }

          posts.add(
            Post.fromFirestore(
              postSnapshot,
            ),
          );
        } catch (_) {}
      }

      yield posts;
    }
  }

  //===================================================
  // COMMENTS
  //===================================================

  Stream<List<
      ProfileCommentActivity>>
  commentsStream(
      String uid,
      ) {
    return _firestore
        .collection('users')
        .doc(uid)
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
        result =
        snapshot.docs
            .map(
          ProfileCommentActivity
              .fromDocument,
        )
            .toList();

        result.sort(
              (
              ProfileCommentActivity a,
              ProfileCommentActivity b,
              ) =>
              (b.createdAt ??
                  DateTime
                      .fromMillisecondsSinceEpoch(
                    0,
                  ))
                  .compareTo(
                a.createdAt ??
                    DateTime
                        .fromMillisecondsSinceEpoch(
                      0,
                    ),
              ),
        );

        return result;
      },
    );
  }

  //===================================================
  // BACKFILL OLD LIKES
  //===================================================

  Future<void> backfillLikes(
      String uid,
      ) async {
    final Set<String> ids =
    <String>{};

    try {
      final QuerySnapshot<
          Map<String, dynamic>>
      oldLikes =
      await _firestore
          .collection('posts')
          .where(
        'likes',
        arrayContains: uid,
      )
          .get();

      for (final QueryDocumentSnapshot<
          Map<String,
              dynamic>>
      document
      in oldLikes.docs) {
        ids.add(
          document.id,
        );
      }
    } catch (_) {}

    try {
      final QuerySnapshot<
          Map<String, dynamic>>
      newerLikes =
      await _firestore
          .collection('posts')
          .where(
        'likedUserIds',
        arrayContains: uid,
      )
          .get();

      for (final QueryDocumentSnapshot<
          Map<String,
              dynamic>>
      document
      in newerLikes.docs) {
        ids.add(
          document.id,
        );
      }
    } catch (_) {}

    if (ids.isEmpty) {
      return;
    }

    final WriteBatch batch =
    _firestore.batch();

    for (final String postId
    in ids) {
      batch.set(
        _firestore
            .collection('users')
            .doc(uid)
            .collection(
          'likedPosts',
        )
            .doc(postId),
        <String, dynamic>{
          'postId': postId,
          'likedAt':
          FieldValue
              .serverTimestamp(),
        },
        SetOptions(
          merge: true,
        ),
      );
    }

    await batch.commit();
  }

  //===================================================
  // BACKFILL OLD COMMENTS
  //===================================================

  Future<void> backfillComments(
      String uid,
      ) async {
    final WriteBatch batch =
    _firestore.batch();

    bool hasWrites = false;

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
        isEqualTo: uid,
      )
          .get();

      for (final QueryDocumentSnapshot<
          Map<String,
              dynamic>>
      document
      in comments.docs) {
        final String postId =
        _postIdFromPath(
          document.reference.path,
        );

        if (postId.isEmpty) {
          continue;
        }

        final DocumentReference<
            Map<String,
                dynamic>>
        target =
        _firestore
            .collection(
          'users',
        )
            .doc(uid)
            .collection(
          'commentActivity',
        )
            .doc(
          'comment_${document.id}',
        );

        batch.set(
          target,
          <String, dynamic>{
            'activityId':
            target.id,
            'postId': postId,
            'commentId':
            document.id,
            'replyId': '',
            'isReply': false,
            'text':
            (document.data()[
            'text'] ??
                '')
                .toString(),
            'createdAt':
            document.data()[
            'createdAt'] ??
                FieldValue
                    .serverTimestamp(),
          },
          SetOptions(
            merge: true,
          ),
        );

        hasWrites = true;
      }
    } catch (_) {}

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
        isEqualTo: uid,
      )
          .get();

      for (final QueryDocumentSnapshot<
          Map<String,
              dynamic>>
      document
      in replies.docs) {
        final String postId =
        _postIdFromPath(
          document.reference.path,
        );

        final String commentId =
        _commentIdFromPath(
          document.reference.path,
        );

        if (postId.isEmpty) {
          continue;
        }

        final DocumentReference<
            Map<String,
                dynamic>>
        target =
        _firestore
            .collection(
          'users',
        )
            .doc(uid)
            .collection(
          'commentActivity',
        )
            .doc(
          'reply_${document.id}',
        );

        batch.set(
          target,
          <String, dynamic>{
            'activityId':
            target.id,
            'postId': postId,
            'commentId':
            commentId,
            'replyId':
            document.id,
            'isReply': true,
            'text':
            (document.data()[
            'text'] ??
                '')
                .toString(),
            'createdAt':
            document.data()[
            'createdAt'] ??
                FieldValue
                    .serverTimestamp(),
          },
          SetOptions(
            merge: true,
          ),
        );

        hasWrites = true;
      }
    } catch (_) {}

    if (hasWrites) {
      try {
        await batch.commit();
      } catch (_) {}
    }
  }

  //===================================================
  // PREPARE OWNER HISTORY
  //===================================================

  Future<void>
  prepareOwnerHistory(
      String uid,
      ) async {
    await Future.wait(
      <Future<void>>[
        backfillLikes(
          uid,
        ),
        backfillComments(
          uid,
        ),
      ],
    );
  }

  //===================================================
  // HELPERS
  //===================================================

  DateTime _documentDate(
      QueryDocumentSnapshot<
          Map<String, dynamic>>
      document,
      ) {
    final dynamic value =
    document.data()[
    'createdAt'];

    if (value is Timestamp) {
      return value.toDate();
    }

    return DateTime
        .fromMillisecondsSinceEpoch(
      0,
    );
  }

  String _postIdFromPath(
      String path,
      ) {
    final List<String> parts =
    path.split('/');

    final int index =
    parts.indexOf(
      'posts',
    );

    if (index < 0 ||
        index + 1 >=
            parts.length) {
      return '';
    }

    return parts[index + 1];
  }

  String _commentIdFromPath(
      String path,
      ) {
    final List<String> parts =
    path.split('/');

    final int index =
    parts.indexOf(
      'comments',
    );

    if (index < 0 ||
        index + 1 >=
            parts.length) {
      return '';
    }

    return parts[index + 1];
  }
}