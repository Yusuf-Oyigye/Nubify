import 'package:cloud_firestore/cloud_firestore.dart';

import 'story_drawing.dart';

//===================================================
// DATETIME BACKWARD COMPATIBILITY
//===================================================

extension NubifyDateTimeCompatibility on DateTime {
  DateTime toDate() {
    return this;
  }
}

//===================================================
// STORY PERSON
//===================================================
class StoryPerson {
  final String uid;
  final String username;
  final String fullName;
  final String photoUrl;
  final double tagX;
  final double tagY;

  const StoryPerson({
    required this.uid,
    required this.username,
    required this.fullName,
    required this.photoUrl,
    this.tagX = 0.50,
    this.tagY = 0.70,
  });

  //===================================================
  // DISPLAY NAME
  //===================================================

  String get displayName {
    if (fullName.trim().isNotEmpty) {
      return fullName.trim();
    }

    if (username.trim().isNotEmpty) {
      return username.trim();
    }

    return 'Nubify User';
  }

  //===================================================
  // FROM MAP
  //===================================================

  factory StoryPerson.fromMap(
    Map<String, dynamic> map, {
    String fallbackUid = '',
  }) {
    final String mappedUid = (map['uid'] ?? '').toString().trim();

    return StoryPerson(
      uid: mappedUid.isNotEmpty ? mappedUid : fallbackUid,

      username: (map['username'] ?? '').toString().trim(),

      fullName: (map['fullName'] ?? map['name'] ?? '').toString().trim(),

      photoUrl: (map['photoUrl'] ?? map['profilePhoto'] ?? '')
          .toString()
          .trim(),

      tagX: map['tagX'] is num ? (map['tagX'] as num).toDouble() : 0.50,

      tagY: map['tagY'] is num ? (map['tagY'] as num).toDouble() : 0.70,
    );
  }

  //===================================================
  // TO MAP
  //===================================================

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'uid': uid,

      'username': username,

      'fullName': fullName,

      'photoUrl': photoUrl,

      'tagX': tagX,

      'tagY': tagY,
    };
  }

  //===================================================
  // COPY WITH
  //===================================================

  StoryPerson copyWith({
    String? uid,
    String? username,
    String? fullName,
    String? photoUrl,
    double? tagX,
    double? tagY,
  }) {
    return StoryPerson(
      uid: uid ?? this.uid,

      username: username ?? this.username,

      fullName: fullName ?? this.fullName,

      photoUrl: photoUrl ?? this.photoUrl,

      tagX: tagX ?? this.tagX,

      tagY: tagY ?? this.tagY,
    );
  }
}
//===================================================
// STORY POLL OPTION
//===================================================

class StoryPollOption {
  final String text;
  final int votes;

  const StoryPollOption({required this.text, required this.votes});

  factory StoryPollOption.fromMap(Map<String, dynamic> map) {
    return StoryPollOption(
      text: (map['text'] ?? '').toString(),
      votes: _toInt(map['votes']),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{'text': text, 'votes': votes};
  }

  StoryPollOption copyWith({String? text, int? votes}) {
    return StoryPollOption(text: text ?? this.text, votes: votes ?? this.votes);
  }
}

//===================================================
// STORY POLL
//===================================================

class StoryPoll {
  final String question;

  final List<StoryPollOption> options;

  final int totalVotes;

  final List<String> votedUserIds;

  final Map<String, int> userVotes;

  const StoryPoll({
    required this.question,
    required this.options,
    required this.totalVotes,
    this.votedUserIds = const <String>[],
    this.userVotes = const <String, int>{},
  });

  factory StoryPoll.fromMap(Map<String, dynamic> map) {
    final List<dynamic> rawOptions = map['options'] is List
        ? map['options'] as List<dynamic>
        : <dynamic>[];

    final List<dynamic> rawVoters = map['votedUserIds'] is List
        ? map['votedUserIds'] as List<dynamic>
        : <dynamic>[];

    final Map<String, int> parsedUserVotes = <String, int>{};

    final dynamic rawUserVotes = map['userVotes'];

    if (rawUserVotes is Map) {
      rawUserVotes.forEach((dynamic key, dynamic value) {
        parsedUserVotes[key.toString()] = _toInt(value);
      });
    }

    return StoryPoll(
      question: (map['question'] ?? '').toString(),
      options: rawOptions.whereType<Map>().map((Map item) {
        return StoryPollOption.fromMap(Map<String, dynamic>.from(item));
      }).toList(),
      totalVotes: _toInt(map['totalVotes']),
      votedUserIds: rawVoters
          .map((dynamic item) {
            return item.toString();
          })
          .where((String item) {
            return item.isNotEmpty;
          })
          .toList(),
      userVotes: parsedUserVotes,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'question': question,
      'options': options.map((StoryPollOption option) {
        return option.toMap();
      }).toList(),
      'totalVotes': totalVotes,
      'votedUserIds': votedUserIds,
      'userVotes': userVotes,
    };
  }

  StoryPoll copyWith({
    String? question,
    List<StoryPollOption>? options,
    int? totalVotes,
    List<String>? votedUserIds,
    Map<String, int>? userVotes,
  }) {
    return StoryPoll(
      question: question ?? this.question,
      options: options ?? this.options,
      totalVotes: totalVotes ?? this.totalVotes,
      votedUserIds: votedUserIds ?? this.votedUserIds,
      userVotes: userVotes ?? this.userVotes,
    );
  }
}

//===================================================
// NUBIFY STORY
//===================================================

class NubifyStory {
  //===================================================
  // OWNER
  //===================================================

  final String storyId;
  final String uid;
  final String username;
  final String fullName;
  final String photoUrl;

  //===================================================
  // CONTENT
  //===================================================

  final String type;
  final String mediaUrl;
  final List<String> mediaUrls;
  final String text;
  final String caption;
  final String thumbnailUrl;
  //===================================================
  // STORY LINK
  //===================================================

  final String linkUrl;

  final String linkStyle;

  final double linkX;

  final double linkY;

  final double linkScale;
  //=============================
  // STICKER
  //=============================

  final String sticker;
  final double stickerX;
  final double stickerY;
  final double stickerSize;

  //===================================================
  // DESIGN
  //===================================================

  final int backgroundColor;
  final int textColor;
  final String textStyle;
  final String textAlign;
  final double textSize;
  final double textX;
  final double textY;
  final List<StoryDrawingStroke> drawings;
  final int durationSeconds;

  //===================================================
  // LAYOUT
  //===================================================

  final int layoutCount;
  final String layoutStyle;

  //===================================================
  // TAGGING
  //===================================================

  final List<StoryPerson> taggedPeople;
  final List<String> taggedUserIds;

  //===================================================
  // ENGAGEMENT
  //===================================================

  final List<String> viewerIds;
  final List<String> likedUserIds;

  final int viewCount;
  final int likeCount;
  final int replyCount;
  final int shareCount;
  final int reshareCount;

  //===================================================
  // POLL
  //===================================================

  final StoryPoll? poll;

  //===================================================
  // POST SHARE
  //===================================================

  final String postId;

  //===================================================
  // STORY RESHARE
  //===================================================

  final String sourceStoryId;
  final String sourceOwnerId;
  final String sourceUsername;
  final String sourceType;
  final String sourceMediaUrl;
  final List<String> sourceMediaUrls;
  final String sourceText;

  //===================================================
  // TIME
  //===================================================

  final DateTime createdAt;
  final DateTime expiresAt;

  const NubifyStory({
    required this.storyId,
    required this.uid,
    required this.username,
    required this.fullName,
    required this.photoUrl,
    required this.type,
    required this.mediaUrl,
    required this.mediaUrls,
    required this.text,
    required this.caption,
    this.thumbnailUrl = '',

    required this.sticker,
    required this.stickerX,
    required this.stickerY,
    required this.stickerSize,

    required this.backgroundColor,
    required this.textColor,
    required this.textStyle,
    required this.textAlign,
    required this.textSize,
    this.textX = 0.50,
    this.textY = 0.50,
    this.drawings = const <StoryDrawingStroke>[],
    required this.durationSeconds,
    required this.layoutCount,
    required this.layoutStyle,
    required this.taggedPeople,
    required this.taggedUserIds,
    required this.viewerIds,
    required this.likedUserIds,
    required this.viewCount,
    required this.likeCount,
    required this.replyCount,
    required this.shareCount,
    required this.reshareCount,
    required this.poll,
    required this.postId,
    required this.sourceStoryId,
    required this.sourceOwnerId,
    required this.sourceUsername,
    required this.sourceType,
    required this.sourceMediaUrl,
    required this.sourceMediaUrls,
    required this.sourceText,
    required this.createdAt,
    required this.expiresAt,
    this.linkUrl = '',
    this.linkStyle = 'medium',
    this.linkX = 0.50,
    this.linkY = 0.52,
    this.linkScale = 1.0,
  });

  //===================================================
  // DISPLAY NAME
  //===================================================

  String get displayName {
    if (fullName.trim().isNotEmpty) {
      return fullName.trim();
    }

    if (username.trim().isNotEmpty) {
      return username.trim();
    }

    return 'Nubify User';
  }

  //===================================================
  // OWNER
  //===================================================

  StoryPerson get owner {
    return StoryPerson(
      uid: uid,
      username: username,
      fullName: fullName,
      photoUrl: photoUrl,
    );
  }

  //===================================================
  // TYPE HELPERS
  //===================================================

  bool get isExpired {
    return !expiresAt.isAfter(DateTime.now());
  }

  bool get isImage => type == 'image';

  bool get isVideo => type == 'video';

  bool get isVoice => type == 'voice';

  bool get isLayout => type == 'layout';

  bool get isText => type == 'text';

  bool get isPoll => type == 'poll';

  bool isViewedBy(String? userId) {
    if (userId == null || userId.trim().isEmpty) {
      return false;
    }

    return viewerIds.contains(userId);
  }

  bool isLikedBy(String? userId) {
    if (userId == null || userId.trim().isEmpty) {
      return false;
    }

    return likedUserIds.contains(userId);
  }

  //===================================================
  // FROM FIRESTORE
  //===================================================

  factory NubifyStory.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    return NubifyStory.fromDocument(document);
  }

  factory NubifyStory.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    return NubifyStory.fromMap(
      document.data() ?? <String, dynamic>{},
      document.id,
    );
  }

  //===================================================
  // FROM MAP
  //===================================================

  factory NubifyStory.fromMap(Map<String, dynamic> map, [String? documentId]) {
    final DateTime now = DateTime.now();

    final DateTime createdAt = _toDateTime(map['createdAt']) ?? now;

    final DateTime expiresAt =
        _toDateTime(map['expiresAt']) ??
        createdAt.add(const Duration(hours: 24));

    final List<dynamic> rawMediaUrls = map['mediaUrls'] is List
        ? map['mediaUrls'] as List<dynamic>
        : <dynamic>[];

    final List<dynamic> rawTaggedPeople = map['taggedPeople'] is List
        ? map['taggedPeople'] as List<dynamic>
        : <dynamic>[];

    final List<dynamic> rawTaggedUserIds = map['taggedUserIds'] is List
        ? map['taggedUserIds'] as List<dynamic>
        : <dynamic>[];

    final List<dynamic> rawViewerIds = map['viewerIds'] is List
        ? map['viewerIds'] as List<dynamic>
        : <dynamic>[];

    final List<dynamic> rawLikedUserIds = map['likedUserIds'] is List
        ? map['likedUserIds'] as List<dynamic>
        : <dynamic>[];

    final List<dynamic> rawSourceMediaUrls = map['sourceMediaUrls'] is List
        ? map['sourceMediaUrls'] as List<dynamic>
        : <dynamic>[];

    final List<dynamic> rawDrawings = map['drawings'] is List
        ? map['drawings'] as List<dynamic>
        : <dynamic>[];

    StoryPoll? poll;

    if (map['poll'] is Map) {
      poll = StoryPoll.fromMap(Map<String, dynamic>.from(map['poll'] as Map));
    }

    int layoutCount = _toInt(map['layoutCount']);

    if (layoutCount < 2) {
      if (rawMediaUrls.length >= 4) {
        layoutCount = 4;
      } else if (rawMediaUrls.length == 3) {
        layoutCount = 3;
      } else {
        layoutCount = 2;
      }
    }

    layoutCount = layoutCount.clamp(2, 4).toInt();

    return NubifyStory(
      storyId: (map['storyId'] ?? documentId ?? '').toString(),

      uid: (map['uid'] ?? '').toString(),

      username: (map['username'] ?? '').toString(),

      fullName: (map['fullName'] ?? map['name'] ?? '').toString(),

      photoUrl: (map['photoUrl'] ?? map['profilePhoto'] ?? '').toString(),

      type: (map['type'] ?? 'text').toString(),

      mediaUrl: (map['mediaUrl'] ?? '').toString(),

      mediaUrls: rawMediaUrls
          .map((dynamic item) {
            return item.toString();
          })
          .where((String item) {
            return item.trim().isNotEmpty;
          })
          .toList(),

      text: (map['text'] ?? '').toString(),

      caption: (map['caption'] ?? '').toString(),
      //=============================
      // STORY LINK AND THUMBNAIL
      //=============================
      thumbnailUrl: (map['thumbnailUrl'] ?? '').toString(),

      linkUrl: (map['linkUrl'] ?? '').toString(),

      linkStyle: (map['linkStyle'] ?? 'medium').toString(),

      linkX: map['linkX'] is num ? (map['linkX'] as num).toDouble() : 0.50,

      linkY: map['linkY'] is num ? (map['linkY'] as num).toDouble() : 0.52,

      linkScale: map['linkScale'] is num
          ? (map['linkScale'] as num).toDouble()
          : 1.0,
      sticker: (map['sticker'] ?? '').toString(),

      stickerX: _toDouble(
        map['stickerX'],
        fallback: 0.80,
      ).clamp(0.04, 0.96).toDouble(),

      stickerY: _toDouble(
        map['stickerY'],
        fallback: 0.14,
      ).clamp(0.04, 0.96).toDouble(),

      stickerSize: _toDouble(
        map['stickerSize'],
        fallback: 54.0,
      ).clamp(28.0, 120.0).toDouble(),

      backgroundColor: _toInt(map['backgroundColor'], fallback: 0xFF101114),

      textColor: _toInt(map['textColor'], fallback: 0xFFFFFFFF),

      textStyle: (map['textStyle'] ?? 'bold').toString(),

      textAlign: (map['textAlign'] ?? 'center').toString(),

      textSize: _toDouble(map['textSize'], fallback: 34),

      textX: _toDouble(
        map['textX'],
        fallback: 0.50,
      ).clamp(0.06, 0.94).toDouble(),

      textY: _toDouble(
        map['textY'],
        fallback: 0.50,
      ).clamp(0.08, 0.92).toDouble(),

      drawings: rawDrawings
          .whereType<Map>()
          .take(80)
          .map(
            (Map<dynamic, dynamic> stroke) => StoryDrawingStroke.fromMap(
              Map<String, dynamic>.from(stroke),
            ),
          )
          .where((StoryDrawingStroke stroke) => stroke.points.isNotEmpty)
          .toList(growable: false),

      //===================================================
      // 3 MINUTES = 180 SECONDS
      //===================================================
      durationSeconds: _toInt(
        map['durationSeconds'],
        fallback: 8,
      ).clamp(3, 180).toInt(),
      layoutCount: layoutCount,

      layoutStyle: (map['layoutStyle'] ?? 'grid').toString(),

      taggedPeople: rawTaggedPeople.whereType<Map>().map((Map item) {
        return StoryPerson.fromMap(Map<String, dynamic>.from(item));
      }).toList(),

      taggedUserIds: rawTaggedUserIds
          .map((dynamic item) => item.toString())
          .where((String item) => item.trim().isNotEmpty)
          .toList(),

      viewerIds: rawViewerIds
          .map((dynamic item) => item.toString())
          .where((String item) => item.trim().isNotEmpty)
          .toList(),

      likedUserIds: rawLikedUserIds
          .map((dynamic item) => item.toString())
          .where((String item) => item.trim().isNotEmpty)
          .toList(),

      viewCount: _toInt(map['viewCount']),

      likeCount: _toInt(map['likeCount']),

      replyCount: _toInt(map['replyCount']),

      shareCount: _toInt(map['shareCount']),

      reshareCount: _toInt(map['reshareCount']),

      poll: poll,

      postId: (map['postId'] ?? '').toString(),

      sourceStoryId: (map['sourceStoryId'] ?? '').toString(),

      sourceOwnerId: (map['sourceOwnerId'] ?? '').toString(),

      sourceUsername: (map['sourceUsername'] ?? '').toString(),

      sourceType: (map['sourceType'] ?? '').toString(),

      sourceMediaUrl: (map['sourceMediaUrl'] ?? '').toString(),

      sourceMediaUrls: rawSourceMediaUrls
          .map((dynamic item) => item.toString())
          .where((String item) => item.trim().isNotEmpty)
          .toList(),

      sourceText: (map['sourceText'] ?? '').toString(),

      createdAt: createdAt,

      expiresAt: expiresAt,
    );
  }

  //===================================================
  // TO MAP
  //===================================================

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'storyId': storyId,
      'uid': uid,
      'username': username,
      'fullName': fullName,
      'photoUrl': photoUrl,
      'type': type,
      'mediaUrl': mediaUrl,
      'mediaUrls': mediaUrls,
      'text': text,
      'caption': caption,

      //=============================
      // STORY LINK AND THUMBNAIL
      //=============================
      'thumbnailUrl': thumbnailUrl,
      'linkUrl': linkUrl,
      'linkStyle': linkStyle,
      'linkX': linkX,
      'linkY': linkY,
      'linkScale': linkScale,

      'sticker': sticker,

      'stickerX': stickerX,

      'stickerY': stickerY,

      'stickerSize': stickerSize,

      'backgroundColor': backgroundColor,
      'textColor': textColor,
      'textStyle': textStyle,
      'textAlign': textAlign,
      'textSize': textSize,
      'textX': textX,
      'textY': textY,
      'drawings': drawings
          .take(80)
          .map((StoryDrawingStroke stroke) => stroke.toMap())
          .toList(growable: false),
      'durationSeconds': durationSeconds,
      'layoutCount': layoutCount,
      'layoutStyle': layoutStyle,
      'taggedPeople': taggedPeople
          .map((StoryPerson person) => person.toMap())
          .toList(),
      'taggedUserIds': taggedUserIds,
      'viewerIds': viewerIds,
      'likedUserIds': likedUserIds,
      'viewCount': viewCount,
      'likeCount': likeCount,
      'replyCount': replyCount,
      'shareCount': shareCount,
      'reshareCount': reshareCount,
      'poll': poll?.toMap(),
      'postId': postId,
      'sourceStoryId': sourceStoryId,
      'sourceOwnerId': sourceOwnerId,
      'sourceUsername': sourceUsername,
      'sourceType': sourceType,
      'sourceMediaUrl': sourceMediaUrl,
      'sourceMediaUrls': sourceMediaUrls,
      'sourceText': sourceText,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
    };
  }

  //===================================================
  // COPY WITH
  //===================================================

  NubifyStory copyWith({
    String? storyId,
    String? uid,
    String? username,
    String? fullName,
    String? photoUrl,
    String? type,
    String? mediaUrl,
    List<String>? mediaUrls,
    String? text,
    String? caption,
    String? thumbnailUrl,
    String? linkUrl,
    String? linkStyle,
    double? linkX,
    double? linkY,
    double? linkScale,

    String? sticker,
    double? stickerX,
    double? stickerY,
    double? stickerSize,

    int? backgroundColor,

    int? textColor,
    String? textStyle,
    String? textAlign,
    double? textSize,
    double? textX,
    double? textY,
    List<StoryDrawingStroke>? drawings,
    int? durationSeconds,
    int? layoutCount,
    String? layoutStyle,
    List<StoryPerson>? taggedPeople,
    List<String>? taggedUserIds,
    List<String>? viewerIds,
    List<String>? likedUserIds,
    int? viewCount,
    int? likeCount,
    int? replyCount,
    int? shareCount,
    int? reshareCount,
    StoryPoll? poll,
    String? postId,
    String? sourceStoryId,
    String? sourceOwnerId,
    String? sourceUsername,
    String? sourceType,
    String? sourceMediaUrl,
    List<String>? sourceMediaUrls,
    String? sourceText,
    DateTime? createdAt,
    DateTime? expiresAt,
  }) {
    return NubifyStory(
      storyId: storyId ?? this.storyId,
      uid: uid ?? this.uid,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      photoUrl: photoUrl ?? this.photoUrl,
      type: type ?? this.type,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      text: text ?? this.text,
      caption: caption ?? this.caption,
      //=============================
      // STORY LINK AND THUMBNAIL
      //=============================
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      linkUrl: linkUrl ?? this.linkUrl,
      linkStyle: linkStyle ?? this.linkStyle,
      linkX: linkX ?? this.linkX,
      linkY: linkY ?? this.linkY,
      linkScale: linkScale ?? this.linkScale,

      sticker: sticker ?? this.sticker,

      stickerX: stickerX ?? this.stickerX,

      stickerY: stickerY ?? this.stickerY,

      stickerSize: stickerSize ?? this.stickerSize,

      backgroundColor: backgroundColor ?? this.backgroundColor,
      textColor: textColor ?? this.textColor,
      textStyle: textStyle ?? this.textStyle,
      textAlign: textAlign ?? this.textAlign,
      textSize: textSize ?? this.textSize,
      textX: textX ?? this.textX,
      textY: textY ?? this.textY,
      drawings: drawings ?? this.drawings,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      layoutCount: layoutCount ?? this.layoutCount,
      layoutStyle: layoutStyle ?? this.layoutStyle,
      taggedPeople: taggedPeople ?? this.taggedPeople,
      taggedUserIds: taggedUserIds ?? this.taggedUserIds,
      viewerIds: viewerIds ?? this.viewerIds,
      likedUserIds: likedUserIds ?? this.likedUserIds,
      viewCount: viewCount ?? this.viewCount,
      likeCount: likeCount ?? this.likeCount,
      replyCount: replyCount ?? this.replyCount,
      shareCount: shareCount ?? this.shareCount,
      reshareCount: reshareCount ?? this.reshareCount,
      poll: poll ?? this.poll,
      postId: postId ?? this.postId,
      sourceStoryId: sourceStoryId ?? this.sourceStoryId,
      sourceOwnerId: sourceOwnerId ?? this.sourceOwnerId,
      sourceUsername: sourceUsername ?? this.sourceUsername,
      sourceType: sourceType ?? this.sourceType,
      sourceMediaUrl: sourceMediaUrl ?? this.sourceMediaUrl,
      sourceMediaUrls: sourceMediaUrls ?? this.sourceMediaUrls,
      sourceText: sourceText ?? this.sourceText,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }
}

//===================================================
// STORY GROUP
//===================================================

class StoryGroup {
  final StoryPerson owner;

  final List<NubifyStory> stories;

  const StoryGroup({required this.owner, required this.stories});

  String get uid => owner.uid;

  String get userId => owner.uid;

  String get ownerId => owner.uid;

  String get username => owner.username;

  String get fullName => owner.fullName;

  String get photoUrl => owner.photoUrl;

  String get displayName => owner.displayName;

  int get storyCount => stories.length;

  bool get isEmpty => stories.isEmpty;

  bool get isNotEmpty => stories.isNotEmpty;

  //===================================================
  // LATEST STORY
  //===================================================

  NubifyStory? get latestStory {
    if (stories.isEmpty) {
      return null;
    }

    NubifyStory latest = stories.first;

    for (final NubifyStory story in stories) {
      if (story.createdAt.isAfter(latest.createdAt)) {
        latest = story;
      }
    }

    return latest;
  }

  //===================================================
  // EARLIEST STORY
  //===================================================

  NubifyStory? get earliestStory {
    if (stories.isEmpty) {
      return null;
    }

    NubifyStory earliest = stories.first;

    for (final NubifyStory story in stories) {
      if (story.createdAt.isBefore(earliest.createdAt)) {
        earliest = story;
      }
    }

    return earliest;
  }

  //===================================================
  // HAS UNREAD
  //===================================================

  bool hasUnreadFor(String? userId) {
    if (stories.isEmpty) {
      return false;
    }

    if (userId == null || userId.trim().isEmpty) {
      return true;
    }

    for (final NubifyStory story in stories) {
      if (!story.viewerIds.contains(userId)) {
        return true;
      }
    }

    return false;
  }

  //===================================================
  // VIEWED ALL
  //===================================================

  bool hasViewedAllFor(String? userId) {
    if (stories.isEmpty) {
      return true;
    }

    return !hasUnreadFor(userId);
  }

  //===================================================
  // UNREAD COUNT
  //===================================================

  int unreadCountFor(String? userId) {
    if (stories.isEmpty) {
      return 0;
    }

    if (userId == null || userId.trim().isEmpty) {
      return stories.length;
    }

    int count = 0;

    for (final NubifyStory story in stories) {
      if (!story.viewerIds.contains(userId)) {
        count++;
      }
    }

    return count;
  }

  //===================================================
  // VIEWED COUNT
  //===================================================

  int viewedCountFor(String? userId) {
    if (stories.isEmpty || userId == null || userId.trim().isEmpty) {
      return 0;
    }

    int count = 0;

    for (final NubifyStory story in stories) {
      if (story.viewerIds.contains(userId)) {
        count++;
      }
    }

    return count;
  }

  //===================================================
  // FIRST UNREAD INDEX
  //===================================================

  int firstUnreadIndexFor(String? userId) {
    if (stories.isEmpty) {
      return 0;
    }

    if (userId == null || userId.trim().isEmpty) {
      return 0;
    }

    for (int index = 0; index < stories.length; index++) {
      final NubifyStory story = stories[index];

      if (!story.viewerIds.contains(userId)) {
        return index;
      }
    }

    return 0;
  }

  //===================================================
  // ACTIVE STORIES
  //===================================================

  List<NubifyStory> get activeStories {
    return stories.where((NubifyStory story) => !story.isExpired).toList();
  }
}

//===================================================
// INT HELPER
//===================================================

int _toInt(dynamic value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

//===================================================
// DOUBLE HELPER
//===================================================

double _toDouble(dynamic value, {double fallback = 0}) {
  if (value is double) {
    return value;
  }

  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

//===================================================
// DATE HELPER
//===================================================

DateTime? _toDateTime(dynamic value) {
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
