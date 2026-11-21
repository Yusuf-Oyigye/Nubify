import 'package:cloud_firestore/cloud_firestore.dart';

class Comment {
  final String commentId;
  final String postId;
  final String uid;

  final String username;
  final String fullName;
  final String photoUrl;

  final String text;

  final Timestamp? createdAt;

  final int likeCount;
  final int replyCount;

  // If this is a reply, this is the comment/reply it belongs to.
  final String? parentId;

  // Username of the person being replied to.
  final String? replyToUsername;

  Comment({
    required this.commentId,
    required this.postId,
    required this.uid,
    required this.username,
    required this.fullName,
    required this.photoUrl,
    required this.text,
    required this.createdAt,
    required this.likeCount,
    required this.replyCount,
    required this.parentId,
    required this.replyToUsername,
  });

  factory Comment.fromFirestore(
      DocumentSnapshot snapshot,
      ) {
    final Map<String, dynamic> data =
    snapshot.data() as Map<String, dynamic>;

    return Comment(
      commentId: data['commentId'] ?? snapshot.id,
      postId: data['postId'] ?? '',
      uid: data['uid'] ?? '',
      username: data['username'] ?? '',
      fullName: data['fullName'] ?? '',
      photoUrl: data['photoUrl'] ?? '',
      text: data['text'] ?? '',
      createdAt: data['createdAt'] is Timestamp
          ? data['createdAt'] as Timestamp
          : null,
      likeCount: (data['likeCount'] ?? 0) as int,
      replyCount: (data['replyCount'] ?? 0) as int,
      parentId: data['parentId'],
      replyToUsername: data['replyToUsername'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'commentId': commentId,
      'postId': postId,
      'uid': uid,
      'username': username,
      'fullName': fullName,
      'photoUrl': photoUrl,
      'text': text,
      'createdAt': createdAt,
      'likeCount': likeCount,
      'replyCount': replyCount,
      'parentId': parentId,
      'replyToUsername': replyToUsername,
    };
  }

  bool get isReply {
    return parentId != null && parentId!.isNotEmpty;
  }

  String get displayName {
    if (fullName.trim().isNotEmpty) {
      return fullName;
    }

    return username;
  }
}