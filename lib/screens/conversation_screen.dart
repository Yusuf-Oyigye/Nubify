import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/chat_message_actions_sheet.dart';

import '../models/chat_message.dart';
import '../models/story.dart';
import '../services/chat_media_service.dart';
import '../services/chat_presence_service.dart';
import '../services/chat_privacy_service.dart';
import '../services/chat_sevice.dart';
import '../services/profile_service.dart';
import '../services/story_service.dart';
import '../widgets/chat_composer.dart';
import '../widgets/chat_date_separator.dart';
import '../widgets/chat_message_bubble.dart';
import '../widgets/marketplace_brand_icon.dart';
import 'chat_catalogue_screen.dart';
import 'chat_media_screen.dart';
import 'profile_screen.dart';
import 'story_viewer_screen.dart';
import 'audio_call_screen.dart';
import 'chat_forward_screen.dart';
import '../widgets/report_user_dialog.dart';
import '../widgets/full_photo_viewer.dart';
import 'comment_screen.dart';
import '../utils/nubify_call_display.dart';
import '../widgets/chat_call_event_bubble.dart';
import '../widgets/nubify_chat_style.dart';

class _ConversationPalette {
  const _ConversationPalette({
    required this.canvas,
    required this.surface,
    required this.field,
    required this.text,
    required this.muted,
    required this.subtle,
    required this.divider,
  });

  final Color canvas;
  final Color surface;
  final Color field;
  final Color text;
  final Color muted;
  final Color subtle;
  final Color divider;

  factory _ConversationPalette.of(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool dark = theme.brightness == Brightness.dark;

    return _ConversationPalette(
      canvas: theme.scaffoldBackgroundColor,
      surface: scheme.surface,
      field: dark ? const Color(0xFF1A2228) : scheme.surfaceContainerHighest,
      text: scheme.onSurface,
      muted: scheme.onSurfaceVariant,
      subtle: scheme.onSurfaceVariant.withValues(alpha: 0.72),
      divider: scheme.outlineVariant,
    );
  }
}

//===============================
// CONVERSATION SCREEN
//===============================

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({
    super.key,
    required this.otherUserId,
    required this.otherName,
    required this.otherUsername,
    required this.otherPhotoUrl,
    this.startCallOnOpen = false,
  });

  final String otherUserId;

  final String otherName;

  final String otherUsername;

  final String otherPhotoUrl;

  final bool startCallOnOpen;

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

//===============================
// CONVERSATION STATE
//===============================

class _ConversationScreenState extends State<ConversationScreen> {
  static const Color _blue = Color(0xFF29B6F6);

  final FirebaseAuth _auth = FirebaseAuth.instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final Stream<QuerySnapshot<Map<String, dynamic>>>
  _outgoingCallHistoryStream;

  late final Stream<QuerySnapshot<Map<String, dynamic>>>
  _incomingCallHistoryStream;

  final ChatService _chatService = ChatService();
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _messagesStream;

  late final Stream<bool> _activityStream;

  final ChatMediaService _mediaService = ChatMediaService();

  final ChatPrivacyService _privacyService = ChatPrivacyService();

  final ChatPresenceService _presenceService = ChatPresenceService();

  final ProfileService _profileService = ProfileService();

  final StoryService _storyService = StoryService();

  final ImagePicker _imagePicker = ImagePicker();

  final TextEditingController _messageController = TextEditingController();

  final TextEditingController _searchController = TextEditingController();

  Timer? _typingTimer;

  final bool _sending = false;

  bool _readSyncScheduled = false;

  bool _readSyncInFlight = false;

  bool _readSyncAgain = false;

  bool _blocked = false;

  bool _searching = false;
  bool _linkPreviewDisabled = false;

  String _search = '';

  ChatMessage? _replyingTo;
  //===============================
  // PENDING DIRECT UPLOADS
  //===============================

  final List<_PendingDirectUpload> _pendingUploads = <_PendingDirectUpload>[];

  int _pendingUploadCounter = 0;

  //===============================
  // CONVERSATION ID
  //===============================

  String get _conversationId =>
      _chatService.getConversationId(widget.otherUserId);

  //===============================
  // INIT
  //===============================

  @override
  void initState() {
    super.initState();
    _messagesStream = _chatService.getMessages(widget.otherUserId);

    _activityStream = _privacyService.mutualActivityStream(widget.otherUserId);
    final String uid = _auth.currentUser?.uid ?? '';

    _outgoingCallHistoryStream = _firestore
        .collection('calls')
        .where('callerId', isEqualTo: uid)
        .snapshots();

    _incomingCallHistoryStream = _firestore
        .collection('calls')
        .where('calleeId', isEqualTo: uid)
        .snapshots();
    if (widget.startCallOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _startCall();
        }
      });
    }

    _initialize();

    _searchController.addListener(() {
      if (!mounted) {
        return;
      }

      setState(() {
        _search = _searchController.text.trim().toLowerCase();
      });
    });
  }

  //===============================
  // INITIALIZE
  //===============================

  Future<void> _initialize() async {
    // Run privacy setup in background.
    unawaited(_privacyService.ensureSettingsExist().catchError((_) {}));
    //===============================
    // ENSURE CONVERSATION
    //===============================

    unawaited(
      _chatService
          .ensureConversationExists(widget.otherUserId)
          .catchError((_) {}),
    );

    // Run presence update in background.
    unawaited(_presenceService.setOnline().catchError((_) {}));

    // Check blocked status without delaying the UI.
    unawaited(_checkBlocked());

    // Delivery/read updates also run in background.
    unawaited(_markInitialMessageStatus());
  }
  //===============================
  // INITIAL MESSAGE STATUS
  //===============================

  Future<void> _markInitialMessageStatus() async {
    try {
      await Future.wait(<Future<void>>[
        _chatService.markConversationDelivered(widget.otherUserId),

        _chatService.markConversationRead(widget.otherUserId),
      ]);
    } catch (_) {}
  }

  //===============================
  // KEEP VISIBLE MESSAGES READ
  //===============================

  void _scheduleReadStatusSync(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final String uid = _auth.currentUser?.uid ?? '';

    if (!mounted || uid.isEmpty) {
      return;
    }

    final bool hasUnreadIncoming = snapshot.docs.any((document) {
      final Map<String, dynamic> data = document.data();
      final String senderId = (data['senderId'] ?? data['senderUid'] ?? '')
          .toString();

      if (senderId.isEmpty || senderId == uid) {
        return false;
      }

      final List<dynamic> readBy = data['readBy'] is List
          ? data['readBy'] as List<dynamic>
          : data['seenBy'] is List
          ? data['seenBy'] as List<dynamic>
          : const <dynamic>[];

      return data['isRead'] != true &&
          !readBy.map((item) => item.toString()).contains(uid);
    });

    if (!hasUnreadIncoming) {
      return;
    }

    if (_readSyncInFlight) {
      _readSyncAgain = true;
      return;
    }

    if (_readSyncScheduled) {
      return;
    }

    _readSyncScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _readSyncScheduled = false;

      if (!mounted) {
        return;
      }

      unawaited(_synchronizeReadStatus());
    });
  }

  Future<void> _synchronizeReadStatus() async {
    if (_readSyncInFlight) {
      _readSyncAgain = true;
      return;
    }

    _readSyncInFlight = true;

    try {
      await _chatService.markConversationRead(widget.otherUserId);
    } catch (_) {
      // A later Firestore snapshot or a reopened chat will retry safely.
    } finally {
      _readSyncInFlight = false;

      if (_readSyncAgain && mounted) {
        _readSyncAgain = false;
        unawaited(_synchronizeReadStatus());
      }
    }
  }
  //===============================
  // CHECK BLOCKED
  //===============================

  Future<void> _checkBlocked() async {
    bool blocked = false;

    try {
      blocked = await _profileService.isBlocked(widget.otherUserId);
    } catch (_) {
      blocked = false;
    }

    if (!mounted) {
      return;
    }

    if (_blocked == blocked) {
      return;
    }

    setState(() {
      _blocked = blocked;
    });
  }
  //===============================
  // SEND TEXT
  //===============================

  Future<void> _sendMessage() async {
    final String text = _messageController.text.trim();

    if (text.isEmpty || _blocked) {
      return;
    }
    final bool linkPreviewDisabled = _linkPreviewDisabled;

    final String replyToMessageId = _replyingTo?.messageId ?? '';

    final String replyToSenderId = _replyingTo?.senderId ?? '';

    final String replyToSenderName = _replyingTo == null
        ? ''
        : _replyingTo!.senderId == _auth.currentUser?.uid
        ? 'You'
        : widget.otherName;

    final String replyToText = _replyingTo?.previewText ?? '';

    final String replyToType = _replyingTo?.type ?? '';

    //===============================
    // CLEAR UI IMMEDIATELY
    //===============================

    _messageController.clear();
    setState(() {
      _linkPreviewDisabled = false;
    });

    _clearReply();

    //===============================
    // STOP TYPING IMMEDIATELY
    //===============================

    unawaited(
      _presenceService
          .setTyping(conversationId: _conversationId, typing: false)
          .catchError((_) {}),
    );

    //===============================
    // SEND IN BACKGROUND
    //===============================

    unawaited(
      _sendDirectTextInBackground(
        linkPreviewDisabled: linkPreviewDisabled,

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
  // SEND DIRECT TEXT IN BACKGROUND
  //===============================

  Future<void> _sendDirectTextInBackground({
    required String text,
    required String replyToMessageId,
    required String replyToSenderId,
    required String replyToSenderName,
    required String replyToText,
    required String replyToType,
    required bool linkPreviewDisabled,
  }) async {
    try {
      await _chatService.sendMessage(
        receiverId: widget.otherUserId,
        linkPreviewDisabled: linkPreviewDisabled,

        text: text,

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

  Future<void> _sendSticker(String sticker) async {
    if (_blocked) {
      return;
    }

    try {
      await _chatService.sendSticker(
        receiverId: widget.otherUserId,
        sticker: sticker,
      );
    } catch (error) {
      _showError(error);
    }
  }

  //===============================
  // CAMERA
  //===============================

  Future<void> _pickCamera() async {
    if (_blocked) {
      return;
    }

    final XFile? file = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
    );

    if (file == null) {
      return;
    }

    await _uploadAndSend(path: file.path, type: 'image');
  }

  //===============================
  // GALLERY
  //===============================

  Future<void> _pickGallery() async {
    if (_blocked) {
      return;
    }

    final XFile? file = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
    );

    if (file == null) {
      return;
    }

    await _uploadAndSend(path: file.path, type: 'image');
  }

  //===============================
  // VIDEO
  //===============================

  Future<void> _pickVideo() async {
    if (_blocked) {
      return;
    }

    final XFile? file = await _imagePicker.pickVideo(
      source: ImageSource.gallery,
    );

    if (file == null) {
      return;
    }

    await _uploadAndSend(path: file.path, type: 'video');
  }

  //===============================
  // DOCUMENT
  //===============================

  Future<void> _pickDocument() async {
    if (_blocked) {
      return;
    }

    final PlatformFile? file = await FilePicker.pickFile(type: FileType.any);

    if (file == null) {
      return;
    }

    final String? path = file.path;

    if (path == null || path.trim().isEmpty) {
      return;
    }

    await _uploadAndSend(path: path, type: 'document', fileName: file.name);
  }
  //===============================
  // VOICE
  //===============================

  Future<void> _sendVoice(String path, int durationMs) async {
    await _uploadAndSend(path: path, type: 'voice', durationMs: durationMs);
  }

  //===============================
  // UPLOAD AND SEND
  //===============================

  Future<void> _uploadAndSend({
    required String path,
    required String type,
    String fileName = '',
    int durationMs = 0,
  }) async {
    if (_blocked) {
      return;
    }

    final ChatMessage? reply = _replyingTo;

    final String pendingId =
        '${DateTime.now().microsecondsSinceEpoch}_${_pendingUploadCounter++}';

    final _PendingDirectUpload pending = _PendingDirectUpload(
      id: pendingId,

      path: path,

      type: type,

      fileName: fileName,

      durationMs: durationMs,

      replyText: reply?.previewText ?? '',

      replySenderName: reply == null
          ? ''
          : reply.senderId == _auth.currentUser?.uid
          ? 'You'
          : widget.otherName,
    );

    //===============================
    // SHOW MESSAGE IMMEDIATELY
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

    unawaited(_performDirectUpload(pending: pending, reply: reply));
  }
  //===============================
  // PERFORM DIRECT UPLOAD
  //===============================

  Future<void> _performDirectUpload({
    required _PendingDirectUpload pending,
    required ChatMessage? reply,
  }) async {
    try {
      final String url = await _mediaService.uploadDirectChatFile(
        otherUid: widget.otherUserId,

        filePath: pending.path,
      );

      await _chatService.sendMediaMessage(
        receiverId: widget.otherUserId,

        mediaUrl: url,

        mediaType: pending.type,

        fileName: pending.fileName,

        durationMs: pending.durationMs,

        replyToMessageId: reply?.messageId ?? '',

        replyToSenderId: reply?.senderId ?? '',

        replyToSenderName: reply == null
            ? ''
            : reply.senderId == _auth.currentUser?.uid
            ? 'You'
            : widget.otherName,

        replyToText: reply?.previewText ?? '',

        replyToType: reply?.type ?? '',
      );

      if (!mounted) {
        return;
      }

      //===============================
      // REMOVE TEMPORARY MESSAGE
      //===============================

      setState(() {
        _pendingUploads.removeWhere(
          (_PendingDirectUpload item) => item.id == pending.id,
        );
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _pendingUploads.removeWhere(
          (_PendingDirectUpload item) => item.id == pending.id,
        );
      });

      _showError(error);
    }
  }
  //===============================
  // TYPING
  //===============================

  void _typingChanged(String value) {
    _typingTimer?.cancel();

    if (value.trim().isEmpty) {
      _presenceService.setTyping(
        conversationId: _conversationId,
        typing: false,
      );

      return;
    }

    _presenceService.setTyping(conversationId: _conversationId, typing: true);

    _typingTimer = Timer(const Duration(seconds: 3), () {
      _presenceService.setTyping(
        conversationId: _conversationId,
        typing: false,
      );
    });
  }

  //===============================
  // RECORDING STATUS
  //===============================

  void _recordingChanged(bool recording) {
    _presenceService.setRecording(
      conversationId: _conversationId,
      recording: recording,
    );
  }
  //===============================
  // MESSAGE ACTIONS
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
        await _chatService.toggleReaction(
          otherUserId: widget.otherUserId,

          messageId: message.messageId,

          emoji: result.emoji,
        );
        break;

      case 'reply':
        _replyTo(message);
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
          await _chatService.deleteMessageForMe(
            otherUserId: widget.otherUserId,

            messageId: message.messageId,
          );
        } else if (mode == 'everyone') {
          await _chatService.deleteMessageForEveryone(
            otherUserId: widget.otherUserId,

            messageId: message.messageId,
          );
        }

        break;
    }
  }

  //===============================
  // REPLY
  //===============================

  void _replyTo(ChatMessage message) {
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
  // OPEN STORY
  //===============================

  Future<void> _openStory(String storyId) async {
    if (storyId.trim().isEmpty) {
      return;
    }

    final NubifyStory? story = await _storyService.getStory(storyId);

    if (!mounted) {
      return;
    }

    if (story == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This story has expired or was removed.')),
      );

      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StoryViewerScreen(stories: <NubifyStory>[story]),
      ),
    );
  }

  //===============================
  // OPEN PROFILE
  //===============================

  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfileScreen(uid: widget.otherUserId)),
    );
  }

  //===============================
  // COPY PROFILE LINK
  //===============================

  Future<void> _copyProfileLink() async {
    final String link =
        'https://nubify.app/user/${widget.otherUsername.trim().isNotEmpty ? widget.otherUsername : widget.otherUserId}';

    await Clipboard.setData(ClipboardData(text: link));

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Profile link copied.')));
  }

  //===============================
  // REPORT USER
  //===============================

  Future<void> _reportUser() async {
    try {
      await showReportUserDialog(
        context: context,

        targetUid: widget.otherUserId,
      );
    } catch (error) {
      _showError(error);
    }
  }
  //===============================
  // BLOCK USER
  //===============================

  Future<void> _blockOrUnblock() async {
    if (_blocked) {
      try {
        await _profileService.unblockUser(widget.otherUserId);

        if (mounted) {
          setState(() {
            _blocked = false;
          });
        }
      } catch (error) {
        _showError(error);
      }

      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Block ${widget.otherName}?'),
          content: const Text(
            'They will no longer be able to interact with you normally through direct messaging.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Block'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _profileService.blockUser(widget.otherUserId);

      if (mounted) {
        setState(() {
          _blocked = true;
        });
      }
    } catch (error) {
      _showError(error);
    }
  }

  //===============================
  // MUTE CONVERSATION
  //===============================

  Future<void>
  // Kept for the conversation-menu mute action when it is re-enabled.
  // ignore: unused_element
  _toggleMute() async {
    final String? uid = _auth.currentUser?.uid;

    if (uid == null) {
      return;
    }

    final DocumentReference<Map<String, dynamic>> reference = _firestore
        .collection('users')
        .doc(uid)
        .collection('mutedConversations')
        .doc(_conversationId);

    final snapshot = await reference.get();

    if (snapshot.exists) {
      await reference.delete();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Conversation unmuted.')));
      }
    } else {
      await reference.set(<String, dynamic>{
        'conversationId': _conversationId,
        'mutedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Conversation muted.')));
      }
    }
  }

  //===============================
  // MENU
  //===============================

  Future<void> _handleMenu(String value) async {
    switch (value) {
      case 'profile':
        _openProfile();
        break;

      case 'media':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatMediaScreen(
              otherUserId: widget.otherUserId,
              otherName: widget.otherName,
            ),
          ),
        );
        break;

      case 'search':
        setState(() {
          _searching = true;
        });
        break;

      case 'copy':
        await _copyProfileLink();
        break;

      case 'report':
        await _reportUser();
        break;

      case 'block':
        await _blockOrUnblock();
        break;
    }
  }

  //===============================
  // CALL
  //===============================

  void _startCall() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => AudioCallScreen(
          otherUserId: widget.otherUserId,

          otherName: widget.otherName,

          otherPhotoUrl: widget.otherPhotoUrl,
        ),
      ),
    );
  }

  //===============================
  // CATALOGUE
  //===============================

  void _openCatalogue() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatCatalogueScreen(
          sellerId: widget.otherUserId,
          sellerName: widget.otherName,
          sellerUsername: widget.otherUsername,
          sellerPhotoUrl: widget.otherPhotoUrl,
        ),
      ),
    );
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
  // PRESENCE TEXT
  //===============================

  Widget _buildPresence() {
    final _ConversationPalette palette = _ConversationPalette.of(context);

    return StreamBuilder<bool>(
      stream: _privacyService.mutualActivityStream(widget.otherUserId),
      builder: (BuildContext context, AsyncSnapshot<bool> privacySnapshot) {
        final bool allowed = privacySnapshot.data == true;

        if (!allowed) {
          return Text(
            widget.otherUsername.trim().isNotEmpty
                ? '@${widget.otherUsername}'
                : 'Nubify',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: palette.muted, fontSize: 11),
          );
        }

        return StreamBuilder<bool>(
          stream: _presenceService.recordingStream(
            conversationId: _conversationId,
            otherUid: widget.otherUserId,
          ),
          builder:
              (BuildContext context, AsyncSnapshot<bool> recordingSnapshot) {
                if (recordingSnapshot.data == true) {
                  return const Text(
                    'recording audio...',
                    style: TextStyle(color: _blue, fontSize: 11),
                  );
                }

                return StreamBuilder<bool>(
                  stream: _presenceService.typingStream(
                    conversationId: _conversationId,
                    otherUid: widget.otherUserId,
                  ),
                  builder:
                      (
                        BuildContext context,
                        AsyncSnapshot<bool> typingSnapshot,
                      ) {
                        if (typingSnapshot.data == true) {
                          return const Text(
                            'typing...',
                            style: TextStyle(color: _blue, fontSize: 11),
                          );
                        }

                        return StreamBuilder<
                          DocumentSnapshot<Map<String, dynamic>>
                        >(
                          stream: _presenceService.presenceStream(
                            widget.otherUserId,
                          ),
                          builder:
                              (
                                BuildContext context,
                                AsyncSnapshot<
                                  DocumentSnapshot<Map<String, dynamic>>
                                >
                                presenceSnapshot,
                              ) {
                                final Map<String, dynamic> presence =
                                    presenceSnapshot.data?.data() ??
                                    <String, dynamic>{};

                                final bool rawOnline =
                                    presence['online'] == true;

                                final Timestamp? updatedAt =
                                    presence['updatedAt'] is Timestamp
                                    ? presence['updatedAt'] as Timestamp
                                    : null;

                                bool online = rawOnline;

                                if (updatedAt != null) {
                                  final int seconds = DateTime.now()
                                      .difference(updatedAt.toDate().toLocal())
                                      .inSeconds;

                                  if (seconds > 100) {
                                    online = false;
                                  }
                                }

                                if (online) {
                                  return const Row(
                                    children: <Widget>[
                                      DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: NubifyChatStyle.online,
                                          shape: BoxShape.circle,
                                        ),
                                        child: SizedBox(width: 7, height: 7),
                                      ),
                                      SizedBox(width: 5),
                                      Text(
                                        'online',
                                        style: TextStyle(
                                          color: NubifyChatStyle.online,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  );
                                }

                                final Timestamp? lastSeen =
                                    presence['lastSeenAt'] is Timestamp
                                    ? presence['lastSeenAt'] as Timestamp
                                    : null;

                                if (lastSeen != null) {
                                  final DateTime time = lastSeen
                                      .toDate()
                                      .toLocal();

                                  final TimeOfDay dayTime =
                                      TimeOfDay.fromDateTime(time);

                                  return Text(
                                    'last seen ${dayTime.format(context)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: palette.muted,
                                      fontSize: 10,
                                    ),
                                  );
                                }

                                return Text(
                                  widget.otherUsername.trim().isNotEmpty
                                      ? '@${widget.otherUsername}'
                                      : 'offline',
                                  style: TextStyle(
                                    color: palette.muted,
                                    fontSize: 11,
                                  ),
                                );
                              },
                        );
                      },
                );
              },
        );
      },
    );
  }

  //===============================
  // CATALOGUE BUTTON
  //===============================

  Widget _catalogueButton() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('marketplaceProducts')
          .where('sellerId', isEqualTo: widget.otherUserId)
          .where('status', isEqualTo: 'available')
          .where('publicVisible', isEqualTo: true)
          .limit(1)
          .snapshots(),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
          ) {
            if ((snapshot.data?.docs.isNotEmpty ?? false) == false) {
              return const SizedBox.shrink();
            }

            return IconButton(
              tooltip: 'Seller Marketplace listings',
              onPressed: _openCatalogue,
              icon: const MarketplaceBrandIcon(
                size: 25,
              ),
            );
          },
    );
  }
  //===============================
  // OPEN PROFILE PHOTO
  //===============================

  // Kept for the full-size avatar action when it is re-enabled.
  // ignore: unused_element
  void _openProfilePhoto() {
    Navigator.push(
      context,

      MaterialPageRoute<void>(
        builder: (_) => FullPhotoViewer(
          title: widget.otherName,

          photoUrl: widget.otherPhotoUrl,
        ),
      ),
    );
  }
  //===============================
  // NORMAL APP BAR
  //===============================

  PreferredSizeWidget _normalAppBar() {
    final _ConversationPalette palette = _ConversationPalette.of(context);

    return AppBar(
      backgroundColor: palette.surface,
      foregroundColor: palette.text,
      surfaceTintColor: Colors.transparent,
      titleSpacing: 0,
      shape: Border(
        bottom: BorderSide(color: palette.divider.withValues(alpha: 0.45)),
      ),
      title: InkWell(
        onTap: _openProfile,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
          child: Row(
            children: <Widget>[
              GestureDetector(
                onTap: _openProfile,

                child: NubifyChatAvatar(
                  photoUrl: widget.otherPhotoUrl,
                  radius: 17,
                  ring: true,
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      widget.otherName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    _buildPresence(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        _catalogueButton(),

        IconButton(
          tooltip: 'Audio call',
          onPressed: _startCall,
          style: IconButton.styleFrom(
            backgroundColor: NubifyChatStyle.royal.withValues(alpha: 0.12),
            foregroundColor: NubifyChatStyle.royal,
          ),
          icon: const Icon(Icons.call_rounded, size: 21),
        ),

        PopupMenuButton<String>(
          onSelected: _handleMenu,
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            const PopupMenuItem<String>(
              value: 'profile',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.person_outline_rounded),
                title: Text('View profile'),
              ),
            ),

            const PopupMenuItem<String>(
              value: 'media',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.perm_media_outlined),
                title: Text('Media, links & docs'),
              ),
            ),

            const PopupMenuItem<String>(
              value: 'search',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.search_rounded),
                title: Text('Search conversation'),
              ),
            ),

            const PopupMenuItem<String>(
              value: 'copy',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.link_rounded),
                title: Text('Copy profile link'),
              ),
            ),

            const PopupMenuDivider(),

            const PopupMenuItem<String>(
              value: 'report',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.flag_outlined, color: Colors.orange),
                title: Text('Report user'),
              ),
            ),

            PopupMenuItem<String>(
              value: 'block',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  _blocked ? Icons.lock_open_rounded : Icons.block_rounded,
                  color: Colors.redAccent,
                ),
                title: Text(_blocked ? 'Unblock user' : 'Block user'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  //===============================
  // SEARCH APP BAR
  //===============================

  PreferredSizeWidget _searchAppBar() {
    final _ConversationPalette palette = _ConversationPalette.of(context);

    return AppBar(
      backgroundColor: palette.surface,
      foregroundColor: palette.text,
      leading: IconButton(
        onPressed: () {
          setState(() {
            _searching = false;

            _searchController.clear();
          });
        },
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      title: TextField(
        controller: _searchController,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Search messages...',
          border: InputBorder.none,
        ),
      ),
    );
  }

  //===============================
  // REPLY BAR
  //===============================

  Widget _replyBar() {
    final ChatMessage? message = _replyingTo;

    if (message == null) {
      return const SizedBox.shrink();
    }

    final String sender = message.senderId == _auth.currentUser?.uid
        ? 'You'
        : widget.otherName;

    final _ConversationPalette palette = _ConversationPalette.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 6, 8, 0),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: NubifyChatStyle.composerCard(context),
      child: Row(
        children: <Widget>[
          Container(
            width: 4,
            height: 38,
            decoration: BoxDecoration(
              gradient: NubifyChatStyle.brand,
              borderRadius: BorderRadius.circular(4),
            ),
          ),

          const SizedBox(width: 9),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  sender,
                  style: const TextStyle(
                    color: NubifyChatStyle.royal,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  message.previewText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.muted, fontSize: 11),
                ),
              ],
            ),
          ),

          IconButton(
            onPressed: _clearReply,
            icon: Icon(Icons.close_rounded, color: palette.muted),
          ),
        ],
      ),
    );
  }

  //===============================
  // BLOCKED BAR
  //===============================

  Widget _blockedBar() {
    final _ConversationPalette palette = _ConversationPalette.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      color: palette.surface,
      child: Row(
        children: <Widget>[
          const Icon(Icons.block_rounded, color: Colors.redAccent),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              '${widget.otherName} is blocked.',
              style: TextStyle(color: palette.text),
            ),
          ),

          TextButton(onPressed: _blockOrUnblock, child: const Text('Unblock')),
        ],
      ),
    );
  }
  //===============================
  // PENDING DIRECT UPLOAD TILE
  //===============================

  Widget _pendingUploadTile(_PendingDirectUpload pending) {
    Widget content;

    //===============================
    // IMAGE
    //===============================

    if (pending.type == 'image') {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(12),

        child: Image.file(
          File(pending.path),

          width: 220,

          height: 220,

          fit: BoxFit.cover,

          errorBuilder: (_, _, _) => const SizedBox(
            width: 220,

            height: 130,

            child: Center(
              child: Icon(
                Icons.image_outlined,

                size: 40,

                color: Colors.white70,
              ),
            ),
          ),
        ),
      );
    }
    //===============================
    // VIDEO
    //===============================
    else if (pending.type == 'video') {
      content = const SizedBox(
        width: 220,

        height: 125,

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,

          children: <Widget>[
            Icon(Icons.play_circle_fill_rounded, size: 47, color: Colors.white),

            SizedBox(height: 7),

            Text(
              'Sending video...',

              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      );
    }
    //===============================
    // VOICE
    //===============================
    else if (pending.type == 'voice') {
      final int totalSeconds = (pending.durationMs / 1000).round();

      final int minutes = totalSeconds ~/ 60;

      final int seconds = totalSeconds % 60;

      final String duration = '$minutes:${seconds.toString().padLeft(2, '0')}';

      content = SizedBox(
        width: 220,

        child: Row(
          children: <Widget>[
            const CircleAvatar(
              radius: 20,

              backgroundColor: Colors.white24,

              child: Icon(
                Icons.play_arrow_rounded,

                color: Colors.white,

                size: 25,
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: <Widget>[
                  const Text(
                    'Sending voice message...',

                    style: TextStyle(
                      color: Colors.white,

                      fontSize: 12,

                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    duration,

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
    // DOCUMENT
    //===============================
    else {
      content = SizedBox(
        width: 220,

        child: Row(
          children: <Widget>[
            const Icon(
              Icons.description_rounded,

              color: Colors.white,

              size: 34,
            ),

            const SizedBox(width: 10),

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

                    style: const TextStyle(
                      color: Colors.white,

                      fontSize: 12,

                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 3),

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
      padding: const EdgeInsets.only(left: 65, right: 9, bottom: 5),

      child: Align(
        alignment: Alignment.centerRight,

        child: Container(
          constraints: const BoxConstraints(maxWidth: 275),

          padding: const EdgeInsets.all(9),

          decoration: NubifyChatStyle.bubble(context, mine: true),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,

            mainAxisSize: MainAxisSize.min,

            children: <Widget>[
              //===============================
              // REPLY PREVIEW
              //===============================

              if (pending.replyText.trim().isNotEmpty)
                Container(
                  width: double.infinity,

                  margin: const EdgeInsets.only(bottom: 7),

                  padding: const EdgeInsets.all(7),

                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.15),

                    borderRadius: BorderRadius.circular(8),
                  ),

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: <Widget>[
                      Text(
                        pending.replySenderName.trim().isNotEmpty
                            ? pending.replySenderName
                            : 'Reply',

                        style: const TextStyle(
                          color: Colors.white,

                          fontWeight: FontWeight.w700,

                          fontSize: 10,
                        ),
                      ),

                      Text(
                        pending.replyText,

                        maxLines: 1,

                        overflow: TextOverflow.ellipsis,

                        style: const TextStyle(
                          color: Colors.white70,

                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),

              content,

              const SizedBox(height: 6),

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
  // SAME DATE
  //===============================

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  //===================================================
  // MESSAGES AND CALL HISTORY
  //===================================================

  Widget _messageList(bool canShowReadReceipt) {
    final String currentUid = _auth.currentUser?.uid ?? '';
    final _ConversationPalette palette = _ConversationPalette.of(context);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _messagesStream,
      builder: (context, messageSnapshot) {
        final QuerySnapshot<Map<String, dynamic>>? messageData =
            messageSnapshot.data;

        if (messageData != null) {
          _scheduleReadStatusSync(messageData);
        }

        //===================================================
        // OUTGOING CALL STREAM
        //===================================================

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _outgoingCallHistoryStream,
          builder: (context, outgoingSnapshot) {
            //===================================================
            // INCOMING CALL STREAM
            //===================================================

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _incomingCallHistoryStream,
              builder: (context, incomingSnapshot) {
                final List<_DirectTimelineItem> allItems =
                    <_DirectTimelineItem>[];

                //===================================================
                // EXISTING CHAT MESSAGES
                //===================================================

                final messageDocs =
                    messageSnapshot.data?.docs ??
                    <QueryDocumentSnapshot<Map<String, dynamic>>>[];

                for (final document in messageDocs) {
                  final ChatMessage message = ChatMessage.fromDocument(
                    document,
                  );

                  if (message.hiddenFor.contains(currentUid)) {
                    continue;
                  }

                  allItems.add(_DirectTimelineItem.fromMessage(message));
                }

                //===================================================
                // COMBINE CALL RECORDS WITHOUT DUPLICATES
                //===================================================

                final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>>
                uniqueCalls = {};

                final callDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[
                  ...?outgoingSnapshot.data?.docs,
                  ...?incomingSnapshot.data?.docs,
                ];

                for (final document in callDocs) {
                  uniqueCalls[document.id] = document;
                }

                //===================================================
                // CALLS BETWEEN THE TWO USERS ONLY
                //===================================================

                for (final document in uniqueCalls.values) {
                  final Map<String, dynamic> call = document.data();

                  final String callerId = (call['callerId'] ?? '').toString();

                  final String calleeId = (call['calleeId'] ?? '').toString();

                  final bool belongsToConversation =
                      (callerId == currentUid &&
                          calleeId == widget.otherUserId) ||
                      (calleeId == currentUid &&
                          callerId == widget.otherUserId);

                  if (!belongsToConversation) {
                    continue;
                  }

                  if (!NubifyCallDisplay.isFinished(call)) {
                    continue;
                  }

                  allItems.add(
                    _DirectTimelineItem.fromCall(
                      callId: document.id,
                      call: call,
                    ),
                  );
                }

                //===================================================
                // SORT THE COMBINED TIMELINE
                //===================================================

                allItems.sort((a, b) => b.date.compareTo(a.date));

                //===================================================
                // SEARCH MESSAGES AND CALLS
                //===================================================

                final List<_DirectTimelineItem> items = _search.isEmpty
                    ? allItems
                    : allItems.where((item) {
                        final ChatMessage? message = item.message;

                        if (message != null) {
                          return message.text.toLowerCase().contains(_search) ||
                              message.fileName.toLowerCase().contains(
                                _search,
                              ) ||
                              message.postCaption.toLowerCase().contains(
                                _search,
                              ) ||
                              message.productName.toLowerCase().contains(
                                _search,
                              );
                        }

                        final Map<String, dynamic>? call = item.call;

                        if (call == null) {
                          return false;
                        }

                        final String label = NubifyCallDisplay.label(
                          call,
                          currentUid,
                        );

                        return label.toLowerCase().contains(_search);
                      }).toList();

                //===================================================
                // PRESERVE PENDING MEDIA UPLOADS
                //===================================================

                final List<_PendingDirectUpload> visiblePending =
                    _search.isEmpty
                    ? _pendingUploads
                    : const <_PendingDirectUpload>[];

                if (items.isEmpty && visiblePending.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        NubifyChatEmptyIcon(
                          icon: _search.isNotEmpty
                              ? Icons.search_off_rounded
                              : Icons.waving_hand_rounded,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _search.isNotEmpty
                              ? 'No matching messages.'
                              : 'Say hi to ${widget.otherName}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: palette.text,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (_search.isEmpty) ...<Widget>[
                          const SizedBox(height: 4),
                          Text(
                            'Start the conversation.',
                            style: TextStyle(color: palette.muted),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                //===================================================
                // DISPLAY CHAT TIMELINE
                //===================================================

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(9, 12, 9, 14),
                  itemCount: visiblePending.length + items.length,
                  itemBuilder: (context, index) {
                    //===================================================
                    // PENDING MEDIA UPLOADS
                    //===================================================

                    if (index < visiblePending.length) {
                      return _pendingUploadTile(visiblePending[index]);
                    }

                    final int itemIndex = index - visiblePending.length;

                    final _DirectTimelineItem item = items[itemIndex];

                    final DateTime date = item.date;

                    //===================================================
                    // DATE SEPARATORS
                    //===================================================

                    final bool showDate =
                        itemIndex == items.length - 1 ||
                        !_sameDay(date, items[itemIndex + 1].date);

                    //===================================================
                    // CALL BUBBLE
                    //===================================================

                    if (item.call != null) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          if (showDate) ChatDateSeparator(date: date),

                          ChatCallEventBubble(
                            call: item.call!,
                            viewerId: currentUid,
                            onCall: _startCall,
                          ),
                        ],
                      );
                    }

                    //===================================================
                    // EXISTING MESSAGE BUBBLE
                    //===================================================

                    final ChatMessage message = item.message!;

                    final bool mine = message.senderId == currentUid;

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        if (showDate) ChatDateSeparator(date: date),

                        ChatMessageBubble(
                          message: message,
                          mine: mine,
                          otherUserId: widget.otherUserId,
                          canShowReadReceipt: canShowReadReceipt,

                          onOpenStory: message.storyId.trim().isNotEmpty
                              ? () {
                                  _openStory(message.storyId);
                                }
                              : null,

                          onOpenPost: message.postId.trim().isEmpty
                              ? null
                              : () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder: (_) => CommentsScreen(
                                        postId: message.postId,
                                      ),
                                    ),
                                  );
                                },

                          onOpenProduct: () {
                            _openCatalogue();
                          },

                          onLongPress: () {
                            _messageActions(message, mine);
                          },
                        ),
                      ],
                    );
                  },
                );
              },
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
    final _ConversationPalette palette = _ConversationPalette.of(context);

    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: _searching ? _searchAppBar() : _normalAppBar(),
      body: NubifyChatBackground(
        child: SafeArea(
        child: Column(
          children: <Widget>[
            //===============================
            // MESSAGES
            //===============================

            Expanded(
              child: StreamBuilder<bool>(
                stream: _activityStream,
                builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
                  return _messageList(snapshot.data == true);
                },
              ),
            ),

            //===============================
            // REPLY
            //===============================
            _replyBar(),

            //===============================
            // BLOCKED / COMPOSER
            //===============================
            if (_blocked)
              _blockedBar()
            else
              ChatComposer(
                onLinkPreviewSuppressedChanged: (bool value) {
                  setState(() {
                    _linkPreviewDisabled = value;
                  });
                },
                controller: _messageController,
                sending: _sending,
                enabled: !_blocked,
                onSend: _sendMessage,
                onCamera: _pickCamera,
                onGallery: _pickGallery,
                onVideo: _pickVideo,
                onDocument: _pickDocument,
                onVoiceRecorded: _sendVoice,
                onStickerSelected: _sendSticker,
                onTextChanged: _typingChanged,
                onRecordingChanged: _recordingChanged,
              ),
          ],
        ),
        ),
      ),
    );
  }

  //===============================
  // DISPOSE
  //===============================

  @override
  void dispose() {
    _typingTimer?.cancel();

    _presenceService.setTyping(conversationId: _conversationId, typing: false);

    _presenceService.setRecording(
      conversationId: _conversationId,
      recording: false,
    );

    _messageController.dispose();

    _searchController.dispose();

    super.dispose();
  }
}
//===============================
// PENDING DIRECT UPLOAD
//===============================

class _PendingDirectUpload {
  const _PendingDirectUpload({
    required this.id,
    required this.path,
    required this.type,
    required this.fileName,
    required this.durationMs,
    required this.replyText,
    required this.replySenderName,
  });

  final String id;

  final String path;

  final String type;

  final String fileName;

  final int durationMs;

  final String replyText;

  final String replySenderName;
}
//===================================================
// DIRECT CONVERSATION TIMELINE ITEM
//===================================================

class _DirectTimelineItem {
  _DirectTimelineItem.fromMessage(ChatMessage value)
    : message = value,
      call = null,
      callId = '',
      date = value.createdAt?.toDate().toLocal() ?? DateTime.now();

  _DirectTimelineItem.fromCall({
    required this.callId,
    required Map<String, dynamic> call,
  }) : message = null,
       call = call,
       date = NubifyCallDisplay.time(call);

  final ChatMessage? message;
  final Map<String, dynamic>? call;
  final String callId;
  final DateTime date;
}
