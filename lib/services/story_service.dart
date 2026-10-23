import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';

import '../models/story.dart';
import '../models/story_drawing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

//===================================================
// STORY SERVICE
//===================================================

class StoryService {
  StoryService();

  //===================================================
  // FIREBASE
  //===================================================

  final FirebaseAuth _auth = FirebaseAuth.instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FirebaseStorage _storage = FirebaseStorage.instance;

  //===================================================
  // CURRENT USER ID
  //===================================================

  String? get currentUserId {
    return _auth.currentUser?.uid;
  }

  //===================================================
  // NEW STORY ID
  //===================================================

  String newStoryId() {
    return _firestore.collection('stories').doc().id;
  }

  //===================================================
  // GET STORY
  //===================================================

  Future<NubifyStory?> getStory(String storyId) async {
    final String cleanId = storyId.trim();

    if (cleanId.isEmpty) {
      return null;
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('stories')
          .doc(cleanId)
          .get();

      if (!snapshot.exists) {
        return null;
      }

      return NubifyStory.fromFirestore(snapshot);
    } catch (error) {
      debugPrint('Get Story error: $error');

      return null;
    }
  }

  //===================================================
  // GET CURRENT USER PROFILE
  //===================================================

  Future<StoryPerson> getCurrentUserProfile() async {
    final User? user = _auth.currentUser;

    if (user == null) {
      throw Exception('User is not logged in.');
    }

    final DocumentSnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .get();

    final Map<String, dynamic> data = snapshot.data() ?? <String, dynamic>{};

    return StoryPerson(
      uid: user.uid,
      username: (data['username'] ?? user.displayName ?? 'user').toString(),
      fullName: (data['fullName'] ?? data['name'] ?? user.displayName ?? '')
          .toString(),
      photoUrl: (data['photoUrl'] ?? user.photoURL ?? '').toString(),
    );
  }

  //===================================================
  // UPLOAD STORY MEDIA
  //===================================================

  Future<String> uploadStoryMedia({
    required String storyId,
    required XFile file,
    String folder = 'media',
  }) async {
    final String? uid = currentUserId;

    if (uid == null) {
      throw Exception('User is not logged in.');
    }

    final File localFile = File(file.path);

    if (!await localFile.exists()) {
      throw Exception('Story media file was not found.');
    }

    final String extension = _extensionFromPath(file.path);

    final String fileName =
        '${DateTime.now().microsecondsSinceEpoch}'
        '${extension.isEmpty ? '' : '.$extension'}';

    final Reference reference = _storage
        .ref()
        .child('stories')
        .child(uid)
        .child(storyId)
        .child(folder)
        .child(fileName);

    final TaskSnapshot snapshot = await reference.putFile(
      localFile,
      SettableMetadata(contentType: _contentTypeFromExtension(extension)),
    );

    return snapshot.ref.getDownloadURL();
  }
  //===================================================
  // STORY VIDEO THUMBNAIL
  //===================================================

  Future<String> uploadStoryVideoThumbnail({
    required String storyId,
    required XFile videoFile,
  }) async {
    final String? uid = currentUserId;

    if (uid == null) {
      throw Exception('User is not logged in.');
    }

    try {
      final Directory temp = await getTemporaryDirectory();

      final String? localThumbnail = await VideoThumbnail.thumbnailFile(
        video: videoFile.path,

        thumbnailPath: temp.path,

        imageFormat: ImageFormat.JPEG,

        maxWidth: 720,

        quality: 82,
      );

      if (localThumbnail == null) {
        return '';
      }

      final File file = File(localThumbnail);

      if (!await file.exists()) {
        return '';
      }

      final Reference reference = _storage.ref().child(
        'stories/$uid/$storyId/thumbnail.jpg',
      );

      final TaskSnapshot snapshot = await reference.putFile(
        file,

        SettableMetadata(contentType: 'image/jpeg'),
      );

      return await snapshot.ref.getDownloadURL();
    } catch (error) {
      debugPrint('Story thumbnail error: $error');

      return '';
    }
  }

  //===================================================
  // UPLOAD VOICE STORY
  //===================================================

  Future<String> uploadVoiceStory({
    required String storyId,
    required String filePath,
  }) async {
    final String? uid = currentUserId;

    if (uid == null) {
      throw Exception('User is not logged in.');
    }

    final File file = File(filePath);

    if (!await file.exists()) {
      throw Exception('Voice recording was not found.');
    }

    final int fileSize = await file.length();

    if (fileSize <= 0) {
      throw Exception('Voice recording is empty.');
    }

    final Reference reference = _storage
        .ref()
        .child('stories')
        .child(uid)
        .child(storyId)
        .child('voice')
        .child('${DateTime.now().microsecondsSinceEpoch}.m4a');

    final TaskSnapshot snapshot = await reference.putFile(
      file,
      SettableMetadata(
        contentType: 'audio/mp4',
        customMetadata: <String, String>{'storyType': 'voice', 'codec': 'aac'},
      ),
    );

    return snapshot.ref.getDownloadURL();
  }

  //===================================================
  // CREATE STORY
  //===================================================

  Future<String> createStory({
    String? storyId,
    required String type,
    String mediaUrl = '',
    List<String> mediaUrls = const <String>[],
    String text = '',
    String caption = '',
    String thumbnailUrl = '',
    String linkUrl = '',
    String linkStyle = 'medium',
    double linkX = 0.50,
    double linkY = 0.52,
    double linkScale = 1.0,

    //=============================
    // STICKER
    //=============================
    String sticker = '',

    double stickerX = 0.80,

    double stickerY = 0.14,

    double stickerSize = 54.0,

    int backgroundColor = 0xFF101114,
    int textColor = 0xFFFFFFFF,
    String textStyle = 'bold',
    String textAlign = 'center',
    double textSize = 34,
    double textX = 0.50,
    double textY = 0.50,
    List<StoryDrawingStroke> drawings = const <StoryDrawingStroke>[],
    int durationSeconds = 8,

    //===================================================
    // LAYOUT
    //===================================================
    int layoutCount = 2,
    String layoutStyle = 'vertical',

    //===================================================
    // TAGGING
    //===================================================
    List<StoryPerson> taggedPeople = const <StoryPerson>[],

    //===================================================
    // POLL
    //===================================================
    StoryPoll? poll,

    //===================================================
    // POST SHARE
    //===================================================
    String postId = '',

    //===================================================
    // STORY RESHARE
    //===================================================
    String sourceStoryId = '',
    String sourceOwnerId = '',
    String sourceUsername = '',
    String sourceType = '',
    String sourceMediaUrl = '',
    List<String> sourceMediaUrls = const <String>[],
    String sourceText = '',
    //=================================
    // FAST / OPTIMISTIC STORY WRITE
    //=================================

    StoryPerson? ownerProfile,
    bool optimisticWrite = false,
  }) async {
    final String? uid = currentUserId;

    if (uid == null) {
      throw Exception('User is not logged in.');
    }

    final StoryPerson profile = ownerProfile ?? await getCurrentUserProfile();

    final DocumentReference<Map<String, dynamic>> storyRef = _firestore
        .collection('stories')
        .doc(storyId ?? newStoryId());

    final DateTime now = DateTime.now();

    final List<String> taggedIds = taggedPeople
        .map((StoryPerson person) => person.uid)
        .where((String id) => id.isNotEmpty)
        .toSet()
        .toList();

    //===================================================
    // DURATION
    //
    // VOICE = MAXIMUM 180 SEC = 3 MIN
    // OTHER STORY = MAXIMUM 60 SEC
    //===================================================

    final int safeDuration = type == 'voice'
        ? durationSeconds.clamp(3, 180).toInt()
        : durationSeconds.clamp(3, 60).toInt();

    final Map<String, dynamic> storyData = <String, dynamic>{
      //===================================================
      // OWNER
      //===================================================

      'storyId': storyRef.id,

      'uid': uid,

      'username': profile.username,

      'fullName': profile.fullName,

      'photoUrl': profile.photoUrl,

      //===================================================
      // CONTENT
      //===================================================
      'type': type,

      'mediaUrl': mediaUrl,

      'mediaUrls': mediaUrls,

      'text': text,

      'caption': caption,
      'thumbnailUrl': thumbnailUrl,
      //=============================
      // STICKER
      //=============================

      'sticker': sticker,

      'stickerX': stickerX.clamp(0.04, 0.96).toDouble(),

      'stickerY': stickerY.clamp(0.04, 0.96).toDouble(),

      'stickerSize': stickerSize.clamp(28.0, 120.0).toDouble(),

      //===================================================
      // DESIGN
      //===================================================
      'backgroundColor': backgroundColor,

      'textColor': textColor,

      'textStyle': textStyle,

      'textAlign': textAlign,

      'textSize': textSize,

      'textX': textX.clamp(0.06, 0.94).toDouble(),

      'textY': textY.clamp(0.08, 0.92).toDouble(),

      'drawings': drawings
          .take(StoryDrawingLimits.maxStrokes)
          .map((StoryDrawingStroke stroke) => stroke.toMap())
          .toList(growable: false),

      'durationSeconds': safeDuration,

      //===================================================
      // LAYOUT
      //===================================================
      'layoutCount': layoutCount.clamp(2, 4).toInt(),

      'layoutStyle': layoutStyle,

      //===================================================
      // TAGGING
      //===================================================
      'taggedPeople': taggedPeople
          .map((StoryPerson person) => person.toMap())
          .toList(),

      'taggedUserIds': taggedIds,

      //===================================================
      // ENGAGEMENT
      //===================================================
      'viewerIds': <String>[],

      'likedUserIds': <String>[],

      'viewCount': 0,

      'likeCount': 0,

      'replyCount': 0,

      'shareCount': 0,

      'reshareCount': 0,

      //===================================================
      // POLL
      //===================================================
      'poll': poll?.toMap(),

      //===================================================
      // POST SHARE
      //===================================================
      'postId': postId,

      //===================================================
      // STORY RESHARE
      //===================================================
      'sourceStoryId': sourceStoryId,

      'sourceOwnerId': sourceOwnerId,

      'sourceUsername': sourceUsername,

      'sourceType': sourceType,

      'sourceMediaUrl': sourceMediaUrl,

      'sourceMediaUrls': sourceMediaUrls,

      'sourceText': sourceText,
      //===================================================
      // STORY LINK
      //===================================================

      'linkUrl': linkUrl,

      'linkStyle': linkStyle,

      'linkX': linkX,

      'linkY': linkY,

      'linkScale': linkScale,

      //===================================================
      // TIME
      //===================================================
      'createdAt': FieldValue.serverTimestamp(),

      'expiresAt': Timestamp.fromDate(now.add(const Duration(hours: 24))),
    };

    if (optimisticWrite) {
      //=================================
      // OPTIMISTIC LOCAL STORY WRITE
      //
      // Firestore applies the mutation to its local cache
      // immediately. Do not keep the Add to Story button
      // spinning while waiting for a server acknowledgement.
      //=================================

      unawaited(
        storyRef.set(storyData).catchError((Object error) {
          debugPrint('Optimistic story write error: $error');
        }),
      );
    } else {
      await storyRef.set(storyData);
    }

    return storyRef.id;
  }
  //============================
  // MY STORY ARCHIVE
  //
  // OWNER'S STORIES ONLY.
  // NEWEST FIRST.
  //
  // INCLUDES ACTIVE + EXPIRED STORIES.
  //============================

  Stream<List<NubifyStory>> watchMyStoryArchive() {
    final String? uid = currentUserId;

    if (uid == null || uid.trim().isEmpty) {
      return Stream<List<NubifyStory>>.value(<NubifyStory>[]);
    }

    return _firestore
        .collection('stories')
        .where('uid', isEqualTo: uid)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
          final List<NubifyStory> stories = <NubifyStory>[];

          for (final QueryDocumentSnapshot<Map<String, dynamic>> document
              in snapshot.docs) {
            try {
              stories.add(NubifyStory.fromFirestore(document));
            } catch (error) {
              debugPrint('Archive Story error ${document.id}: $error');
            }
          }

          //============================
          // NEWEST FIRST
          //============================

          stories.sort((NubifyStory a, NubifyStory b) {
            return b.createdAt.compareTo(a.createdAt);
          });

          return stories;
        });
  }
  //===================================================
  // FIRESTORE ACTIVE STORIES STREAM
  //===================================================

  Stream<QuerySnapshot<Map<String, dynamic>>> streamActiveStories() {
    return _firestore
        .collection('stories')
        .where('expiresAt', isGreaterThan: Timestamp.fromDate(DateTime.now()))
        .orderBy('expiresAt')
        .snapshots();
  }

  //===================================================
  // BACKWARD COMPATIBILITY
  //===================================================

  Stream<QuerySnapshot<Map<String, dynamic>>> activeStoriesStream() {
    return streamActiveStories();
  }

  //===================================================
  // ACTIVE STORY MODEL STREAM
  //
  // NEWEST -> OLDEST
  //===================================================

  Stream<List<NubifyStory>> watchActiveStories() {
    return streamActiveStories().map((
      QuerySnapshot<Map<String, dynamic>> snapshot,
    ) {
      final List<NubifyStory> stories = snapshot.docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> document) {
            return NubifyStory.fromFirestore(document);
          })
          .where((NubifyStory story) {
            return !story.isExpired;
          })
          .toList();

      //===================================================
      // NEWEST STORY FIRST
      //===================================================

      stories.sort((NubifyStory a, NubifyStory b) {
        return b.createdAt.compareTo(a.createdAt);
      });

      return stories;
    });
  }

  //===================================================
  // GET ACTIVE STORIES
  //
  // NEWEST -> OLDEST
  //===================================================

  Future<List<NubifyStory>> getActiveStories() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('stories')
        .where('expiresAt', isGreaterThan: Timestamp.fromDate(DateTime.now()))
        .get();

    final List<NubifyStory> stories = snapshot.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> document) {
          return NubifyStory.fromFirestore(document);
        })
        .where((NubifyStory story) {
          return !story.isExpired;
        })
        .toList();

    //===================================================
    // NEWEST STORY FIRST
    //===================================================

    stories.sort((NubifyStory a, NubifyStory b) {
      return b.createdAt.compareTo(a.createdAt);
    });

    return stories;
  }

  //===================================================
  // RECORD VIEW
  //
  // ONE USER = ONE VIEW
  //===================================================

  Future<void> recordView(NubifyStory story) async {
    final String? uid = currentUserId;

    if (uid == null || story.storyId.trim().isEmpty) {
      return;
    }

    final DocumentReference<Map<String, dynamic>> storyRef = _firestore
        .collection('stories')
        .doc(story.storyId);

    final DocumentReference<Map<String, dynamic>> viewRef = storyRef
        .collection('views')
        .doc(uid);

    await _firestore.runTransaction((Transaction transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> existingView =
          await transaction.get(viewRef);

      //===================================================
      // USER ALREADY VIEWED
      //===================================================

      if (existingView.exists) {
        return;
      }

      final DocumentSnapshot<Map<String, dynamic>> existingStory =
          await transaction.get(storyRef);

      if (!existingStory.exists) {
        return;
      }

      //===================================================
      // SAVE VIEW
      //===================================================

      transaction.set(viewRef, <String, dynamic>{
        'uid': uid,
        'viewedAt': FieldValue.serverTimestamp(),
      });

      //===================================================
      // UPDATE STORY
      //===================================================

      transaction.update(storyRef, <String, dynamic>{
        'viewerIds': FieldValue.arrayUnion(<String>[uid]),
        'viewCount': FieldValue.increment(1),
      });
    });
  }

  //===================================================
  // TOGGLE LIKE
  //===================================================

  Future<bool> toggleLike(NubifyStory story) async {
    final String? uid = currentUserId;

    if (uid == null) {
      throw Exception('User is not logged in.');
    }

    final DocumentReference<Map<String, dynamic>> storyRef = _firestore
        .collection('stories')
        .doc(story.storyId);

    return _firestore.runTransaction<bool>((Transaction transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await transaction
          .get(storyRef);

      if (!snapshot.exists) {
        throw Exception('Story no longer exists.');
      }

      final Map<String, dynamic> data = snapshot.data() ?? <String, dynamic>{};

      final List<String> users =
          (data['likedUserIds'] as List<dynamic>? ?? <dynamic>[]).map((
            dynamic value,
          ) {
            return value.toString();
          }).toList();

      final bool liked = users.contains(uid);

      //===================================================
      // UNLIKE
      //===================================================

      if (liked) {
        transaction.update(storyRef, <String, dynamic>{
          'likedUserIds': FieldValue.arrayRemove(<String>[uid]),
          'likeCount': FieldValue.increment(-1),
        });

        return false;
      }

      //===================================================
      // LIKE
      //===================================================

      transaction.update(storyRef, <String, dynamic>{
        'likedUserIds': FieldValue.arrayUnion(<String>[uid]),
        'likeCount': FieldValue.increment(1),
      });

      return true;
    });
  }

  //===================================================
  // REPLY TO STORY
  //===================================================

  Future<void> replyToStory({
    required NubifyStory story,
    required String message,
  }) async {
    final String? uid = currentUserId;

    if (uid == null) {
      throw Exception('User is not logged in.');
    }

    final String clean = message.trim();

    if (clean.isEmpty) {
      return;
    }

    final StoryPerson profile = await getCurrentUserProfile();

    final DocumentReference<Map<String, dynamic>> replyRef = _firestore
        .collection('stories')
        .doc(story.storyId)
        .collection('replies')
        .doc();

    await replyRef.set(<String, dynamic>{
      'replyId': replyRef.id,

      'storyId': story.storyId,

      'storyOwnerId': story.uid,

      'uid': uid,

      'username': profile.username,

      'fullName': profile.fullName,

      'photoUrl': profile.photoUrl,

      'text': clean,

      'createdAt': FieldValue.serverTimestamp(),
    });

    await _firestore.collection('stories').doc(story.storyId).update(
      <String, dynamic>{'replyCount': FieldValue.increment(1)},
    );
  }

  //===================================================
  // VOTE STORY POLL
  //===================================================

  Future<void> votePoll({
    required NubifyStory story,
    required int optionIndex,
  }) async {
    final String? uid = currentUserId;

    if (uid == null) {
      throw Exception('User is not logged in.');
    }

    final DocumentReference<Map<String, dynamic>> storyRef = _firestore
        .collection('stories')
        .doc(story.storyId);

    await _firestore.runTransaction((Transaction transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await transaction
          .get(storyRef);

      if (!snapshot.exists) {
        throw Exception('Story no longer exists.');
      }

      final Map<String, dynamic> data = snapshot.data() ?? <String, dynamic>{};

      if (data['poll'] is! Map) {
        throw Exception('This story has no poll.');
      }

      final Map<String, dynamic> poll = Map<String, dynamic>.from(
        data['poll'] as Map,
      );

      final List<String> votedIds =
          (poll['votedUserIds'] as List<dynamic>? ?? <dynamic>[]).map((
            dynamic value,
          ) {
            return value.toString();
          }).toList();

      //===================================================
      // ALREADY VOTED
      //===================================================

      if (votedIds.contains(uid)) {
        throw Exception('ALREADY_VOTED');
      }

      final List<dynamic> rawOptions =
          poll['options'] as List<dynamic>? ?? <dynamic>[];

      if (optionIndex < 0 || optionIndex >= rawOptions.length) {
        throw Exception('Invalid poll option.');
      }

      final List<Map<String, dynamic>> options = rawOptions.map((
        dynamic value,
      ) {
        return Map<String, dynamic>.from(value as Map);
      }).toList();

      final int currentVotes = _toInt(options[optionIndex]['votes']);

      options[optionIndex]['votes'] = currentVotes + 1;

      votedIds.add(uid);

      final Map<String, dynamic> userVotes = poll['userVotes'] is Map
          ? Map<String, dynamic>.from(poll['userVotes'] as Map)
          : <String, dynamic>{};

      userVotes[uid] = optionIndex;

      poll['options'] = options;

      poll['votedUserIds'] = votedIds;

      poll['userVotes'] = userVotes;

      poll['totalVotes'] = options.fold<int>(0, (
        int total,
        Map<String, dynamic> option,
      ) {
        return total + _toInt(option['votes']);
      });

      transaction.update(storyRef, <String, dynamic>{'poll': poll});
    });
  }

  //===================================================
  // SHARE COUNT
  //===================================================

  Future<void> incrementShare(String storyId) async {
    if (storyId.trim().isEmpty) {
      return;
    }

    await _firestore.collection('stories').doc(storyId).update(
      <String, dynamic>{'shareCount': FieldValue.increment(1)},
    );
  }

  //===================================================
  // RESHARE STORY
  //===================================================

  Future<String> reshareStory(NubifyStory source) async {
    final String storyId = await createStory(
      type: 'reshare',

      caption: source.caption,

      backgroundColor: source.backgroundColor,

      textColor: source.textColor,

      textStyle: source.textStyle,

      textAlign: source.textAlign,

      textSize: source.textSize,

      textX: source.textX,

      textY: source.textY,

      drawings: source.drawings,

      durationSeconds: source.durationSeconds,

      layoutCount: source.layoutCount,

      layoutStyle: source.layoutStyle,

      sourceStoryId: source.storyId,

      sourceOwnerId: source.uid,

      sourceUsername: source.username,

      sourceType: source.type,

      sourceMediaUrl: source.mediaUrl,

      sourceMediaUrls: source.mediaUrls,

      sourceText: source.text,
    );

    try {
      await _firestore.collection('stories').doc(source.storyId).update(
        <String, dynamic>{'reshareCount': FieldValue.increment(1)},
      );
    } catch (error) {
      debugPrint('Story reshare count error: $error');
    }

    return storyId;
  }

  //===================================================
  // SHARE POST TO STORY
  //===================================================

  Future<void> sharePostToStory({
    required String postId,
    String? caption,
  }) async {
    await createStory(
      type: 'postShare',

      postId: postId,

      caption: caption ?? '',

      durationSeconds: 10,
    );
  }

  //===================================================
  // SHARE VIDEO TO STORY
  //===================================================

  Future<void> shareVideoToStory({
    required String postId,
    required String videoUrl,
  }) async {
    await createStory(
      type: 'videoShare',

      postId: postId,

      mediaUrl: videoUrl,

      durationSeconds: 15,
    );
  }

  //===================================================
  // STREAM STORY VIEWERS
  //===================================================

  Stream<QuerySnapshot<Map<String, dynamic>>> streamViewers(String storyId) {
    return _firestore
        .collection('stories')
        .doc(storyId)
        .collection('views')
        .orderBy('viewedAt', descending: true)
        .snapshots();
  }

  //===================================================
  // DELETE STORY
  //===================================================

  Future<void> deleteStory(NubifyStory story) async {
    final String? uid = currentUserId;

    if (uid == null || uid != story.uid) {
      throw Exception('Only the owner can delete this story.');
    }

    //===================================================
    // DELETE FIRESTORE FIRST
    //
    // THIS MAKES STORY DISAPPEAR QUICKLY.
    //===================================================

    await _firestore.collection('stories').doc(story.storyId).delete();

    //===================================================
    // DELETE STORAGE AFTER
    //===================================================

    try {
      final Reference root = _storage
          .ref()
          .child('stories')
          .child(uid)
          .child(story.storyId);

      await _deleteStorageFolder(root);
    } catch (error) {
      debugPrint('Story storage cleanup error: $error');
    }
  }

  //===================================================
  // DELETE STORAGE FOLDER RECURSIVELY
  //===================================================

  Future<void> _deleteStorageFolder(Reference reference) async {
    final ListResult result = await reference.listAll();

    //===================================================
    // DELETE FILES
    //===================================================

    for (final Reference item in result.items) {
      try {
        await item.delete();
      } catch (_) {}
    }

    //===================================================
    // DELETE NESTED FOLDERS
    //===================================================

    for (final Reference folder in result.prefixes) {
      await _deleteStorageFolder(folder);
    }
  }

  //===================================================
  // FILE EXTENSION
  //===================================================

  String _extensionFromPath(String path) {
    final String clean = path.split('?').first;

    final int dot = clean.lastIndexOf('.');

    if (dot == -1 || dot == clean.length - 1) {
      return '';
    }

    return clean.substring(dot + 1).toLowerCase();
  }

  //===================================================
  // CONTENT TYPE
  //===================================================

  String _contentTypeFromExtension(String extension) {
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';

      case 'png':
        return 'image/png';

      case 'webp':
        return 'image/webp';

      case 'gif':
        return 'image/gif';

      case 'mp4':
        return 'video/mp4';

      case 'mov':
        return 'video/quicktime';

      case 'm4v':
        return 'video/x-m4v';

      default:
        return 'application/octet-stream';
    }
  }

  //===================================================
  // INT HELPER
  //===================================================

  int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
