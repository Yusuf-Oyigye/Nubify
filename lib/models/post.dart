import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  final String postId;
  final String uid;
  final String username;
  final String fullName;
  final String photoUrl;
  final String caption;

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

  final bool isRepost;
  final String? originalPostId;
  final String? repostCaption;

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
  });

  // ============================================================
  // FROM FIRESTORE
  // ============================================================

  factory Post.fromFirestore(
      DocumentSnapshot snapshot,
      ) {
    final Map<String, dynamic> data =
    snapshot.data() as Map<String, dynamic>;

    final List<dynamic> mediaData =
        data['media'] ?? [];

    final List<dynamic> taggedData =
        data['taggedUsers'] ?? [];

    return Post(
      postId: data['postId'] ?? snapshot.id,

      uid: data['uid'] ?? '',

      username: data['username'] ?? 'User',

      fullName: data['fullName'] ?? '',

      photoUrl: data['photoUrl'] ?? '',

      caption: data['caption'] ?? '',

      media: mediaData.map((item) {
        return PostMedia.fromMap(
          Map<String, dynamic>.from(item),
        );
      }).toList(),

      isNUBuzz: data['isNUBuzz'] == true,

      postType: data['postType'] ?? 'post',

      hasPoll: data['hasPoll'] == true,

      poll: data['poll'] != null
          ? Map<String, dynamic>.from(
        data['poll'],
      )
          : null,

      taggedUsers: taggedData.map((item) {
        return TaggedUser.fromMap(
          Map<String, dynamic>.from(item),
        );
      }).toList(),

      taggedUserIds:
      List<String>.from(
        data['taggedUserIds'] ?? [],
      ),

      likeCount:
      (data['likeCount'] ?? 0) as int,

      commentCount:
      (data['commentCount'] ?? 0) as int,

      repostCount:
      (data['repostCount'] ?? 0) as int,

      shareCount:
      (data['shareCount'] ?? 0) as int,

      viewCount:
      (data['viewCount'] ?? 0) as int,

      createdAt:
      data['createdAt'] is Timestamp
          ? data['createdAt']
          : null,

      isRepost:
      data['isRepost'] == true,

      originalPostId:
      data['originalPostId'],

      repostCaption:
      data['repostCaption'],
    );
  }

  // ============================================================
  // TO FIRESTORE
  // ============================================================

  Map<String, dynamic> toMap() {
    return {
      'postId': postId,
      'uid': uid,
      'username': username,
      'fullName': fullName,
      'photoUrl': photoUrl,
      'caption': caption,

      'media':
      media.map((item) => item.toMap()).toList(),

      'mediaCount': media.length,

      'isNUBuzz': isNUBuzz,
      'postType': postType,

      'hasPoll': hasPoll,
      'poll': poll,

      'taggedUsers':
      taggedUsers
          .map((user) => user.toMap())
          .toList(),

      'taggedUserIds': taggedUserIds,

      'likeCount': likeCount,
      'commentCount': commentCount,
      'repostCount': repostCount,
      'shareCount': shareCount,
      'viewCount': viewCount,

      'createdAt': createdAt,

      'isRepost': isRepost,
      'originalPostId': originalPostId,
      'repostCaption': repostCaption,
    };
  }
}

// ============================================================
// POST MEDIA
// ============================================================

class PostMedia {
  final String url;
  final String type;
  final String fileName;
  final String storagePath;
  final int order;

  PostMedia({
    required this.url,
    required this.type,
    required this.fileName,
    required this.storagePath,
    required this.order,
  });

  // ============================================================
  // FROM MAP
  // ============================================================

  factory PostMedia.fromMap(
      Map<String, dynamic> data,
      ) {
    return PostMedia(
      url: data['url'] ?? '',

      type: data['type'] ?? 'image',

      fileName: data['fileName'] ?? '',

      storagePath:
      data['storagePath'] ?? '',

      order: data['order'] ?? 0,
    );
  }

  // ============================================================
  // TO MAP
  // ============================================================

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'type': type,
      'fileName': fileName,
      'storagePath': storagePath,
      'order': order,
    };
  }

  // ============================================================
  // CHECK MEDIA TYPE
  // ============================================================

  bool get isVideo {
    return type == 'video';
  }

  bool get isImage {
    return type == 'image';
  }
}

// ============================================================
// TAGGED USER
// ============================================================

class TaggedUser {
  final String uid;
  final String username;
  final String photoUrl;

  TaggedUser({
    required this.uid,
    required this.username,
    required this.photoUrl,
  });

  // ============================================================
  // FROM MAP
  // ============================================================

  factory TaggedUser.fromMap(
      Map<String, dynamic> data,
      ) {
    return TaggedUser(
      uid: data['uid'] ?? '',

      username: data['username'] ?? 'User',

      photoUrl: data['photoUrl'] ?? '',
    );
  }

  // ============================================================
  // TO MAP
  // ============================================================

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'username': username,
      'photoUrl': photoUrl,
    };
  }
}