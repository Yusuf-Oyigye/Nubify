import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';

import '../models/nubuzz_post.dart';

//===================================================
// NUBUZZ SERVICE
//===================================================

class NubuzzService {
  NubuzzService._();

  static final NubuzzService instance =
  NubuzzService._();

  //===================================================
  // FIREBASE
  //===================================================

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>>
  get _posts =>
      _firestore.collection(
        'posts',
      );

  //===================================================
  // GET NUBUZZ VIDEOS
  //
  // ALL USERS CAN SEE ALL PUBLIC NUBUZZ VIDEOS.
  //
  // RULE:
  //
  // LAST 24 HOURS:
  // NEWEST FIRST.
  //
  // OLDER THAN 24 HOURS:
  // RANDOMLY SHUFFLED EACH REFRESH.
  //
  // ALSO REMOVES:
  // - globally hidden posts
  // - reposts whose original is hidden
  // - legacy personally hidden posts
  // - blocked users
  //===================================================

  Future<List<NubuzzVideo>>
  getNubuzzVideos() async {
    final QuerySnapshot<
        Map<String, dynamic>>
    snapshot =
    await _posts
        .where(
      'isNUBuzz',
      isEqualTo:
      true,
    )
        .limit(
      200,
    )
        .get();

    //===================================================
    // LEGACY PERSONAL HIDDEN POSTS
    //
    // KEEP THIS FOR OLD NUBIFY DATA.
    //===================================================

    final Set<String> hiddenPostIds =
    await _getHiddenPostIds();

    //===================================================
    // BLOCKED USERS
    //===================================================

    final Set<String> blockedUserIds =
    await _getBlockedUserIds();

    final List<NubuzzVideo> videos =
    <NubuzzVideo>[];

    for (
    final QueryDocumentSnapshot<
        Map<String, dynamic>>
    document
    in snapshot.docs
    ) {
      try {
        final Map<String, dynamic> data =
        document.data();

        //===================================================
        // GLOBAL OWNER HIDE
        //
        // If the owner hides this post, nobody should see
        // it on NUBuzz.
        //===================================================

        if (data['isHidden'] ==
            true) {
          continue;
        }

        //===================================================
        // ORIGINAL POST HIDDEN
        //
        // Safety for repost-style documents referencing a
        // hidden original.
        //===================================================

        if (data['isRootHidden'] ==
            true) {
          continue;
        }

        //===================================================
        // ONLY REAL NUBUZZ POSTS
        //===================================================

        if (data['isNUBuzz'] !=
            true) {
          continue;
        }

        final NubuzzVideo video =
        NubuzzVideo.fromFirestore(
          document,
        );

        //===================================================
        // NO VIDEO URL
        //===================================================

        if (video.videoUrl
            .trim()
            .isEmpty) {
          continue;
        }

        //===================================================
        // LEGACY PERSONAL HIDE
        //===================================================

        if (hiddenPostIds.contains(
          video.postId,
        )) {
          continue;
        }

        //===================================================
        // BLOCKED USER
        //===================================================

        if (blockedUserIds.contains(
          video.uid,
        )) {
          continue;
        }

        videos.add(
          video,
        );
      } catch (error) {
        //===================================================
        // SKIP MALFORMED OLD POSTS
        //===================================================

        debugPrint(
          'Skipping malformed NUBuzz post ${document.id}: $error',
        );
      }
    }

    return _applyTwentyFourHourRule(
      videos,
    );
  }

  //===================================================
  // 24-HOUR NUBUZZ RULE
  //
  // UNDER 24 HOURS:
  // NEWEST VIDEOS STAY FIRST.
  //
  // AFTER 24 HOURS:
  // VIDEOS ENTER THE OLDER POOL.
  //
  // EVERY REFRESH:
  // OLDER VIDEOS ARE RESHUFFLED.
  //===================================================

  List<NubuzzVideo>
  _applyTwentyFourHourRule(
      List<NubuzzVideo> videos,
      ) {
    final DateTime now =
    DateTime.now();

    final List<NubuzzVideo> freshVideos =
    <NubuzzVideo>[];

    final List<NubuzzVideo> oldVideos =
    <NubuzzVideo>[];

    for (
    final NubuzzVideo video
    in videos
    ) {
      final Duration age =
      now.difference(
        video.createdAt,
      );

      if (!age.isNegative &&
          age <
              const Duration(
                hours:
                24,
              )) {
        freshVideos.add(
          video,
        );
      } else {
        oldVideos.add(
          video,
        );
      }
    }

    //===================================================
    // NEW VIDEOS FIRST
    //===================================================

    freshVideos.sort(
          (
          NubuzzVideo a,
          NubuzzVideo b,
          ) {
        return b.createdAt
            .compareTo(
          a.createdAt,
        );
      },
    );

    //===================================================
    // OLD VIDEOS RANDOM
    //===================================================

    oldVideos.shuffle(
      Random(),
    );

    return <NubuzzVideo>[
      ...freshVideos,
      ...oldVideos,
    ];
  }

  //===================================================
  // LEGACY PERSONAL HIDDEN POSTS
  //
  // users/{uid}/hiddenPosts
  //
  // We keep this because old versions of Nubify used
  // this collection.
  //
  // New owner-global hiding is ALSO checked directly
  // from posts/{postId}.isHidden above.
  //===================================================

  Future<Set<String>>
  _getHiddenPostIds() async {
    final User? user =
        _auth.currentUser;

    if (user == null) {
      return <String>{};
    }

    try {
      final QuerySnapshot<
          Map<String, dynamic>>
      snapshot =
      await _firestore
          .collection(
        'users',
      )
          .doc(
        user.uid,
      )
          .collection(
        'hiddenPosts',
      )
          .get();

      return snapshot.docs
          .map(
            (
            QueryDocumentSnapshot<
                Map<String, dynamic>>
            document,
            ) {
          final Map<String, dynamic> data =
          document.data();

          return (data['postId'] ??
              document.id)
              .toString()
              .trim();
        },
      )
          .where(
            (
            String postId,
            ) =>
        postId.isNotEmpty,
      )
          .toSet();
    } catch (error) {
      debugPrint(
        'NUBuzz hidden posts error: $error',
      );

      return <String>{};
    }
  }

  //===================================================
  // BLOCKED USERS
  //===================================================

  Future<Set<String>>
  _getBlockedUserIds() async {
    final User? user =
        _auth.currentUser;

    if (user == null) {
      return <String>{};
    }

    try {
      final QuerySnapshot<
          Map<String, dynamic>>
      snapshot =
      await _firestore
          .collection(
        'users',
      )
          .doc(
        user.uid,
      )
          .collection(
        'blockedUsers',
      )
          .get();

      return snapshot.docs
          .map(
            (
            QueryDocumentSnapshot<
                Map<String, dynamic>>
            document,
            ) {
          final Map<String, dynamic> data =
          document.data();

          return (data['uid'] ??
              document.id)
              .toString()
              .trim();
        },
      )
          .where(
            (
            String uid,
            ) =>
        uid.isNotEmpty,
      )
          .toSet();
    } catch (error) {
      debugPrint(
        'NUBuzz blocked users error: $error',
      );

      return <String>{};
    }
  }

  //===================================================
  // RECORD VIEW
  //
  // ONE USER = ONE VIEW
  //
  // posts/{postId}/views/{uid}
  //
  // If the user already has a view document,
  // viewCount is NOT increased again.
  //===================================================

  Future<bool> recordView(
      String postId,
      ) async {
    final User? user =
        _auth.currentUser;

    if (user == null) {
      return false;
    }

    final String cleanPostId =
    postId.trim();

    if (cleanPostId.isEmpty) {
      return false;
    }

    final DocumentReference<
        Map<String, dynamic>>
    postRef =
    _firestore
        .collection(
      'posts',
    )
        .doc(
      cleanPostId,
    );

    final DocumentReference<
        Map<String, dynamic>>
    viewRef =
    postRef
        .collection(
      'views',
    )
        .doc(
      user.uid,
    );

    try {
      return await _firestore
          .runTransaction<bool>(
            (
            Transaction transaction,
            ) async {
          //===================================================
          // CHECK IF ALREADY VIEWED
          //===================================================

          final DocumentSnapshot<
              Map<String, dynamic>>
          viewSnapshot =
          await transaction.get(
            viewRef,
          );

          if (viewSnapshot.exists) {
            return false;
          }

          //===================================================
          // CHECK POST
          //===================================================

          final DocumentSnapshot<
              Map<String, dynamic>>
          postSnapshot =
          await transaction.get(
            postRef,
          );

          if (!postSnapshot.exists ||
              postSnapshot.data() ==
                  null) {
            return false;
          }

          final Map<String, dynamic> postData =
          postSnapshot.data()!;

          //===================================================
          // DO NOT RECORD VIEWS ON HIDDEN POSTS
          //===================================================

          if (postData['isHidden'] ==
              true ||
              postData['isRootHidden'] ==
                  true) {
            return false;
          }

          //===================================================
          // SAVE UNIQUE VIEW
          //===================================================

          transaction.set(
            viewRef,
            <String, dynamic>{
              'uid':
              user.uid,

              'viewedAt':
              FieldValue
                  .serverTimestamp(),
            },
          );

          //===================================================
          // INCREASE VIEW COUNT
          //===================================================

          transaction.update(
            postRef,
            <String, dynamic>{
              'viewCount':
              FieldValue.increment(
                1,
              ),
            },
          );

          return true;
        },
      );
    } catch (error) {
      debugPrint(
        'Error recording NUBuzz view: $error',
      );

      return false;
    }
  }

  //===================================================
  // SHARE COUNT
  //===================================================

  Future<void> recordShare(
      String postId,
      ) async {
    final String cleanPostId =
    postId.trim();

    if (cleanPostId.isEmpty) {
      return;
    }

    try {
      final DocumentReference<
          Map<String, dynamic>>
      postRef =
      _posts.doc(
        cleanPostId,
      );

      final DocumentSnapshot<
          Map<String, dynamic>>
      snapshot =
      await postRef.get();

      if (!snapshot.exists ||
          snapshot.data() ==
              null) {
        return;
      }

      final Map<String, dynamic> data =
      snapshot.data()!;

      //===================================================
      // DON'T COUNT SHARES ON HIDDEN POSTS
      //===================================================

      if (data['isHidden'] ==
          true ||
          data['isRootHidden'] ==
              true) {
        return;
      }

      await postRef.update(
        <String, dynamic>{
          'shareCount':
          FieldValue.increment(
            1,
          ),
        },
      );
    } catch (error) {
      debugPrint(
        'NUBuzz share count error: $error',
      );
    }
  }
}