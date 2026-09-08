import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RepostService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  //===================================================
  // PLAIN REPOST
  //===================================================

  Future<String> repost(
      String originalPostId,
      ) async {
    final User? user =
        _auth.currentUser;

    if (user == null) {
      throw Exception(
        'Please log in to repost.',
      );
    }

    final String repostId =
        'repost_${user.uid}_$originalPostId';

    final DocumentReference<
        Map<String, dynamic>>
    repostRef =
    _firestore
        .collection('posts')
        .doc(repostId);

    final DocumentSnapshot<
        Map<String, dynamic>>
    oldRepost =
    await repostRef.get();

    if (oldRepost.exists) {
      return repostId;
    }

    return _createRepost(
      originalPostId:
      originalPostId,
      repostId: repostId,
      type: 'repost',
      quote: '',
    );
  }

  //===================================================
  // QUOTE REPOST
  //===================================================

  Future<String> quoteRepost({
    required String
    originalPostId,
    required String text,
  }) async {
    final User? user =
        _auth.currentUser;

    if (user == null) {
      throw Exception(
        'Please log in to repost.',
      );
    }

    final String repostId =
        _firestore
            .collection('posts')
            .doc()
            .id;

    return _createRepost(
      originalPostId:
      originalPostId,
      repostId: repostId,
      type: 'quote',
      quote: text.trim(),
    );
  }

  //===================================================
  // CREATE REPOST DOCUMENT
  //===================================================

  Future<String> _createRepost({
    required String
    originalPostId,
    required String repostId,
    required String type,
    required String quote,
  }) async {
    final User user =
    _auth.currentUser!;

    final DocumentReference<
        Map<String, dynamic>>
    originalRef =
    _firestore
        .collection('posts')
        .doc(originalPostId);

    final DocumentSnapshot<
        Map<String, dynamic>>
    originalSnapshot =
    await originalRef.get();

    if (!originalSnapshot.exists) {
      throw Exception(
        'Original post no longer exists.',
      );
    }

    final Map<String, dynamic>
    original =
        originalSnapshot.data() ??
            <String, dynamic>{};

    final DocumentSnapshot<
        Map<String, dynamic>>
    userSnapshot =
    await _firestore
        .collection('users')
        .doc(user.uid)
        .get();

    final Map<String, dynamic>
    profile =
        userSnapshot.data() ??
            <String, dynamic>{};

    final String username =
    (profile['username'] ??
        '')
        .toString();

    final String fullName =
    (profile['fullName'] ??
        user.displayName ??
        '')
        .toString();

    final String photoUrl =
    (profile['photoUrl'] ??
        user.photoURL ??
        '')
        .toString();

    final DocumentReference<
        Map<String, dynamic>>
    repostRef =
    _firestore
        .collection('posts')
        .doc(repostId);

    final Map<String, dynamic>
    repost =
    Map<String, dynamic>.from(
      original,
    );

    //===================================================
    // REPOST OWNER
    //===================================================

    repost['postId'] =
        repostId;

    repost['uid'] =
        user.uid;

    repost['username'] =
        username;

    repost['fullName'] =
        fullName;

    repost['photoUrl'] =
        photoUrl;

    //===================================================
    // REPOST METADATA
    //===================================================

    repost['isRepost'] =
    true;

    repost['repostType'] =
        type;

    repost['repostText'] =
        quote;

    repost['originalPostId'] =
        originalPostId;

    repost['originalUid'] =
        (original['uid'] ?? '')
            .toString();

    repost['originalUsername'] =
        (original['username'] ??
            '')
            .toString();

    repost['originalFullName'] =
        (original['fullName'] ??
            '')
            .toString();

    repost['originalPhotoUrl'] =
        (original['photoUrl'] ??
            '')
            .toString();

    repost['originalCaption'] =
        (original['caption'] ??
            '')
            .toString();

    repost['repostedByUid'] =
        user.uid;

    repost['repostedByUsername'] =
        username;

    repost['repostedByFullName'] =
        fullName;

    repost['repostedAt'] =
        FieldValue
            .serverTimestamp();

    //===================================================
    // IT IS A HOME REPOST, NOT A SECOND NUBUZZ ENTRY
    //===================================================

    repost['isNUBuzz'] =
    false;

    repost['postType'] =
    'repost';

    //===================================================
    // NEW INTERACTION COUNTS
    //===================================================

    repost['likes'] =
    <String>[];

    repost['likedUserIds'] =
    <String>[];

    repost['likeCount'] = 0;
    repost['commentCount'] = 0;
    repost['repostCount'] = 0;
    repost['shareCount'] = 0;
    repost['viewCount'] = 0;

    //===================================================
    // DO NOT COPY A VOTED POLL AS A NEW POLL
    //===================================================

    repost['hasPoll'] =
    false;

    repost.remove(
      'poll',
    );

    repost['createdAt'] =
        FieldValue
            .serverTimestamp();

    repost['updatedAt'] =
        FieldValue
            .serverTimestamp();

    final WriteBatch batch =
    _firestore.batch();

    batch.set(
      repostRef,
      repost,
    );

    batch.update(
      originalRef,
      <String, dynamic>{
        'repostCount':
        FieldValue.increment(
          1,
        ),
      },
    );

    final String originalOwner =
    (original['uid'] ?? '')
        .toString();

    if (originalOwner.isNotEmpty &&
        originalOwner !=
            user.uid) {
      final DocumentReference<
          Map<String, dynamic>>
      notificationRef =
      _firestore
          .collection(
        'notifications',
      )
          .doc();

      batch.set(
        notificationRef,
        <String, dynamic>{
          'notificationId':
          notificationRef.id,
          'uid':
          originalOwner,
          'senderUid':
          user.uid,
          'type':
          type == 'quote'
              ? 'quoteRepost'
              : 'repost',
          'postId':
          originalPostId,
          'repostPostId':
          repostId,
          'isRead': false,
          'createdAt':
          FieldValue
              .serverTimestamp(),
        },
      );
    }

    await batch.commit();

    return repostId;
  }

  //===================================================
  // HAS REPOSTED
  //===================================================

  Future<bool> hasReposted(
      String originalPostId,
      ) async {
    final User? user =
        _auth.currentUser;

    if (user == null) {
      return false;
    }

    final String id =
        'repost_${user.uid}_$originalPostId';

    final DocumentSnapshot<
        Map<String, dynamic>>
    snapshot =
    await _firestore
        .collection('posts')
        .doc(id)
        .get();

    return snapshot.exists;
  }

  //===================================================
  // DELETE REPOST
  //===================================================

  Future<void> deleteRepost(
      String repostPostId,
      ) async {
    final User? user =
        _auth.currentUser;

    if (user == null) {
      return;
    }

    final DocumentReference<
        Map<String, dynamic>>
    repostRef =
    _firestore
        .collection('posts')
        .doc(repostPostId);

    await _firestore
        .runTransaction(
          (
          Transaction transaction,
          ) async {
        final DocumentSnapshot<
            Map<String, dynamic>>
        snapshot =
        await transaction
            .get(repostRef);

        if (!snapshot.exists) {
          return;
        }

        final Map<String, dynamic>
        data =
            snapshot.data() ??
                <String, dynamic>{};

        if (data['uid']
            ?.toString() !=
            user.uid) {
          throw Exception(
            'Only the repost owner can delete it.',
          );
        }

        final String originalId =
        (data['originalPostId'] ??
            '')
            .toString();

        transaction.delete(
          repostRef,
        );

        if (originalId.isNotEmpty) {
          final DocumentReference<
              Map<String,
                  dynamic>>
          originalRef =
          _firestore
              .collection(
            'posts',
          )
              .doc(
            originalId,
          );

          final DocumentSnapshot<
              Map<String,
                  dynamic>>
          originalSnapshot =
          await transaction
              .get(
            originalRef,
          );

          if (originalSnapshot
              .exists) {
            final int count =
            ((originalSnapshot
                .data()?[
            'repostCount']
            is num
                ? originalSnapshot
                .data()![
            'repostCount']
            as num
                : 0))
                .toInt();

            transaction.update(
              originalRef,
              <String, dynamic>{
                'repostCount':
                count > 0
                    ? count - 1
                    : 0,
              },
            );
          }
        }
      },
    );
  }
}