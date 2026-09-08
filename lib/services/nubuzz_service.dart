import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';

import '../models/nubuzz_post.dart';

class NubuzzService {
  NubuzzService._();

  static final NubuzzService instance =
  NubuzzService._();

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>>
  get _posts =>
      _firestore.collection('posts');

  // ============================================================
  // GET NUBUZZ VIDEOS
  // ============================================================

  Future<List<NubuzzVideo>>
  getNubuzzVideos() async {
    final QuerySnapshot<
        Map<String, dynamic>
    >
    snapshot =
    await _posts
        .where(
      'isNUBuzz',
      isEqualTo: true,
    )
        .limit(200)
        .get();

    final Set<String> hiddenPostIds =
    await _getHiddenPostIds();

    final Set<String> blockedUserIds =
    await _getBlockedUserIds();

    final List<NubuzzVideo> videos =
    <NubuzzVideo>[];

    for (
    final QueryDocumentSnapshot<
        Map<String, dynamic>
    >
    document in snapshot.docs
    ) {
      try {
        final NubuzzVideo video =
        NubuzzVideo.fromFirestore(
          document,
        );

        if (video.videoUrl
            .trim()
            .isEmpty) {
          continue;
        }

        if (hiddenPostIds.contains(
          video.postId,
        )) {
          continue;
        }

        if (blockedUserIds.contains(
          video.uid,
        )) {
          continue;
        }

        videos.add(video);
      } catch (e) {
        // Skip malformed old posts.
      }
    }

    return _applyTwentyFourHourRule(
      videos,
    );
  }

  // ============================================================
  // 24-HOUR NUBUZZ RULE
  //
  // Under 24 hours:
  //   newest videos stay first.
  //
  // After 24 hours:
  //   videos enter the older pool.
  //
  // Every refresh:
  //   older videos are reshuffled.
  // ============================================================

  List<NubuzzVideo>
  _applyTwentyFourHourRule(
      List<NubuzzVideo> videos,
      ) {
    final DateTime now =
    DateTime.now();

    final List<NubuzzVideo>
    freshVideos = <NubuzzVideo>[];

    final List<NubuzzVideo>
    oldVideos = <NubuzzVideo>[];

    for (final NubuzzVideo video
    in videos) {
      final Duration age =
      now.difference(
        video.createdAt,
      );

      if (!age.isNegative &&
          age <
              const Duration(
                hours: 24,
              )) {
        freshVideos.add(video);
      } else {
        oldVideos.add(video);
      }
    }

    // New videos stay first.
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

    // Older videos reshuffle.
    oldVideos.shuffle(
      Random(),
    );

    return <NubuzzVideo>[
      ...freshVideos,
      ...oldVideos,
    ];
  }

  // ============================================================
  // HIDDEN POSTS
  // ============================================================

  Future<Set<String>>
  _getHiddenPostIds() async {
    final User? user =
        _auth.currentUser;

    if (user == null) {
      return <String>{};
    }

    try {
      final QuerySnapshot<
          Map<String, dynamic>
      >
      snapshot =
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection(
        'hiddenPosts',
      )
          .get();

      return snapshot.docs
          .map(
            (
            QueryDocumentSnapshot<
                Map<String, dynamic>
            >
            doc,
            ) =>
        doc.id,
      )
          .toSet();
    } catch (e) {
      return <String>{};
    }
  }

  // ============================================================
  // BLOCKED USERS
  // ============================================================

  Future<Set<String>>
  _getBlockedUserIds() async {
    final User? user =
        _auth.currentUser;

    if (user == null) {
      return <String>{};
    }

    try {
      final QuerySnapshot<
          Map<String, dynamic>
      >
      snapshot =
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection(
        'blockedUsers',
      )
          .get();

      return snapshot.docs
          .map(
            (
            QueryDocumentSnapshot<
                Map<String, dynamic>
            >
            doc,
            ) =>
        doc.id,
      )
          .toSet();
    } catch (e) {
      return <String>{};
    }
  }

  // =====================================================================
// RECORD VIEW
// ONE USER = ONE VIEW
// ======================================================================

  Future<bool> recordView(
      String postId,
      ) async {
    final User? user =
        _auth.currentUser;

    if (user == null) {
      return false;
    }

    final DocumentReference<Map<String, dynamic>>
    postRef =
    _firestore
        .collection('posts')
        .doc(postId);

    final DocumentReference<Map<String, dynamic>>
    viewRef =
    postRef
        .collection('views')
        .doc(user.uid);

    try {
      return await _firestore
          .runTransaction<bool>(
            (transaction) async {
          // ========================================================
          // CHECK IF USER ALREADY VIEWED
          // ====================================================

          final DocumentSnapshot<Map<String, dynamic>>
          viewSnapshot =
          await transaction.get(viewRef);

          if (viewSnapshot.exists) {
            return false;
          }

          // =========================================================
          // CHECK POST EXISTS
          // ==========================================================

          final DocumentSnapshot<Map<String, dynamic>>
          postSnapshot =
          await transaction.get(postRef);

          if (!postSnapshot.exists) {
            return false;
          }

          // ======================================================
          // SAVE UNIQUE VIEW
          // ===================================================

          transaction.set(
            viewRef,
            {
              'uid': user.uid,
              'viewedAt':
              FieldValue.serverTimestamp(),
            },
          );

          // ==============================================================
          // INCREASE VIEW COUNT
          // ==============================================================

          transaction.update(
            postRef,
            {
              'viewCount':
              FieldValue.increment(1),
            },
          );

          return true;
        },
      );
    } catch (e) {
      debugPrint(
        'Error recording NUBuzz view: $e',
      );

      return false;
    }
  }

  // ============================================================
  // SHARE COUNT
  // ============================================================

  Future<void> recordShare(
      String postId,
      ) async {
    await _posts
        .doc(postId)
        .update(
      <String, dynamic>{
        'shareCount':
        FieldValue
            .increment(1),
      },
    );
  }
}