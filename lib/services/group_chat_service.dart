import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/chat_group.dart';
import '../models/chat_message.dart';

//===============================
// GROUP CHAT SERVICE
//===============================

class GroupChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  //===================================================
  // GROUP INVITATION CLOUD FUNCTIONS
  //===================================================

  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'europe-west1',
  );

  //===============================
  // CURRENT UID
  //===============================

  String? get currentUid => _auth.currentUser?.uid;

  //===============================
  // GROUP REFERENCE
  //===============================

  DocumentReference<Map<String, dynamic>> _groupReference(String groupId) {
    return _firestore.collection('chatGroups').doc(groupId);
  }

  //===============================
  // RANDOM INVITE TOKEN
  //===============================

  String _generateInviteToken() {
    const String chars =
        'ABCDEFGHJKLMNPQRSTUVWXYZ'
        'abcdefghijkmnopqrstuvwxyz'
        '23456789';

    final Random random = Random.secure();

    return List<String>.generate(
      32,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
  }

  //===============================
  // CREATE GROUP
  //===============================

  Future<String> createGroup({
    required String name,
    required String description,
    required List<String> selectedMemberIds,
    String photoUrl = '',
  }) async {
    final String? uid = currentUid;

    final String cleanName = name.trim();

    if (uid == null || uid.isEmpty) {
      throw Exception('User is not logged in.');
    }

    if (cleanName.isEmpty) {
      throw Exception('Group name is required.');
    }

    final Set<String> members = <String>{
      uid,
      ...selectedMemberIds.where((String item) => item.trim().isNotEmpty),
    };

    final DocumentReference<Map<String, dynamic>> groupReference = _firestore
        .collection('chatGroups')
        .doc();

    final Timestamp now = Timestamp.now();

    final Map<String, dynamic> memberJoinedAt = <String, dynamic>{};

    for (final String memberId in members) {
      memberJoinedAt[memberId] = now;
    }

    await groupReference.set(<String, dynamic>{
      'groupId': groupReference.id,

      'name': cleanName,

      'description': description.trim(),

      'photoUrl': photoUrl,

      'creatorId': uid,

      'memberIds': members.toList(),

      'members': members.toList(),

      'adminIds': <String>[uid],

      'permissions': const ChatGroupPermissions().toMap(),

      'inviteToken': _generateInviteToken(),

      'lastMessage': '',

      'lastMessageType': '',

      'lastMessageSenderId': '',

      'lastMessageAt': null,

      'memberJoinedAt': memberJoinedAt,

      'createdAt': now,

      'updatedAt': now,
    });

    return groupReference.id;
  }

  //===============================
  // GROUP STREAM
  //===============================

  Stream<DocumentSnapshot<Map<String, dynamic>>> groupStream(String groupId) {
    return _groupReference(groupId).snapshots();
  }

  //===============================
  // USER GROUPS
  //===============================

  Stream<QuerySnapshot<Map<String, dynamic>>> getGroups() {
    final String? uid = currentUid;

    if (uid == null || uid.isEmpty) {
      return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
    }

    return _firestore
        .collection('chatGroups')
        .where('memberIds', arrayContains: uid)
        .snapshots();
  }

  //===============================
  // MESSAGES
  //===============================

  Stream<QuerySnapshot<Map<String, dynamic>>> getMessages(
    String groupId, {
    ChatGroup? knownGroup,
  }) async* {
    final String? uid = currentUid;

    if (uid == null || uid.isEmpty) {
      return;
    }

    // Use the group already loaded by the screen.
    // Only fetch it again if no group was supplied.
    final ChatGroup group = knownGroup ?? await _loadGroup(groupId);

    Query<Map<String, dynamic>> query = _groupReference(
      groupId,
    ).collection('messages');

    //===============================
    // NEW MEMBER HISTORY PERMISSION
    //===============================

    if (!group.permissions.newMembersCanSeeHistory) {
      final Timestamp? joinedAt = group.memberJoinedAt[uid];

      if (joinedAt != null) {
        query = query.where('createdAt', isGreaterThanOrEqualTo: joinedAt);
      }
    }

    yield* query.orderBy('createdAt', descending: true).limit(150).snapshots();
  }

  //===============================
  // LOAD GROUP
  //===============================

  Future<ChatGroup> _loadGroup(String groupId) async {
    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await _groupReference(groupId).get();

    if (!snapshot.exists) {
      throw Exception('Group no longer exists.');
    }

    return ChatGroup.fromDocument(snapshot);
  }

  //===============================
  // GENERIC SEND
  //===============================

  Future<String> _sendGroupMessage({
    required String groupId,
    required String type,
    required String preview,

    ChatGroup? knownGroup,

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

    bool isForwarded = false,
    bool linkPreviewDisabled = false,
  }) async {
    final String? uid = currentUid;

    if (uid == null || uid.isEmpty) {
      throw Exception('User is not logged in.');
    }
    final ChatGroup group = knownGroup ?? await _loadGroup(groupId);

    if (!group.isMember(uid)) {
      throw Exception('You are not a member of this group.');
    }

    if (!group.isAdmin(uid) && !group.permissions.membersCanSendMessages) {
      throw Exception('Only admins can send messages in this group.');
    }

    final DocumentReference<Map<String, dynamic>> groupReference =
        _groupReference(groupId);

    final DocumentReference<Map<String, dynamic>> messageReference =
        groupReference.collection('messages').doc();

    final Timestamp now = Timestamp.now();

    final WriteBatch batch = _firestore.batch();

    batch.set(messageReference, <String, dynamic>{
      'linkPreviewDisabled': linkPreviewDisabled,

      'messageId': messageReference.id,

      'groupId': groupId,

      'senderId': uid,

      'senderUid': uid,

      'receiverId': '',

      'type': type,

      'messageType': type,

      'text': text,

      'mediaUrl': mediaUrl,

      'fileName': fileName,

      'durationMs': durationMs,

      'storyId': storyId,

      'sharedStoryId': storyId,

      'storyOwnerId': storyOwnerId,

      'storyUsername': storyUsername,

      'storyType': storyType,

      'storyPreviewUrl': storyPreviewUrl,

      'storyMediaUrl': storyPreviewUrl,

      'postId': postId,

      'sharedPostId': postId,

      'postOwnerId': postOwnerId,

      'postUsername': postUsername,

      'postFullName': postFullName,

      'postCaption': postCaption,

      'postPreviewUrl': postPreviewUrl,

      'productId': productId,

      'productSellerId': productSellerId,

      'productName': productName,

      'productImageUrl': productImageUrl,

      'productPrice': productPrice,

      'replyToMessageId': replyToMessageId,

      'replyToSenderId': replyToSenderId,

      'replyToSenderName': replyToSenderName,

      'replyToText': replyToText,

      'replyToType': replyToType,

      'deliveredTo': <String>[uid],

      'readBy': <String>[uid],

      'seenBy': <String>[uid],
      //===============================
      // MESSAGE ACTION DATA
      //===============================

      'reactions': <String, String>{},

      'hiddenFor': <String>[],

      'deletedForEveryone': false,

      'isForwarded': isForwarded,
      'createdAt': now,

      'timestamp': now,
    });

    batch.set(groupReference, <String, dynamic>{
      'lastMessageId': messageReference.id,

      'lastMessage': preview,

      'lastMessageType': type,

      'lastMessageSenderId': uid,

      'lastSenderId': uid,

      'lastMessageAt': now,

      'updatedAt': now,
    }, SetOptions(merge: true));

    await batch.commit();

    return messageReference.id;
  }

  //===============================
  // SEND TEXT
  //===============================

  Future<void> sendMessage({
    required String groupId,
    required String text,

    ChatGroup? knownGroup,

    String replyToMessageId = '',
    String replyToSenderId = '',
    String replyToSenderName = '',
    String replyToText = '',
    String replyToType = '',

    bool linkPreviewDisabled = false,
  }) async {
    final String message = text.trim();

    if (message.isEmpty) {
      return;
    }

    await _sendGroupMessage(
      linkPreviewDisabled: linkPreviewDisabled,

      groupId: groupId,

      type: 'text',

      preview: message,

      knownGroup: knownGroup,

      text: message,

      replyToMessageId: replyToMessageId,

      replyToSenderId: replyToSenderId,

      replyToSenderName: replyToSenderName,

      replyToText: replyToText,

      replyToType: replyToType,
    );
  }

  //===============================
  // SEND STICKER
  //===============================

  Future<void> sendSticker({
    required String groupId,
    required String sticker,
    ChatGroup? knownGroup,
  }) async {
    final String cleanSticker = sticker.trim();

    if (cleanSticker.isEmpty) {
      return;
    }

    await _sendGroupMessage(
      groupId: groupId,

      type: 'sticker',

      preview: 'Sticker',

      knownGroup: knownGroup,

      text: cleanSticker,
    );
  }

  //===============================
  // SEND MEDIA
  //===============================

  Future<void> sendMediaMessage({
    required String groupId,
    required String mediaUrl,
    required String mediaType,

    ChatGroup? knownGroup,

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
        preview = '📷 Photo';
        break;

      case 'video':
        preview = '🎥 Video';
        break;

      case 'voice':
        preview = '🎤 Voice message';
        break;

      case 'document':
        preview = fileName.isNotEmpty ? '📄 $fileName' : '📄 Document';
        break;

      default:
        preview = 'Media';
    }

    await _sendGroupMessage(
      groupId: groupId,

      type: mediaType,

      preview: preview,

      knownGroup: knownGroup,

      mediaUrl: mediaUrl,

      fileName: fileName,

      durationMs: durationMs,

      replyToMessageId: replyToMessageId,

      replyToSenderId: replyToSenderId,

      replyToSenderName: replyToSenderName,

      replyToText: replyToText,

      replyToType: replyToType,
    );
  }

  //===============================
  // SHARE POST
  //===============================

  Future<void> sendPostMessage({
    required String groupId,
    required String postId,
    required String postOwnerId,
    required String postUsername,
    required String postFullName,
    required String postCaption,
    required String postPreviewUrl,
  }) async {
    await _sendGroupMessage(
      groupId: groupId,

      type: 'post',

      preview: 'Shared a post',

      postId: postId,

      postOwnerId: postOwnerId,

      postUsername: postUsername,

      postFullName: postFullName,

      postCaption: postCaption,

      postPreviewUrl: postPreviewUrl,
    );
  }

  //===============================
  // SHARE STORY
  //===============================

  Future<void> sendStoryMessage({
    required String groupId,
    required String storyId,
    required String storyOwnerId,
    required String storyUsername,
    required String storyPreviewUrl,
    required String storyType,
  }) async {
    await _sendGroupMessage(
      groupId: groupId,

      type: 'storyShare',

      preview: 'Shared a story',

      storyId: storyId,

      storyOwnerId: storyOwnerId,

      storyUsername: storyUsername,

      storyType: storyType,

      storyPreviewUrl: storyPreviewUrl,
    );
  }

  //===============================
  // SHARE PRODUCT
  //===============================

  Future<void> sendProductMessage({
    required String groupId,
    required String productId,
    required String productSellerId,
    required String productName,
    required String productImageUrl,
    required String productPrice,
  }) async {
    await _sendGroupMessage(
      groupId: groupId,

      type: 'product',

      preview: 'Shared a Marketplace product',

      productId: productId,

      productSellerId: productSellerId,

      productName: productName,

      productImageUrl: productImageUrl,

      productPrice: productPrice,
    );
  }
  //===============================
  // TOGGLE REACTION
  //===============================

  Future<void> toggleReaction({
    required String groupId,
    required String messageId,
    required String emoji,
  }) async {
    final String? uid = currentUid;

    if (uid == null || uid.isEmpty) {
      return;
    }

    final DocumentReference<Map<String, dynamic>> reference = _groupReference(
      groupId,
    ).collection('messages').doc(messageId);

    final DocumentSnapshot<Map<String, dynamic>> snapshot = await reference
        .get();

    final Map<String, dynamic> reactions = snapshot.data()?['reactions'] is Map
        ? Map<String, dynamic>.from(snapshot.data()?['reactions'] as Map)
        : <String, dynamic>{};

    if ((reactions[uid] ?? '').toString() == emoji) {
      await reference.update(<String, dynamic>{
        'reactions.$uid': FieldValue.delete(),
      });

      return;
    }

    await reference.update(<String, dynamic>{'reactions.$uid': emoji});
  }

  //===============================
  // DELETE FOR ME
  //===============================

  Future<void> deleteMessageForMe({
    required String groupId,
    required String messageId,
  }) async {
    final String? uid = currentUid;

    if (uid == null || uid.isEmpty) {
      return;
    }

    await _groupReference(groupId).collection('messages').doc(messageId).update(
      <String, dynamic>{
        'hiddenFor': FieldValue.arrayUnion(<String>[uid]),
      },
    );
  }

  //===============================
  // DELETE FOR EVERYONE
  //===============================

  Future<void> deleteMessageForEveryone({
    required String groupId,
    required String messageId,
  }) async {
    final String? uid = currentUid;

    if (uid == null || uid.isEmpty) {
      return;
    }

    final DocumentReference<Map<String, dynamic>> groupReference =
        _groupReference(groupId);

    final DocumentReference<Map<String, dynamic>> messageReference =
        groupReference.collection('messages').doc(messageId);

    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await messageReference.get();

    if (!snapshot.exists) {
      return;
    }

    if ((snapshot.data()?['senderId'] ?? '').toString() != uid) {
      throw Exception('You can only delete your own message for everyone.');
    }

    final DocumentSnapshot<Map<String, dynamic>> groupSnapshot =
        await groupReference.get();

    final WriteBatch batch = _firestore.batch();

    batch.update(messageReference, <String, dynamic>{
      'deletedForEveryone': true,

      'text': '',

      'mediaUrl': '',

      'fileName': '',

      'storyId': '',

      'postId': '',

      'productId': '',

      'reactions': <String, String>{},
    });

    if ((groupSnapshot.data()?['lastMessageId'] ?? '').toString() ==
        messageId) {
      batch.set(groupReference, <String, dynamic>{
        'lastMessage': 'Message deleted',

        'lastMessageType': 'text',
      }, SetOptions(merge: true));
    }

    await batch.commit();
  }

  //===============================
  // FORWARD MESSAGE
  //===============================

  Future<void> forwardMessage({
    required String groupId,
    required ChatMessage message,
  }) async {
    if (message.deletedForEveryone) {
      return;
    }

    await _sendGroupMessage(
      groupId: groupId,

      type: message.type,

      preview: message.previewText,

      text: message.text,

      mediaUrl: message.mediaUrl,

      fileName: message.fileName,

      durationMs: message.durationMs,

      storyId: message.storyId,

      storyOwnerId: message.storyOwnerId,

      storyUsername: message.storyUsername,

      storyType: message.storyType,

      storyPreviewUrl: message.storyPreviewUrl,

      postId: message.postId,

      postOwnerId: message.postOwnerId,

      postUsername: message.postUsername,

      postFullName: message.postFullName,

      postCaption: message.postCaption,

      postPreviewUrl: message.postPreviewUrl,

      productId: message.productId,

      productSellerId: message.productSellerId,

      productName: message.productName,

      productImageUrl: message.productImageUrl,

      productPrice: message.productPrice,

      isForwarded: true,
    );
  }

  //===============================
  // MARK DELIVERED
  //===============================

  Future<void> markMessagesDelivered(String groupId) async {
    final String? uid = currentUid;

    if (uid == null || uid.isEmpty) {
      return;
    }

    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await _groupReference(groupId)
            .collection('messages')
            .orderBy('createdAt', descending: true)
            .limit(100)
            .get();

    final WriteBatch batch = _firestore.batch();

    bool changed = false;

    for (final QueryDocumentSnapshot<Map<String, dynamic>> document
        in snapshot.docs) {
      final Map<String, dynamic> data = document.data();

      if ((data['senderId'] ?? '').toString() == uid) {
        continue;
      }

      final List<String> deliveredTo = data['deliveredTo'] is List
          ? (data['deliveredTo'] as List)
                .map((dynamic item) => item.toString())
                .toList()
          : <String>[];

      if (deliveredTo.contains(uid)) {
        continue;
      }

      batch.update(document.reference, <String, dynamic>{
        'deliveredTo': FieldValue.arrayUnion(<String>[uid]),
      });

      changed = true;
    }

    if (changed) {
      await batch.commit();
    }
  }

  //===============================
  // MARK READ
  //===============================

  Future<void> markMessagesRead(String groupId) async {
    final String? uid = currentUid;

    if (uid == null || uid.isEmpty) {
      return;
    }

    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await _groupReference(groupId)
            .collection('messages')
            .orderBy('createdAt', descending: true)
            .limit(150)
            .get();

    final WriteBatch batch = _firestore.batch();

    bool changed = false;

    for (final QueryDocumentSnapshot<Map<String, dynamic>> document
        in snapshot.docs) {
      final Map<String, dynamic> data = document.data();

      if ((data['senderId'] ?? '').toString() == uid) {
        continue;
      }

      final List<String> readBy = data['readBy'] is List
          ? (data['readBy'] as List)
                .map((dynamic item) => item.toString())
                .toList()
          : <String>[];

      if (readBy.contains(uid)) {
        continue;
      }

      batch.update(document.reference, <String, dynamic>{
        'deliveredTo': FieldValue.arrayUnion(<String>[uid]),

        'readBy': FieldValue.arrayUnion(<String>[uid]),

        'seenBy': FieldValue.arrayUnion(<String>[uid]),
      });

      changed = true;
    }

    if (changed) {
      await batch.commit();
    }
  }

  //===============================
  // UNREAD COUNT
  //===============================

  Stream<int> unreadCountStream(String groupId) {
    final String? uid = currentUid;

    if (uid == null || uid.isEmpty) {
      return Stream<int>.value(0);
    }

    return getMessages(groupId).map((
      QuerySnapshot<Map<String, dynamic>> snapshot,
    ) {
      int unread = 0;

      for (final QueryDocumentSnapshot<Map<String, dynamic>> document
          in snapshot.docs) {
        final Map<String, dynamic> data = document.data();

        if ((data['senderId'] ?? '').toString() == uid) {
          continue;
        }

        final List<String> readBy = data['readBy'] is List
            ? (data['readBy'] as List)
                  .map((dynamic item) => item.toString())
                  .toList()
            : <String>[];

        if (!readBy.contains(uid)) {
          unread++;
        }
      }

      return unread;
    });
  }

  //===============================
  // UPDATE GROUP INFO
  //===============================

  Future<void> updateGroupInfo({
    required String groupId,
    String? name,
    String? description,
    String? photoUrl,
  }) async {
    final String? uid = currentUid;

    if (uid == null || uid.isEmpty) {
      return;
    }

    final ChatGroup group = await _loadGroup(groupId);

    final bool allowed =
        group.isAdmin(uid) || group.permissions.membersCanEditGroupSettings;

    if (!allowed) {
      throw Exception('You do not have permission to edit this group.');
    }

    final Map<String, dynamic> updates = <String, dynamic>{
      'updatedAt': Timestamp.now(),
    };

    if (name != null && name.trim().isNotEmpty) {
      updates['name'] = name.trim();
    }

    if (description != null) {
      updates['description'] = description.trim();
    }

    if (photoUrl != null) {
      updates['photoUrl'] = photoUrl;
    }

    await _groupReference(groupId).update(updates);
  }

  //===============================
  // UPDATE PERMISSION
  //===============================

  Future<void> updatePermission({
    required String groupId,
    required String permission,
    required bool value,
  }) async {
    final String? uid = currentUid;

    if (uid == null || uid.isEmpty) {
      return;
    }

    final ChatGroup group = await _loadGroup(groupId);

    if (!group.isAdmin(uid)) {
      throw Exception('Only admins can edit group permissions.');
    }

    const Set<String> allowedPermissions = <String>{
      'membersCanEditGroupSettings',
      'membersCanSendMessages',
      'membersCanAddMembers',
      'newMembersCanSeeHistory',
      'adminApprovalRequired',
    };

    if (!allowedPermissions.contains(permission)) {
      throw Exception('Invalid group permission.');
    }

    await _groupReference(groupId).update(<String, dynamic>{
      'permissions.$permission': value,

      'updatedAt': Timestamp.now(),
    });
  }

  //===============================
  // ADD MEMBERS
  //===============================

  Future<void> addMembers({
    required String groupId,
    required List<String> userIds,
  }) async {
    final String? uid = currentUid;

    if (uid == null || uid.isEmpty) {
      return;
    }

    final ChatGroup group = await _loadGroup(groupId);

    final bool allowed =
        group.isAdmin(uid) || group.permissions.membersCanAddMembers;

    if (!allowed) {
      throw Exception('Only admins can add members to this group.');
    }

    final List<String> cleanIds = userIds
        .where(
          (String item) =>
              item.trim().isNotEmpty && !group.memberIds.contains(item),
        )
        .toSet()
        .toList();

    if (cleanIds.isEmpty) {
      return;
    }

    final Map<String, dynamic> updates = <String, dynamic>{
      'memberIds': FieldValue.arrayUnion(cleanIds),

      'members': FieldValue.arrayUnion(cleanIds),

      'updatedAt': Timestamp.now(),
    };

    final Timestamp joinedAt = Timestamp.now();

    for (final String memberId in cleanIds) {
      updates['memberJoinedAt.$memberId'] = joinedAt;
    }

    await _groupReference(groupId).update(updates);
  }

  //===============================
  // REMOVE MEMBER
  //===============================

  Future<void> removeMember({
    required String groupId,
    required String userId,
  }) async {
    final String? uid = currentUid;

    if (uid == null || uid.isEmpty) {
      return;
    }

    final ChatGroup group = await _loadGroup(groupId);

    if (!group.isAdmin(uid)) {
      throw Exception('Only admins can remove members.');
    }

    if (userId == group.creatorId) {
      throw Exception('The group creator cannot be removed.');
    }

    await _groupReference(groupId).update(<String, dynamic>{
      'memberIds': FieldValue.arrayRemove(<String>[userId]),

      'members': FieldValue.arrayRemove(<String>[userId]),

      'adminIds': FieldValue.arrayRemove(<String>[userId]),

      'memberJoinedAt.$userId': FieldValue.delete(),

      'updatedAt': Timestamp.now(),
    });
  }

  //===============================
  // MAKE ADMIN
  //===============================

  Future<void> makeAdmin({
    required String groupId,
    required String userId,
  }) async {
    final String? uid = currentUid;

    if (uid == null || uid.isEmpty) {
      return;
    }

    final ChatGroup group = await _loadGroup(groupId);

    if (!group.isAdmin(uid)) {
      throw Exception('Only admins can edit group admins.');
    }

    if (!group.memberIds.contains(userId)) {
      throw Exception('User is not a group member.');
    }

    await _groupReference(groupId).update(<String, dynamic>{
      'adminIds': FieldValue.arrayUnion(<String>[userId]),

      'updatedAt': Timestamp.now(),
    });
  }

  //===============================
  // DISMISS ADMIN
  //===============================

  Future<void> dismissAdmin({
    required String groupId,
    required String userId,
  }) async {
    final String? uid = currentUid;

    if (uid == null || uid.isEmpty) {
      return;
    }

    final ChatGroup group = await _loadGroup(groupId);

    if (!group.isAdmin(uid)) {
      throw Exception('Only admins can edit group admins.');
    }

    if (userId == group.creatorId) {
      throw Exception('The group creator must remain an admin.');
    }

    await _groupReference(groupId).update(<String, dynamic>{
      'adminIds': FieldValue.arrayRemove(<String>[userId]),

      'updatedAt': Timestamp.now(),
    });
  }

  //===============================
  // LEAVE GROUP
  //===============================

  Future<void> leaveGroup(String groupId) async {
    final String? uid = currentUid;

    if (uid == null || uid.isEmpty) {
      return;
    }

    final ChatGroup group = await _loadGroup(groupId);

    if (!group.memberIds.contains(uid)) {
      return;
    }

    //===============================
    // ONLY MEMBER
    //===============================

    if (group.memberIds.length == 1) {
      await _groupReference(groupId).delete();

      return;
    }

    //===============================
    // OTHER ADMINS
    //===============================

    final List<String> otherAdmins = group.adminIds
        .where(
          (String adminId) =>
              adminId != uid && group.memberIds.contains(adminId),
        )
        .toList();

    if (group.isAdmin(uid) && otherAdmins.isEmpty) {
      throw Exception(
        'Make another member an admin before leaving this group.',
      );
    }

    final Map<String, dynamic> updates = <String, dynamic>{
      'memberIds': FieldValue.arrayRemove(<String>[uid]),

      'members': FieldValue.arrayRemove(<String>[uid]),

      'adminIds': FieldValue.arrayRemove(<String>[uid]),

      'memberJoinedAt.$uid': FieldValue.delete(),

      'updatedAt': Timestamp.now(),
    };

    //===============================
    // TRANSFER CREATOR
    //===============================

    if (group.creatorId == uid && otherAdmins.isNotEmpty) {
      updates['creatorId'] = otherAdmins.first;
    }

    await _groupReference(groupId).update(updates);
  }
  //===============================
  // INVITE LINK
  //===============================

  Future<String> getInviteLink(String groupId) async {
    final ChatGroup group = await _loadGroup(groupId);

    if (group.inviteToken.isEmpty) {
      throw Exception('This group has no invite link.');
    }

    return 'https://nubify.app/group/join/${group.inviteToken}';
  }

  //===============================
  // RESET INVITE LINK
  //===============================

  Future<String> resetInviteLink(String groupId) async {
    final String? uid = currentUid;

    if (uid == null || uid.isEmpty) {
      throw Exception('User is not logged in.');
    }

    final ChatGroup group = await _loadGroup(groupId);

    if (!group.isAdmin(uid)) {
      throw Exception('Only admins can reset the group link.');
    }

    final String token = _generateInviteToken();

    await _groupReference(groupId).update(<String, dynamic>{
      'inviteToken': token,

      'updatedAt': Timestamp.now(),
    });

    return 'https://nubify.app/group/join/$token';
  }

  //===================================================
  // JOIN GROUP USING SECURE INVITATION
  //===================================================

  Future<String> joinUsingToken(String token) async {
    final String? uid = currentUid;

    if (uid == null || uid.isEmpty) {
      throw Exception('You must sign in before joining a group.');
    }

    final String cleanToken = token.trim();

    if (cleanToken.isEmpty) {
      throw Exception('Invalid group invitation link.');
    }

    try {
      //===================================================
      // CALL FIREBASE BACKEND
      //===================================================

      final HttpsCallable callable = _functions.httpsCallable(
        'joinGroupByInvite',
      );

      final HttpsCallableResult<dynamic> result = await callable.call(
        <String, dynamic>{'token': cleanToken},
      );

      if (result.data is! Map) {
        throw Exception('Invalid response from Firebase.');
      }

      final Map<String, dynamic> data = Map<String, dynamic>.from(
        result.data as Map,
      );

      final String status = (data['status'] ?? '').toString();

      //===================================================
      // ADMIN APPROVAL REQUIRED
      //===================================================

      if (status == 'pending') {
        return '';
      }

      //===================================================
      // MEMBERSHIP CONFIRMED
      //===================================================

      if (status == 'joined') {
        final String groupId = (data['groupId'] ?? '').toString();

        if (groupId.isEmpty) {
          throw Exception('Group ID is missing.');
        }

        return groupId;
      }

      throw Exception('Unable to join this group.');
    } on FirebaseFunctionsException catch (error) {
      throw Exception(
        error.message ?? 'Unable to join the group. Please try again.',
      );
    }
  }

  //===============================
  // APPROVE JOIN REQUEST
  //===============================

  Future<void> approveJoinRequest({
    required String groupId,
    required String userId,
  }) async {
    final String? uid = currentUid;

    if (uid == null || uid.isEmpty) {
      return;
    }

    final ChatGroup group = await _loadGroup(groupId);

    if (!group.isAdmin(uid)) {
      throw Exception('Only admins can approve new members.');
    }

    final DocumentReference<Map<String, dynamic>> requestReference =
        _groupReference(groupId).collection('joinRequests').doc(userId);

    final WriteBatch batch = _firestore.batch();

    batch.update(_groupReference(groupId), <String, dynamic>{
      'memberIds': FieldValue.arrayUnion(<String>[userId]),

      'members': FieldValue.arrayUnion(<String>[userId]),

      'memberJoinedAt.$userId': Timestamp.now(),

      'updatedAt': Timestamp.now(),
    });

    batch.delete(requestReference);

    await batch.commit();
  }

  //===================================================
  // REJECT GROUP JOIN REQUEST
  //===================================================

  Future<void> rejectJoinRequest({
    required String groupId,
    required String userId,
  }) async {
    final String? uid = currentUid;

    if (uid == null || uid.isEmpty) {
      throw Exception('You must be logged in.');
    }

    //===================================================
    // VERIFY ADMIN
    //===================================================

    final ChatGroup group = await _loadGroup(groupId);

    if (!group.isAdmin(uid)) {
      throw Exception('Only group admins can reject join requests.');
    }

    //===================================================
    // DELETE PENDING REQUEST
    //===================================================

    await _groupReference(
      groupId,
    ).collection('joinRequests').doc(userId).delete();
  }
}
