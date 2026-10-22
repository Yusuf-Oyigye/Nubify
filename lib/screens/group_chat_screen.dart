import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/chat_message_actions_sheet.dart';

import '../models/chat_group.dart';
import '../models/chat_message.dart';
import '../services/chat_media_service.dart';
import '../services/group_chat_service.dart';
import '../widgets/chat_composer.dart';
import '../widgets/chat_date_separator.dart';
import '../widgets/group_message_bubble.dart';
import 'add_group_members_screen.dart';
import 'group_info_screen.dart';
import 'group_permissions_screen.dart';
import 'chat_forward_screen.dart';
import '../widgets/full_photo_viewer.dart';
import '../widgets/universal_link_composer_preview.dart';

//===============================
// GROUP CHAT SCREEN
//===============================

class GroupChatScreen extends StatefulWidget {
  const GroupChatScreen({super.key, required this.groupId, this.initialGroup});

  final String groupId;

  final ChatGroup? initialGroup;

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

//===============================
// GROUP CHAT STATE
//===============================

class _GroupChatScreenState extends State<GroupChatScreen> {
  static const Color _blue = Color(0xFF29B6F6);


  Stream<QuerySnapshot<Map<String, dynamic>>>?
  _groupMessagesStream;

  String _groupMessagesKey = '';

//===================================================
// GET GROUP MESSAGE STREAM
//===================================================

  Stream<QuerySnapshot<Map<String, dynamic>>> _messagesFor(
      ChatGroup group,
      ) {
    final String uid = _auth.currentUser?.uid ?? '';

    final int joinedAt =
        group.memberJoinedAt[uid]?.millisecondsSinceEpoch ?? 0;

    final String key =
        '${group.groupId}|${group.permissions.newMembersCanSeeHistory}|$joinedAt';

    if (_groupMessagesStream == null ||
        _groupMessagesKey != key) {
      _groupMessagesKey = key;

      _groupMessagesStream = _groupService.getMessages(
        group.groupId,
        knownGroup: group,
      );
    }

    return _groupMessagesStream!;
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  final GroupChatService _groupService = GroupChatService();

  final ChatMediaService _mediaService = ChatMediaService();

  final ImagePicker _imagePicker = ImagePicker();

  final TextEditingController _messageController = TextEditingController();

  final bool _sending = false;
  final bool _linkPreviewDisabled = false;

  ChatMessage? _replyingTo;
  //===============================
  // PENDING UPLOADS
  //===============================

  final List<_PendingGroupUpload> _pendingUploads = <_PendingGroupUpload>[];

  int _pendingUploadCounter = 0;

  //===============================
  // USER CACHE
  //===============================

  final Map<String, Future<DocumentSnapshot<Map<String, dynamic>>>>
  _userFutureCache = <String, Future<DocumentSnapshot<Map<String, dynamic>>>>{};

  //===============================
  // CACHED USER
  //===============================

  Future<DocumentSnapshot<Map<String, dynamic>>> _cachedUser(String uid) {
    return _userFutureCache.putIfAbsent(
      uid,
      () => _firestore.collection('users').doc(uid).get(),
    );
  }

  //===================================================
// INITIALIZE GROUP CHAT
//===================================================

  @override
  void initState() {
    super.initState();

    _markSeen();
  }

  //===============================
  // MARK SEEN
  //===============================

  Future<void> _markSeen() async {
    try {
      await _groupService.markMessagesRead(widget.groupId);
    } catch (_) {}
  }

  //===============================
  // SEND TEXT
  //===============================

  Future<void> _sendText(ChatGroup group) async {
    final String text = _messageController.text.trim();

    if (text.isEmpty) {
      return;
    }

    final String replyToMessageId = _replyingTo?.messageId ?? '';

    final String replyToSenderId = _replyingTo?.senderId ?? '';

    final String replyToSenderName = _replyingTo == null
        ? ''
        : _replyingTo!.senderId == _auth.currentUser?.uid
        ? 'You'
        : await _userName(_replyingTo!.senderId);

    final String replyToText = _replyingTo?.previewText ?? '';

    final String replyToType = _replyingTo?.type ?? '';

    //===============================
    // CLEAR UI IMMEDIATELY
    //===============================

    _messageController.clear();

    _clearReply();

    //===============================
    // SEND IN BACKGROUND
    //===============================

    unawaited(
      _sendTextInBackground(
        group: group,
        text: text,
        replyToMessageId: replyToMessageId,
        replyToSenderId: replyToSenderId,
        replyToSenderName: replyToSenderName,
        replyToText: replyToText,
        replyToType: replyToType,
      ),
    );
  }

  //===============================
  // SEND TEXT IN BACKGROUND
  //===============================

  Future<void> _sendTextInBackground({
    required ChatGroup group,
    required String text,
    required String replyToMessageId,
    required String replyToSenderId,
    required String replyToSenderName,
    required String replyToText,
    required String replyToType,
  }) async {
    try {
      await _groupService.sendMessage(
        groupId: widget.groupId,
        linkPreviewDisabled: _linkPreviewDisabled,
        text: text,
        knownGroup: group,
        replyToMessageId: replyToMessageId,
        replyToSenderId: replyToSenderId,
        replyToSenderName: replyToSenderName,
        replyToText: replyToText,
        replyToType: replyToType,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      if (_messageController.text.trim().isEmpty) {
        _messageController.text = text;

        _messageController.selection = TextSelection.collapsed(
          offset: _messageController.text.length,
        );
      }

      _showError(error);
    }
  }

  //===============================
  // SEND STICKER
  //===============================

  Future<void> _sendSticker(ChatGroup group, String sticker) async {
    if (sticker.trim().isEmpty) {
      return;
    }

    try {
      await _groupService.sendSticker(
        groupId: widget.groupId,
        sticker: sticker,
        knownGroup: group,
      );
    } catch (error) {
      _showError(error);
    }
  }

  //===============================
  // CAMERA
  //===============================

  Future<void> _camera(ChatGroup group) async {
    final XFile? file = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
    );

    if (file == null) {
      return;
    }

    await _uploadAndSend(group: group, path: file.path, type: 'image');
  }

  //===============================
  // GALLERY
  //===============================

  Future<void> _gallery(ChatGroup group) async {
    final XFile? file = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
    );

    if (file == null) {
      return;
    }

    await _uploadAndSend(group: group, path: file.path, type: 'image');
  }

  //===============================
  // VIDEO
  //===============================

  Future<void> _video(ChatGroup group) async {
    final XFile? file = await _imagePicker.pickVideo(
      source: ImageSource.gallery,
    );

    if (file == null) {
      return;
    }

    await _uploadAndSend(group: group, path: file.path, type: 'video');
  }

  //===============================
  // DOCUMENT
  //===============================

  Future<void> _document(ChatGroup group) async {
    final PlatformFile? file = await FilePicker.pickFile(type: FileType.any);

    if (file == null) {
      return;
    }

    if (file.path == null || file.path!.trim().isEmpty) {
      return;
    }

    await _uploadAndSend(
      group: group,
      path: file.path!,
      type: 'document',
      fileName: file.name,
    );
  }

  //===============================
  // VOICE
  //===============================

  Future<void> _voice(ChatGroup group, String path, int durationMs) async {
    await _uploadAndSend(
      group: group,
      path: path,
      type: 'voice',
      durationMs: durationMs,
    );
  }

  //===============================
  // UPLOAD + SEND
  //===============================

  Future<void> _uploadAndSend({
    required ChatGroup group,
    required String path,
    required String type,
    String fileName = '',
    int durationMs = 0,
  }) async {
    final ChatMessage? reply = _replyingTo;

    final String pendingId =
        '${DateTime.now().microsecondsSinceEpoch}_${_pendingUploadCounter++}';

    final _PendingGroupUpload pending = _PendingGroupUpload(
      id: pendingId,

      path: path,

      type: type,

      fileName: fileName,

      durationMs: durationMs,
    );

    //===============================
    // SHOW LOCALLY IMMEDIATELY
    //===============================

    if (mounted) {
      setState(() {
        _pendingUploads.insert(0, pending);
      });
    }

    // Clear reply immediately.
    _clearReply();

    //===============================
    // UPLOAD IN BACKGROUND
    //===============================

    unawaited(_performUpload(group: group, pending: pending, reply: reply));
  }
  //===============================
  // PERFORM UPLOAD
  //===============================

  Future<void> _performUpload({
    required ChatGroup group,
    required _PendingGroupUpload pending,
    required ChatMessage? reply,
  }) async {
    try {
      final String url = await _mediaService.uploadGroupChatFile(
        groupId: widget.groupId,

        filePath: pending.path,
      );

      String replySenderName = '';

      if (reply != null) {
        if (reply.senderId == _auth.currentUser?.uid) {
          replySenderName = 'You';
        } else {
          replySenderName = await _userName(reply.senderId);
        }
      }

      await _groupService.sendMediaMessage(
        groupId: widget.groupId,

        mediaUrl: url,

        mediaType: pending.type,

        knownGroup: group,

        fileName: pending.fileName,

        durationMs: pending.durationMs,

        replyToMessageId: reply?.messageId ?? '',

        replyToSenderId: reply?.senderId ?? '',

        replyToSenderName: replySenderName,

        replyToText: reply?.previewText ?? '',

        replyToType: reply?.type ?? '',
      );

      //===============================
      // REMOVE LOCAL PENDING MESSAGE
      //===============================

      if (!mounted) {
        return;
      }

      setState(() {
        _pendingUploads.removeWhere(
          (_PendingGroupUpload item) => item.id == pending.id,
        );
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _pendingUploads.removeWhere(
          (_PendingGroupUpload item) => item.id == pending.id,
        );
      });

      _showError(error);
    }
  }
  //===============================
  // PENDING UPLOAD TILE
  //===============================

  Widget _pendingUploadTile(_PendingGroupUpload pending) {
    Widget content;

    //===============================
    // IMAGE PREVIEW
    //===============================

    if (pending.type == 'image') {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          File(pending.path),
          width: 210,
          height: 210,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const SizedBox(
            width: 210,
            height: 120,
            child: Center(
              child: Icon(
                Icons.image_outlined,
                color: Colors.white70,
                size: 38,
              ),
            ),
          ),
        ),
      );
    }
    //===============================
    // VIDEO PREVIEW
    //===============================
    else if (pending.type == 'video') {
      content = const SizedBox(
        width: 210,
        height: 120,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.videocam_rounded, color: Colors.white, size: 42),
            SizedBox(height: 6),
            Text(
              'Sending video...',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      );
    }
    //===============================
    // VOICE PREVIEW
    //===============================
    else if (pending.type == 'voice') {
      final int seconds = (pending.durationMs / 1000).round();

      content = SizedBox(
        width: 210,
        child: Row(
          children: <Widget>[
            const CircleAvatar(
              radius: 19,
              backgroundColor: Colors.white24,
              child: Icon(Icons.mic_rounded, color: Colors.white, size: 20),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Sending voice...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  Text(
                    '${seconds}s',
                    style: const TextStyle(color: Colors.white60, fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    //===============================
    // DOCUMENT PREVIEW
    //===============================
    else {
      content = SizedBox(
        width: 210,
        child: Row(
          children: <Widget>[
            const Icon(
              Icons.description_rounded,
              color: Colors.white,
              size: 33,
            ),

            const SizedBox(width: 9),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    pending.fileName.trim().isNotEmpty
                        ? pending.fileName
                        : 'Document',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),

                  const Text(
                    'Sending...',
                    style: TextStyle(color: Colors.white60, fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(left: 60, right: 9, bottom: 5),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _blue,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(17),
              topRight: Radius.circular(17),
              bottomLeft: Radius.circular(17),
              bottomRight: Radius.circular(5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              content,

              const SizedBox(height: 5),

              const Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.cloud_upload_outlined,
                    size: 13,
                    color: Colors.white70,
                  ),

                  SizedBox(width: 4),

                  Text(
                    'Sending',
                    style: TextStyle(color: Colors.white70, fontSize: 9),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  //===============================
  // USER NAME
  //===============================

  Future<String> _userName(String uid) async {
    if (uid.isEmpty) {
      return 'User';
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await _cachedUser(
        uid,
      );

      final Map<String, dynamic> data = snapshot.data() ?? <String, dynamic>{};

      final String fullName = (data['fullName'] ?? '').toString();

      final String username = (data['username'] ?? '').toString();

      return fullName.trim().isNotEmpty
          ? fullName
          : username.trim().isNotEmpty
          ? username
          : 'User';
    } catch (_) {
      return 'User';
    }
  }

  //===============================
  // MEMBER NAMES
  //===============================

  Future<String> _memberNames(ChatGroup group) async {
    final List<String> memberIds = group.memberIds.take(4).toList();

    if (memberIds.isEmpty) {
      return 'No members';
    }

    final List<String> names = await Future.wait(
      memberIds.map((String uid) => _userName(uid)),
    );

    String text = names.join(', ');

    if (group.memberIds.length > names.length) {
      text = '$text +${group.memberIds.length - names.length}';
    }

    return text;
  }

  //===============================
  // EDIT NAME
  //===============================

  Future<void> _editName(ChatGroup group) async {
    String draft = group.name;

    final String? value = await showDialog<String>(
      context: context,

      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Edit group name'),

          content: TextFormField(
            initialValue: group.name,

            autofocus: true,

            maxLength: 80,

            onChanged: (String value) {
              draft = value;
            },
          ),

          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },

              child: const Text('Cancel'),
            ),

            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, draft.trim());
              },

              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (value == null || value.trim().isEmpty) {
      return;
    }

    try {
      await _groupService.updateGroupInfo(
        groupId: group.groupId,

        name: value.trim(),
      );
    } catch (error) {
      _showError(error);
    }
  }
  //===============================
  // EDIT DESCRIPTION
  //===============================

  Future<void> _editDescription(ChatGroup group) async {
    String draft = group.description;

    final String? value = await showDialog<String>(
      context: context,

      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Edit description'),

          content: TextFormField(
            initialValue: group.description,

            autofocus: true,

            maxLength: 300,

            maxLines: 5,

            onChanged: (String value) {
              draft = value;
            },
          ),

          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },

              child: const Text('Cancel'),
            ),

            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, draft.trim());
              },

              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (value == null) {
      return;
    }

    try {
      await _groupService.updateGroupInfo(
        groupId: group.groupId,

        description: value.trim(),
      );
    } catch (error) {
      _showError(error);
    }
  }
  //===============================
  // GROUP MESSAGE ACTIONS
  //===============================

  Future<void> _messageActions(ChatMessage message, bool mine) async {
    final ChatMessageActionResult? result = await showChatMessageActions(
      context: context,

      mine: mine,
    );

    if (result == null || !mounted) {
      return;
    }

    switch (result.action) {
      case 'react':
        await _groupService.toggleReaction(
          groupId: widget.groupId,

          messageId: message.messageId,

          emoji: result.emoji,
        );
        break;

      case 'reply':
        _reply(message);
        break;

      case 'forward':
        Navigator.push(
          context,

          MaterialPageRoute<void>(
            builder: (_) => ChatForwardScreen(message: message),
          ),
        );
        break;

      case 'delete':
        final String? mode = await showDeleteMessageDialog(
          context: context,

          mine: mine,
        );

        if (mode == 'me') {
          await _groupService.deleteMessageForMe(
            groupId: widget.groupId,

            messageId: message.messageId,
          );
        } else if (mode == 'everyone') {
          await _groupService.deleteMessageForEveryone(
            groupId: widget.groupId,

            messageId: message.messageId,
          );
        }

        break;
    }
  }
  //===============================
  // REPLY
  //===============================

  void _reply(ChatMessage message) {
    setState(() {
      _replyingTo = message;
    });
  }

  //===============================
  // CLEAR REPLY
  //===============================

  void _clearReply() {
    if (!mounted) {
      return;
    }

    setState(() {
      _replyingTo = null;
    });
  }

  //===============================
  // SAME DATE
  //===============================

  bool _sameDay(DateTime one, DateTime two) {
    return one.year == two.year && one.month == two.month && one.day == two.day;
  }

  //===============================
  // ERROR
  //===============================

  void _showError(Object error) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
    );
  }

  //===============================
  // GROUP MENU
  //===============================

  Future<void> _menu(String value, ChatGroup group) async {
    final String uid = _auth.currentUser?.uid ?? '';

    final bool admin = group.isAdmin(uid);

    final bool canAdd = admin || group.permissions.membersCanAddMembers;

    final bool canEdit = admin || group.permissions.membersCanEditGroupSettings;

    switch (value) {
      case 'info':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GroupInfoScreen(groupId: group.groupId),
          ),
        );
        break;

      case 'add':
        if (canAdd) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddGroupMembersScreen(groupId: group.groupId),
            ),
          );
        }
        break;

      case 'name':
        if (canEdit) {
          await _editName(group);
        }
        break;

      case 'description':
        if (canEdit) {
          await _editDescription(group);
        }
        break;

      case 'permissions':
        if (admin) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GroupPermissionsScreen(groupId: group.groupId),
            ),
          );
        }
        break;
    }
  }

  //===============================
  // REPLY BAR
  //===============================

  Widget _replyBar() {
    final ChatMessage? message = _replyingTo;

    if (message == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 7, 7, 7),
      color: const Color(0xFF151E24),
      child: Row(
        children: <Widget>[
          Container(width: 3, height: 39, color: _blue),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Replying to message',
                  style: TextStyle(
                    color: _blue,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
                Text(
                  message.previewText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _clearReply,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }

  //===============================
  // MESSAGE TILE
  //===============================

  Widget _messageTile({
    required ChatMessage message,
    required ChatGroup group,
  }) {
    final String currentUid = _auth.currentUser?.uid ?? '';
    final bool mine = message.senderId == currentUid;

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: _cachedUser(message.senderId),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
          ) {
            final Map<String, dynamic> user =
                snapshot.data?.data() ?? <String, dynamic>{};

            final String fullName = (user['fullName'] ?? '').toString();

            final String username = (user['username'] ?? '').toString();

            final String photoUrl = (user['photoUrl'] ?? '').toString();

            final String displayName = fullName.trim().isNotEmpty
                ? fullName
                : username.trim().isNotEmpty
                ? username
                : mine
                ? 'You'
                : 'User';

            return GroupMessageBubble(
              message: message,

              mine: mine,

              senderName: displayName,

              senderPhotoUrl: photoUrl,

              memberIds: group.memberIds,

              //===============================
              // MESSAGE LONG PRESS
              //===============================
              onLongPress: () {
                _messageActions(message, mine);
              },

              //===============================
              // SENDER PROFILE PHOTO
              //===============================
              onSenderPhotoTap: mine
                  ? null
                  : () {
                      Navigator.push(
                        context,

                        MaterialPageRoute<void>(
                          builder: (_) => FullPhotoViewer(
                            title: displayName,

                            photoUrl: photoUrl,
                          ),
                        ),
                      );
                    },
            );
          },
    );
  }

  //===============================
  // BUILD
  //===============================

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _groupService.groupStream(widget.groupId),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> groupSnapshot,
          ) {
            if (groupSnapshot.hasData && !groupSnapshot.data!.exists) {
              return const Scaffold(
                backgroundColor: Color(0xFF0B1116),
                body: Center(child: Text('Group not found.')),
              );
            }

            final ChatGroup? group =
                groupSnapshot.hasData && groupSnapshot.data!.exists
                ? ChatGroup.fromDocument(groupSnapshot.data!)
                : widget.initialGroup;

            if (group == null) {
              return const Scaffold(
                backgroundColor: Color(0xFF0B1116),
                body: SizedBox.shrink(),
              );
            }

            final String uid = _auth.currentUser?.uid ?? '';

            final bool admin = group.isAdmin(uid);

            final bool canSend =
                admin || group.permissions.membersCanSendMessages;

            final bool canAdd = admin || group.permissions.membersCanAddMembers;

            final bool canEdit =
                admin || group.permissions.membersCanEditGroupSettings;

            return Scaffold(
              backgroundColor: const Color(0xFF0B1116),

              //===============================
              // APP BAR
              //===============================
              appBar: AppBar(
                backgroundColor: const Color(0xFF0B1116),
                titleSpacing: 0,
                title: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GroupInfoScreen(groupId: group.groupId),
                      ),
                    );
                  },
                  child: Row(
                    children: <Widget>[
                      CircleAvatar(
                        radius: 19,
                        backgroundColor: const Color(0xFF17252E),
                        backgroundImage: group.photoUrl.trim().isNotEmpty
                            ? NetworkImage(group.photoUrl)
                            : null,
                        child: group.photoUrl.trim().isEmpty
                            ? const Icon(Icons.groups_rounded, color: _blue)
                            : null,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              group.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            FutureBuilder<String>(
                              future: _memberNames(group),
                              builder:
                                  (
                                    BuildContext context,
                                    AsyncSnapshot<String> snapshot,
                                  ) {
                                    return Text(
                                      snapshot.data ??
                                          '${group.memberIds.length} members',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 10,
                                      ),
                                    );
                                  },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                actions: <Widget>[
                  PopupMenuButton<String>(
                    onSelected: (String value) {
                      _menu(value, group);
                    },
                    itemBuilder: (BuildContext context) =>
                        <PopupMenuEntry<String>>[
                          const PopupMenuItem<String>(
                            value: 'info',
                            child: Text('Group info'),
                          ),
                          if (canAdd)
                            const PopupMenuItem<String>(
                              value: 'add',
                              child: Text('Add members'),
                            ),
                          if (canEdit)
                            const PopupMenuItem<String>(
                              value: 'name',
                              child: Text('Edit group name'),
                            ),
                          if (canEdit)
                            const PopupMenuItem<String>(
                              value: 'description',
                              child: Text('Edit description'),
                            ),
                          if (admin)
                            const PopupMenuItem<String>(
                              value: 'permissions',
                              child: Text('Group permissions'),
                            ),
                        ],
                  ),
                ],
              ),

              //===============================
              // BODY
              //===============================
              body: SafeArea(
                child: Column(
                  children: <Widget>[
                    Expanded(
                      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _messagesFor(group),
                        builder:
                            (
                              BuildContext context,
                              AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>>
                              snapshot,
                            ) {
                              final String currentUid =
                                  _auth.currentUser?.uid ?? '';

                              final List<ChatMessage> messages =
                                  (snapshot.data?.docs ??
                                          <
                                            QueryDocumentSnapshot<
                                              Map<String, dynamic>
                                            >
                                          >[])
                                      .map(
                                        (
                                          QueryDocumentSnapshot<
                                            Map<String, dynamic>
                                          >
                                          document,
                                        ) => ChatMessage.fromDocument(document),
                                      )
                                      .where(
                                        (ChatMessage message) => !message
                                            .hiddenFor
                                            .contains(currentUid),
                                      )
                                      .toList();
                              (snapshot.data?.docs ??
                                      <
                                        QueryDocumentSnapshot<
                                          Map<String, dynamic>
                                        >
                                      >[])
                                  .map(
                                    (
                                      QueryDocumentSnapshot<
                                        Map<String, dynamic>
                                      >
                                      document,
                                    ) => ChatMessage.fromDocument(document),
                                  )
                                  .toList();

                              if (messages.isEmpty) {
                                return const Center(
                                  child: Text(
                                    'Start the group conversation.',
                                    style: TextStyle(color: Colors.white54),
                                  ),
                                );
                              }

                              return ListView.builder(
                                reverse: true,
                                padding: const EdgeInsets.fromLTRB(
                                  9,
                                  12,
                                  9,
                                  12,
                                ),
                                itemCount:
                                    _pendingUploads.length + messages.length,
                                itemBuilder: (BuildContext context, int index) {
                                  //===============================
                                  // PENDING UPLOAD
                                  //===============================

                                  if (index < _pendingUploads.length) {
                                    return _pendingUploadTile(
                                      _pendingUploads[index],
                                    );
                                  }

                                  //===============================
                                  // FIRESTORE MESSAGE
                                  //===============================

                                  final int messageIndex =
                                      index - _pendingUploads.length;

                                  final ChatMessage message =
                                      messages[messageIndex];

                                  final DateTime date =
                                      message.createdAt?.toDate().toLocal() ??
                                      DateTime.now();

                                  bool showDate = false;
                                  if (messageIndex == messages.length - 1) {
                                    showDate = true;
                                  } else {
                                    final DateTime older =
                                        messages[messageIndex + 1].createdAt
                                            ?.toDate()
                                            .toLocal() ??
                                        date;

                                    showDate = !_sameDay(date, older);
                                  }

                                  return Column(
                                    children: <Widget>[
                                      if (showDate)
                                        ChatDateSeparator(date: date),
                                      _messageTile(
                                        message: message,
                                        group: group,
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                      ),
                    ),

                    _replyBar(),

                    if (!canSend)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        color: const Color(0xFF172027),
                        child: const Text(
                          'Only admins can send messages in this group.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white60),
                        ),
                      )
                    else
                      UniversalLinkComposerPreview(
                        controller: _messageController,

                        onSuppressedChanged: (bool value) {
                          if (!mounted) {
                            return;
                          }
                        },
                      ),
                    ChatComposer(
                      controller: _messageController,
                      sending: _sending,
                      onSend: () => _sendText(group),
                      onCamera: () => _camera(group),
                      onGallery: () => _gallery(group),
                      onVideo: () => _video(group),
                      onDocument: () => _document(group),
                      onVoiceRecorded: (String path, int durationMs) =>
                          _voice(group, path, durationMs),
                      onStickerSelected: (String sticker) =>
                          _sendSticker(group, sticker),
                    ),
                  ],
                ),
              ),
            );
          },
    );
  }

  //===============================
  // DISPOSE
  //===============================

  @override
  void dispose() {
    _messageController.dispose();

    super.dispose();
  }
}
//===============================
// PENDING GROUP UPLOAD
//===============================

class _PendingGroupUpload {
  const _PendingGroupUpload({
    required this.id,
    required this.path,
    required this.type,
    required this.fileName,
    required this.durationMs,
  });

  final String id;

  final String path;

  final String type;

  final String fileName;

  final int durationMs;
}
