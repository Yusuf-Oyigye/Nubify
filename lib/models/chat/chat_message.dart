import 'package:cloud_firestore/cloud_firestore.dart';

//===============================
// CHAT MESSAGE MODEL
//===============================

class ChatMessage {
  final String messageId;
  final String conversationId;
  final String groupId;

  final String senderId;
  final String receiverId;

  final String type;
  final String text;
  final bool linkPreviewDisabled;

  final String mediaUrl;
  final String fileName;
  final int durationMs;

  final String storyId;
  final String storyOwnerId;
  final String storyUsername;
  final String storyType;
  final String storyPreviewUrl;

  final String postId;
  final String postOwnerId;
  final String postUsername;
  final String postFullName;
  final String postCaption;
  final String postPreviewUrl;

  final String productId;
  final String productSellerId;
  final String productName;
  final String productImageUrl;
  final String productPrice;

  final String replyToMessageId;
  final String replyToSenderId;
  final String replyToSenderName;
  final String replyToText;
  final String replyToType;

  final List<String> deliveredTo;
  final List<String> readBy;

  //===============================
  // MESSAGE ACTION DATA
  //===============================

  final Map<String, String> reactions;

  final List<String> hiddenFor;

  final bool deletedForEveryone;

  final bool isForwarded;

  final Timestamp? createdAt;

  const ChatMessage({
    required this.messageId,
    required this.conversationId,
    required this.groupId,
    required this.senderId,
    required this.receiverId,
    required this.type,
    required this.text,
    required this.mediaUrl,
    required this.fileName,
    required this.durationMs,
    required this.storyId,
    required this.storyOwnerId,
    required this.storyUsername,
    required this.storyType,
    required this.storyPreviewUrl,
    required this.postId,
    required this.postOwnerId,
    required this.postUsername,
    required this.postFullName,
    required this.postCaption,
    required this.postPreviewUrl,
    required this.productId,
    required this.productSellerId,
    required this.productName,
    required this.productImageUrl,
    required this.productPrice,
    required this.replyToMessageId,
    required this.replyToSenderId,
    required this.replyToSenderName,
    required this.replyToText,
    required this.replyToType,
    required this.deliveredTo,
    required this.readBy,
    required this.createdAt,
    required this.reactions,
    required this.hiddenFor,
    required this.deletedForEveryone,
    required this.isForwarded,
    this.linkPreviewDisabled = false,
  });

  //===============================
  // EMPTY
  //===============================

  factory ChatMessage.empty() {
    return const ChatMessage(
      reactions: <String, String>{},

      hiddenFor: <String>[],

      deletedForEveryone: false,

      isForwarded: false,
      messageId: '',
      conversationId: '',
      groupId: '',
      senderId: '',
      receiverId: '',
      type: 'text',
      text: '',
      mediaUrl: '',
      fileName: '',
      durationMs: 0,
      storyId: '',
      storyOwnerId: '',
      storyUsername: '',
      storyType: '',
      storyPreviewUrl: '',
      postId: '',
      postOwnerId: '',
      postUsername: '',
      postFullName: '',
      postCaption: '',
      postPreviewUrl: '',
      productId: '',
      productSellerId: '',
      productName: '',
      productImageUrl: '',
      productPrice: '',
      replyToMessageId: '',
      replyToSenderId: '',
      replyToSenderName: '',
      replyToText: '',
      replyToType: '',
      deliveredTo: <String>[],
      readBy: <String>[],
      createdAt: null,
    );
  }

  //===============================
  // FROM FIRESTORE
  //===============================

  factory ChatMessage.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic> data = document.data() ?? <String, dynamic>{};

    //==============================
    // READ MESSAGE TYPE CORRECTLY
    //==============================
    String type = (data['type'] ?? data['messageType'] ?? 'text')
        .toString()
        .trim();

    //===============================
    // LEGACY STORY SUPPORT
    //===============================

    if (type == 'story') {
      type = 'storyShare';
    }

    final String senderId = (data['senderId'] ?? data['senderUid'] ?? '')
        .toString();

    final String receiverId = (data['receiverId'] ?? data['recipientId'] ?? '')
        .toString();

    final List<String> deliveredTo = _stringList(data['deliveredTo']);

    final List<String> readBy = _stringList(data['readBy'] ?? data['seenBy']);

    //===============================
    // LEGACY IS READ
    //===============================

    if (data['isRead'] == true &&
        receiverId.isNotEmpty &&
        !readBy.contains(receiverId)) {
      readBy.add(receiverId);
    }

    final dynamic rawDuration =
        data['durationMs'] ?? data['voiceDurationMs'] ?? 0;

    int durationMs = 0;

    if (rawDuration is int) {
      durationMs = rawDuration;
    } else if (rawDuration is num) {
      durationMs = rawDuration.toInt();
    } else {
      durationMs = int.tryParse(rawDuration.toString()) ?? 0;
    }

    return ChatMessage(
      linkPreviewDisabled: data['linkPreviewDisabled'] == true,
      messageId: (data['messageId'] ?? document.id).toString(),

      conversationId: (data['conversationId'] ?? '').toString(),

      groupId: (data['groupId'] ?? '').toString(),

      senderId: senderId,

      receiverId: receiverId,

      type: type,

      text: (data['text'] ?? '').toString(),

      mediaUrl: (data['mediaUrl'] ?? data['storyMediaUrl'] ?? '').toString(),

      fileName: (data['fileName'] ?? '').toString(),

      durationMs: durationMs,

      storyId: (data['storyId'] ?? data['sharedStoryId'] ?? '').toString(),

      storyOwnerId: (data['storyOwnerId'] ?? '').toString(),

      storyUsername: (data['storyUsername'] ?? '').toString(),

      storyType: (data['storyType'] ?? '').toString(),

      storyPreviewUrl: (data['storyPreviewUrl'] ?? data['storyMediaUrl'] ?? '')
          .toString(),

      postId: (data['postId'] ?? data['sharedPostId'] ?? '').toString(),

      postOwnerId: (data['postOwnerId'] ?? '').toString(),

      postUsername: (data['postUsername'] ?? '').toString(),

      postFullName: (data['postFullName'] ?? '').toString(),

      postCaption: (data['postCaption'] ?? '').toString(),

      postPreviewUrl: (data['postPreviewUrl'] ?? '').toString(),

      productId: (data['productId'] ?? '').toString(),

      productSellerId: (data['productSellerId'] ?? '').toString(),

      productName: (data['productName'] ?? '').toString(),

      productImageUrl: (data['productImageUrl'] ?? '').toString(),

      productPrice: (data['productPrice'] ?? '').toString(),

      replyToMessageId: (data['replyToMessageId'] ?? '').toString(),

      replyToSenderId: (data['replyToSenderId'] ?? '').toString(),

      replyToSenderName: (data['replyToSenderName'] ?? '').toString(),

      replyToText: (data['replyToText'] ?? '').toString(),

      replyToType: (data['replyToType'] ?? '').toString(),

      deliveredTo: deliveredTo,

      readBy: readBy,

      //===============================
      // MESSAGE ACTION DATA
      //===============================
      reactions: _stringMap(data['reactions']),

      hiddenFor: _stringList(data['hiddenFor']),

      deletedForEveryone: data['deletedForEveryone'] == true,

      isForwarded: data['isForwarded'] == true,

      createdAt: data['createdAt'] is Timestamp
          ? data['createdAt'] as Timestamp
          : data['timestamp'] is Timestamp
          ? data['timestamp'] as Timestamp
          : null,
    );
  }

  //===============================
  // STRING LIST
  //===============================

  static List<String> _stringList(dynamic value) {
    if (value is! List) {
      return <String>[];
    }

    return value
        .map((dynamic item) => item.toString())
        .where((String item) => item.trim().isNotEmpty)
        .toList();
  }
  //===============================
  // STRING MAP
  //===============================

  static Map<String, String> _stringMap(dynamic value) {
    if (value is! Map) {
      return <String, String>{};
    }

    return value.map(
      (dynamic key, dynamic item) =>
          MapEntry<String, String>(key.toString(), item.toString()),
    );
  }

  //===============================
  // TYPE HELPERS
  //===============================

  bool get isText => type == 'text';

  bool get isImage => type == 'image';

  bool get isVideo => type == 'video';

  bool get isVoice => type == 'voice';

  bool get isDocument => type == 'document';

  bool get isSticker => type == 'sticker';

  bool get isStoryReply => type == 'storyReply';

  bool get isStoryShare => type == 'storyShare';

  bool get isPost => type == 'post';

  bool get isProduct => type == 'product';

  //===============================
  // DELIVERY
  //===============================

  bool isDeliveredTo(String uid) {
    return deliveredTo.contains(uid);
  }

  bool isReadBy(String uid) {
    return readBy.contains(uid);
  }

  //===============================
  // PREVIEW
  //===============================

  String get previewText {
    if (deletedForEveryone) {
      return 'Message deleted';
    }
    switch (type) {
      case 'image':
        return '📷 Photo';

      case 'video':
        return '🎥 Video';

      case 'voice':
        return '🎤 Voice message';

      case 'document':
        return fileName.isNotEmpty ? '📄 $fileName' : '📄 Document';

      case 'sticker':
        return 'Sticker';

      case 'storyReply':
        return text.isNotEmpty
            ? 'Replied to a story: $text'
            : 'Replied to a story';

      case 'storyShare':
        return 'Shared a story';

      case 'post':
        return 'Shared a post';

      case 'product':
        return 'Shared a Marketplace product';

      default:
        return text;
    }
  }
}
