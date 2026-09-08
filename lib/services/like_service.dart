import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'notification_service.dart';

//===================================================
// LIKE SERVICE
//===================================================

class LikeService {
  //===================================================
  // FIREBASE
  //===================================================

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  //===================================================
  // NOTIFICATION SERVICE
  //===================================================

  final NotificationService _notificationService =
  NotificationService();

  //===================================================
  // LIKE POST / REPOST / NUBUZZ
  //
  // CANONICAL LIKE:
  //
  // posts/{postId}/likes/{uid}
  //
  // PROFILE -> LIKES HISTORY:
  //
  // users/{uid}/likedPosts/{postId}
  //
  // COMPATIBILITY:
  //
  // likes[]
  // likedUserIds[]
  //===================================================

  Future<void> likePost(
      String postId,
      ) async {
    final User? currentUser =
        _auth.currentUser;

    if (currentUser == null) {
      throw Exception(
        'User is not logged in.',
      );
    }

    final String cleanPostId =
    postId.trim();

    if (cleanPostId.isEmpty) {
      throw Exception(
        'Post could not be found.',
      );
    }

    final String uid =
        currentUser.uid;

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

    //===================================================
    // READ CURRENT POST STATE
    //
    // NO FIRESTORE TRANSACTION HERE.
    //
    // TRANSACTIONS WAIT FOR THE SERVER AND MADE THE
    // HEART / COUNT FEEL FROZEN ON HOME + NUBUZZ.
    //===================================================

    final DocumentSnapshot<
        Map<String, dynamic>>
    postSnapshot =
    await postRef.get();

    if (!postSnapshot.exists ||
        postSnapshot.data() ==
            null) {
      throw Exception(
        'Post no longer exists.',
      );
    }

    final Map<String, dynamic>
    postData =
    postSnapshot.data()!;

    if (postData['isHidden'] ==
        true ||
        postData['isRootHidden'] ==
            true) {
      throw Exception(
        'This post is currently hidden.',
      );
    }

    final Set<String> currentUsers =
    <String>{
      ..._stringList(
        postData['likes'],
      ),
      ..._stringList(
        postData['likedUserIds'],
      ),
    };

    final String postOwnerUid =
    (postData['uid'] ?? '')
        .toString()
        .trim();

    //===================================================
// ALREADY LIKED
//
// DO NOT INCREMENT TWICE.
//===================================================

    if (currentUsers.contains(
      uid,
    )) {
      unawaited(
        _writeLikeSupportDocuments(
          postId:
          cleanPostId,
          uid:
          uid,

          //==========================
          // OLD LIKE
          //==========================

          recordNewLike:
          false,
        ),
      );

      return;
    }
    //===================================================
    // CORE LIKE WRITE
    //
    // ONE NORMAL UPDATE = LOCAL CACHE UPDATES QUICKLY.
    //===================================================

    await postRef.update(
      <String, dynamic>{
        'likeCount':
        FieldValue.increment(
          1,
        ),

        'likes':
        FieldValue.arrayUnion(
          <String>[
            uid,
          ],
        ),

        'likedUserIds':
        FieldValue.arrayUnion(
          <String>[
            uid,
          ],
        ),
      },
    );
//===================================================
// BEST-EFFORT LIKE DOCUMENT + PROFILE HISTORY
//
// THIS IS A REAL NEW LIKE.
// IT SHOULD BECOME THE NEWEST ITEM IN PROFILE LIKES.
//===================================================

    unawaited(
      _writeLikeSupportDocuments(
        postId:
        cleanPostId,
        uid:
        uid,

        //==========================
        // NEW REAL LIKE
        //==========================

        recordNewLike:
        true,
      ),
    );
    //===================================================
    // BEST-EFFORT NOTIFICATION
    //===================================================

    if (postOwnerUid.isNotEmpty &&
        postOwnerUid !=
            uid) {
      unawaited(
        _notificationService
            .notifyLike(
          postOwnerId:
          postOwnerUid,
          postId:
          cleanPostId,
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
            print(
              'Like notification error: $error',
            );
          },
        ),
      );
    }
  }

  //===================================================
  // UNLIKE POST / REPOST / NUBUZZ
  //===================================================

  Future<void> unlikePost(
      String postId,
      ) async {
    final User? currentUser =
        _auth.currentUser;

    if (currentUser == null) {
      throw Exception(
        'User is not logged in.',
      );
    }

    final String cleanPostId =
    postId.trim();

    if (cleanPostId.isEmpty) {
      return;
    }

    final String uid =
        currentUser.uid;

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

    final DocumentSnapshot<
        Map<String, dynamic>>
    postSnapshot =
    await postRef.get();

    if (!postSnapshot.exists ||
        postSnapshot.data() ==
            null) {
      return;
    }

    final Map<String, dynamic>
    postData =
    postSnapshot.data()!;

    final Set<String> currentUsers =
    <String>{
      ..._stringList(
        postData['likes'],
      ),
      ..._stringList(
        postData['likedUserIds'],
      ),
    };

    if (!currentUsers.contains(
      uid,
    )) {
      return;
    }

    final int currentCount =
    _toInt(
      postData['likeCount'],
    );

    await postRef.update(
      <String, dynamic>{
        'likeCount':
        currentCount > 0
            ? FieldValue.increment(
          -1,
        )
            : 0,

        'likes':
        FieldValue.arrayRemove(
          <String>[
            uid,
          ],
        ),

        'likedUserIds':
        FieldValue.arrayRemove(
          <String>[
            uid,
          ],
        ),
      },
    );

    unawaited(
      _deleteLikeSupportDocuments(
        postId:
        cleanPostId,
        uid:
        uid,
      ),
    );
  }

  //===================================================
  // CHECK IF CURRENT USER LIKED
  //
  // SUPPORTS:
  //
  // 1. posts/{postId}/likes/{uid}
  // 2. likes[]
  // 3. likedUserIds[]
  //===================================================

  Future<bool> hasLiked(
      String postId,
      ) async {
    final User? currentUser =
        _auth.currentUser;

    if (currentUser == null) {
      return false;
    }

    final String cleanPostId =
    postId.trim();

    if (cleanPostId.isEmpty) {
      return false;
    }

    final String uid =
        currentUser.uid;

    //===================================================
    // MAIN POST ARRAYS ARE THE SOURCE OF TRUTH
    //===================================================

    try {
      final DocumentSnapshot<
          Map<String, dynamic>>
      postSnapshot =
      await _firestore
          .collection(
        'posts',
      )
          .doc(
        cleanPostId,
      )
          .get()
          .timeout(
        const Duration(
          seconds:
          6,
        ),
      );

      if (!postSnapshot.exists ||
          postSnapshot.data() ==
              null) {
        return false;
      }

      final Map<String, dynamic>
      data =
      postSnapshot.data()!;

      final bool liked =
          _stringList(
            data['likes'],
          ).contains(
            uid,
          ) ||
              _stringList(
                data['likedUserIds'],
              ).contains(
                uid,
              );
      if (liked) {
        unawaited(
          _writeLikeSupportDocuments(
            postId:
            cleanPostId,
            uid:
            uid,

            //==========================
            // STATUS CHECK ONLY
            //
            // DO NOT MOVE OLD LIKE TO TOP.
            //==========================

            recordNewLike:
            false,
          ),
        );
      }

      return liked;
    } catch (_) {
      //===================================================
      // LEGACY FALLBACK ONLY WHEN MAIN POST READ FAILS
      //===================================================

      try {
        final DocumentSnapshot<
            Map<String, dynamic>>
        likeSnapshot =
        await _firestore
            .collection(
          'posts',
        )
            .doc(
          cleanPostId,
        )
            .collection(
          'likes',
        )
            .doc(
          uid,
        )
            .get()
            .timeout(
          const Duration(
            seconds:
            4,
          ),
        );

        return likeSnapshot.exists;
      } catch (_) {
        return false;
      }
    }
  }

  //===================================================
  // GET LIKE COUNT
  //===================================================

  Future<int> getLikeCount(
      String postId,
      ) async {
    final String cleanPostId =
    postId.trim();

    if (cleanPostId.isEmpty) {
      return 0;
    }

    final DocumentSnapshot<
        Map<String, dynamic>>
    snapshot =
    await _firestore
        .collection(
      'posts',
    )
        .doc(
      cleanPostId,
    )
        .get();

    if (!snapshot.exists ||
        snapshot.data() ==
            null) {
      return 0;
    }

    return _toInt(
      snapshot.data()![
      'likeCount'],
    );
  }

  //===================================================
  // WATCH LIKE COUNT
  //===================================================

  Stream<int> likeCountStream(
      String postId,
      ) {
    final String cleanPostId =
    postId.trim();

    if (cleanPostId.isEmpty) {
      return Stream<int>.value(
        0,
      );
    }

    return _firestore
        .collection(
      'posts',
    )
        .doc(
      cleanPostId,
    )
        .snapshots()
        .map(
          (
          DocumentSnapshot<
              Map<String, dynamic>>
          snapshot,
          ) {
        if (!snapshot.exists ||
            snapshot.data() ==
                null) {
          return 0;
        }

        return _toInt(
          snapshot.data()![
          'likeCount'],
        );
      },
    );
  }

  //===================================================
  // WATCH CURRENT USER LIKE STATE
  //
  // USEFUL ANYWHERE YOU WANT A LIVE HEART STATE.
  //===================================================

  Stream<bool> hasLikedStream(
      String postId,
      ) {
    final User? currentUser =
        _auth.currentUser;

    final String cleanPostId =
    postId.trim();

    if (currentUser == null ||
        cleanPostId.isEmpty) {
      return Stream<bool>.value(
        false,
      );
    }

    return _firestore
        .collection(
      'posts',
    )
        .doc(
      cleanPostId,
    )
        .collection(
      'likes',
    )
        .doc(
      currentUser.uid,
    )
        .snapshots()
        .map(
          (
          DocumentSnapshot<
              Map<String, dynamic>>
          snapshot,
          ) =>
      snapshot.exists,
    );
  }

  //===================================================
  // REPAIR OLD LIKE HISTORY FOR ONE POST
  //
  // THIS DOES NOT CHANGE likeCount.
  //
  // IT ONLY BRINGS OLD NUBIFY LIKES INTO:
  //
  // posts/{postId}/likes/{uid}
  //
  // AND:
  //
  // users/{uid}/likedPosts/{postId}
  //===================================================

  Future<void> repairLikeHistory(
      String postId,
      ) async {
    final User? currentUser =
        _auth.currentUser;

    if (currentUser == null) {
      return;
    }

    final String cleanPostId =
    postId.trim();

    if (cleanPostId.isEmpty) {
      return;
    }

    final String uid =
        currentUser.uid;

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
    likeRef =
    postRef
        .collection(
      'likes',
    )
        .doc(
      uid,
    );

    final DocumentReference<
        Map<String, dynamic>>
    historyRef =
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
      cleanPostId,
    );

    try {
      final DocumentSnapshot<
          Map<String, dynamic>>
      postSnapshot =
      await postRef.get();

      if (!postSnapshot.exists ||
          postSnapshot.data() ==
              null) {
        try {
          await historyRef.delete();
        } catch (_) {}

        return;
      }

      final DocumentSnapshot<
          Map<String, dynamic>>
      likeSnapshot =
      await likeRef.get();

      final Map<String, dynamic>
      postData =
      postSnapshot.data()!;

      final bool liked =
          _stringList(
            postData['likes'],
          ).contains(
            uid,
          ) ||
              _stringList(
                postData[
                'likedUserIds'],
              ).contains(
                uid,
              );

      //===================================================
      // USER IS NOT ACTUALLY LIKING THIS POST
      //===================================================

      if (!liked) {
        try {
          final WriteBatch cleanupBatch =
          _firestore.batch();

          cleanupBatch.delete(
            historyRef,
          );

          cleanupBatch.delete(
            likeRef,
          );

          await cleanupBatch.commit();
        } catch (_) {}

        return;
      }

      final WriteBatch batch =
      _firestore.batch();

      //===================================================
      // CREATE CANONICAL LIKE IF OLD LIKE ONLY EXISTS
      // IN AN ARRAY.
      //===================================================

      if (!likeSnapshot.exists) {
        batch.set(
          likeRef,
          <String, dynamic>{
            'uid':
            uid,

            'createdAt':
            FieldValue
                .serverTimestamp(),

            'migratedFromLegacy':
            true,
          },
          SetOptions(
            merge:
            true,
          ),
        );
      }

      //===================================================
      // PROFILE HISTORY
      //===================================================

      batch.set(
        historyRef,
        <String, dynamic>{
          'postId':
          cleanPostId,

          'likedAt':
          likeSnapshot
              .data()?[
          'createdAt'] ??
              FieldValue
                  .serverTimestamp(),

          'backfilled':
          !likeSnapshot.exists,
        },
        SetOptions(
          merge:
          true,
        ),
      );

      //===================================================
      // KEEP BOTH ARRAYS CONSISTENT
      //===================================================

      batch.update(
        postRef,
        <String, dynamic>{
          'likes':
          FieldValue
              .arrayUnion(
            <String>[
              uid,
            ],
          ),

          'likedUserIds':
          FieldValue
              .arrayUnion(
            <String>[
              uid,
            ],
          ),
        },
      );

      await batch.commit();
    } catch (error) {
      print(
        'Like history repair error: $error',
      );
    }
  }

  //===================================================
  // GET USERS WHO LIKED A POST
  //
  // USEFUL FOR:
  //
  // "LIKED BY"
  //===================================================

  Stream<QuerySnapshot<Map<String, dynamic>>>
  likedByStream(
      String postId,
      ) {
    final String cleanPostId =
    postId.trim();

    if (cleanPostId.isEmpty) {
      return const Stream<
          QuerySnapshot<
              Map<String, dynamic>>>.empty();
    }

    return _firestore
        .collection(
      'posts',
    )
        .doc(
      cleanPostId,
    )
        .collection(
      'likes',
    )
        .orderBy(
      'createdAt',
      descending:
      true,
    )
        .snapshots();
  }
//===================================================
// WRITE LIKE SUPPORT DOCUMENTS
//
// recordNewLike = true
// -> USER ACTUALLY PRESSED LIKE NOW.
// -> CREATE A NEW likedAt TIME.
//
// recordNewLike = false
// -> WE ARE ONLY REPAIRING / CHECKING AN OLD LIKE.
// -> KEEP THE OLD TIME.
//===================================================

  Future<void> _writeLikeSupportDocuments({
    required String postId,
    required String uid,
    required bool recordNewLike,
  }) async {
    //===================================================
    // CHECK MAIN POST BEFORE WRITING SUPPORT DOCUMENTS
    //===================================================

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
          .get()
          .timeout(
        const Duration(
          seconds:
          6,
        ),
      );

      final Map<String, dynamic>? data =
      postSnapshot.data();

      if (!postSnapshot.exists ||
          data == null ||
          (!_stringList(
            data['likes'],
          ).contains(
            uid,
          ) &&
              !_stringList(
                data['likedUserIds'],
              ).contains(
                uid,
              ))) {
        return;
      }
    } catch (error) {
      print(
        'Like support pre-check error: $error',
      );

      return;
    }

    //===================================================
    // REFERENCES
    //===================================================

    final DocumentReference<
        Map<String, dynamic>>
    likeRef =
    _firestore
        .collection(
      'posts',
    )
        .doc(
      postId,
    )
        .collection(
      'likes',
    )
        .doc(
      uid,
    );

    final DocumentReference<
        Map<String, dynamic>>
    historyRef =
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

    try {
      //===================================================
      // READ EXISTING LIKE HISTORY
      //
      // THIS LETS US KEEP THE OLD TIMESTAMP.
      //===================================================

      final DocumentSnapshot<
          Map<String, dynamic>>
      likeSnapshot =
      await likeRef.get();

      final DocumentSnapshot<
          Map<String, dynamic>>
      historySnapshot =
      await historyRef.get();

      final dynamic existingLikeTime =
      likeSnapshot.data()?[
      'createdAt'];

      final dynamic existingLikedAt =
      historySnapshot.data()?[
      'likedAt'];

      final WriteBatch batch =
      _firestore.batch();

      //===================================================
      // ACTUAL NEW LIKE
      //
      // USER PRESSED LIKE NOW.
      //===================================================

      if (recordNewLike) {
        batch.set(
          likeRef,
          <String, dynamic>{
            'uid':
            uid,

            'createdAt':
            FieldValue
                .serverTimestamp(),
          },
          SetOptions(
            merge:
            true,
          ),
        );

        batch.set(
          historyRef,
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
      // EXISTING / OLD LIKE
      //
      // DO NOT CHANGE AN EXISTING LIKE DATE.
      //===================================================

      else {
        //===================================================
        // CANONICAL LIKE DOCUMENT MISSING
        //===================================================

        if (!likeSnapshot.exists) {
          batch.set(
            likeRef,
            <String, dynamic>{
              'uid':
              uid,

              //===================================================
              // USE OLD PROFILE LIKE TIME WHEN POSSIBLE.
              //===================================================

              'createdAt':
              existingLikedAt ??
                  FieldValue
                      .serverTimestamp(),

              'migratedFromLegacy':
              true,
            },
            SetOptions(
              merge:
              true,
            ),
          );
        }

        //===================================================
        // PROFILE LIKE HISTORY MISSING
        //===================================================

        if (!historySnapshot.exists ||
            existingLikedAt ==
                null) {
          batch.set(
            historyRef,
            <String, dynamic>{
              'postId':
              postId,

              //===================================================
              // USE OLD CANONICAL LIKE TIME WHEN POSSIBLE.
              //
              // ONLY USE "NOW" IF OLD NUBIFY DATA HAS NO
              // LIKE TIMESTAMP AT ALL.
              //===================================================

              'likedAt':
              existingLikeTime ??
                  FieldValue
                      .serverTimestamp(),

              'backfilled':
              true,
            },
            SetOptions(
              merge:
              true,
            ),
          );
        }
      }

      //===================================================
      // COMMIT
      //===================================================

      await batch.commit()
          .timeout(
        const Duration(
          seconds:
          6,
        ),
      );
    } catch (error) {
      print(
        'Like support-document error: $error',
      );
    }
  }
  //===================================================
  // DELETE LIKE SUPPORT DOCUMENTS
  //===================================================

  Future<void> _deleteLikeSupportDocuments({
    required String postId,
    required String uid,
  }) async {
    try {
      final WriteBatch batch =
      _firestore.batch();

      batch.delete(
        _firestore
            .collection(
          'posts',
        )
            .doc(
          postId,
        )
            .collection(
          'likes',
        )
            .doc(
          uid,
        ),
      );

      batch.delete(
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
        ),
      );

      await batch.commit()
          .timeout(
        const Duration(
          seconds:
          6,
        ),
      );
    } catch (error) {
      print(
        'Unlike support-document error: $error',
      );
    }
  }

  //===================================================
  // REPAIR MAIN POST LIKE ARRAYS
  //===================================================

  Future<void> _repairMainPostLikeArrays({
    required String postId,
    required String uid,
  }) async {
    try {
      await _firestore
          .collection(
        'posts',
      )
          .doc(
        postId,
      )
          .update(
        <String, dynamic>{
          'likes':
          FieldValue.arrayUnion(
            <String>[
              uid,
            ],
          ),
          'likedUserIds':
          FieldValue.arrayUnion(
            <String>[
              uid,
            ],
          ),
        },
      )
          .timeout(
        const Duration(
          seconds:
          6,
        ),
      );
    } catch (error) {
      print(
        'Like-array repair error: $error',
      );
    }
  }

  //===================================================
  // STRING LIST
  //===================================================

  static List<String> _stringList(
      dynamic value,
      ) {
    if (value is! Iterable) {
      return <String>[];
    }

    return value
        .map(
          (
          dynamic item,
          ) =>
          item
              .toString()
              .trim(),
    )
        .where(
          (
          String item,
          ) =>
      item.isNotEmpty,
    )
        .toList();
  }

  //===================================================
  // INT HELPER
  //===================================================

  static int _toInt(
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
// LIKE TRANSACTION RESULT
//===================================================

class _LikeTransactionResult {
  final bool newlyLiked;

  final String postOwnerUid;

  const _LikeTransactionResult({
    required this.newlyLiked,
    required this.postOwnerUid,
  });
}