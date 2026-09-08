import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatService {
  final FirebaseFirestore
  _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  //===========================================================
  // GET CURRENT USER
  //===========================================================

  String? get currentUserId {
    return _auth
        .currentUser
        ?.uid;
  }

  //===========================================================
  // CREATE / GET CONVERSATION ID
  //===========================================================

  String getConversationId(
      String otherUserId,
      ) {
    final String? uid =
        currentUserId;

    if (uid == null) {
      throw Exception(
        'User is not logged in.',
      );
    }

    final List<String> ids =
    <String>[
      uid,
      otherUserId,
    ];

    ids.sort();

    return ids.join(
      '_',
    );
  }

  //===========================================================
  // PREPARE CONVERSATION
  //===========================================================

  Future<
      DocumentReference<
          Map<String, dynamic>>>
  _prepareConversation({
    required String receiverId,
    required String lastMessage,
  }) async {
    final String? senderId =
        currentUserId;

    if (senderId == null) {
      throw Exception(
        'User is not logged in.',
      );
    }

    final String
    conversationId =
    getConversationId(
      receiverId,
    );

    final DocumentReference<
        Map<String, dynamic>>
    conversation =
    _firestore
        .collection(
      'conversations',
    )
        .doc(
      conversationId,
    );

    await conversation.set(
      {
        'participants':
        <String>[
          senderId,
          receiverId,
        ],

        'lastMessage':
        lastMessage,

        'lastMessageSenderId':
        senderId,

        'lastMessageAt':
        FieldValue
            .serverTimestamp(),
      },

      SetOptions(
        merge:
        true,
      ),
    );

    return conversation;
  }

  //===========================================================
  // SEND TEXT MESSAGE
  //===========================================================

  Future<void> sendMessage({
    required String receiverId,
    required String text,
  }) async {
    final String? senderId =
        currentUserId;

    final String message =
    text.trim();

    if (senderId == null ||
        message.isEmpty) {
      return;
    }

    final DocumentReference<
        Map<String, dynamic>>
    conversation =
    await _prepareConversation(
      receiverId:
      receiverId,

      lastMessage:
      message,
    );

    await conversation
        .collection(
      'messages',
    )
        .add({
      'senderId':
      senderId,

      'receiverId':
      receiverId,

      'text':
      message,

      'type':
      'text',

      'isRead':
      false,

      'createdAt':
      FieldValue
          .serverTimestamp(),
    });
  }

  //===========================================================
  // SEND MEDIA MESSAGE
  //===========================================================

  Future<void>
  sendMediaMessage({
    required String receiverId,
    required String mediaUrl,
    required String mediaType,
  }) async {
    final String? senderId =
        currentUserId;

    if (senderId == null) {
      return;
    }

    final String lastMessage =
    mediaType ==
        'image'
        ? '📷 Photo'
        : mediaType ==
        'video'
        ? '🎥 Video'
        : 'Media';

    final DocumentReference<
        Map<String, dynamic>>
    conversation =
    await _prepareConversation(
      receiverId:
      receiverId,

      lastMessage:
      lastMessage,
    );

    await conversation
        .collection(
      'messages',
    )
        .add({
      'senderId':
      senderId,

      'receiverId':
      receiverId,

      'text':
      '',

      'mediaUrl':
      mediaUrl,

      'type':
      mediaType,

      'isRead':
      false,

      'createdAt':
      FieldValue
          .serverTimestamp(),
    });
  }

  //===========================================================
  // SEND STORY REPLY
  //===========================================================

  Future<void>
  sendStoryReply({
    required String receiverId,
    required String storyId,
    required String storyOwnerId,
    required String storyPreviewUrl,
    required String storyType,
    required String text,
  }) async {
    final String? senderId =
        currentUserId;

    final String message =
    text.trim();

    if (senderId == null ||
        message.isEmpty) {
      return;
    }

    final DocumentReference<
        Map<String, dynamic>>
    conversation =
    await _prepareConversation(
      receiverId:
      receiverId,

      lastMessage:
      'Replied to your story: $message',
    );

    await conversation
        .collection(
      'messages',
    )
        .add({
      'senderId':
      senderId,

      'receiverId':
      receiverId,

      'text':
      message,

      'type':
      'storyReply',

      'storyId':
      storyId,

      'storyOwnerId':
      storyOwnerId,

      'storyPreviewUrl':
      storyPreviewUrl,

      'storyType':
      storyType,

      'isRead':
      false,

      'createdAt':
      FieldValue
          .serverTimestamp(),
    });
  }

  //===========================================================
  // SEND STORY TO CHAT
  //===========================================================

  Future<void>
  sendStoryMessage({
    required String receiverId,
    required String storyId,
    required String storyOwnerId,
    required String storyUsername,
    required String storyPreviewUrl,
    required String storyType,
  }) async {
    final String? senderId =
        currentUserId;

    if (senderId == null) {
      return;
    }

    final DocumentReference<
        Map<String, dynamic>>
    conversation =
    await _prepareConversation(
      receiverId:
      receiverId,

      lastMessage:
      'Shared a story',
    );

    await conversation
        .collection(
      'messages',
    )
        .add({
      'senderId':
      senderId,

      'receiverId':
      receiverId,

      'text':
      '',

      'type':
      'storyShare',

      'storyId':
      storyId,

      'storyOwnerId':
      storyOwnerId,

      'storyUsername':
      storyUsername,

      'storyPreviewUrl':
      storyPreviewUrl,

      'storyType':
      storyType,

      'isRead':
      false,

      'createdAt':
      FieldValue
          .serverTimestamp(),
    });
  }

  //===========================================================
  // GET MESSAGES
  //===========================================================

  Stream<QuerySnapshot>
  getMessages(
      String otherUserId,
      ) {
    final String
    conversationId =
    getConversationId(
      otherUserId,
    );

    return _firestore
        .collection(
      'conversations',
    )
        .doc(
      conversationId,
    )
        .collection(
      'messages',
    )
        .orderBy(
      'createdAt',
      descending:
      true,
    )
        .snapshots();
  }

  //===========================================================
  // MARK MESSAGE AS READ
  //===========================================================

  Future<void>
  markMessageAsRead({
    required String otherUserId,
    required String messageId,
  }) async {
    final String
    conversationId =
    getConversationId(
      otherUserId,
    );

    await _firestore
        .collection(
      'conversations',
    )
        .doc(
      conversationId,
    )
        .collection(
      'messages',
    )
        .doc(
      messageId,
    )
        .update({
      'isRead':
      true,
    });
  }

  //===========================================================
  // GET CONVERSATIONS
  //===========================================================

  Stream<QuerySnapshot>
  getConversations() {
    final String? uid =
        currentUserId;

    if (uid == null) {
      return const Stream
          .empty();
    }

    return _firestore
        .collection(
      'conversations',
    )
        .where(
      'participants',
      arrayContains:
      uid,
    )
        .orderBy(
      'lastMessageAt',
      descending:
      true,
    )
        .snapshots();
  }
}