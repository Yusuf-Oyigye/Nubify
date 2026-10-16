import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'notification_service.dart';

//===================================================
// REPOST SERVICE
//===================================================

class RepostService {
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
  // POSTS COLLECTION
  //===================================================

  CollectionReference<Map<String, dynamic>> get _posts =>
      _firestore.collection('posts');

  //===================================================
  // PLAIN REPOST
  //
  // ONE PLAIN REPOST PER USER PER EXACT POST / REPOST.
  //
  // USER CAN STILL QUOTE REPOST THE SAME TARGET ONCE.
  //===================================================

  Future<String> repost(String originalPostId) async {
    final User user = _requireUser();

    final String requestedPostId = originalPostId.trim();

    if (requestedPostId.isEmpty) {
      throw Exception('Post could not be found.');
    }

    //===================================================
    // EXACT DIRECT TARGET
    //
    // ORIGINAL POST A AND REPOST B ARE DIFFERENT TARGETS.
    //===================================================

    final String sourcePostId = requestedPostId;

    //===================================================
    // CHECK EXISTING PLAIN REPOST
    //===================================================

    final bool alreadyReposted = await hasReposted(sourcePostId);

    if (alreadyReposted) {
      throw Exception('ALREADY_REPOSTED');
    }

    //===================================================
    // TRUE ROOT ORIGINAL
    //===================================================

    final String rootPostId = await resolveRootPostId(sourcePostId);

    if (rootPostId.isEmpty) {
      throw Exception('Original post could not be found.');
    }

    //===================================================
    // ONE PLAIN REPOST ID PER USER + EXACT TARGET
    //===================================================

    final String repostId = 'repost_${user.uid}_$sourcePostId';

    return _createRepost(
      sourcePostId: sourcePostId,
      rootPostId: rootPostId,
      repostId: repostId,
      type: 'repost',
      quote: '',
      currentUser: user,
    );
  }
  //===================================================
  // QUOTE REPOST
  //
  // ONE QUOTE REPOST PER USER PER EXACT POST / REPOST.
  //
  // PLAIN REPOST IS SEPARATE.
  //
  // USER CAN DO:
  // 1 PLAIN REPOST
  // 1 QUOTE REPOST
  //===================================================

  Future<String> quoteRepost({
    required String originalPostId,
    required String text,
  }) async {
    final User user = _requireUser();

    final String requestedPostId = originalPostId.trim();

    final String quote = text.trim();

    if (requestedPostId.isEmpty) {
      throw Exception('Post could not be found.');
    }

    //===================================================
    // EXACT DIRECT TARGET
    //===================================================

    final String sourcePostId = requestedPostId;

    //===================================================
    // CHECK EXISTING QUOTE REPOST
    //===================================================

    final bool alreadyQuoteReposted = await hasQuoteReposted(sourcePostId);

    if (alreadyQuoteReposted) {
      throw Exception('ALREADY_QUOTE_REPOSTED');
    }

    //===================================================
    // TRUE ROOT ORIGINAL
    //===================================================

    final String rootPostId = await resolveRootPostId(sourcePostId);

    if (rootPostId.isEmpty) {
      throw Exception('Original post could not be found.');
    }

    //===================================================
    // ONE QUOTE REPOST ID PER USER + EXACT TARGET
    //
    // DIFFERENT FROM PLAIN REPOST ID.
    //===================================================

    final String repostId = 'quote_${user.uid}_$sourcePostId';

    return _createRepost(
      sourcePostId: sourcePostId,
      rootPostId: rootPostId,
      repostId: repostId,
      type: 'quote',
      quote: quote,
      currentUser: user,
    );
  }

  //===================================================
  // CREATE REPOST / QUOTE REPOST DOCUMENT
  //===================================================

  Future<String> _createRepost({
    required String sourcePostId,
    required String rootPostId,
    required String repostId,
    required String type,
    required String quote,
    User? currentUser,
  }) async {
    final User user = currentUser ?? _requireUser();

    //===================================================
    // REFERENCES
    //===================================================

    final DocumentReference<Map<String, dynamic>> sourceRef = _posts.doc(
      sourcePostId,
    );

    final DocumentReference<Map<String, dynamic>> rootRef = _posts.doc(
      rootPostId,
    );

    final DocumentReference<Map<String, dynamic>> repostRef = _posts.doc(
      repostId,
    );

    //===================================================
    // LOAD SOURCE POST
    //===================================================

    final DocumentSnapshot<Map<String, dynamic>> sourceSnapshot =
        await sourceRef.get();

    if (!sourceSnapshot.exists || sourceSnapshot.data() == null) {
      throw Exception('Post no longer exists.');
    }

    final Map<String, dynamic> source = sourceSnapshot.data()!;

    //===================================================
    // SOURCE VISIBILITY CHECK
    //===================================================

    if (source['isHidden'] == true || source['isRootHidden'] == true) {
      throw Exception('This post is currently hidden.');
    }

    //===================================================
    // LOAD ROOT ORIGINAL
    //===================================================

    DocumentSnapshot<Map<String, dynamic>> rootSnapshot = sourceSnapshot;

    if (rootPostId != sourcePostId) {
      rootSnapshot = await rootRef.get();
    }

    if (!rootSnapshot.exists || rootSnapshot.data() == null) {
      throw Exception('Original post no longer exists.');
    }

    final Map<String, dynamic> root = rootSnapshot.data()!;

    //===================================================
    // ROOT VISIBILITY CHECK
    //===================================================

    if (root['isHidden'] == true || root['isRootHidden'] == true) {
      throw Exception('This post is currently hidden.');
    }

    //===================================================
    // LOAD REPOSTER PROFILE
    //===================================================

    final DocumentSnapshot<Map<String, dynamic>> profileSnapshot =
        await _firestore.collection('users').doc(user.uid).get();

    final Map<String, dynamic> profile =
        profileSnapshot.data() ?? <String, dynamic>{};

    //===================================================
    // REPOSTER DETAILS
    //===================================================

    final String username = (profile['username'] ?? '').toString().trim();

    final String fullName = (profile['fullName'] ?? user.displayName ?? '')
        .toString()
        .trim();

    final String photoUrl = (profile['photoUrl'] ?? user.photoURL ?? '')
        .toString()
        .trim();

    //===================================================
    // TRUE ORIGINAL DETAILS
    //===================================================

    final String originalOwnerUid = (root['uid'] ?? '').toString().trim();

    final String originalUsername = (root['username'] ?? '').toString().trim();

    final String originalFullName = (root['fullName'] ?? '').toString().trim();

    final String originalPhotoUrl = (root['photoUrl'] ?? '').toString().trim();

    final String originalCaption = (root['caption'] ?? '').toString();

    final dynamic originalCreatedAt = root['createdAt'];

    //===================================================
    // DIRECT SOURCE OWNER
    //
    // THIS CAN BE:
    //
    // ORIGINAL AUTHOR
    // OR QUOTE-REPOST AUTHOR.
    //===================================================

    final String sourceOwnerUid = (source['uid'] ?? '').toString().trim();

    final bool quoteRepost = type == 'quote';

    final Timestamp clientNow = Timestamp.now();

    //===================================================
    // REPOST DOCUMENT
    //===================================================

    final Map<String, dynamic> repostData = <String, dynamic>{
      //===================================================
      // BASIC POST ID
      //===================================================

      'postId': repostId,

      //===================================================
      // REPOSTER
      //===================================================
      'uid': user.uid,

      'username': username,

      'fullName': fullName,

      'photoUrl': photoUrl,

      //===================================================
      // OWN TEXT
      //
      // PLAIN REPOST -> EMPTY
      //
      // QUOTE REPOST -> USER QUOTE
      //===================================================
      'caption': quoteRepost ? quote : '',

      //===================================================
      // OWN MEDIA
      //
      // REFERENCED CONTENT IS LOADED FROM sourcePostId.
      //===================================================
      'media': <dynamic>[],

      'mediaCount': 0,

      //===================================================
      // NUBUZZ
      //===================================================
      'isNUBuzz': false,

      //===================================================
      // POST TYPE
      //===================================================
      'postType': 'repost',

      //===================================================
      // POLL
      //
      // REPOST WRAPPER ITSELF HAS NO NEW POLL.
      // REFERENCED POST MAY HAVE A POLL.
      //===================================================
      'hasPoll': false,

      //===================================================
      // TAGS
      //===================================================
      'taggedUsers': <dynamic>[],

      'taggedUserIds': <String>[],

      //===================================================
      // REPOST'S OWN ENGAGEMENT
      //===================================================
      'likes': <String>[],

      'likedUserIds': <String>[],

      'likeCount': 0,

      'commentCount': 0,

      'repostCount': 0,

      'shareCount': 0,

      'viewCount': 0,

      //===================================================
      // REPOST FLAGS
      //===================================================
      'isRepost': true,

      'repostType': quoteRepost ? 'quote' : 'repost',

      'repostText': quoteRepost ? quote : '',

      'repostCaption': quoteRepost ? quote : '',

      //===================================================
      // TRUE ROOT ORIGINAL
      //===================================================
      'originalPostId': rootPostId,

      'rootOriginalPostId': rootPostId,

      //===================================================
      // DIRECT SOURCE
      //
      // THIS IS THE POST THIS REPOST SHOULD SHOW.
      //
      // FOR QUOTE OF QUOTE:
      // sourcePostId CAN POINT TO ANOTHER QUOTE POST.
      //===================================================
      'sourcePostId': sourcePostId,

      //===================================================
      // ORIGINAL FALLBACK DETAILS
      //===================================================
      'originalUid': originalOwnerUid,

      'originalUsername': originalUsername,

      'originalFullName': originalFullName,

      'originalPhotoUrl': originalPhotoUrl,

      'originalCaption': originalCaption,

      'originalCreatedAt': originalCreatedAt,

      //===================================================
      // REPOSTER FALLBACK DETAILS
      //===================================================
      'repostedByUid': user.uid,

      'repostedByUsername': username,

      'repostedByFullName': fullName,

      'repostedByPhotoUrl': photoUrl,

      //===================================================
      // VISIBILITY
      //===================================================
      'isHidden': false,

      'isRootHidden': false,

      //===================================================
      // TIME
      //===================================================
      'createdAt': FieldValue.serverTimestamp(),

      'repostedAt': FieldValue.serverTimestamp(),

      'clientCreatedAt': clientNow,

      'updatedAt': FieldValue.serverTimestamp(),
    };

    //=================================
    // UNIQUE REPOST WRITE
    //
    // BOTH PLAIN AND QUOTE REPOSTS NOW USE
    // DETERMINISTIC IDS.
    //
    // THIS TRANSACTION STOPS FAST DOUBLE-TAPS
    // FROM CREATING / COUNTING THE SAME ACTION TWICE.
    //=================================

    final Map<String, dynamic> coreRepostData = Map<String, dynamic>.from(
      repostData,
    );

    //=================================
    // ATOMIC UNIQUE WRITE
    //=================================

    Future<void> writeCore(Map<String, dynamic> data) async {
      await _firestore.runTransaction((Transaction transaction) async {
        final DocumentSnapshot<Map<String, dynamic>> existing =
            await transaction.get(repostRef);

        //=================================
        // ACTION ALREADY EXISTS
        //=================================

        if (existing.exists) {
          throw Exception(
            quoteRepost ? 'ALREADY_QUOTE_REPOSTED' : 'ALREADY_REPOSTED',
          );
        }

        //=================================
        // CREATE EXACTLY ONCE
        //=================================

        transaction.set(repostRef, data);
      });
    }

    //=================================
    // NORMAL WRITE + COMPATIBILITY
    //=================================

    try {
      await writeCore(coreRepostData);
    } on FirebaseException catch (error) {
      final bool canTryCompatibility =
          error.code == 'permission-denied' ||
          error.code == 'failed-precondition' ||
          error.code == 'invalid-argument';

      if (!canTryCompatibility) {
        rethrow;
      }

      final Map<String, dynamic> compatibilityData = Map<String, dynamic>.from(
        coreRepostData,
      );

      compatibilityData['postType'] = 'text';

      compatibilityData['poll'] = null;

      await writeCore(compatibilityData);
    }
    //===================================================
    // DIRECT SOURCE REPOST COUNT
    // BEST-EFFORT ONLY
    //===================================================

    unawaited(
      sourceRef
          .update(<String, dynamic>{'repostCount': FieldValue.increment(1)})
          .timeout(const Duration(seconds: 6))
          .catchError((Object error) {
            print('Source repost-count error: $error');
          }),
    );

    //===================================================
    // ROOT AGGREGATE COUNT
    // BEST-EFFORT ONLY
    //===================================================

    if (rootPostId != sourcePostId) {
      unawaited(
        rootRef
            .update(<String, dynamic>{'repostCount': FieldValue.increment(1)})
            .timeout(const Duration(seconds: 6))
            .catchError((Object error) {
              print('Root repost-count error: $error');
            }),
      );
    }

    //===================================================
    // REPOST / QUOTE NOTIFICATION
    // BEST-EFFORT ONLY
    //===================================================

    if (sourceOwnerUid.isNotEmpty && sourceOwnerUid != user.uid) {
      final Future<void> notificationFuture = quoteRepost
          ? _notificationService.notifyQuoteRepost(
              postOwnerId: sourceOwnerUid,
              postId: sourcePostId,
              repostPostId: repostId,
            )
          : _notificationService.notifyRepost(
              postOwnerId: sourceOwnerUid,
              postId: sourcePostId,
              repostPostId: repostId,
            );

      unawaited(
        notificationFuture.timeout(const Duration(seconds: 6)).catchError((
          Object error,
        ) {
          print('Repost notification error: $error');
        }),
      );
    }

    return repostId;
  }

  //===================================================
  // RESOLVE TRUE ROOT ORIGINAL POST
  //
  // EXAMPLE:
  //
  // QUOTE C
  // -> QUOTE B
  // -> QUOTE A
  // -> ORIGINAL
  //
  // RETURNS ORIGINAL
  //===================================================

  Future<String> resolveRootPostId(String postId) async {
    String currentId = postId.trim();

    if (currentId.isEmpty) {
      return '';
    }

    final Set<String> visited = <String>{};

    for (int depth = 0; depth < 12; depth++) {
      if (currentId.isEmpty || visited.contains(currentId)) {
        break;
      }

      visited.add(currentId);

      final DocumentSnapshot<Map<String, dynamic>> snapshot = await _posts
          .doc(currentId)
          .get();

      if (!snapshot.exists || snapshot.data() == null) {
        return currentId;
      }

      final Map<String, dynamic> data = snapshot.data()!;

      final bool isRepost =
          data['isRepost'] == true ||
          (data['repostType'] ?? '').toString().trim().isNotEmpty;

      //===================================================
      // NORMAL POST IS THE ROOT
      //===================================================

      if (!isRepost) {
        return snapshot.id;
      }

      //===================================================
      // NEW ROOT FIELD
      //===================================================

      final String explicitRoot = (data['rootOriginalPostId'] ?? '')
          .toString()
          .trim();

      if (explicitRoot.isNotEmpty && explicitRoot != currentId) {
        currentId = explicitRoot;

        continue;
      }

      //===================================================
      // OLD ORIGINAL FIELD
      //===================================================

      final String oldOriginal = (data['originalPostId'] ?? '')
          .toString()
          .trim();

      if (oldOriginal.isNotEmpty && oldOriginal != currentId) {
        currentId = oldOriginal;

        continue;
      }

      //===================================================
      // SOURCE FALLBACK
      //===================================================

      final String sourcePostId = (data['sourcePostId'] ?? '')
          .toString()
          .trim();

      if (sourcePostId.isNotEmpty && sourcePostId != currentId) {
        currentId = sourcePostId;

        continue;
      }

      return currentId;
    }

    return currentId;
  }

  //===================================================
  // RESOLVE DISTINCT INTERACTION TARGET
  //
  // NORMAL POST
  // -> RETURNS ITSELF
  //
  // QUOTE POST
  // -> RETURNS QUOTE POST ITSELF
  //
  // PLAIN REPOST
  // -> FOLLOWS WHAT IT SHARES
  //
  // THIS ALLOWS:
  //
  // USER CAN REPOST NORMAL POST ONCE.
  //
  // USER CAN REPOST A QUOTE POST ONCE.
  //
  // USER CAN CREATE NEW QUOTE REPOSTS REPEATEDLY.
  //===================================================

  Future<String> resolveInteractionPostId(String postId) async {
    String currentId = postId.trim();

    if (currentId.isEmpty) {
      return '';
    }

    final Set<String> visited = <String>{};

    for (int depth = 0; depth < 12; depth++) {
      if (currentId.isEmpty || visited.contains(currentId)) {
        break;
      }

      visited.add(currentId);

      final DocumentSnapshot<Map<String, dynamic>> snapshot = await _posts
          .doc(currentId)
          .get();

      if (!snapshot.exists || snapshot.data() == null) {
        return currentId;
      }

      final Map<String, dynamic> data = snapshot.data()!;

      final bool isRepost =
          data['isRepost'] == true ||
          (data['repostType'] ?? '').toString().trim().isNotEmpty;

      //===================================================
      // NORMAL POST
      //===================================================

      if (!isRepost) {
        return snapshot.id;
      }

      final String type = (data['repostType'] ?? '').toString().trim();

      final String quote = (data['repostText'] ?? data['repostCaption'] ?? '')
          .toString()
          .trim();

      //===================================================
      // QUOTE POST IS ITS OWN INTERACTION
      //===================================================

      if (type == 'quote' || quote.isNotEmpty) {
        return snapshot.id;
      }

      //===================================================
      // PLAIN REPOST
      //
      // FOLLOW WHAT IT REPRESENTS.
      //===================================================

      final String sourcePostId =
          (data['sourcePostId'] ??
                  data['originalPostId'] ??
                  data['rootOriginalPostId'] ??
                  '')
              .toString()
              .trim();

      if (sourcePostId.isEmpty || sourcePostId == currentId) {
        return currentId;
      }

      currentId = sourcePostId;
    }

    return currentId;
  }

  //===================================================
  // GET ROOT ORIGINAL POST
  //===================================================

  Future<DocumentSnapshot<Map<String, dynamic>>> getRootOriginalPost(
    String postId,
  ) async {
    final String rootPostId = await resolveRootPostId(postId);

    return _posts.doc(rootPostId).get();
  }

  //===================================================
  // WATCH REFERENCED / ROOT POST
  //===================================================

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchRootOriginalPost(
    String rootPostId,
  ) {
    return _posts.doc(rootPostId.trim()).snapshots();
  }

  //===================================================
  // CHECK IF USER ALREADY PLAIN-REPOSTED EXACT TARGET
  //
  // DO NOT FLATTEN REPOSTS.
  //
  // POST A AND REPOST B ARE DIFFERENT TARGETS.
  //===================================================

  Future<bool> hasReposted(String originalPostId) async {
    final User? user = _auth.currentUser;

    if (user == null) {
      return false;
    }

    final String sourcePostId = originalPostId.trim();

    if (sourcePostId.isEmpty) {
      return false;
    }

    //===================================================
    // NEW DETERMINISTIC PLAIN REPOST
    //===================================================

    final String deterministicId = 'repost_${user.uid}_$sourcePostId';

    final DocumentSnapshot<Map<String, dynamic>> deterministic = await _posts
        .doc(deterministicId)
        .get();

    if (deterministic.exists) {
      return true;
    }

    //===================================================
    // OLD PLAIN REPOST BACKWARD COMPATIBILITY
    //===================================================

    final QuerySnapshot<Map<String, dynamic>> snapshot = await _posts
        .where('uid', isEqualTo: user.uid)
        .get();

    for (final QueryDocumentSnapshot<Map<String, dynamic>> document
        in snapshot.docs) {
      final Map<String, dynamic> data = document.data();

      if (data['isRepost'] != true) {
        continue;
      }

      final String type = (data['repostType'] ?? 'repost').toString().trim();

      //===================================================
      // QUOTE DOES NOT COUNT AS PLAIN REPOST
      //===================================================

      if (type == 'quote') {
        continue;
      }

      final String candidateSource = (data['sourcePostId'] ?? '')
          .toString()
          .trim();

      if (candidateSource == sourcePostId) {
        return true;
      }
    }

    return false;
  }

  //===================================================
  // CHECK IF USER ALREADY QUOTE-REPOSTED EXACT TARGET
  //
  // PLAIN REPOST DOES NOT COUNT.
  //
  // SAME EXACT TARGET CAN HAVE:
  // 1 PLAIN REPOST
  // 1 QUOTE REPOST
  //===================================================

  Future<bool> hasQuoteReposted(String originalPostId) async {
    final User? user = _auth.currentUser;

    if (user == null) {
      return false;
    }

    final String sourcePostId = originalPostId.trim();

    if (sourcePostId.isEmpty) {
      return false;
    }

    //===================================================
    // NEW DETERMINISTIC QUOTE REPOST
    //===================================================

    final String deterministicId = 'quote_${user.uid}_$sourcePostId';

    final DocumentSnapshot<Map<String, dynamic>> deterministic = await _posts
        .doc(deterministicId)
        .get();

    if (deterministic.exists) {
      return true;
    }

    //===================================================
    // OLD QUOTE REPOST BACKWARD COMPATIBILITY
    //===================================================

    final QuerySnapshot<Map<String, dynamic>> snapshot = await _posts
        .where('uid', isEqualTo: user.uid)
        .get();

    for (final QueryDocumentSnapshot<Map<String, dynamic>> document
        in snapshot.docs) {
      final Map<String, dynamic> data = document.data();

      if (data['isRepost'] != true) {
        continue;
      }

      final String type = (data['repostType'] ?? '').toString().trim();

      if (type != 'quote') {
        continue;
      }

      final String candidateSource = (data['sourcePostId'] ?? '')
          .toString()
          .trim();

      if (candidateSource == sourcePostId) {
        return true;
      }
    }

    return false;
  }
  //===================================================
  // DELETE REPOST / QUOTE REPOST
  //===================================================

  Future<void> deleteRepost(String repostPostId) async {
    final User user = _requireUser();

    final String cleanRepostId = repostPostId.trim();

    if (cleanRepostId.isEmpty) {
      return;
    }

    final DocumentReference<Map<String, dynamic>> repostRef = _posts.doc(
      cleanRepostId,
    );

    //===================================================
    // DELETE TRANSACTION
    //===================================================

    await _firestore.runTransaction((Transaction transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> repostSnapshot =
          await transaction.get(repostRef);

      if (!repostSnapshot.exists || repostSnapshot.data() == null) {
        return;
      }

      final Map<String, dynamic> repostData = repostSnapshot.data()!;

      //===================================================
      // OWNER CHECK
      //===================================================

      if ((repostData['uid'] ?? '').toString() != user.uid) {
        throw Exception('Only the repost owner can delete it.');
      }

      //===================================================
      // SOURCE + ROOT IDS
      //===================================================

      final String sourcePostId =
          (repostData['sourcePostId'] ?? repostData['originalPostId'] ?? '')
              .toString()
              .trim();

      final String rootPostId =
          (repostData['rootOriginalPostId'] ??
                  repostData['originalPostId'] ??
                  '')
              .toString()
              .trim();

      DocumentReference<Map<String, dynamic>>? sourceRef;

      DocumentSnapshot<Map<String, dynamic>>? sourceSnapshot;

      DocumentReference<Map<String, dynamic>>? rootRef;

      DocumentSnapshot<Map<String, dynamic>>? rootSnapshot;

      //===================================================
      // LOAD SOURCE FOR COUNT
      //===================================================

      if (sourcePostId.isNotEmpty && sourcePostId != cleanRepostId) {
        sourceRef = _posts.doc(sourcePostId);

        sourceSnapshot = await transaction.get(sourceRef);
      }

      //===================================================
      // LOAD ROOT FOR COUNT
      //===================================================

      if (rootPostId.isNotEmpty &&
          rootPostId != cleanRepostId &&
          rootPostId != sourcePostId) {
        rootRef = _posts.doc(rootPostId);

        rootSnapshot = await transaction.get(rootRef);
      }

      //===================================================
      // DELETE REPOST
      //===================================================

      transaction.delete(repostRef);

      //===================================================
      // DECREMENT SOURCE COUNT
      //===================================================

      if (sourceRef != null &&
          sourceSnapshot != null &&
          sourceSnapshot.exists &&
          sourceSnapshot.data() != null) {
        final int currentCount = _intValue(
          sourceSnapshot.data()!['repostCount'],
        );

        transaction.update(sourceRef, <String, dynamic>{
          'repostCount': currentCount > 0 ? currentCount - 1 : 0,
        });
      }

      //===================================================
      // DECREMENT ROOT COUNT
      //===================================================

      if (rootRef != null &&
          rootSnapshot != null &&
          rootSnapshot.exists &&
          rootSnapshot.data() != null) {
        final int currentRootCount = _intValue(
          rootSnapshot.data()!['repostCount'],
        );

        transaction.update(rootRef, <String, dynamic>{
          'repostCount': currentRootCount > 0 ? currentRootCount - 1 : 0,
        });
      }
    });

    //===================================================
    // REMOVE FROM SAVED HISTORY
    //===================================================

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('savedPosts')
          .doc(cleanRepostId)
          .delete();
    } catch (_) {}

    //===================================================
    // REMOVE FROM LIKED HISTORY
    //===================================================

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('likedPosts')
          .doc(cleanRepostId)
          .delete();
    } catch (_) {}
  }

  //===================================================
  // WATCH ALL REPOST ENGAGEMENTS FOR ROOT POST
  //===================================================

  Stream<List<Map<String, dynamic>>> watchRepostEngagements(
    String originalPostId,
  ) {
    final String requestedRoot = originalPostId.trim();

    if (requestedRoot.isEmpty) {
      return Stream<List<Map<String, dynamic>>>.value(<Map<String, dynamic>>[]);
    }

    final Stream<List<Map<String, dynamic>>> stream = _posts
        .where('rootOriginalPostId', isEqualTo: requestedRoot)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
          final List<Map<String, dynamic>> results = <Map<String, dynamic>>[];

          for (final QueryDocumentSnapshot<Map<String, dynamic>> document
              in snapshot.docs) {
            final Map<String, dynamic> raw = document.data();

            //===================================================
            // ONLY REPOST DOCUMENTS
            //===================================================

            if (raw['isRepost'] != true) {
              continue;
            }

            //===================================================
            // HIDDEN REPOSTS
            //===================================================

            if (raw['isHidden'] == true || raw['isRootHidden'] == true) {
              continue;
            }

            //===================================================
            // ROOT ID
            //===================================================

            final String rootPostId =
                (raw['rootOriginalPostId'] ?? raw['originalPostId'] ?? '')
                    .toString()
                    .trim();

            if (rootPostId != requestedRoot) {
              continue;
            }

            //===================================================
            // ADD RESULT
            //===================================================

            final Map<String, dynamic> data = Map<String, dynamic>.from(raw);

            data['postId'] = (data['postId'] ?? document.id).toString().trim();

            results.add(data);
          }

          //===================================================
          // NEWEST FIRST
          //===================================================

          results.sort(_newestMapFirst);

          return results;
        });

    return stream.asBroadcastStream();
  }

  //===================================================
  // WATCH QUOTE REPOSTS
  //===================================================

  Stream<List<Map<String, dynamic>>> watchQuotes(String rootPostId) {
    final Stream<List<Map<String, dynamic>>> stream =
        watchRepostEngagements(rootPostId).map((
          List<Map<String, dynamic>> reposts,
        ) {
          return reposts.where((Map<String, dynamic> data) {
            final String type = (data['repostType'] ?? '').toString().trim();

            final String quote =
                (data['repostText'] ?? data['repostCaption'] ?? '')
                    .toString()
                    .trim();

            return type == 'quote' || quote.isNotEmpty;
          }).toList();
        });

    return stream.asBroadcastStream();
  }

  //===================================================
  // WATCH PLAIN REPOSTS
  //===================================================

  Stream<List<Map<String, dynamic>>> watchPlainReposts(String rootPostId) {
    final Stream<List<Map<String, dynamic>>>
    stream = watchRepostEngagements(rootPostId).map((
      List<Map<String, dynamic>> reposts,
    ) {
      return reposts.where((Map<String, dynamic> data) {
        final String type = (data['repostType'] ?? 'repost').toString().trim();

        final String quote = (data['repostText'] ?? data['repostCaption'] ?? '')
            .toString()
            .trim();

        return type != 'quote' && quote.isEmpty;
      }).toList();
    });

    return stream.asBroadcastStream();
  }

  //===================================================
  // GET TOTAL REPOST COUNT
  //===================================================

  Future<int> getRepostCount(String rootPostId) async {
    final String cleanRootId = rootPostId.trim();

    if (cleanRootId.isEmpty) {
      return 0;
    }

    final QuerySnapshot<Map<String, dynamic>> snapshot = await _posts
        .where('rootOriginalPostId', isEqualTo: cleanRootId)
        .get();

    int count = 0;

    for (final QueryDocumentSnapshot<Map<String, dynamic>> document
        in snapshot.docs) {
      final Map<String, dynamic> data = document.data();

      if (data['isRepost'] != true ||
          data['isHidden'] == true ||
          data['isRootHidden'] == true) {
        continue;
      }

      count++;
    }

    return count;
  }

  //===================================================
  // GET QUOTE COUNT
  //===================================================

  Future<int> getQuoteCount(String rootPostId) async {
    final List<Map<String, dynamic>> reposts = await watchQuotes(
      rootPostId,
    ).first;

    return reposts.length;
  }

  //===================================================
  // GET PLAIN REPOST COUNT
  //===================================================

  Future<int> getPlainRepostCount(String rootPostId) async {
    final List<Map<String, dynamic>> reposts = await watchPlainReposts(
      rootPostId,
    ).first;

    return reposts.length;
  }

  //===================================================
  // REPOST COUNT STREAM
  //===================================================

  Stream<int> repostCountStream(String rootPostId) {
    return watchRepostEngagements(rootPostId).map((
      List<Map<String, dynamic>> items,
    ) {
      return items.length;
    });
  }

  //===================================================
  // QUOTE COUNT STREAM
  //===================================================

  Stream<int> quoteCountStream(String rootPostId) {
    return watchQuotes(rootPostId).map((List<Map<String, dynamic>> items) {
      return items.length;
    });
  }

  //===================================================
  // PLAIN REPOST COUNT STREAM
  //===================================================

  Stream<int> plainRepostCountStream(String rootPostId) {
    return watchPlainReposts(rootPostId).map((
      List<Map<String, dynamic>> items,
    ) {
      return items.length;
    });
  }

  //===================================================
  // SYNC ROOT VISIBILITY TO REPOST WRAPPERS
  //===================================================

  Future<void> syncRootVisibility({
    required String rootPostId,
    required bool hidden,
  }) async {
    final String cleanRootId = rootPostId.trim();

    if (cleanRootId.isEmpty) {
      return;
    }

    //===================================================
    // LOAD ROOT
    //===================================================

    final DocumentSnapshot<Map<String, dynamic>> rootSnapshot = await _posts
        .doc(cleanRootId)
        .get();

    if (!rootSnapshot.exists || rootSnapshot.data() == null) {
      return;
    }

    //===================================================
    // OWNER CHECK
    //===================================================

    final User user = _requireUser();

    if ((rootSnapshot.data()!['uid'] ?? '').toString() != user.uid) {
      throw Exception('Only the original post owner can change visibility.');
    }

    //===================================================
    // LOAD ALL POSTS
    //===================================================

    final QuerySnapshot<Map<String, dynamic>> allPosts = await _posts.get();

    final List<DocumentReference<Map<String, dynamic>>> wrappers =
        <DocumentReference<Map<String, dynamic>>>[];

    //===================================================
    // FIND ALL REPOST WRAPPERS FOR ROOT
    //===================================================

    for (final QueryDocumentSnapshot<Map<String, dynamic>> document
        in allPosts.docs) {
      final Map<String, dynamic> data = document.data();

      if (data['isRepost'] != true) {
        continue;
      }

      final String candidateRoot =
          (data['rootOriginalPostId'] ?? data['originalPostId'] ?? '')
              .toString()
              .trim();

      if (candidateRoot == cleanRootId) {
        wrappers.add(document.reference);
      }
    }

    if (wrappers.isEmpty) {
      return;
    }

    //===================================================
    // FIRESTORE BATCH LIMIT SAFETY
    //===================================================

    const int batchSize = 400;

    for (int start = 0; start < wrappers.length; start += batchSize) {
      final int end = start + batchSize > wrappers.length
          ? wrappers.length
          : start + batchSize;

      final WriteBatch batch = _firestore.batch();

      for (int index = start; index < end; index++) {
        batch.update(wrappers[index], <String, dynamic>{
          'isRootHidden': hidden,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    }
  }

  //===================================================
  // REQUIRE AUTHENTICATED USER
  //===================================================

  User _requireUser() {
    final User? user = _auth.currentUser;

    if (user == null) {
      throw Exception('Please log in first.');
    }

    return user;
  }

  //===================================================
  // SORT NEWEST FIRST
  //===================================================

  static int _newestMapFirst(Map<String, dynamic> a, Map<String, dynamic> b) {
    final DateTime aDate =
        _dateValue(a['repostedAt'] ?? a['createdAt']) ??
        DateTime.fromMillisecondsSinceEpoch(0);

    final DateTime bDate =
        _dateValue(b['repostedAt'] ?? b['createdAt']) ??
        DateTime.fromMillisecondsSinceEpoch(0);

    return bDate.compareTo(aDate);
  }

  //===================================================
  // DATE HELPER
  //===================================================

  static DateTime? _dateValue(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }

  //===================================================
  // INT HELPER
  //===================================================

  static int _intValue(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
