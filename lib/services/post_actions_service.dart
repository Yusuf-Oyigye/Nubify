import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class PostActionsService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseStorage _storage =
      FirebaseStorage.instance;

  //===================================================
  // DELETE POST
  //===================================================

  Future<void> deletePost(
      String postId,
      ) async {
    final DocumentReference<
        Map<String, dynamic>>
    postRef =
    _firestore
        .collection('posts')
        .doc(postId);

    try {
      final DocumentSnapshot<
          Map<String, dynamic>>
      snapshot =
      await postRef.get();

      if (!snapshot.exists) {
        return;
      }

      final Map<String, dynamic>
      data =
          snapshot.data() ??
              <String, dynamic>{};

      final bool isRepost =
          data['isRepost'] ==
              true;

      //===================================================
      // IF ORIGINAL POST IS BEING DELETED,
      // HIDE ALL REPOST WRAPPERS FIRST.
      //
      // THIS PREVENTS REPOST CARDS FROM SHOWING A
      // BROKEN/DELETED ORIGINAL.
      //===================================================

      if (!isRepost) {
        await _syncRootVisibility(
          rootPostId:
          postId,
          hidden:
          true,
        );
      }

      await postRef.delete();
    } catch (error) {
      rethrow;
    }
  }

  //===================================================
  // HIDE POST
  //
  // NEW RULE:
  // ONLY THE OWNER OF THE POST/REPOST CAN HIDE IT.
  //
  // THIS IS GLOBAL HIDE, NOT PERSONAL "I DON'T WANT
  // TO SEE THIS POST".
  //===================================================

  Future<void> hidePost(
      String postId,
      String uid,
      ) async {
    final String cleanPostId =
    postId.trim();

    final String cleanUid =
    uid.trim();

    if (cleanPostId.isEmpty ||
        cleanUid.isEmpty) {
      throw Exception(
        'Invalid post or user.',
      );
    }

    final DocumentReference<
        Map<String, dynamic>>
    postRef =
    _firestore
        .collection('posts')
        .doc(cleanPostId);

    final DocumentReference<
        Map<String, dynamic>>
    hiddenRef =
    _firestore
        .collection('users')
        .doc(cleanUid)
        .collection(
      'hiddenPosts',
    )
        .doc(cleanPostId);

    bool isRepost = false;

    //===================================================
    // TRANSACTION
    //
    // CHECK OWNERSHIP BEFORE HIDING.
    //===================================================

    await _firestore.runTransaction(
          (
          Transaction transaction,
          ) async {
        final DocumentSnapshot<
            Map<String, dynamic>>
        snapshot =
        await transaction.get(
          postRef,
        );

        if (!snapshot.exists ||
            snapshot.data() ==
                null) {
          throw Exception(
            'Post no longer exists.',
          );
        }

        final Map<String, dynamic>
        data =
        snapshot.data()!;

        final String ownerUid =
        (data['uid'] ?? '')
            .toString()
            .trim();

        if (ownerUid !=
            cleanUid) {
          throw Exception(
            'Only the owner of this post can hide it.',
          );
        }

        isRepost =
            data['isRepost'] ==
                true;

        //===================================================
        // HIDE POST GLOBALLY
        //===================================================

        transaction.update(
          postRef,
          <String, dynamic>{
            'isHidden':
            true,

            'hiddenAt':
            FieldValue
                .serverTimestamp(),

            'hiddenByUid':
            cleanUid,

            'updatedAt':
            FieldValue
                .serverTimestamp(),
          },
        );

        //===================================================
        // SAVE REFERENCE FOR:
        //
        // PROFILE -> ⋮ -> HIDDEN POSTS
        //===================================================

        transaction.set(
          hiddenRef,
          <String, dynamic>{
            'postId':
            cleanPostId,

            'uid':
            cleanUid,

            'isRepost':
            isRepost,

            'hiddenAt':
            FieldValue
                .serverTimestamp(),
          },
          SetOptions(
            merge: true,
          ),
        );
      },
    );

    //===================================================
    // IMPORTANT
    //
    // IF THIS IS THE REAL ORIGINAL POST:
    //
    // A hides Post A.
    //
    // B's repost of Post A must disappear.
    // C's quote repost of Post A must disappear.
    //
    // But hiding B's own repost must NOT hide A's
    // original post.
    //===================================================

    if (!isRepost) {
      await _syncRootVisibility(
        rootPostId:
        cleanPostId,
        hidden:
        true,
      );
    }
  }

  //===================================================
  // UNHIDE POST
  //
  // OWNER ONLY.
  //===================================================

  Future<void> unhidePost(
      String postId,
      String uid,
      ) async {
    final String cleanPostId =
    postId.trim();

    final String cleanUid =
    uid.trim();

    if (cleanPostId.isEmpty ||
        cleanUid.isEmpty) {
      throw Exception(
        'Invalid post or user.',
      );
    }

    final DocumentReference<
        Map<String, dynamic>>
    postRef =
    _firestore
        .collection('posts')
        .doc(cleanPostId);

    final DocumentReference<
        Map<String, dynamic>>
    hiddenRef =
    _firestore
        .collection('users')
        .doc(cleanUid)
        .collection(
      'hiddenPosts',
    )
        .doc(cleanPostId);

    bool isRepost = false;

    await _firestore.runTransaction(
          (
          Transaction transaction,
          ) async {
        final DocumentSnapshot<
            Map<String, dynamic>>
        snapshot =
        await transaction.get(
          postRef,
        );

        if (!snapshot.exists ||
            snapshot.data() ==
                null) {
          //===================================================
          // POST WAS DELETED.
          // CLEAN OLD HIDDEN REFERENCE.
          //===================================================

          transaction.delete(
            hiddenRef,
          );

          return;
        }

        final Map<String, dynamic>
        data =
        snapshot.data()!;

        final String ownerUid =
        (data['uid'] ?? '')
            .toString()
            .trim();

        if (ownerUid !=
            cleanUid) {
          throw Exception(
            'Only the owner of this post can unhide it.',
          );
        }

        isRepost =
            data['isRepost'] ==
                true;

        transaction.update(
          postRef,
          <String, dynamic>{
            'isHidden':
            false,

            'hiddenAt':
            FieldValue.delete(),

            'hiddenByUid':
            FieldValue.delete(),

            'updatedAt':
            FieldValue
                .serverTimestamp(),
          },
        );

        transaction.delete(
          hiddenRef,
        );
      },
    );

    //===================================================
    // ORIGINAL RETURNS -> ITS REPOSTS MAY RETURN TOO
    //===================================================

    if (!isRepost) {
      await _syncRootVisibility(
        rootPostId:
        cleanPostId,
        hidden:
        false,
      );
    }
  }

  //===================================================
  // IS POST HIDDEN
  //===================================================

  Future<bool> isPostHidden(
      String postId,
      ) async {
    final DocumentSnapshot<
        Map<String, dynamic>>
    snapshot =
    await _firestore
        .collection('posts')
        .doc(postId)
        .get();

    if (!snapshot.exists ||
        snapshot.data() ==
            null) {
      return false;
    }

    return snapshot.data()![
    'isHidden'] ==
        true;
  }

  //===================================================
  // STREAM OWNER'S HIDDEN POST REFERENCES
  //
  // USED BY PROFILE -> ⋮ -> HIDDEN POSTS
  //===================================================

  Stream<QuerySnapshot<
      Map<String, dynamic>>>
  hiddenPostsStream(
      String uid,
      ) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection(
      'hiddenPosts',
    )
        .orderBy(
      'hiddenAt',
      descending: true,
    )
        .snapshots();
  }

  //===================================================
  // GET OWNER'S HIDDEN POST IDS
  //===================================================

  Future<List<String>>
  getHiddenPostIds(
      String uid,
      ) async {
    final QuerySnapshot<
        Map<String, dynamic>>
    snapshot =
    await _firestore
        .collection('users')
        .doc(uid)
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
        return (document.data()[
        'postId'] ??
            document.id)
            .toString()
            .trim();
      },
    )
        .where(
          (
          String id,
          ) =>
      id.isNotEmpty,
    )
        .toList();
  }

  //===================================================
  // REPORT POST
  //
  // EXISTING FUNCTION KEPT.
  //===================================================

  Future<void> reportPost(
      String postId,
      String uid,
      ) async {
    await _firestore
        .collection('reports')
        .add(
      <String, dynamic>{
        'postId':
        postId,

        'reportedBy':
        uid,

        'createdAt':
        FieldValue
            .serverTimestamp(),
      },
    );
  }

  //===================================================
  // BLOCK USER
  //
  // EXISTING FUNCTION KEPT.
  //===================================================

  Future<void> blockUser(
      String currentUid,
      String blockedUid,
      ) async {
    await _firestore
        .collection('users')
        .doc(currentUid)
        .collection(
      'blockedUsers',
    )
        .doc(blockedUid)
        .set(
      <String, dynamic>{
        'uid':
        blockedUid,

        'blockedAt':
        FieldValue
            .serverTimestamp(),
      },
    );
  }

  //===================================================
  // SYNC ORIGINAL POST VISIBILITY TO ITS REPOSTS
  //
  // BOTH NEW AND OLD REPOST FORMATS ARE SUPPORTED:
  //
  // NEW:
  // rootOriginalPostId
  //
  // OLD:
  // originalPostId
  //===================================================

  Future<void> _syncRootVisibility({
    required String rootPostId,
    required bool hidden,
  }) async {
    final String cleanRootId =
    rootPostId.trim();

    if (cleanRootId.isEmpty) {
      return;
    }

    final Map<
        String,
        DocumentReference<
            Map<String, dynamic>>>
    references =
    <String,
        DocumentReference<
            Map<String, dynamic>>>{};

    //===================================================
    // NEW REPOST DOCUMENTS
    //===================================================

    try {
      final QuerySnapshot<
          Map<String, dynamic>>
      newFormat =
      await _firestore
          .collection('posts')
          .where(
        'rootOriginalPostId',
        isEqualTo:
        cleanRootId,
      )
          .get();

      for (
      final QueryDocumentSnapshot<
          Map<String, dynamic>>
      document
      in newFormat.docs
      ) {
        references[
        document.id] =
            document.reference;
      }
    } catch (error) {
      //===================================================
      // DON'T FAIL THE OWNER'S HIDE JUST BECAUSE AN
      // OLD REPOST QUERY HAS A PROBLEM.
      //===================================================

      print(
        'Root repost visibility query error: $error',
      );
    }

    //===================================================
    // OLD REPOST DOCUMENTS
    //===================================================

    try {
      final QuerySnapshot<
          Map<String, dynamic>>
      oldFormat =
      await _firestore
          .collection('posts')
          .where(
        'originalPostId',
        isEqualTo:
        cleanRootId,
      )
          .get();

      for (
      final QueryDocumentSnapshot<
          Map<String, dynamic>>
      document
      in oldFormat.docs
      ) {
        if (document.data()[
        'isRepost'] ==
            true) {
          references[
          document.id] =
              document.reference;
        }
      }
    } catch (error) {
      print(
        'Old repost visibility query error: $error',
      );
    }

    if (references.isEmpty) {
      return;
    }

    final List<
        DocumentReference<
            Map<String, dynamic>>>
    refs =
    references.values
        .toList();

    //===================================================
    // FIRESTORE MAX BATCH IS 500.
    // USE 400 FOR SAFETY.
    //===================================================

    const int batchSize =
    400;

    for (
    int start = 0;
    start < refs.length;
    start += batchSize
    ) {
      final int end =
      start + batchSize >
          refs.length
          ? refs.length
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
          refs[index],
          <String, dynamic>{
            'isRootHidden':
            hidden,

            'rootVisibilityUpdatedAt':
            FieldValue
                .serverTimestamp(),
          },
        );
      }

      await batch.commit();
    }
  }
}