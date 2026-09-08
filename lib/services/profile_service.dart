import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/post.dart';
import '../resources/storage_methods.dart';
import 'notification_service.dart';

//===================================================
// PROFILE SERVICE
//===================================================

class ProfileService {
  //===================================================
  // FIREBASE
  //===================================================

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  //===================================================
  // NOTIFICATION SERVICE
  //===================================================

  final NotificationService _notificationService = NotificationService();

  //===================================================
  // CURRENT USER ID
  //===================================================

  String? get currentUid => _auth.currentUser?.uid;

  //===================================================
  // USER STREAM
  //===================================================

  Stream<DocumentSnapshot<Map<String, dynamic>>> userStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots();
  }

  //===================================================
  // USER POSTS STREAM
  //===================================================

  Stream<QuerySnapshot<Map<String, dynamic>>> postsStream(String uid) {
    return _firestore
        .collection('posts')
        .where('uid', isEqualTo: uid)
        .snapshots();
  }

  //===================================================
  // LIKES RECEIVED STREAM
  //
  // TOTAL LIKES RECEIVED ON ALL POSTS CREATED BY USER
  //===================================================

  Stream<int> likesReceivedStream(String uid) {
    final String cleanUid = uid.trim();

    if (cleanUid.isEmpty) {
      return Stream<int>.value(0);
    }

    return _firestore
        .collection('posts')
        .where('uid', isEqualTo: cleanUid)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
          int totalLikes = 0;

          for (final QueryDocumentSnapshot<Map<String, dynamic>> post
              in snapshot.docs) {
            final dynamic rawLikeCount = post.data()['likeCount'];

            if (rawLikeCount is int) {
              totalLikes += rawLikeCount;
            } else if (rawLikeCount is num) {
              totalLikes += rawLikeCount.toInt();
            } else {
              totalLikes += int.tryParse(rawLikeCount?.toString() ?? '') ?? 0;
            }
          }

          return totalLikes;
        });
  }

  //===================================================
  // SAVED POSTS STREAM
  //===================================================

  Stream<List<Post>> savedPostsStream(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('savedPosts')
        .snapshots()
        .asyncMap((QuerySnapshot<Map<String, dynamic>> savedSnapshot) async {
          final List<MapEntry<DateTime, Post>> loaded =
              <MapEntry<DateTime, Post>>[];

          for (final QueryDocumentSnapshot<Map<String, dynamic>> savedDoc
              in savedSnapshot.docs) {
            final String postId = (savedDoc.data()['postId'] ?? savedDoc.id)
                .toString()
                .trim();

            if (postId.isEmpty) {
              continue;
            }

            final DocumentSnapshot<Map<String, dynamic>> postSnapshot =
                await _firestore.collection('posts').doc(postId).get();

            if (!postSnapshot.exists || postSnapshot.data() == null) {
              continue;
            }

            final dynamic savedAtRaw = savedDoc.data()['savedAt'];

            final DateTime savedAt = savedAtRaw is Timestamp
                ? savedAtRaw.toDate()
                : DateTime.fromMillisecondsSinceEpoch(0);

            loaded.add(
              MapEntry<DateTime, Post>(
                savedAt,
                Post.fromFirestore(postSnapshot),
              ),
            );
          }

          //===================================================
          // NEWEST SAVED POST FIRST
          //===================================================

          loaded.sort((MapEntry<DateTime, Post> a, MapEntry<DateTime, Post> b) {
            return b.key.compareTo(a.key);
          });

          return loaded
              .map((MapEntry<DateTime, Post> item) => item.value)
              .toList();
        });
  }

  //===================================================
  // FOLLOW / UNFOLLOW
  //===================================================

  Future<bool> toggleFollow(String targetUid) async {
    final String? uid = currentUid;

    if (uid == null || uid.isEmpty) {
      throw Exception('Please log in first.');
    }

    final String cleanTargetUid = targetUid.trim();

    if (cleanTargetUid.isEmpty || cleanTargetUid == uid) {
      return false;
    }

    final DocumentReference<Map<String, dynamic>> currentRef = _firestore
        .collection('users')
        .doc(uid);

    final DocumentReference<Map<String, dynamic>> targetRef = _firestore
        .collection('users')
        .doc(cleanTargetUid);

    //===================================================
    // UPDATE FOLLOW DATA
    //===================================================

    final bool nowFollowing = await _firestore.runTransaction<bool>((
      Transaction transaction,
    ) async {
      final DocumentSnapshot<Map<String, dynamic>> currentSnapshot =
          await transaction.get(currentRef);

      final DocumentSnapshot<Map<String, dynamic>> targetSnapshot =
          await transaction.get(targetRef);

      if (!currentSnapshot.exists || !targetSnapshot.exists) {
        throw Exception('User profile was not found.');
      }

      final List<String> following = List<String>.from(
        currentSnapshot.data()?['following'] ?? <String>[],
      );

      final List<String> followers = List<String>.from(
        targetSnapshot.data()?['followers'] ?? <String>[],
      );

      final bool isFollowing = following.contains(cleanTargetUid);

      //===================================================
      // UNFOLLOW
      //===================================================

      if (isFollowing) {
        following.remove(cleanTargetUid);

        followers.remove(uid);
      }
      //===================================================
      // FOLLOW
      //===================================================
      else {
        if (!following.contains(cleanTargetUid)) {
          following.add(cleanTargetUid);
        }

        if (!followers.contains(uid)) {
          followers.add(uid);
        }
      }

      //===================================================
      // UPDATE CURRENT USER
      //===================================================

      transaction.update(currentRef, <String, dynamic>{'following': following});

      //===================================================
      // UPDATE TARGET USER
      //===================================================

      transaction.update(targetRef, <String, dynamic>{'followers': followers});

      return !isFollowing;
    });

    //===================================================
    // SEND FOLLOW NOTIFICATION
    //
    // Only send when user FOLLOWED.
    // Do not send when user UNFOLLOWED.
    //===================================================

    if (nowFollowing) {
      try {
        await _notificationService.notifyFollow(receiverId: cleanTargetUid);
      } catch (_) {
        //===================================================
        // FOLLOW MUST STILL SUCCEED EVEN IF
        // NOTIFICATION CREATION FAILS
        //===================================================
      }
    }

    return nowFollowing;
  }

  //===================================================
  // PIN / UNPIN POST
  // MAXIMUM = 3 POSTS
  //===================================================

  Future<bool> togglePinPost(String postId) async {
    final String? uid = currentUid;

    if (uid == null || uid.isEmpty) {
      throw Exception('Please log in first.');
    }

    final DocumentReference<Map<String, dynamic>> userRef = _firestore
        .collection('users')
        .doc(uid);

    final DocumentReference<Map<String, dynamic>> postRef = _firestore
        .collection('posts')
        .doc(postId);

    return _firestore.runTransaction<bool>((Transaction transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> userSnapshot =
          await transaction.get(userRef);

      final DocumentSnapshot<Map<String, dynamic>> postSnapshot =
          await transaction.get(postRef);

      if (!postSnapshot.exists || postSnapshot.data() == null) {
        throw Exception('This post no longer exists.');
      }

      final String postOwnerUid = (postSnapshot.data()?['uid'] ?? '')
          .toString();

      if (postOwnerUid != uid) {
        throw Exception('You can only pin your own post.');
      }

      final List<String> pinnedPostIds = List<String>.from(
        userSnapshot.data()?['pinnedPostIds'] ?? <String>[],
      );

      final bool isPinned = pinnedPostIds.contains(postId);

      //===================================================
      // UNPIN
      //===================================================

      if (isPinned) {
        pinnedPostIds.remove(postId);
      }
      //===================================================
      // PIN
      //===================================================
      else {
        if (pinnedPostIds.length >= 3) {
          throw Exception('You can pin only 3 posts to your profile.');
        }

        pinnedPostIds.insert(0, postId);
      }

      transaction.set(userRef, <String, dynamic>{
        'pinnedPostIds': pinnedPostIds,
      }, SetOptions(merge: true));

      return !isPinned;
    });
  }

  //===================================================
  // REPORT USER
  //===================================================

  Future<void> reportUser({
    required String targetUid,
    required String reason,
    String details = '',
  }) async {
    final String? uid = currentUid;

    if (uid == null || uid.isEmpty) {
      throw Exception('Please log in first.');
    }

    if (targetUid == uid) {
      throw Exception('You cannot report yourself.');
    }

    await _firestore.collection('reports').add(<String, dynamic>{
      'type': 'user',

      'reportedUserId': targetUid,

      'reportedBy': uid,

      'reason': reason,

      'details': details.trim(),

      'status': 'pending',

      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  //===================================================
  // BLOCK USER
  //===================================================

  Future<void> blockUser(String targetUid) async {
    final String? uid = currentUid;

    if (uid == null || uid.isEmpty) {
      throw Exception('Please log in first.');
    }

    if (targetUid == uid) {
      throw Exception('You cannot block yourself.');
    }

    await _firestore
        .collection('users')
        .doc(uid)
        .collection('blockedUsers')
        .doc(targetUid)
        .set(<String, dynamic>{
          'uid': targetUid,

          'blockedAt': FieldValue.serverTimestamp(),
        });
  }

  //===================================================
  // UNBLOCK USER
  //===================================================

  Future<void> unblockUser(String targetUid) async {
    final String? uid = currentUid;

    if (uid == null || uid.isEmpty) {
      return;
    }

    await _firestore
        .collection('users')
        .doc(uid)
        .collection('blockedUsers')
        .doc(targetUid)
        .delete();
  }

  //===================================================
  // IS USER BLOCKED
  //===================================================

  Future<bool> isBlocked(String targetUid) async {
    final String? uid = currentUid;

    if (uid == null || uid.isEmpty) {
      return false;
    }

    final DocumentSnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('blockedUsers')
        .doc(targetUid)
        .get();

    return snapshot.exists;
  }

  //===================================================
  // USERNAME AVAILABLE
  //===================================================

  Future<bool> isUsernameAvailable({
    required String username,
    required String currentUid,
  }) async {
    final String normalized = username.trim().toLowerCase();

    if (normalized.isEmpty) {
      return false;
    }

    //===================================================
    // CHECK USERS WITH usernameLower
    //===================================================

    final QuerySnapshot<Map<String, dynamic>> direct = await _firestore
        .collection('users')
        .where('usernameLower', isEqualTo: normalized)
        .limit(2)
        .get();

    if (direct.docs.any(
      (QueryDocumentSnapshot<Map<String, dynamic>> doc) => doc.id != currentUid,
    )) {
      return false;
    }

    if (direct.docs.isNotEmpty) {
      return true;
    }

    //===================================================
    // OLD USERS WITHOUT usernameLower
    //===================================================

    final QuerySnapshot<Map<String, dynamic>> fallback = await _firestore
        .collection('users')
        .get();

    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in fallback.docs) {
      if (doc.id == currentUid) {
        continue;
      }

      final String existing = (doc.data()['username'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

      if (existing == normalized) {
        return false;
      }
    }

    return true;
  }

  //===================================================
  // UPDATE PROFILE
  //===================================================

  Future<void> updateProfile({
    required String fullName,
    required String username,
    required String faculty,
    required String hobbies,
    required String favoriteQuote,
    Uint8List? newPhoto,
    bool removePhoto = false,
  }) async {
    final User? authUser = _auth.currentUser;

    if (authUser == null) {
      throw Exception('Please log in first.');
    }

    //===================================================
    // CLEAN VALUES
    //===================================================

    final String cleanFullName = fullName.trim();

    final String cleanUsername = username.trim();

    final String cleanFaculty = faculty.trim();

    final String cleanHobbies = hobbies.trim();

    final String cleanQuote = favoriteQuote.trim();

    //===================================================
    // VALIDATION
    //===================================================

    if (cleanFullName.isEmpty ||
        cleanUsername.isEmpty ||
        cleanFaculty.isEmpty) {
      throw Exception('Full name, username and faculty are required.');
    }

    //===================================================
    // CHECK USERNAME
    //===================================================

    final bool available = await isUsernameAvailable(
      username: cleanUsername,

      currentUid: authUser.uid,
    );

    if (!available) {
      throw Exception('That username is already taken.');
    }
    //===================================================
    // CHANGE OR REMOVE PROFILE PICTURE
    //===================================================

    String? photoUrl;

    if (removePhoto) {
      photoUrl = '';
    } else if (newPhoto != null) {
      photoUrl = await StorageMethods().uploadImageToStorage(
        'profilePics',
        newPhoto,
        false,
      );
    }
    //===================================================
    // USER UPDATE DATA
    //===================================================

    final Map<String, dynamic> update = <String, dynamic>{
      'fullName': cleanFullName,

      'username': cleanUsername,

      'usernameLower': cleanUsername.toLowerCase(),

      'faculty': cleanFaculty,

      'hobbies': cleanHobbies,

      'favoriteQuote': cleanQuote,

      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (photoUrl != null) {
      update['photoUrl'] = photoUrl;
    }

    //===================================================
    // UPDATE USER DOCUMENT
    //===================================================

    await _firestore.collection('users').doc(authUser.uid).update(update);

    //===================================================
    // UPDATE NAME / USERNAME / PHOTO
    // ON EXISTING POSTS
    //===================================================

    final QuerySnapshot<Map<String, dynamic>> posts = await _firestore
        .collection('posts')
        .where('uid', isEqualTo: authUser.uid)
        .get();

    WriteBatch batch = _firestore.batch();

    int operations = 0;

    //===================================================
    // COMMIT BATCH WHEN NEEDED
    //===================================================

    Future<void> commitIfNeeded() async {
      if (operations == 0) {
        return;
      }

      await batch.commit();

      batch = _firestore.batch();

      operations = 0;
    }

    //===================================================
    // UPDATE OLD POSTS
    //===================================================

    for (final QueryDocumentSnapshot<Map<String, dynamic>> post in posts.docs) {
      final Map<String, dynamic> postUpdate = <String, dynamic>{
        'fullName': cleanFullName,

        'username': cleanUsername,
      };

      if (photoUrl != null) {
        postUpdate['photoUrl'] = photoUrl;
      }

      batch.update(post.reference, postUpdate);

      operations++;

      if (operations >= 400) {
        await commitIfNeeded();
      }
    }

    //===================================================
    // UPDATE NAME / USERNAME / PHOTO
    // ON EXISTING STORIES
    //===================================================

    final QuerySnapshot<Map<String, dynamic>> stories = await _firestore
        .collection('stories')
        .where('uid', isEqualTo: authUser.uid)
        .get();

    for (final QueryDocumentSnapshot<Map<String, dynamic>> story
        in stories.docs) {
      final Map<String, dynamic> storyUpdate = <String, dynamic>{
        'fullName': cleanFullName,

        'username': cleanUsername,
      };

      if (photoUrl != null) {
        storyUpdate['photoUrl'] = photoUrl;
      }

      batch.update(story.reference, storyUpdate);

      operations++;

      if (operations >= 400) {
        await commitIfNeeded();
      }
    }

    //===================================================
    // COMMIT REMAINING OPERATIONS
    //===================================================

    await commitIfNeeded();
  }

  //===================================================
  // CHANGE PASSWORD
  //===================================================

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final User? user = _auth.currentUser;

    if (user == null || user.email == null) {
      throw Exception('Please log in again.');
    }

    //===================================================
    // VALIDATE NEW PASSWORD
    //===================================================

    if (newPassword.length < 6) {
      throw Exception('New password must be at least 6 characters.');
    }

    //===================================================
    // CREATE CURRENT PASSWORD CREDENTIAL
    //===================================================

    final AuthCredential credential = EmailAuthProvider.credential(
      email: user.email!,

      password: currentPassword,
    );

    //===================================================
    // REAUTHENTICATE USER
    //===================================================

    await user.reauthenticateWithCredential(credential);

    //===================================================
    // CHANGE PASSWORD
    //===================================================

    await user.updatePassword(newPassword);
  }
}
