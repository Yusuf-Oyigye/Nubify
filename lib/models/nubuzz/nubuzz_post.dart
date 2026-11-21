import 'package:cloud_firestore/cloud_firestore.dart';

class NubuzzVideo {
  final String postId;
  final String uid;
  final String username;
  final String fullName;
  final String photoUrl;
  final String caption;
  final String videoUrl;
  final DateTime createdAt;
  final int likeCount;
  final int commentCount;
  final int repostCount;
  final int shareCount;
  final int viewCount;

  const NubuzzVideo({
    required this.postId,
    required this.uid,
    required this.username,
    required this.fullName,
    required this.photoUrl,
    required this.caption,
    required this.videoUrl,
    required this.createdAt,
    required this.likeCount,
    required this.commentCount,
    required this.repostCount,
    required this.shareCount,
    required this.viewCount,
  });

  factory NubuzzVideo.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> document,
      ) {
    final Map<String, dynamic> data =
        document.data() ?? <String, dynamic>{};

    final dynamic rawCreatedAt = data['createdAt'];

    DateTime createdAt;

    if (rawCreatedAt is Timestamp) {
      createdAt = rawCreatedAt.toDate();
    } else if (rawCreatedAt is DateTime) {
      createdAt = rawCreatedAt;
    } else if (rawCreatedAt is String) {
      createdAt =
          DateTime.tryParse(rawCreatedAt) ??
              DateTime.fromMillisecondsSinceEpoch(0);
    } else {
      createdAt = DateTime.fromMillisecondsSinceEpoch(0);
    }

    String videoUrl = '';

    final dynamic rawMedia = data['media'];

    if (rawMedia is List && rawMedia.isNotEmpty) {
      for (final dynamic rawItem in rawMedia) {
        if (rawItem is Map) {
          final Map<String, dynamic> item =
          Map<String, dynamic>.from(rawItem);

          final String type =
          (item['type'] ?? '')
              .toString()
              .toLowerCase();

          final String url =
          (
              item['url'] ??
                  item['downloadUrl'] ??
                  item['mediaUrl'] ??
                  ''
          ).toString();

          if (url.isNotEmpty &&
              (type == 'video' || type.isEmpty)) {
            videoUrl = url;
            break;
          }
        } else if (rawItem is String &&
            rawItem.isNotEmpty) {
          videoUrl = rawItem;
          break;
        }
      }
    }

    if (videoUrl.isEmpty) {
      videoUrl =
          (data['videoUrl'] ?? '').toString();
    }

    return NubuzzVideo(
      postId:
      (data['postId'] ?? document.id)
          .toString(),

      uid:
      (data['uid'] ?? '').toString(),

      username:
      (data['username'] ?? 'User')
          .toString(),

      fullName:
      (data['fullName'] ?? '')
          .toString(),

      photoUrl:
      (data['photoUrl'] ?? '')
          .toString(),

      caption:
      (data['caption'] ?? '')
          .toString(),

      videoUrl: videoUrl,

      createdAt: createdAt,

      likeCount:
      _toInt(data['likeCount']),

      commentCount:
      _toInt(data['commentCount']),

      repostCount:
      _toInt(data['repostCount']),

      shareCount:
      _toInt(data['shareCount']),

      viewCount:
      _toInt(data['viewCount']),
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
      value?.toString() ?? '',
    ) ??
        0;
  }
}