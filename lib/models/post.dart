import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  final String postId;
  final String uid;
  final String username;
  final String fullName;
  final String photoUrl;
  final String caption;
  final String thumbnailUrl;

  final List<PostMedia> media;

  final bool isNUBuzz;
  final String postType;

  final bool hasPoll;
  final Map<String, dynamic>? poll;

  final List<TaggedUser> taggedUsers;
  final List<String> taggedUserIds;

  final int likeCount;
  final int commentCount;
  final int repostCount;
  final int shareCount;
  final int viewCount;

  final Timestamp? createdAt;

  //===================================================
  // REPOST
  //===================================================

  final bool isRepost;

  //===================================================
  // BACKWARD COMPATIBILITY
  //===================================================

  final String? originalPostId;
  final String? repostCaption;

  //===================================================
  // X / TWITTER STYLE REPOST DATA
  //
  // repostType:
  // repost = normal repost
  // quote = repost with quote
  //
  // rootOriginalPostId:
  // always points to the REAL original post.
  //
  // This stops:
  // repost -> repost -> repost nesting.
  //===================================================

  final String repostType;
  final String repostText;

  final String rootOriginalPostId;
  final String sourcePostId;

  final String originalUid;
  final String originalUsername;
  final String originalFullName;
  final String originalPhotoUrl;
  final String originalCaption;

  final Timestamp? originalCreatedAt;
  final Timestamp? repostedAt;

  //===================================================
  // GLOBAL OWNER HIDE
  //
  // isHidden:
  // owner hid THIS post/repost.
  //
  // isRootHidden:
  // original post that this repost references is hidden.
  //===================================================

  final bool isHidden;
  final bool isRootHidden;
  final Timestamp? hiddenAt;

  Post({
    required this.postId,
    required this.uid,
    required this.username,
    required this.fullName,
    required this.photoUrl,
    required this.caption,
    required this.media,
    required this.isNUBuzz,
    required this.postType,
    required this.hasPoll,
    required this.poll,
    required this.taggedUsers,
    required this.taggedUserIds,
    required this.likeCount,
    required this.commentCount,
    required this.repostCount,
    required this.shareCount,
    required this.viewCount,
    required this.createdAt,
    required this.isRepost,
    required this.originalPostId,
    required this.repostCaption,
    this.repostType = '',
    this.repostText = '',
    this.rootOriginalPostId = '',
    this.sourcePostId = '',
    this.originalUid = '',
    this.originalUsername = '',
    this.originalFullName = '',
    this.originalPhotoUrl = '',
    this.originalCaption = '',
    this.originalCreatedAt,
    this.repostedAt,
    this.isHidden = false,
    this.isRootHidden = false,
    this.hiddenAt,
    this.thumbnailUrl = '',
  });

  //===================================================
  // FROM FIRESTORE
  //===================================================

  factory Post.fromFirestore(DocumentSnapshot snapshot) {
    final dynamic rawData = snapshot.data();

    if (rawData == null || rawData is! Map) {
      throw Exception('Invalid post document: ${snapshot.id}');
    }

    final Map<String, dynamic> data = Map<String, dynamic>.from(rawData as Map);

    final List<dynamic> mediaData = data['media'] is List
        ? List<dynamic>.from(data['media'] as List)
        : <dynamic>[];

    final List<dynamic> taggedData = data['taggedUsers'] is List
        ? List<dynamic>.from(data['taggedUsers'] as List)
        : <dynamic>[];

    return Post(
      postId: (data['postId'] ?? snapshot.id).toString(),

      uid: (data['uid'] ?? '').toString(),

      username: (data['username'] ?? 'User').toString(),

      fullName: (data['fullName'] ?? '').toString(),

      photoUrl: (data['photoUrl'] ?? '').toString(),

      caption: (data['caption'] ?? '').toString(),
      //=============================
      // POST VIDEO THUMBNAIL
      //=============================
      thumbnailUrl: (data['thumbnailUrl'] ?? '').toString(),

      media: mediaData.where((dynamic item) => item is Map).map((dynamic item) {
        return PostMedia.fromMap(Map<String, dynamic>.from(item as Map));
      }).toList(),

      isNUBuzz: data['isNUBuzz'] == true,

      postType: (data['postType'] ?? 'post').toString(),

      hasPoll: data['hasPoll'] == true,

      poll: data['poll'] is Map
          ? Map<String, dynamic>.from(data['poll'] as Map)
          : null,

      taggedUsers: taggedData.where((dynamic item) => item is Map).map((
        dynamic item,
      ) {
        return TaggedUser.fromMap(Map<String, dynamic>.from(item as Map));
      }).toList(),

      taggedUserIds: data['taggedUserIds'] is List
          ? List<String>.from(
              (data['taggedUserIds'] as List).map(
                (dynamic value) => value.toString(),
              ),
            )
          : <String>[],

      likeCount: _intValue(data['likeCount']),

      commentCount: _intValue(data['commentCount']),

      repostCount: _intValue(data['repostCount']),

      shareCount: _intValue(data['shareCount']),

      viewCount: _intValue(data['viewCount']),

      createdAt: _timestampValue(
        data['createdAt'] ?? data['clientCreatedAt'] ?? data['repostedAt'],
      ),

      //===================================================
      // REPOST
      //===================================================
      isRepost: data['isRepost'] == true,

      originalPostId: data['originalPostId']?.toString(),

      repostCaption: data['repostCaption']?.toString(),

      repostType: (data['repostType'] ?? '').toString(),

      repostText: (data['repostText'] ?? data['repostCaption'] ?? '')
          .toString(),

      rootOriginalPostId:
          (data['rootOriginalPostId'] ?? data['originalPostId'] ?? '')
              .toString(),

      sourcePostId: (data['sourcePostId'] ?? data['originalPostId'] ?? '')
          .toString(),

      originalUid: (data['originalUid'] ?? '').toString(),

      originalUsername: (data['originalUsername'] ?? '').toString(),

      originalFullName: (data['originalFullName'] ?? '').toString(),

      originalPhotoUrl: (data['originalPhotoUrl'] ?? '').toString(),

      originalCaption: (data['originalCaption'] ?? '').toString(),

      originalCreatedAt: _timestampValue(data['originalCreatedAt']),

      repostedAt: _timestampValue(data['repostedAt']),

      //===================================================
      // HIDE
      //===================================================
      isHidden: data['isHidden'] == true,

      isRootHidden: data['isRootHidden'] == true,

      hiddenAt: _timestampValue(data['hiddenAt']),
    );
  }

  //===================================================
  // TO FIRESTORE
  //===================================================

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'postId': postId,

      'uid': uid,

      'username': username,

      'fullName': fullName,

      'photoUrl': photoUrl,

      'caption': caption,

      'thumbnailUrl': thumbnailUrl,

      'media': media.map((PostMedia item) => item.toMap()).toList(),

      'mediaCount': media.length,

      'isNUBuzz': isNUBuzz,

      'postType': postType,

      'hasPoll': hasPoll,

      'poll': poll,

      'taggedUsers': taggedUsers
          .map((TaggedUser user) => user.toMap())
          .toList(),

      'taggedUserIds': taggedUserIds,

      'likeCount': likeCount,

      'commentCount': commentCount,

      'repostCount': repostCount,

      'shareCount': shareCount,

      'viewCount': viewCount,

      'createdAt': createdAt,

      //===================================================
      // REPOST
      //===================================================
      'isRepost': isRepost,

      'originalPostId': originalPostId,

      'repostCaption': repostCaption,

      'repostType': repostType,

      'repostText': repostText,

      'rootOriginalPostId': rootOriginalPostId,

      'sourcePostId': sourcePostId,

      'originalUid': originalUid,

      'originalUsername': originalUsername,

      'originalFullName': originalFullName,

      'originalPhotoUrl': originalPhotoUrl,

      'originalCaption': originalCaption,

      'originalCreatedAt': originalCreatedAt,

      'repostedAt': repostedAt,

      //===================================================
      // HIDE
      //===================================================
      'isHidden': isHidden,

      'isRootHidden': isRootHidden,

      'hiddenAt': hiddenAt,
    };
  }

  //===================================================
  // IS PLAIN REPOST
  //===================================================

  bool get isPlainRepost {
    return isRepost && repostType != 'quote' && repostText.trim().isEmpty;
  }

  //===================================================
  // IS QUOTE REPOST
  //===================================================

  bool get isQuoteRepost {
    return isRepost && (repostType == 'quote' || repostText.trim().isNotEmpty);
  }

  //===================================================
  // ROOT POST ID
  //===================================================

  String get rootPostId {
    if (!isRepost) {
      return postId;
    }

    if (rootOriginalPostId.trim().isNotEmpty) {
      return rootOriginalPostId.trim();
    }

    if (originalPostId?.trim().isNotEmpty == true) {
      return originalPostId!.trim();
    }

    return postId;
  }

  //===================================================
  // SHOULD BE PUBLICLY VISIBLE
  //===================================================

  bool get isPubliclyVisible {
    return !isHidden && !isRootHidden;
  }
}

//===================================================
// POST MEDIA
//===================================================

class PostMedia {
  final String url;
  final String type;
  final String fileName;
  final String storagePath;
  final int order;
  final String thumbnailUrl;

  PostMedia({
    required this.url,
    required this.type,
    required this.fileName,
    required this.storagePath,
    required this.order,
    this.thumbnailUrl = '',
  });

  //===================================================
  // FROM MAP
  //===================================================

  factory PostMedia.fromMap(Map<String, dynamic> data) {
    return PostMedia(
      url: (data['url'] ?? '').toString(),

      type: (data['type'] ?? 'image').toString(),

      fileName: (data['fileName'] ?? '').toString(),

      storagePath: (data['storagePath'] ?? '').toString(),

      order: _intValue(data['order']),
      thumbnailUrl: (data['thumbnailUrl'] ?? '').toString(),
    );
  }
  //===================================================
  // SAVE POST MEDIA WITH THUMBNAIL
  //===================================================

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'url': url,
      'type': type,
      'fileName': fileName,
      'storagePath': storagePath,
      'order': order,
      'thumbnailUrl': thumbnailUrl,
    };
  }
  //===================================================
  // CHECK MEDIA TYPE
  //===================================================

  bool get isVideo {
    return type.toLowerCase() == 'video';
  }

  bool get isImage {
    return type.toLowerCase() == 'image';
  }
}

//===================================================
// TAGGED USER
//===================================================

class TaggedUser {
  final String uid;
  final String username;
  final String photoUrl;

  TaggedUser({
    required this.uid,
    required this.username,
    required this.photoUrl,
  });

  //===================================================
  // FROM MAP
  //===================================================

  factory TaggedUser.fromMap(Map<String, dynamic> data) {
    return TaggedUser(
      uid: (data['uid'] ?? '').toString(),

      username: (data['username'] ?? 'User').toString(),

      photoUrl: (data['photoUrl'] ?? '').toString(),
    );
  }

  //===================================================
  // TO MAP
  //===================================================

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'uid': uid,

      'username': username,

      'photoUrl': photoUrl,
    };
  }
}

//===================================================
// INT HELPER
//===================================================

int _intValue(dynamic value) {
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(value?.toString() ?? '') ?? 0;
}

//===================================================
// TIMESTAMP HELPER
//===================================================

Timestamp? _timestampValue(dynamic value) {
  if (value is Timestamp) {
    return value;
  }

  if (value is DateTime) {
    return Timestamp.fromDate(value);
  }

  if (value is String) {
    final DateTime? parsed = DateTime.tryParse(value);

    if (parsed != null) {
      return Timestamp.fromDate(parsed);
    }
  }

  return null;
}
