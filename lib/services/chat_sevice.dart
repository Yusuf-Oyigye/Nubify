import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/chat_message.dart';

//===============================
// CHAT SERVICE
//===============================

class ChatService {
  final FirebaseFirestore
  _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth
  _auth =
      FirebaseAuth.instance;

  //===============================
  // CURRENT USER
  //===============================

  String? get currentUserId =>
      _auth.currentUser?.uid;

  //===============================
  // CONVERSATION ID
  //===============================

  String getConversationId(
      String otherUserId,
      ) {
    final String? uid =
        currentUserId;

    if (uid == null ||
        uid.isEmpty) {
      throw Exception(
        'User is not logged in.',
      );
    }

    final List<String> ids =
    <String>[
      uid,
      otherUserId,
    ]..sort();

    return ids.join(
      '_',
    );
  }

  //===============================
  // CONVERSATION REFERENCE
  //===============================

  DocumentReference<
      Map<String, dynamic>>
  _conversationReference(
      String otherUserId,
      ) {
    return _firestore
        .collection(
      'conversations',
    )
        .doc(
      getConversationId(
        otherUserId,
      ),
    );
  }
//===============================
// ENSURE CONVERSATION
//===============================

  Future<void> ensureConversationExists(
      String otherUserId,
      ) async {
    final String? uid =
        currentUserId;

    if (uid == null ||
        uid.isEmpty ||
        otherUserId.trim().isEmpty ||
        otherUserId == uid) {
      return;
    }

    final DocumentReference<
        Map<String, dynamic>>
    reference =
    _conversationReference(
      otherUserId,
    );

    final List<String> participants =
    <String>[
      uid,
      otherUserId,
    ]..sort();

    await reference.set(
      <String, dynamic>{
        'conversationId':
        reference.id,

        'type':
        'direct',

        'participants':
        participants,

        'participantIds':
        participants,

        'members':
        participants,

        'updatedAt':
        Timestamp.now(),
      },
      SetOptions(
        merge:
        true,
      ),
    );
  }
  //===============================
  // GENERIC SEND
  //===============================

  Future<String>
  _sendDirectMessage({
    bool isForwarded = false,
    bool linkPreviewDisabled = false,

    required String receiverId,
    required String type,
    required String preview,

    String text = '',
    String mediaUrl = '',
    String fileName = '',
    int durationMs = 0,

    String storyId = '',
    String storyOwnerId = '',
    String storyUsername = '',
    String storyType = '',
    String storyPreviewUrl = '',

    String postId = '',
    String postOwnerId = '',
    String postUsername = '',
    String postFullName = '',
    String postCaption = '',
    String postPreviewUrl = '',

    String productId = '',
    String productSellerId = '',
    String productName = '',
    String productImageUrl = '',
    String productPrice = '',

    String replyToMessageId = '',
    String replyToSenderId = '',
    String replyToSenderName = '',
    String replyToText = '',
    String replyToType = '',

  }) async {
    final String? senderId =
        currentUserId;

    if (senderId == null ||
        senderId.isEmpty) {
      throw Exception(
        'User is not logged in.',
      );
    }

    if (receiverId
        .trim()
        .isEmpty ||
        receiverId ==
            senderId) {
      throw Exception(
        'Invalid receiver.',
      );
    }

    final String conversationId =
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

    final DocumentReference<
        Map<String, dynamic>>
    messageReference =
    conversation
        .collection(
      'messages',
    )
        .doc();

    final Timestamp now =
    Timestamp.now();

    final List<String> participants =
    <String>[
      senderId,
      receiverId,
    ]..sort();

    final WriteBatch batch =
    _firestore.batch();

    //===============================
    // MESSAGE
    //===============================

    batch.set(
      messageReference,
      <String, dynamic>{
        'linkPreviewDisabled':
        linkPreviewDisabled,
        'messageId':
        messageReference.id,

        'conversationId':
        conversationId,

        'senderId':
        senderId,

        'senderUid':
        senderId,

        'receiverId':
        receiverId,

        'recipientId':
        receiverId,

        'type':
        type,

        'messageType':
        type,

        'text':
        text,

        'mediaUrl':
        mediaUrl,

        'fileName':
        fileName,

        'durationMs':
        durationMs,

        'storyId':
        storyId,

        'sharedStoryId':
        storyId,

        'storyOwnerId':
        storyOwnerId,

        'storyUsername':
        storyUsername,

        'storyType':
        storyType,

        'storyPreviewUrl':
        storyPreviewUrl,

        'storyMediaUrl':
        storyPreviewUrl,

        'postId':
        postId,

        'sharedPostId':
        postId,

        'postOwnerId':
        postOwnerId,

        'postUsername':
        postUsername,

        'postFullName':
        postFullName,

        'postCaption':
        postCaption,

        'postPreviewUrl':
        postPreviewUrl,

        'productId':
        productId,

        'productSellerId':
        productSellerId,

        'productName':
        productName,

        'productImageUrl':
        productImageUrl,

        'productPrice':
        productPrice,

        'replyToMessageId':
        replyToMessageId,

        'replyToSenderId':
        replyToSenderId,

        'replyToSenderName':
        replyToSenderName,

        'replyToText':
        replyToText,

        'replyToType':
        replyToType,

        'deliveredTo':
        <String>[
          senderId,
        ],

        'readBy':
        <String>[
          senderId,
        ],

        'seenBy':
        <String>[
          senderId,
        ],

        'isRead':
        false,

//===============================
// MESSAGE ACTION DATA
//===============================

        'reactions':
        <String, String>{},

        'hiddenFor':
        <String>[],

        'deletedForEveryone':
        false,

        'isForwarded':
        isForwarded,

        'createdAt':
        now,

        'timestamp':
        now,
      },
    );


    //===============================
    // CONVERSATION
    //===============================

    batch.set(
      conversation,
      <String, dynamic>{
        'conversationId':
        conversationId,

        'type':
        'direct',

        'participants':
        participants,

        'participantIds':
        participants,

        'members':
        participants,

        'lastMessageId':
        messageReference.id,

        'lastMessage':
        preview,

        'lastMessageType':
        type,

        'lastMessageSenderId':
        senderId,

        'lastSenderId':
        senderId,

        'lastMessageAt':
        now,

        'lastMessageDeliveredTo':
        <String>[
          senderId,
        ],

        'lastMessageReadBy':
        <String>[
          senderId,
        ],
        //===============================
      // UNREAD COUNTS
      //===============================

        'unreadCounts':
        <String, dynamic>{
          senderId:
          0,

          receiverId:
          FieldValue.increment(
            1,
          ),
        },

        'updatedAt':
        now,

        'createdAt':
        FieldValue
            .serverTimestamp(),
      },

      SetOptions(
        merge:
        true,
      ),
    );

    await batch.commit();

    return messageReference.id;
  }

  //===============================
  // SEND TEXT
  //===============================

  Future<void> sendMessage({
    required String receiverId,
    required String text,

    String replyToMessageId = '',
    String replyToSenderId = '',
    String replyToSenderName = '',
    String replyToText = '',
    String replyToType = '',

    bool isForwarded = false,
    bool linkPreviewDisabled = false,
  }) async {
    final String message =
    text.trim();

    if (message.isEmpty) {
      return;
    }

    await _sendDirectMessage(
      linkPreviewDisabled:
      linkPreviewDisabled,

      receiverId:
      receiverId,

      type:
      'text',

      preview:
      message,

      text:
      message,

      replyToMessageId:
      replyToMessageId,

      replyToSenderId:
      replyToSenderId,

      replyToSenderName:
      replyToSenderName,

      replyToText:
      replyToText,

      replyToType:
      replyToType,
    );
  }

  //===============================
  // SEND MEDIA
  //===============================

  Future<void>
  sendMediaMessage({
    required String receiverId,
    required String mediaUrl,
    required String mediaType,

    String fileName = '',
    int durationMs = 0,

    String replyToMessageId = '',
    String replyToSenderId = '',
    String replyToSenderName = '',
    String replyToText = '',
    String replyToType = '',
  }) async {
    String preview;

    switch (mediaType) {
      case 'image':
        preview =
        '📷 Photo';
        break;

      case 'video':
        preview =
        '🎥 Video';
        break;

      case 'voice':
        preview =
        '🎤 Voice message';
        break;

      case 'document':
        preview =
        fileName.isNotEmpty
            ? '📄 $fileName'
            : '📄 Document';
        break;

      default:
        preview =
        'Media';
    }

    await _sendDirectMessage(
      receiverId:
      receiverId,

      type:
      mediaType,

      preview:
      preview,

      mediaUrl:
      mediaUrl,

      fileName:
      fileName,

      durationMs:
      durationMs,

      replyToMessageId:
      replyToMessageId,

      replyToSenderId:
      replyToSenderId,

      replyToSenderName:
      replyToSenderName,

      replyToText:
      replyToText,

      replyToType:
      replyToType,
    );
  }

  //===============================
  // SEND STICKER
  //===============================

  Future<void> sendSticker({
    required String receiverId,
    required String sticker,
  }) async {
    if (sticker
        .trim()
        .isEmpty) {
      return;
    }

    await _sendDirectMessage(
      receiverId:
      receiverId,

      type:
      'sticker',

      preview:
      'Sticker',

      text:
      sticker,
    );
  }

  //===============================
  // STORY REPLY
  //===============================

  Future<void>
  sendStoryReply({
    required String receiverId,
    required String storyId,
    required String storyOwnerId,
    required String storyPreviewUrl,
    required String storyType,
    required String text,

    String storyUsername = '',
  }) async {
    final String message =
    text.trim();

    if (message.isEmpty) {
      return;
    }

    await _sendDirectMessage(
      receiverId:
      receiverId,

      type:
      'storyReply',

      preview:
      'Replied to your story: $message',

      text:
      message,

      storyId:
      storyId,

      storyOwnerId:
      storyOwnerId,

      storyUsername:
      storyUsername,

      storyType:
      storyType,

      storyPreviewUrl:
      storyPreviewUrl,
    );
  }

  //===============================
  // SHARE STORY
  //===============================

  Future<void>
  sendStoryMessage({
    required String receiverId,
    required String storyId,
    required String storyOwnerId,
    required String storyUsername,
    required String storyPreviewUrl,
    required String storyType,
  }) async {
    await _sendDirectMessage(
      receiverId:
      receiverId,

      type:
      'storyShare',

      preview:
      'Shared a story',

      storyId:
      storyId,

      storyOwnerId:
      storyOwnerId,

      storyUsername:
      storyUsername,

      storyType:
      storyType,

      storyPreviewUrl:
      storyPreviewUrl,
    );
  }

  //===============================
  // SHARE POST
  //===============================

  Future<void>
  sendPostMessage({
    required String receiverId,
    required String postId,
    required String postOwnerId,
    required String postUsername,
    required String postFullName,
    required String postCaption,
    required String postPreviewUrl,
  }) async {
    await _sendDirectMessage(
      receiverId:
      receiverId,

      type:
      'post',

      preview:
      'Shared a post',

      postId:
      postId,

      postOwnerId:
      postOwnerId,

      postUsername:
      postUsername,

      postFullName:
      postFullName,

      postCaption:
      postCaption,

      postPreviewUrl:
      postPreviewUrl,
    );
  }

  //===============================
  // SHARE PRODUCT
  //===============================

  Future<void>
  sendProductMessage({
    required String receiverId,
    required String productId,
    required String productSellerId,
    required String productName,
    required String productImageUrl,
    required String productPrice,
  }) async {
    await _sendDirectMessage(
      receiverId:
      receiverId,

      type:
      'product',

      preview:
      'Shared a Marketplace product',

      productId:
      productId,

      productSellerId:
      productSellerId,

      productName:
      productName,

      productImageUrl:
      productImageUrl,

      productPrice:
      productPrice,
    );
  }
  //===============================
// TOGGLE REACTION
//===============================

  Future<void> toggleReaction({
    required String otherUserId,
    required String messageId,
    required String emoji,
  }) async {
    final String? uid =
        currentUserId;

    if (uid == null ||
        uid.isEmpty) {
      return;
    }

    final DocumentReference<
        Map<String, dynamic>>
    reference =
    _conversationReference(
      otherUserId,
    )
        .collection(
      'messages',
    )
        .doc(
      messageId,
    );

    final DocumentSnapshot<
        Map<String, dynamic>>
    snapshot =
    await reference.get();

    final Map<String, dynamic>
    reactions =
    snapshot.data()?[
    'reactions']
    is Map
        ? Map<String, dynamic>.from(
      snapshot.data()?[
      'reactions'] as Map,
    )
        : <String, dynamic>{};

    if ((reactions[uid] ?? '')
        .toString() ==
        emoji) {
      await reference.update(
        <String, dynamic>{
          'reactions.$uid':
          FieldValue.delete(),
        },
      );

      return;
    }

    await reference.update(
      <String, dynamic>{
        'reactions.$uid':
        emoji,
      },
    );
  }

//===============================
// DELETE FOR ME
//===============================

  Future<void> deleteMessageForMe({
    required String otherUserId,
    required String messageId,
  }) async {
    final String? uid =
        currentUserId;

    if (uid == null ||
        uid.isEmpty) {
      return;
    }

    await _conversationReference(
      otherUserId,
    )
        .collection(
      'messages',
    )
        .doc(
      messageId,
    )
        .update(
      <String, dynamic>{
        'hiddenFor':
        FieldValue.arrayUnion(
          <String>[
            uid,
          ],
        ),
      },
    );
  }

//===============================
// DELETE FOR EVERYONE
//===============================

  Future<void>
  deleteMessageForEveryone({
    required String otherUserId,
    required String messageId,
  }) async {
    final String? uid =
        currentUserId;

    if (uid == null ||
        uid.isEmpty) {
      return;
    }

    final DocumentReference<
        Map<String, dynamic>>
    conversation =
    _conversationReference(
      otherUserId,
    );

    final DocumentReference<
        Map<String, dynamic>>
    messageReference =
    conversation
        .collection(
      'messages',
    )
        .doc(
      messageId,
    );

    final DocumentSnapshot<
        Map<String, dynamic>>
    messageSnapshot =
    await messageReference
        .get();

    if (!messageSnapshot.exists) {
      return;
    }

    if ((messageSnapshot.data()?[
    'senderId'] ??
        '')
        .toString() !=
        uid) {
      throw Exception(
        'You can only delete your own message for everyone.',
      );
    }

    final DocumentSnapshot<
        Map<String, dynamic>>
    conversationSnapshot =
    await conversation.get();

    final WriteBatch batch =
    _firestore.batch();

    batch.update(
      messageReference,
      <String, dynamic>{
        'deletedForEveryone':
        true,

        'text':
        '',

        'mediaUrl':
        '',

        'fileName':
        '',

        'storyId':
        '',

        'postId':
        '',

        'productId':
        '',

        'reactions':
        <String, String>{},
      },
    );

    if ((conversationSnapshot
        .data()?[
    'lastMessageId'] ??
        '')
        .toString() ==
        messageId) {
      batch.set(
        conversation,
        <String, dynamic>{
          'lastMessage':
          'Message deleted',

          'lastMessageType':
          'text',
        },
        SetOptions(
          merge:
          true,
        ),
      );
    }

    await batch.commit();
  }

//===============================
// FORWARD MESSAGE
//===============================

  Future<void> forwardMessage({
    required String receiverId,
    required ChatMessage message,
  }) async {
    if (message.deletedForEveryone) {
      return;
    }

    await _sendDirectMessage(
      receiverId:
      receiverId,

      type:
      message.type,

      preview:
      message.previewText,

      text:
      message.text,

      mediaUrl:
      message.mediaUrl,

      fileName:
      message.fileName,

      durationMs:
      message.durationMs,

      storyId:
      message.storyId,

      storyOwnerId:
      message.storyOwnerId,

      storyUsername:
      message.storyUsername,

      storyType:
      message.storyType,

      storyPreviewUrl:
      message.storyPreviewUrl,

      postId:
      message.postId,

      postOwnerId:
      message.postOwnerId,

      postUsername:
      message.postUsername,

      postFullName:
      message.postFullName,

      postCaption:
      message.postCaption,

      postPreviewUrl:
      message.postPreviewUrl,

      productId:
      message.productId,

      productSellerId:
      message.productSellerId,

      productName:
      message.productName,

      productImageUrl:
      message.productImageUrl,

      productPrice:
      message.productPrice,

      isForwarded:
      true,
    );
  }
//===============================
// GET MESSAGES
//===============================

  Stream<QuerySnapshot<Map<String, dynamic>>> getMessages(
      String otherUserId,
      ) {
    final String conversationId =
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
  //===============================
  // DELIVER CONVERSATION
  //===============================

  Future<void>
  markConversationDelivered(
      String otherUserId,
      ) async {
    final String? uid =
        currentUserId;

    if (uid == null ||
        uid.isEmpty) {
      return;
    }

    final DocumentReference<
        Map<String, dynamic>>
    conversation =
    _conversationReference(
      otherUserId,
    );

    final QuerySnapshot<
        Map<String, dynamic>>
    snapshot =
    await conversation
        .collection(
      'messages',
    )
        .orderBy(
      'createdAt',
      descending:
      true,
    )
        .limit(
      100,
    )
        .get();

    final WriteBatch batch =
    _firestore.batch();

    bool changed =
    false;

    for (final QueryDocumentSnapshot<
        Map<String, dynamic>>
    document
    in snapshot.docs) {
      final Map<String, dynamic>
      data =
      document.data();

      final String senderId =
      (
          data['senderId'] ??
              data['senderUid'] ??
              ''
      )
          .toString();

      if (senderId ==
          uid) {
        continue;
      }

      final List<String>
      deliveredTo =
      data['deliveredTo']
      is List
          ? (data['deliveredTo']
      as List)
          .map(
            (dynamic item) =>
            item.toString(),
      )
          .toList()
          : <String>[];

      if (deliveredTo
          .contains(
        uid,
      )) {
        continue;
      }

      batch.update(
        document.reference,
        <String, dynamic>{
          'deliveredTo':
          FieldValue
              .arrayUnion(
            <String>[
              uid,
            ],
          ),
        },
      );

      changed =
      true;
    }

    if (changed) {
      await batch.commit();
    }

    final DocumentSnapshot<
        Map<String, dynamic>>
    conversationSnapshot =
    await conversation.get();

    final Map<String, dynamic>
    conversationData =
        conversationSnapshot
            .data() ??
            <String, dynamic>{};

    final String lastSender =
    (
        conversationData[
        'lastMessageSenderId'] ??
            conversationData[
            'lastSenderId'] ??
            ''
    )
        .toString();

    if (lastSender.isNotEmpty &&
        lastSender != uid) {
      await conversation.set(
        <String, dynamic>{
          'lastMessageDeliveredTo':
          FieldValue
              .arrayUnion(
            <String>[
              uid,
            ],
          ),
        },

        SetOptions(
          merge:
          true,
        ),
      );
    }
  }

  //===============================
  // READ CONVERSATION
  //===============================

  Future<void>
  markConversationRead(
      String otherUserId,
      ) async {
    final String? uid =
        currentUserId;

    if (uid == null ||
        uid.isEmpty) {
      return;
    }

    final DocumentReference<
        Map<String, dynamic>>
    conversation =
    _conversationReference(
      otherUserId,
    );

    final QuerySnapshot<
        Map<String, dynamic>>
    snapshot =
    await conversation
        .collection(
      'messages',
    )
        .orderBy(
      'createdAt',
      descending:
      true,
    )
        .limit(
      150,
    )
        .get();

    final WriteBatch batch =
    _firestore.batch();

    bool changed =
    false;

    for (final QueryDocumentSnapshot<
        Map<String, dynamic>>
    document
    in snapshot.docs) {
      final Map<String, dynamic>
      data =
      document.data();

      final String senderId =
      (
          data['senderId'] ??
              data['senderUid'] ??
              ''
      )
          .toString();

      if (senderId ==
          uid) {
        continue;
      }

      final List<String>
      readBy =
      data['readBy']
      is List
          ? (data['readBy']
      as List)
          .map(
            (dynamic item) =>
            item.toString(),
      )
          .toList()
          : data['seenBy']
      is List
          ? (data['seenBy']
      as List)
          .map(
            (dynamic item) =>
            item.toString(),
      )
          .toList()
          : <String>[];

      if (readBy.contains(
        uid,
      )) {
        continue;
      }

      batch.update(
        document.reference,
        <String, dynamic>{
          'isRead':
          true,

          'readBy':
          FieldValue
              .arrayUnion(
            <String>[
              uid,
            ],
          ),

          'seenBy':
          FieldValue
              .arrayUnion(
            <String>[
              uid,
            ],
          ),

          'deliveredTo':
          FieldValue
              .arrayUnion(
            <String>[
              uid,
            ],
          ),
        },
      );

      changed =
      true;
    }

    if (changed) {
      await batch.commit();
    }

    final DocumentSnapshot<
        Map<String, dynamic>>
    conversationSnapshot =
    await conversation.get();

    final Map<String, dynamic>
    conversationData =
        conversationSnapshot
            .data() ??
            <String, dynamic>{};

    final String lastSender =
    (
        conversationData[
        'lastMessageSenderId'] ??
            conversationData[
            'lastSenderId'] ??
            ''
    )
        .toString();

    if (lastSender.isNotEmpty &&
        lastSender != uid) {
      await conversation.set(
        <String, dynamic>{
          'lastMessageDeliveredTo':
          FieldValue
              .arrayUnion(
            <String>[
              uid,
            ],
          ),

          'lastMessageReadBy':
          FieldValue
              .arrayUnion(
            <String>[
              uid,
            ],
          ),
        },

        SetOptions(
          merge:
          true,
        ),
      );
    }
    //===============================
   // RESET UNREAD COUNT
   //===============================

    try {
      await conversation.update(
        <String, dynamic>{
          'unreadCounts.$uid':
          0,
        },
      );
    } catch (_) {}
  }

  //===============================
  // MARK ONE MESSAGE READ
  //===============================

  Future<void>
  markMessageAsRead({
    required String otherUserId,
    required String messageId,
  }) async {
    final String? uid =
        currentUserId;

    if (uid == null ||
        uid.isEmpty) {
      return;
    }

    final String conversationId =
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
        .set(
      <String, dynamic>{
        'isRead':
        true,

        'readBy':
        FieldValue
            .arrayUnion(
          <String>[
            uid,
          ],
        ),

        'seenBy':
        FieldValue
            .arrayUnion(
          <String>[
            uid,
          ],
        ),

        'deliveredTo':
        FieldValue
            .arrayUnion(
          <String>[
            uid,
          ],
        ),
      },

      SetOptions(
        merge:
        true,
      ),
    );
  }

  //===============================
// CONVERSATIONS
//===============================

  Stream<QuerySnapshot<
      Map<String, dynamic>>>
  getConversations() {
    final String? uid =
        currentUserId;

    if (uid == null ||
        uid.isEmpty) {
      return const Stream<
          QuerySnapshot<
              Map<String, dynamic>>>
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
        .snapshots();
  }
  //===============================
  // UNREAD COUNT
  //===============================

  Stream<int> unreadCountStream(
      String otherUserId,
      ) {
    final String? uid =
        currentUserId;

    if (uid == null ||
        uid.isEmpty) {
      return Stream<int>.value(
        0,
      );
    }

    return getMessages(
      otherUserId,
    ).map(
          (
          QuerySnapshot<
              Map<String, dynamic>>
          snapshot,
          ) {
        int unread =
        0;

        for (final QueryDocumentSnapshot<
            Map<String, dynamic>>
        document
        in snapshot.docs) {
          final Map<String, dynamic>
          data =
          document.data();

          final String senderId =
          (
              data['senderId'] ??
                  data['senderUid'] ??
                  ''
          )
              .toString();

          if (senderId ==
              uid) {
            continue;
          }

          final List<String> readBy =
          data['readBy']
          is List
              ? (data['readBy']
          as List)
              .map(
                (dynamic item) =>
                item.toString(),
          )
              .toList()
              : data['seenBy']
          is List
              ? (data['seenBy']
          as List)
              .map(
                (dynamic item) =>
                item.toString(),
          )
              .toList()
              : <String>[];

          final bool legacyRead =
              data['isRead'] ==
                  true;

          if (!readBy.contains(
            uid,
          ) &&
              !legacyRead) {
            unread++;
          }
        }

        return unread;
      },
    );
  }

  //===============================
  // CONVERSATION DOCUMENT
  //===============================

  Stream<DocumentSnapshot<
      Map<String, dynamic>>>
  conversationStream(
      String otherUserId,
      ) {
    return _conversationReference(
      otherUserId,
    ).snapshots();
  }
}