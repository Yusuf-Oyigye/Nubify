import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../models/post.dart';
import '../models/story.dart';
import '../services/story_service.dart';
import '../widgets/post_media_carousel.dart';
import '../widgets/shared_post_story_card.dart';
import 'comment_screen.dart';
import 'chat_forward_screen.dart';
import '../widgets/draggable_story_tags.dart';
import '../widgets/story_link_preview_overlay.dart';
import '../widgets/story_drawing_canvas.dart';
import '../services/nubify_link_router.dart';
import '../utils/link_detector.dart';

//===================================================
// STORY VIEWER SCREEN
//===================================================

class StoryViewerScreen extends StatefulWidget {
  const StoryViewerScreen({
    super.key,
    required this.stories,
    this.initialIndex = 0,
    this.allowExpiredStories = false,
  });

  final List<NubifyStory> stories;
  final int initialIndex;
  final bool allowExpiredStories;

  @override
  State<StoryViewerScreen> createState() {
    return _StoryViewerScreenState();
  }
}

//===================================================
// STORY VIEWER STATE
//===================================================
class _StoryViewerScreenState extends State<StoryViewerScreen>
    with WidgetsBindingObserver {
  bool _resumeAfterExternalLink = false;
  //===================================================
  // FIREBASE
  //===================================================

  final FirebaseAuth _auth = FirebaseAuth.instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  //===================================================
  // SERVICE
  //===================================================

  final StoryService _storyService = StoryService();

  //===================================================
  // STORIES
  //===================================================

  late List<NubifyStory> _stories;

  int _currentIndex = 0;

  int _playbackRevision = 0;

  //===================================================
  // PROGRESS
  //===================================================

  Timer? _progressTimer;

  Timer? _advanceTimer;

  Timer? _timeRefreshTimer;

  double _progress = 0;

  bool _progressPaused = false;
  bool _mediaBuffering = false;
  bool _pausedBeforeOverlay = false;

  bool _centerHoldActive = false;

  bool _pausedBeforeCenterHold = false;

  bool _voiceCompletionHandled = false;

  bool _videoCompletionHandled = false;
  //============================
  // NETWORK CONTENT READY
  //============================

  bool _contentReadyHandled = false;
  //===================================================
  // COUNTS
  //===================================================

  bool _liked = false;

  bool _likeLoading = false;

  int _viewCount = 0;

  int _likeCount = 0;

  int _replyCount = 0;

  int _shareCount = 0;

  // Updated by retained reshare flows that can be re-enabled from the viewer.
  // ignore: unused_field
  int _reshareCount = 0;

  //===================================================
  // REPLY
  //===================================================

  final TextEditingController _replyController = TextEditingController();

  final FocusNode _replyFocusNode = FocusNode();

  bool _sendingReply = false;

  //===================================================
  // OWNER SEEN
  //===================================================

  final Set<String> _ownerSeenStoryIds = <String>{};

  //===================================================
  // COLOR
  //===================================================

  static const Color _nubifyBlue = Color(0xFF29B6F6);

  //===================================================
  // INIT
  //===================================================

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _stories = widget.stories.where((NubifyStory story) {
      return widget.allowExpiredStories || !story.isExpired;
    }).toList();
    if (_stories.isNotEmpty) {
      _currentIndex = widget.initialIndex.clamp(0, _stories.length - 1).toInt();

      _prepareCurrentStory();
    }

    _replyFocusNode.addListener(_handleReplyFocus);

    _timeRefreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      _removeExpiredStories();

      if (mounted) {
        setState(() {});
      }
    });
  }

  //===================================================
  // CURRENT STORY
  //===================================================

  NubifyStory? get _currentStory {
    if (_stories.isEmpty ||
        _currentIndex < 0 ||
        _currentIndex >= _stories.length) {
      return null;
    }

    return _stories[_currentIndex];
  }

  //===================================================
  // CURRENT UID
  //===================================================

  String get _currentUid => _auth.currentUser?.uid ?? '';

  //===================================================
  // OWNER
  //===================================================

  bool get _isOwner {
    final NubifyStory? story = _currentStory;

    if (story == null) {
      return false;
    }

    return _currentUid.isNotEmpty && story.uid == _currentUid;
  }

  //===================================================
  // OPEN STORY OWNER PROFILE
  //===================================================

  Future<void> _openStoryOwnerProfile(NubifyStory story) async {
    final String uid = story.uid.trim();

    if (uid.isEmpty || !mounted) {
      return;
    }

    final bool oldPaused = _progressPaused;

    if (story.type != 'voice') {
      setState(() {
        _progressPaused = true;
      });
    }

    await Navigator.of(context).pushNamed('/profile', arguments: uid);

    if (!mounted) {
      return;
    }

    if (story.type != 'voice') {
      setState(() {
        _progressPaused = oldPaused;
      });
    }
  }
  //===================================================
  // OPEN TAGGED USER PROFILE
  //===================================================

  Future<void> _openTaggedUserProfile(StoryPerson person) async {
    final String uid = person.uid.trim();

    if (uid.isEmpty || !mounted) {
      return;
    }

    _pauseForOverlay();

    await Navigator.of(context).pushNamed('/profile', arguments: uid);

    if (!mounted) {
      return;
    }

    _resumeAfterOverlay();
  }

  //===================================================
  // REPLY FOCUS
  //===================================================

  void _handleReplyFocus() {
    final NubifyStory? story = _currentStory;

    if (!mounted || story == null) {
      return;
    }

    if (story.type != 'voice') {
      setState(() {
        _progressPaused = _replyFocusNode.hasFocus;
      });
    }
  }

  //===================================================
  // PREPARE CURRENT STORY
  //===================================================

  void _prepareCurrentStory() {
    final NubifyStory? story = _currentStory;

    if (story == null) {
      return;
    }

    _progressTimer?.cancel();

    _advanceTimer?.cancel();

    _playbackRevision++;

    _progress = 0;

    _progressPaused = false;

    _mediaBuffering = false;

    _centerHoldActive = false;

    _pausedBeforeCenterHold = false;

    _voiceCompletionHandled = false;

    _videoCompletionHandled = false;

    // Every story must report its own ready state. Without resetting this,
    // the first story starts normally but later stories remain at 0%.
    _contentReadyHandled = false;

    _liked = story.likedUserIds.contains(_currentUid);

    _viewCount = story.viewCount;

    _likeCount = story.likeCount;

    _replyCount = story.replyCount;

    _shareCount = story.shareCount;

    _reshareCount = story.reshareCount;

    if (_isOwner) {
      _markOwnerStoryAsSeen(story);
    } else {
      _recordView(story);
    }
    //===================================================
    // NETWORK-AWARE STORY PROGRESS
    //
    // DO NOT START THE TIMER JUST BECAUSE THE SCREEN
    // OPENED.
    //
    // IMAGE / LAYOUT / SHARED POST WAIT UNTIL CONTENT
    // ACTUALLY LOADS.
    //
    // VIDEO + VOICE USE THEIR REAL MEDIA POSITION.
    //
    // TEXT + POLL HAVE NOTHING TO DOWNLOAD, SO THEY ARE
    // READY IMMEDIATELY.
    //===================================================

    if (story.type == 'text' || story.type == 'poll') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _onStoryContentReady(story.storyId);
      });
    }
  }

  //===================================================
  // OWNER SEES OWN STORY
  //
  // BORDER CAN TURN GREY
  // BUT OWNER DOES NOT ADD TO VIEW COUNT
  //===================================================

  Future<void> _markOwnerStoryAsSeen(NubifyStory story) async {
    final String uid = _currentUid;

    if (uid.isEmpty || _ownerSeenStoryIds.contains(story.storyId)) {
      return;
    }

    if (story.viewerIds.contains(uid)) {
      _ownerSeenStoryIds.add(story.storyId);

      return;
    }

    _ownerSeenStoryIds.add(story.storyId);

    try {
      await _firestore.collection('stories').doc(story.storyId).update(
        <String, dynamic>{
          'viewerIds': FieldValue.arrayUnion(<String>[uid]),
        },
      );
    } catch (error) {
      _ownerSeenStoryIds.remove(story.storyId);

      debugPrint('Owner Story seen error: $error');
    }
  }

  //===================================================
  // RECORD VIEW
  //===================================================

  Future<void> _recordView(NubifyStory story) async {
    if (_currentUid.isEmpty) {
      return;
    }

    final bool alreadyViewed = story.viewerIds.contains(_currentUid);

    try {
      await _storyService.recordView(story);

      if (!mounted || alreadyViewed) {
        return;
      }

      setState(() {
        _viewCount++;
      });
    } catch (error) {
      debugPrint('Story view error: $error');
    }
  }
  //===================================================
  // STORY CONTENT READY
  //
  // USED BY BOTH:
  // - LIVE STORY
  // - STORY ARCHIVE
  //===================================================

  void _onStoryContentReady(String storyId) {
    final NubifyStory? story = _currentStory;

    if (!mounted ||
        story == null ||
        story.storyId != storyId ||
        _contentReadyHandled ||
        _videoCompletionHandled ||
        _voiceCompletionHandled) {
      return;
    }

    //===================================================
    // DIRECT VIDEO + VOICE NEVER USE NORMAL TIMER.
    //===================================================

    if (story.type == 'video' || story.type == 'voice') {
      return;
    }

    _contentReadyHandled = true;

    _progressTimer?.cancel();

    setState(() {
      _progress = 0.0;
    });

    _startNormalProgress();
  }
  //===================================================
  // NORMAL STORY PROGRESS
  //
  // VOICE DOES NOT USE THIS
  //===================================================

  void _startNormalProgress() {
    _progressTimer?.cancel();
    _contentReadyHandled = true;

    final NubifyStory? story = _currentStory;

    if (story == null || story.type == 'voice' || story.type == 'video') {
      return;
    }

    final int seconds = story.durationSeconds.clamp(3, 60).toInt();

    const int tickMilliseconds = 100;

    final double increment = tickMilliseconds / (seconds * 1000);

    _progressTimer = Timer.periodic(
      const Duration(milliseconds: tickMilliseconds),
      (Timer timer) {
        if (!mounted || _progressPaused) {
          return;
        }

        final double next = _progress + increment;

        if (next >= 1) {
          timer.cancel();

          setState(() {
            _progress = 1;
          });

          _scheduleNextStory(const Duration(milliseconds: 80));

          return;
        }

        setState(() {
          _progress = next;
        });
      },
    );
  }

  //============================
  // REAL VIDEO PROGRESS
  //============================

  void _onVideoProgress(String storyId, double progress) {
    final NubifyStory? story = _currentStory;

    if (!mounted ||
        story == null ||
        story.storyId != storyId ||
        _videoCompletionHandled ||
        _progressPaused ||
        _mediaBuffering) {
      return;
    }

    //============================
    // VIDEO NOW CONTROLS THE BAR
    //============================

    _progressTimer?.cancel();

    final double safeProgress = progress.clamp(0.0, 1.0).toDouble();

    setState(() {
      _progress = safeProgress;
    });
  }

  //============================
  // VIDEO COMPLETED
  //============================

  void _onVideoCompleted(String storyId) {
    if (!mounted ||
        _currentStory?.storyId != storyId ||
        _videoCompletionHandled) {
      return;
    }

    _videoCompletionHandled = true;

    _mediaBuffering = false;

    _progressTimer?.cancel();

    setState(() {
      _progress = 1.0;
    });

    _scheduleNextStory(const Duration(milliseconds: 100));
  }

  //============================
  // REAL VIDEO BUFFERING
  //
  // This is deliberately separate from _progressPaused. Buffering must freeze
  // the bar without force-pausing the player, otherwise the player would not
  // be allowed to resume after the network recovers.
  //============================

  void _onVideoBuffering(String storyId, bool buffering) {
    if (!mounted ||
        _currentStory?.storyId != storyId ||
        _videoCompletionHandled ||
        _mediaBuffering == buffering) {
      return;
    }

    setState(() {
      _mediaBuffering = buffering;
    });
  }
  //===================================================
  // VOICE PROGRESS
  //
  // ACTUAL AUDIO POSITION / DURATION
  //===================================================

  void _onVoiceProgress(String storyId, double progress) {
    final NubifyStory? story = _currentStory;

    if (!mounted ||
        story == null ||
        story.storyId != storyId ||
        story.type != 'voice' ||
        _voiceCompletionHandled ||
        _progressPaused) {
      return;
    }
    final double safe = progress.clamp(0.0, 1.0).toDouble();

    setState(() {
      _progress = safe;
    });
  }

  //===================================================
  // VOICE COMPLETED
  //===================================================

  void _onVoiceCompleted(String storyId) {
    final NubifyStory? story = _currentStory;

    if (!mounted ||
        story == null ||
        story.storyId != storyId ||
        story.type != 'voice' ||
        _voiceCompletionHandled) {
      return;
    }

    _voiceCompletionHandled = true;

    setState(() {
      _progress = 1;
    });

    _scheduleNextStory(const Duration(milliseconds: 100));
  }

  //===================================================
  // SAFE AUTOMATIC ADVANCE
  //
  // The delayed callback belongs only to the story that scheduled it.
  // Cancelling and checking the story id prevents a manual tap near the end
  // from advancing two stories instead of one.
  //===================================================

  void _scheduleNextStory(Duration delay) {
    final String storyId = _currentStory?.storyId ?? '';

    if (storyId.isEmpty) {
      return;
    }

    _advanceTimer?.cancel();

    _advanceTimer = Timer(delay, () {
      if (!mounted || _currentStory?.storyId != storyId) {
        return;
      }

      _nextStory();
    });
  }

  //===================================================
  // MEDIA PAUSE
  //===================================================

  void _setMediaPaused(bool paused) {
    if (!mounted) {
      return;
    }

    setState(() {
      _progressPaused = paused;
    });
  }

  //===================================================
  // PRESS AND HOLD CENTRE TO PAUSE
  //===================================================

  void _startCenterHold(LongPressStartDetails details) {
    if (!mounted) {
      return;
    }

    final Size screenSize = MediaQuery.sizeOf(context);

    final double x = details.localPosition.dx;

    final double y = details.localPosition.dy;

    final bool isInCenter =
        x > screenSize.width * 0.20 &&
        x < screenSize.width * 0.80 &&
        y > 105 &&
        y < screenSize.height - 120;

    if (!isInCenter) {
      return;
    }

    _pausedBeforeCenterHold = _progressPaused;

    _centerHoldActive = true;

    setState(() {
      _progressPaused = true;
    });
  }

  void _endCenterHold() {
    if (!mounted || !_centerHoldActive) {
      return;
    }

    final bool restorePaused = _pausedBeforeCenterHold;

    _centerHoldActive = false;

    setState(() {
      _progressPaused = restorePaused;
    });
  }

  //===================================================
  // NEXT
  //===================================================

  void _nextStory() {
    _advanceTimer?.cancel();

    if (_stories.isEmpty) {
      _closeViewer();

      return;
    }

    if (_currentIndex < _stories.length - 1) {
      setState(() {
        _currentIndex++;
      });

      _prepareCurrentStory();

      return;
    }

    _closeViewer();
  }

  //===================================================
  // PREVIOUS
  //===================================================

  void _previousStory() {
    _advanceTimer?.cancel();

    if (_stories.isEmpty) {
      return;
    }

    final NubifyStory? story = _currentStory;

    if (story == null) {
      return;
    }

    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });

      _prepareCurrentStory();

      return;
    }

    // There is no earlier story. Restart the first one from the beginning.
    _prepareCurrentStory();

    setState(() {});
  }

  //===================================================
  // REMOVE EXPIRED
  //===================================================

  void _removeExpiredStories() {
    if (widget.allowExpiredStories) {
      return;
    }
    if (_stories.isEmpty) {
      return;
    }

    final String? currentId = _currentStory?.storyId;

    final List<NubifyStory> active = _stories
        .where((NubifyStory story) => !story.isExpired)
        .toList();

    if (active.length == _stories.length) {
      return;
    }

    if (active.isEmpty) {
      _closeViewer();

      return;
    }

    int newIndex = active.indexWhere(
      (NubifyStory story) => story.storyId == currentId,
    );

    if (newIndex < 0) {
      newIndex = _currentIndex.clamp(0, active.length - 1).toInt();
    }

    setState(() {
      _stories = active;

      _currentIndex = newIndex;
    });

    _prepareCurrentStory();
  }

  //===================================================
  // CLOSE
  //===================================================

  void _closeViewer() {
    if (!mounted) {
      return;
    }

    Navigator.of(context).pop();
  }

  //===================================================
  // LIKE STORY
  //===================================================

  Future<void> _toggleLike() async {
    final NubifyStory? story = _currentStory;

    if (story == null || _isOwner || _currentUid.isEmpty || _likeLoading) {
      return;
    }

    setState(() {
      _likeLoading = true;
    });

    try {
      final bool liked = await _storyService.toggleLike(story);

      if (!mounted) {
        return;
      }

      setState(() {
        _liked = liked;

        if (liked) {
          _likeCount++;
        } else if (_likeCount > 0) {
          _likeCount--;
        }
      });
    } catch (error) {
      debugPrint('Story like error: $error');

      _showMessage('Unable to update reaction.');
    } finally {
      if (mounted) {
        setState(() {
          _likeLoading = false;
        });
      }
    }
  }

  //===================================================
  // SEND REPLY
  //===================================================

  Future<void> _sendReply() async {
    final NubifyStory? story = _currentStory;

    if (story == null || _isOwner || _sendingReply) {
      return;
    }

    final String text = _replyController.text.trim();

    if (text.isEmpty) {
      return;
    }

    setState(() {
      _sendingReply = true;

      if (story.type != 'voice') {
        _progressPaused = true;
      }
    });

    try {
      await _storyService.replyToStory(story: story, message: text);

      if (!mounted) {
        return;
      }

      _replyController.clear();

      _replyFocusNode.unfocus();

      setState(() {
        _replyCount++;
      });

      _showMessage('Reply sent.');
    } catch (error) {
      debugPrint('Story reply error: $error');

      _showMessage('Unable to send reply.');
    } finally {
      if (mounted) {
        setState(() {
          _sendingReply = false;

          if (story.type != 'voice') {
            _progressPaused = false;
          }
        });
      }
    }
  }

  //===================================================
  // STORY SHARE MENU
  //===================================================

  Future<void> _showShareMenu() async {
    final NubifyStory? story = _currentStory;

    if (story == null) {
      return;
    }

    _pauseForOverlay();

    await showModalBottomSheet<void>(
      context: context,

      backgroundColor: const Color(0xFF171717),

      showDragHandle: true,

      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,

            children: <Widget>[
              const Padding(
                padding: EdgeInsets.only(bottom: 8),

                child: Text(
                  'Share Story',

                  style: TextStyle(
                    color: Colors.white,

                    fontSize: 20,

                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              //===================================================
              // SEND TO CHAT
              //===================================================
              ListTile(
                leading: const Icon(
                  Icons.chat_bubble_outline_rounded,

                  color: _nubifyBlue,
                ),

                title: const Text(
                  'Send to Chat',

                  style: TextStyle(color: Colors.white),
                ),

                onTap: () {
                  Navigator.pop(sheetContext);

                  _showChatPicker(story);
                },
              ),

              //===================================================
              // COPY LINK
              //===================================================
              ListTile(
                leading: const Icon(Icons.link, color: Colors.white),

                title: const Text(
                  'Copy Link',

                  style: TextStyle(color: Colors.white),
                ),

                onTap: () async {
                  Navigator.pop(sheetContext);

                  await _copyStoryLink(story);
                },
              ),

              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );

    _resumeAfterOverlay();
  }
  //===================================================
  // RESHARE
  //===================================================

  // ignore: unused_element
  Future<void> _reshareStory(NubifyStory story) async {
    try {
      await _storyService.reshareStory(story);

      if (!mounted) {
        return;
      }

      setState(() {
        _reshareCount++;
      });

      _showMessage('Story added to your Story.');
    } catch (error) {
      debugPrint('Reshare Story error: $error');

      _showMessage('Unable to reshare Story.');
    }
  }

  //===================================================
  // EXTERNAL SHARE
  //===================================================

  // ignore: unused_element
  Future<void> _shareExternal(NubifyStory story) async {
    final String link = 'https://nubify.app/story/${story.storyId}';

    final String text = story.caption.trim().isEmpty
        ? link
        : '${story.caption.trim()}\n\n$link';

    try {
      await SharePlus.instance.share(ShareParams(text: text));

      await _storyService.incrementShare(story.storyId);

      if (mounted) {
        setState(() {
          _shareCount++;
        });
      }
    } catch (error) {
      debugPrint('Story share error: $error');
    }
  }

  //===================================================
  // COPY STORY LINK
  //===================================================

  Future<void> _copyStoryLink(NubifyStory story) async {
    final String link = 'https://nubify.app/story/${story.storyId}';

    await Clipboard.setData(ClipboardData(text: link));

    try {
      await _storyService.incrementShare(story.storyId);

      if (mounted) {
        setState(() {
          _shareCount++;
        });
      }
    } catch (_) {}

    _showMessage('Story link copied.');
  }

  //===================================================
  //CHAT PICKER
  //===================================================

  Future<void> _showChatPicker(NubifyStory story) async {
    _pauseForOverlay();
    final bool isVideoOrVoice =
        story.type.toLowerCase() == 'video' ||
        story.type.toLowerCase() == 'voice';

    final String previewUrl = story.thumbnailUrl.trim().isNotEmpty
        ? story.thumbnailUrl.trim()
        : isVideoOrVoice
        ? ''
        : story.mediaUrl.trim().isNotEmpty
        ? story.mediaUrl
        : story.mediaUrls.isNotEmpty
        ? story.mediaUrls.first
        : story.sourceMediaUrl;
    final bool? sent = await Navigator.push<bool>(
      context,

      MaterialPageRoute<bool>(
        builder: (_) => ChatForwardScreen(
          storyId: story.storyId,

          storyOwnerId: story.uid,

          storyUsername: story.username,

          storyPreviewUrl: previewUrl,

          storyType: story.type,
        ),
      ),
    );

    if (sent == true) {
      try {
        await _storyService.incrementShare(story.storyId);

        if (mounted) {
          setState(() {
            _shareCount++;
          });
        }
      } catch (_) {}

      _showMessage('Story sent.');
    }

    _resumeAfterOverlay();
  }
  //===================================================
  // SEND STORY TO CHAT
  //===================================================

  // ignore: unused_element
  Future<bool> _sendStoryToChat(NubifyStory story, StoryPerson person) async {
    final String senderUid = _currentUid;

    final String receiverUid = person.uid.trim();

    if (senderUid.isEmpty || receiverUid.isEmpty || senderUid == receiverUid) {
      return false;
    }

    try {
      final List<String> users = <String>[senderUid, receiverUid]..sort();

      final String conversationId = users.join('_');

      final DocumentReference<Map<String, dynamic>> conversationRef = _firestore
          .collection('conversations')
          .doc(conversationId);

      final DocumentReference<Map<String, dynamic>> messageRef = conversationRef
          .collection('messages')
          .doc();

      final Timestamp now = Timestamp.now();

      final WriteBatch batch = _firestore.batch();

      batch.set(conversationRef, <String, dynamic>{
        'conversationId': conversationId,
        'participants': users,
        'participantIds': users,
        'members': users,
        'lastMessage': 'Shared a Story',
        'lastMessageType': 'story',
        'lastStoryId': story.storyId,
        'lastSenderId': senderUid,
        'lastMessageAt': now,
        'updatedAt': now,
      }, SetOptions(merge: true));

      batch.set(messageRef, <String, dynamic>{
        'messageId': messageRef.id,
        'conversationId': conversationId,
        'senderId': senderUid,
        'senderUid': senderUid,
        'receiverId': receiverUid,
        'recipientId': receiverUid,
        'type': 'story',
        'messageType': 'story',
        'storyId': story.storyId,
        'sharedStoryId': story.storyId,
        'storyOwnerId': story.uid,
        'storyUsername': story.username,
        'storyType': story.type,
        'storyMediaUrl': story.mediaUrl,
        'storyMediaUrls': story.mediaUrls,
        'storyText': story.text,
        'text': 'Shared a Story',
        'createdAt': now,
        'timestamp': now,
        'isRead': false,
        'seenBy': <String>[senderUid],
      });

      await batch.commit();

      try {
        await _storyService.incrementShare(story.storyId);
      } catch (_) {}

      if (mounted) {
        setState(() {
          _shareCount++;
        });

        _showMessage('Story sent to @${person.username}.');
      }

      return true;
    } catch (error) {
      debugPrint('Send Story chat error: $error');

      _showMessage('Unable to send Story.');

      return false;
    }
  }

  //===================================================
  // OWNER ACTIVITY
  //===================================================

  Future<void> _showOwnerActivity() async {
    final NubifyStory? story = _currentStory;

    if (story == null || !_isOwner) {
      return;
    }

    _pauseForOverlay();

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF101114),
      useSafeArea: true,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return FractionallySizedBox(
          heightFactor: 0.86,
          child: _StoryActivitySheet(story: story),
        );
      },
    );

    await _refreshCurrentStory();

    _resumeAfterOverlay();
  }

  //===================================================
  // REFRESH STORY
  //===================================================

  Future<void> _refreshCurrentStory() async {
    final NubifyStory? story = _currentStory;

    if (story == null) {
      return;
    }

    try {
      final NubifyStory? updated = await _storyService.getStory(story.storyId);

      if (updated == null || !mounted) {
        return;
      }

      setState(() {
        _stories[_currentIndex] = updated;

        _liked = updated.likedUserIds.contains(_currentUid);

        _viewCount = updated.viewCount;

        _likeCount = updated.likeCount;

        _replyCount = updated.replyCount;

        _shareCount = updated.shareCount;

        _reshareCount = updated.reshareCount;
      });
    } catch (error) {
      debugPrint('Story refresh error: $error');
    }
  }

  //===================================================
  // MORE MENU
  //===================================================

  Future<void> _showMoreMenu() async {
    final NubifyStory? story = _currentStory;

    if (story == null) {
      return;
    }

    _pauseForOverlay();

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF171717),
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (_isOwner)
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.redAccent,
                  ),
                  title: const Text(
                    'Delete Story',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);

                    _deleteStory(story);
                  },
                )
              else
                ListTile(
                  leading: const Icon(Icons.flag_outlined, color: Colors.white),
                  title: const Text(
                    'Report Story',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);

                    _reportStory(story);
                  },
                ),

              ListTile(
                leading: const Icon(Icons.link, color: Colors.white),
                title: const Text(
                  'Copy Link',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);

                  _copyStoryLink(story);
                },
              ),

              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    _resumeAfterOverlay();
  }

  //===================================================
  // DELETE STORY
  //===================================================

  Future<void> _deleteStory(NubifyStory story) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete Story?'),
          content: const Text('This Story will be permanently removed.'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),

            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _storyService.deleteStory(story);

      if (!mounted) {
        return;
      }

      setState(() {
        _stories.removeWhere(
          (NubifyStory item) => item.storyId == story.storyId,
        );

        if (_stories.isNotEmpty && _currentIndex >= _stories.length) {
          _currentIndex = _stories.length - 1;
        }
      });

      if (_stories.isEmpty) {
        _closeViewer();

        return;
      }

      _prepareCurrentStory();
    } catch (error) {
      debugPrint('Delete Story error: $error');

      _showMessage('Unable to delete Story.');
    }
  }

  //===================================================
  // REPORT STORY
  //===================================================

  Future<void> _reportStory(NubifyStory story) async {
    try {
      await _firestore.collection('reports').add(<String, dynamic>{
        'type': 'story',
        'storyId': story.storyId,
        'reportedStoryOwnerId': story.uid,
        'reportedBy': _currentUid,
        'reason': 'Reported from Story viewer',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      _showMessage('Story reported.');
    } catch (error) {
      debugPrint('Report Story error: $error');

      _showMessage('Unable to report Story.');
    }
  }

  //===================================================
  // PAUSE FOR OVERLAY
  //===================================================

  void _pauseForOverlay() {
    if (!mounted) {
      return;
    }

    _pausedBeforeOverlay = _progressPaused;

    setState(() {
      _progressPaused = true;
    });
  }

  //===================================================
  // RESUME AFTER OVERLAY
  //===================================================

  void _resumeAfterOverlay() {
    if (!mounted) {
      return;
    }

    setState(() {
      _progressPaused = _pausedBeforeOverlay;
    });
  }
  //===================================================
  // TIME AGO
  //===================================================

  String _timeAgo(DateTime createdAt) {
    Duration difference = DateTime.now().difference(createdAt);

    if (difference.isNegative) {
      difference = Duration.zero;
    }

    if (difference.inSeconds < 60) {
      return 'just now';
    }

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    }

    if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    }

    return '24h ago';
  }

  //===================================================
  // BUILD
  //===================================================

  @override
  Widget build(BuildContext context) {
    final NubifyStory? story = _currentStory;

    if (story == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            'Story unavailable',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }
    //=============================
    // SHARED POST STORY
    //=============================

    final bool isSharedPostStory =
        story.type == 'postShare' ||
        story.type == 'post_share' ||
        story.type == 'videoShare' ||
        story.type == 'video_share';

    final double edgeTapWidth =
        MediaQuery.sizeOf(context).width * (isSharedPostStory ? 0.14 : 0.20);

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onLongPressStart: _startCenterHold,
        onLongPressEnd: (_) {
          _endCenterHold();
        },
        onLongPressCancel: _endCenterHold,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            _StoryContent(
              key: ValueKey<String>('${story.storyId}_$_playbackRevision'),

              story: story,

              forcePaused: _progressPaused,

              onTaggedPersonTap: _openTaggedUserProfile,

              onPauseChanged: _setMediaPaused,

              onContentReady: () {
                _onStoryContentReady(story.storyId);
              },

              onVideoProgress: (double progress) {
                _onVideoProgress(story.storyId, progress);
              },

              onVideoBufferingChanged: (bool buffering) {
                _onVideoBuffering(story.storyId, buffering);
              },

              onVideoCompleted: () {
                _onVideoCompleted(story.storyId);
              },

              onVoiceProgress: (double progress) {
                _onVoiceProgress(story.storyId, progress);
              },

              onVoiceCompleted: () {
                _onVoiceCompleted(story.storyId);
              },

              onRefresh: _refreshCurrentStory,

              onOpenLink: _openStoryLink,
            ),
            //=============================
            // TAPPABLE STORY LINK PREVIEW
            //=============================
            if (story.linkUrl.trim().isNotEmpty)
              Positioned.fill(
                child: StoryLinkPreviewOverlay(
                  url: story.linkUrl,
                  style: story.linkStyle,
                  x: story.linkX,
                  y: story.linkY,
                  scale: story.linkScale,
                  editable: false,
                  onOpen: () => _openStoryLink(story.linkUrl),
                ),
              ),
            //===================================================
            // TOP GRADIENT
            //===================================================

            IgnorePointer(
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  height: 155,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[Color(0xC0000000), Colors.transparent],
                    ),
                  ),
                ),
              ),
            ),

            //===================================================
            // BOTTOM GRADIENT
            //===================================================
            IgnorePointer(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  height: 180,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: <Color>[Color(0xD0000000), Colors.transparent],
                    ),
                  ),
                ),
              ),
            ),

            SafeArea(
              child: Column(
                children: <Widget>[
                  _buildProgressBars(),

                  _buildHeader(story),

                  const Spacer(),

                  _buildStoryCaption(story),

                  if (_isOwner)
                    _buildOwnerBottomBar()
                  else
                    _buildViewerBottomBar(),
                ],
              ),
            ),

            Positioned(
              left: 0,
              top: 105,
              bottom: 120,
              width: edgeTapWidth,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _previousStory,
              ),
            ),

            Positioned(
              right: 0,
              top: 105,
              bottom: 120,
              width: edgeTapWidth,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _nextStory,
              ),
            ),
          ],
        ),
      ),
    );
  }

  //===================================================
  // PROGRESS BARS
  //===================================================

  Widget _buildProgressBars() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 7, 8, 4),
      child: Row(
        children: List<Widget>.generate(_stories.length, (int index) {
          double value = 0;

          if (index < _currentIndex) {
            value = 1;
          } else if (index == _currentIndex) {
            value = _progress;
          }

          return Expanded(
            child: Container(
              height: 3.2,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.white30,
                borderRadius: BorderRadius.circular(20),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: value.clamp(0.0, 1.0).toDouble(),
                child: Container(color: Colors.white),
              ),
            ),
          );
        }),
      ),
    );
  }

  //===================================================
  // HEADER
  //===================================================

  Widget _buildHeader(NubifyStory story) {
    final String displayName = story.fullName.trim().isNotEmpty
        ? story.fullName.trim()
        : story.username.trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 5, 4, 0),
      child: Row(
        children: <Widget>[
          //===================================================
          // HEART PROFILE -> PROFILE PAGE
          //===================================================

          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              _openStoryOwnerProfile(story);
            },
            child: _HeartAvatar(photoUrl: story.photoUrl, size: 45),
          ),

          const SizedBox(width: 10),

          //===================================================
          // NAME / USERNAME -> PROFILE PAGE
          //===================================================
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                _openStoryOwnerProfile(story);
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),

                      const SizedBox(width: 7),

                      Text(
                        _timeAgo(story.createdAt),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),

                  if (story.username.trim().isNotEmpty)
                    Text(
                      '@${story.username.trim()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
          ),

          IconButton(
            onPressed: _showMoreMenu,
            icon: const Icon(Icons.more_vert, color: Colors.white),
          ),

          IconButton(
            onPressed: _closeViewer,
            icon: const Icon(Icons.close, color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }

  //===================================================
  // VIEWER BOTTOM BAR
  //===================================================

  Widget _buildStoryCaption(NubifyStory story) {
    final String caption = story.caption.trim();

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: caption.isEmpty
          ? const SizedBox.shrink()
          : Container(
              key: ValueKey<String>('story-caption-${story.storyId}'),
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(18, 6, 18, 2),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xD91A1D24),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white24),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 18,
                    offset: Offset(0, 7),
                  ),
                ],
              ),
              child: Text(
                caption,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
    );
  }

  Widget _buildViewerBottomBar() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        MediaQuery.of(context).viewInsets.bottom > 0 ? 8 : 12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: _replyController,
              focusNode: _replyFocusNode,
              minLines: 1,
              maxLines: 3,
              textInputAction: TextInputAction.send,
              style: const TextStyle(color: Colors.white),
              onSubmitted: (_) {
                _sendReply();
              },
              decoration: InputDecoration(
                hintText: 'Send a message...',
                hintStyle: const TextStyle(color: Colors.white54),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: const BorderSide(color: Colors.white30),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: const BorderSide(color: _nubifyBlue, width: 1.5),
                ),
                suffixIcon: _sendingReply
                    ? const Padding(
                        padding: EdgeInsets.all(13),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _nubifyBlue,
                          ),
                        ),
                      )
                    : IconButton(
                        onPressed: _sendReply,
                        icon: const Icon(
                          Icons.send,
                          color: _nubifyBlue,
                          size: 20,
                        ),
                      ),
              ),
            ),
          ),

          const SizedBox(width: 10),

          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleLike,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _likeLoading
                      ? const SizedBox(
                          width: 29,
                          height: 29,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _nubifyBlue,
                          ),
                        )
                      : Icon(
                          _liked ? Icons.favorite : Icons.favorite_border,
                          color: _liked ? _nubifyBlue : Colors.white,
                          size: 30,
                        ),

                  if (_likeCount > 0)
                    Text(
                      '$_likeCount',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 12),

          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _showShareMenu,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(
                    Icons.send_outlined,
                    color: Colors.white,
                    size: 29,
                  ),

                  if (_shareCount > 0)
                    Text(
                      '$_shareCount',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  //===================================================
  // OWNER BOTTOM BAR
  //===================================================

  Widget _buildOwnerBottomBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        children: <Widget>[
          Expanded(
            child: GestureDetector(
              onTap: _showOwnerActivity,
              child: Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: Colors.white30),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.visibility_outlined,
                      color: Colors.white,
                      size: 20,
                    ),

                    const SizedBox(width: 5),

                    Text(
                      '$_viewCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(width: 13),

                    const Icon(Icons.favorite, color: _nubifyBlue, size: 19),

                    const SizedBox(width: 4),

                    Text(
                      '$_likeCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(width: 13),

                    const Icon(
                      Icons.chat_bubble_outline,
                      color: Colors.white,
                      size: 18,
                    ),

                    const SizedBox(width: 4),

                    Text(
                      '$_replyCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const Spacer(),

                    const Text(
                      'Activity',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const Icon(Icons.keyboard_arrow_up, color: Colors.white),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 10),

          GestureDetector(
            onTap: _showShareMenu,
            child: const Padding(
              padding: EdgeInsets.all(7),
              child: Icon(Icons.send_outlined, color: Colors.white, size: 29),
            ),
          ),
        ],
      ),
    );
  }

  //===================================================
  // MESSAGE
  //===================================================

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  //=============================
  // DISPOSE
  //=============================
  @override
  void dispose() {
    _progressTimer?.cancel();
    _advanceTimer?.cancel();
    _timeRefreshTimer?.cancel();

    _replyFocusNode.removeListener(_handleReplyFocus);

    _replyController.dispose();
    _replyFocusNode.dispose();

    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }

  //=============================
  // STORY LINK
  //=============================
  Future<void> _openStoryLink(String url) async {
    if (url.trim().isEmpty) {
      return;
    }

    _pauseForOverlay();

    if (LinkDetector.isNubifyUrl(url)) {
      await NubifyLinkRouter.open(context, url);

      if (mounted) {
        _resumeAfterOverlay();
      }

      return;
    }

    _resumeAfterExternalLink = true;

    await NubifyLinkRouter.open(context, url);
  }

  //=============================
  // APP LIFECYCLE
  //=============================
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed && _resumeAfterExternalLink) {
      _resumeAfterExternalLink = false;
      _resumeAfterOverlay();
    }
  }
}

//===================================================
// HEART AVATAR
//===================================================

class _HeartAvatar extends StatelessWidget {
  const _HeartAvatar({required this.photoUrl, required this.size});

  final String photoUrl;

  final double size;

  @override
  Widget build(BuildContext context) {
    //===================================================
    // STORY VIEWER HEADER AVATAR
    //
    // KEEP THE HEART SHAPE, BUT DO NOT DRAW THE THICK
    // STORY RING HERE. THE BOLD BLUE/GREY RING BELONGS
    // ONLY TO THE STORY TRAY ON HOME.
    //
    // THE PHOTO STILL USES BoxFit.cover SO THE USER'S
    // PROFILE PICTURE FILLS THE HEART COMPLETELY.
    // THIS CHANGE DOES NOT TOUCH STORY PLAYBACK, VOICE,
    // VIDEO, POLLS, ACTIVITY, LIKES, REPLIES, SHARING,
    // DELETION, REPORTING OR STORY PROGRESS LOGIC.
    //===================================================

    return SizedBox(
      width: size,
      height: size,
      child: ClipPath(
        clipper: _HeartClipper(),
        child: Container(
          width: size,
          height: size,
          color: Colors.grey.shade800,
          child: photoUrl.trim().isNotEmpty
              ? Image.network(
                  photoUrl,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (
                        BuildContext context,
                        Object error,
                        StackTrace? stackTrace,
                      ) {
                        return const Icon(Icons.person, color: Colors.white70);
                      },
                )
              : const Icon(Icons.person, color: Colors.white70),
        ),
      ),
    );
  }
}

//===================================================
// HEART CLIPPER
//===================================================

class _HeartClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return _heartPath(size, 0);
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) {
    return false;
  }
}

//===================================================
// HEART BORDER
//===================================================

// ignore: unused_element
class _HeartBorderPainter extends CustomPainter {
  const _HeartBorderPainter({required this.color, required this.strokeWidth});

  final Color color;

  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final Path path = _heartPath(size, strokeWidth / 2 + 0.5);

    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _HeartBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
  }
}

//===================================================
// PROPER HEART PATH
//===================================================

Path _heartPath(Size size, double inset) {
  final double left = inset;

  final double top = inset;

  final double width = size.width - inset * 2;

  final double height = size.height - inset * 2;

  final double centerX = left + width * 0.50;

  final Path path = Path();

  path.moveTo(centerX, top + height * 0.97);

  path.cubicTo(
    left + width * 0.35,
    top + height * 0.84,

    left + width * 0.03,
    top + height * 0.62,

    left + width * 0.03,
    top + height * 0.34,
  );

  path.cubicTo(
    left + width * 0.03,
    top + height * 0.13,

    left + width * 0.17,
    top + height * 0.02,

    left + width * 0.31,
    top + height * 0.02,
  );

  path.cubicTo(
    left + width * 0.41,
    top + height * 0.02,

    left + width * 0.48,
    top + height * 0.09,

    centerX,
    top + height * 0.19,
  );

  path.cubicTo(
    left + width * 0.52,
    top + height * 0.09,

    left + width * 0.59,
    top + height * 0.02,

    left + width * 0.69,
    top + height * 0.02,
  );

  path.cubicTo(
    left + width * 0.83,
    top + height * 0.02,

    left + width * 0.97,
    top + height * 0.13,

    left + width * 0.97,
    top + height * 0.34,
  );

  path.cubicTo(
    left + width * 0.97,
    top + height * 0.62,

    left + width * 0.65,
    top + height * 0.84,

    centerX,
    top + height * 0.97,
  );

  path.close();

  return path;
}

//===================================================
// STORY CONTENT
//===================================================

class _StoryContent extends StatelessWidget {
  const _StoryContent({
    super.key,
    required this.story,

    required this.forcePaused,
    required this.onTaggedPersonTap,
    required this.onPauseChanged,

    required this.onContentReady,

    required this.onVideoProgress,
    required this.onVideoBufferingChanged,
    required this.onVideoCompleted,

    required this.onVoiceProgress,
    required this.onVoiceCompleted,

    required this.onRefresh,
    required this.onOpenLink,
  });
  final NubifyStory story;
  final bool forcePaused;

  final ValueChanged<StoryPerson> onTaggedPersonTap;
  final ValueChanged<String> onOpenLink;
  final ValueChanged<bool> onPauseChanged;
  final VoidCallback onContentReady;

  //============================
  // VIDEO PROGRESS
  //============================

  final ValueChanged<double> onVideoProgress;

  final ValueChanged<bool> onVideoBufferingChanged;

  final VoidCallback onVideoCompleted;

  //============================
  // VOICE PROGRESS
  //============================

  final ValueChanged<double> onVoiceProgress;

  final VoidCallback onVoiceCompleted;

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    Widget content;

    switch (story.type) {
      case 'image':
        content = _StoryImage(url: story.mediaUrl, onReady: onContentReady);
        break;

      case 'video':
        content = _StoryVideo(
          url: story.mediaUrl,

          forcePaused: forcePaused,

          onPauseChanged: onPauseChanged,

          onProgressChanged: onVideoProgress,

          onBufferingChanged: onVideoBufferingChanged,

          onCompleted: onVideoCompleted,
        );
        break;

      case 'voice':
        content = _StoryVoicePlayer(
          key: ValueKey<String>('${story.storyId}_${story.mediaUrl}'),

          url: story.mediaUrl,

          forcePaused: forcePaused,

          backgroundColor: story.backgroundColor,

          fallbackDurationSeconds: story.durationSeconds,

          onPauseChanged: onPauseChanged,

          onProgressChanged: onVoiceProgress,

          onCompleted: onVoiceCompleted,
        );
        break;

      case 'layout':
        content = _NetworkAwareStoryLayout(
          story: story,

          onReady: onContentReady,
        );
        break;

      case 'poll':
        content = _StoryPollView(story: story, onRefresh: onRefresh);
        break;

      case 'reshare':
        content = _StoryReshare(story: story, onReady: onContentReady);
        break;
      case 'postShare':
      case 'post_share':
      case 'videoShare':
      case 'video_share':
        return _SharedPostStory(
          story: story,

          forcePaused: forcePaused,

          onContentReady: onContentReady,

          onVideoProgress: onVideoProgress,

          onVideoBufferingChanged: onVideoBufferingChanged,

          onVideoCompleted: onVideoCompleted,

          onTaggedPersonTap: onTaggedPersonTap,
        );
      case 'text':
      default:
        content = _StoryText(story: story);
        break;
    }

    //===================================================
    // NORMAL CREATE-STORY STICKER
    //
    // Shared-post Stories already have their own
    // backwards-compatible sticker rendering.
    //===================================================

    final bool showTextOverlay =
        story.type != 'text' &&
        story.type != 'postShare' &&
        story.type != 'post_share' &&
        story.type != 'videoShare' &&
        story.type != 'video_share' &&
        story.text.trim().isNotEmpty;

    if (story.sticker.trim().isEmpty &&
        !showTextOverlay &&
        story.drawings.isEmpty) {
      return content;
    }

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        content,

        if (story.drawings.isNotEmpty)
          Positioned.fill(child: StoryDrawingCanvas(strokes: story.drawings)),

        if (showTextOverlay)
          IgnorePointer(child: _StoryTextOverlay(story: story)),

        if (story.sticker.trim().isNotEmpty)
          IgnorePointer(child: _StoryStickerOverlay(story: story)),
      ],
    );
  }
}

//===================================================
// MOVABLE STORY TEXT DISPLAY
//===================================================

class _StoryTextOverlay extends StatelessWidget {
  const _StoryTextOverlay({required this.story});

  final NubifyStory story;

  TextAlign get _alignment {
    if (story.textAlign == 'left') {
      return TextAlign.left;
    }
    if (story.textAlign == 'right') {
      return TextAlign.right;
    }
    return TextAlign.center;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned(
              left: (story.textX * constraints.maxWidth)
                  .clamp(0.0, constraints.maxWidth)
                  .toDouble(),
              top: (story.textY * constraints.maxHeight)
                  .clamp(0.0, constraints.maxHeight)
                  .toDouble(),
              child: FractionalTranslation(
                translation: const Offset(-0.5, -0.5),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth * 0.84,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      story.text.trim(),
                      textAlign: _alignment,
                      style: TextStyle(
                        color: Color(story.textColor),
                        fontSize: story.textSize.clamp(18.0, 72.0),
                        fontWeight: story.textStyle == 'bold'
                            ? FontWeight.w800
                            : FontWeight.w500,
                        fontStyle: story.textStyle == 'italic'
                            ? FontStyle.italic
                            : FontStyle.normal,
                        fontFamily: story.textStyle == 'mono'
                            ? 'monospace'
                            : null,
                        shadows: const <Shadow>[
                          Shadow(color: Colors.black54, blurRadius: 6),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

//===================================================
// STORY STICKER DISPLAY
//===================================================

class _StoryStickerOverlay extends StatelessWidget {
  const _StoryStickerOverlay({required this.story});

  final NubifyStory story;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned(
              left: (story.stickerX * constraints.maxWidth)
                  .clamp(0.0, constraints.maxWidth)
                  .toDouble(),

              top: (story.stickerY * constraints.maxHeight)
                  .clamp(0.0, constraints.maxHeight)
                  .toDouble(),

              child: Transform.translate(
                offset: Offset(
                  -story.stickerSize * 0.55,
                  -story.stickerSize * 0.55,
                ),

                child: Padding(
                  padding: const EdgeInsets.all(12),

                  child: Text(
                    story.sticker,

                    style: TextStyle(fontSize: story.stickerSize, height: 1),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
//===================================================
// IMAGE STORY
//
// STORY PROGRESS STAYS AT 0 UNTIL IMAGE IS READY.
//===================================================

class _StoryImage extends StatefulWidget {
  const _StoryImage({required this.url, required this.onReady});

  final String url;

  final VoidCallback onReady;

  @override
  State<_StoryImage> createState() => _StoryImageState();
}

class _StoryImageState extends State<_StoryImage> {
  bool _readySent = false;

  //============================
  // IMAGE READY
  //============================

  void _notifyReady() {
    if (_readySent) {
      return;
    }

    _readySent = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onReady();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.url.trim().isEmpty) {
      _notifyReady();

      return const ColoredBox(
        color: Colors.black,

        child: Center(
          child: Icon(
            Icons.broken_image_outlined,
            color: Colors.white54,
            size: 60,
          ),
        ),
      );
    }

    return Container(
      color: Colors.black,

      alignment: Alignment.center,

      child: Image.network(
        widget.url,

        width: double.infinity,

        height: double.infinity,

        fit: BoxFit.contain,

        loadingBuilder:
            (
              BuildContext context,
              Widget child,
              ImageChunkEvent? loadingProgress,
            ) {
              if (loadingProgress == null) {
                _notifyReady();

                return child;
              }

              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF29B6F6)),
              );
            },

        errorBuilder:
            (BuildContext context, Object error, StackTrace? stackTrace) {
              _notifyReady();

              return const Icon(
                Icons.broken_image_outlined,

                color: Colors.white54,

                size: 60,
              );
            },
      ),
    );
  }
}

//===================================================
// TEXT STORY
//===================================================

class _StoryText extends StatelessWidget {
  const _StoryText({required this.story});

  final NubifyStory story;

  //=============================
  // STICKER POSITION
  //=============================

  // ignore: unused_element
  Offset _savedStickerPosition() {
    final String raw = story.textAlign.trim();

    if (!raw.startsWith('sticker:')) {
      return const Offset(0.80, 0.14);
    }

    final String encoded = raw.substring('sticker:'.length);

    final List<String> parts = encoded.split(',');

    if (parts.length != 2) {
      return const Offset(0.80, 0.14);
    }

    final double? x = double.tryParse(parts[0]);

    final double? y = double.tryParse(parts[1]);

    if (x == null || y == null) {
      return const Offset(0.80, 0.14);
    }

    return Offset(
      x.clamp(0.04, 0.96).toDouble(),
      y.clamp(0.04, 0.96).toDouble(),
    );
  }

  //=============================
  // STICKER SIZE
  //=============================

  // ignore: unused_element
  double _savedStickerSize() {
    if (!story.textAlign.trim().startsWith('sticker:')) {
      return 52.0;
    }

    return story.textSize.clamp(28.0, 120.0).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    TextAlign align = TextAlign.center;

    if (story.textAlign == 'left') {
      align = TextAlign.left;
    } else if (story.textAlign == 'right') {
      align = TextAlign.right;
    }

    return Container(
      color: Color(story.backgroundColor),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Text(
        story.text,
        textAlign: align,
        style: TextStyle(
          color: Color(story.textColor),
          fontSize: story.textSize,
          fontWeight: story.textStyle == 'bold'
              ? FontWeight.w800
              : FontWeight.w500,
          fontStyle: story.textStyle == 'italic'
              ? FontStyle.italic
              : FontStyle.normal,
          fontFamily: story.textStyle == 'mono' ? 'monospace' : null,
        ),
      ),
    );
  }
}
//===================================================
// VIDEO STORY
//
// VIDEO POSITION DRIVES THE TOP STORY PROGRESS BAR.
//===================================================

class _StoryVideo extends StatefulWidget {
  const _StoryVideo({
    required this.url,
    required this.forcePaused,
    required this.onPauseChanged,
    required this.onProgressChanged,
    required this.onBufferingChanged,
    required this.onCompleted,
  });

  final String url;
  final bool forcePaused;

  final ValueChanged<bool> onPauseChanged;

  final ValueChanged<double> onProgressChanged;

  final ValueChanged<bool> onBufferingChanged;

  final VoidCallback onCompleted;

  @override
  State<_StoryVideo> createState() => _StoryVideoState();
}

class _StoryVideoState extends State<_StoryVideo> {
  VideoPlayerController? _controller;

  bool _loading = true;

  bool _error = false;

  bool _completionHandled = false;

  bool _isBuffering = false;
  //===================================================
  // FORCED ACTIVITY PAUSE
  //===================================================

  bool _wasPlayingBeforeForcedPause = false;

  //===================================================
  // SYNC ACTIVITY PAUSE
  //===================================================

  Future<void> _syncForcedPause() async {
    final VideoPlayerController? controller = _controller;

    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    if (widget.forcePaused) {
      if (controller.value.isPlaying) {
        _wasPlayingBeforeForcedPause = true;

        await controller.pause();
      }

      return;
    }

    if (_wasPlayingBeforeForcedPause) {
      _wasPlayingBeforeForcedPause = false;

      await controller.play();
    }
  }

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void didUpdateWidget(covariant _StoryVideo oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.forcePaused != widget.forcePaused) {
      unawaited(_syncForcedPause());
    }
  }

  //===================================================
  // INITIALIZE VIDEO
  //===================================================

  Future<void> _initialize() async {
    try {
      final VideoPlayerController controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.url),
      );

      await controller.initialize();

      //===================================================
      // STORY VIDEO SHOULD FINISH ONCE.
      //
      // DO NOT LOOP HERE BECAUSE THE STORY SHOULD MOVE
      // TO THE NEXT STORY WHEN THE VIDEO FINISHES.
      //===================================================

      await controller.setLooping(false);

      await controller.setVolume(1.0);

      controller.addListener(_videoListener);

      if (!mounted) {
        controller.removeListener(_videoListener);

        await controller.dispose();

        return;
      }

      setState(() {
        _controller = controller;

        _loading = false;

        _error = false;
      });

      await controller.play();

      if (widget.forcePaused) {
        _wasPlayingBeforeForcedPause = true;

        await controller.pause();
      }
    } catch (error) {
      debugPrint('Story video error: $error');

      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;

        _error = true;
      });
    }
  }

  //===================================================
  // REAL VIDEO POSITION
  //===================================================

  void _videoListener() {
    final VideoPlayerController? controller = _controller;

    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    final bool nextBuffering = controller.value.isBuffering;

    if (_isBuffering != nextBuffering) {
      _isBuffering = nextBuffering;
      widget.onBufferingChanged(nextBuffering);

      if (mounted) {
        setState(() {});
      }
    }

    final Duration duration = controller.value.duration;

    final Duration position = controller.value.position;

    final int durationMs = duration.inMilliseconds;

    if (durationMs <= 0) {
      return;
    }

    final double progress = position.inMilliseconds / durationMs;

    if (!_isBuffering) {
      widget.onProgressChanged(progress.clamp(0.0, 1.0).toDouble());
    }

    //===================================================
    // VIDEO FINISHED
    //===================================================

    if (!_completionHandled && position.inMilliseconds >= durationMs - 120) {
      _completionHandled = true;

      widget.onProgressChanged(1);

      widget.onCompleted();
    }
  }

  //===================================================
  // PLAY / PAUSE
  //===================================================

  Future<void> _toggleVideo() async {
    final VideoPlayerController? controller = _controller;

    if (controller == null) {
      return;
    }

    if (controller.value.isPlaying) {
      await controller.pause();

      widget.onPauseChanged(true);
    } else {
      await controller.play();

      widget.onPauseChanged(false);
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final VideoPlayerController? controller = _controller;

    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_error || controller == null || !controller.value.isInitialized) {
      return const Center(
        child: Text(
          'Unable to play video',

          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return GestureDetector(
      onTap: _toggleVideo,

      child: Container(
        color: Colors.black,

        alignment: Alignment.center,

        child: Stack(
          alignment: Alignment.center,

          children: <Widget>[
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.contain,

                child: SizedBox(
                  width: controller.value.size.width,

                  height: controller.value.size.height,

                  child: VideoPlayer(controller),
                ),
              ),
            ),

            if (!controller.value.isPlaying && !_isBuffering)
              Container(
                width: 70,

                height: 70,

                decoration: const BoxDecoration(
                  color: Colors.black54,

                  shape: BoxShape.circle,
                ),

                child: const Icon(
                  Icons.play_arrow,

                  color: Colors.white,

                  size: 44,
                ),
              ),

            if (_isBuffering)
              Container(
                width: 58,
                height: 58,
                padding: const EdgeInsets.all(14),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    final VideoPlayerController? controller = _controller;

    controller?.removeListener(_videoListener);

    controller?.dispose();

    super.dispose();
  }
}
//===================================================
// VOICE STORY
//
// REAL AUDIO CONTROLS TOP PROGRESS BAR
//===================================================

class _StoryVoicePlayer extends StatefulWidget {
  const _StoryVoicePlayer({
    super.key,
    required this.url,
    required this.backgroundColor,
    required this.fallbackDurationSeconds,
    required this.onPauseChanged,
    required this.onProgressChanged,
    required this.onCompleted,
    required this.forcePaused,
  });

  final String url;

  final int backgroundColor;

  final int fallbackDurationSeconds;

  final ValueChanged<bool> onPauseChanged;

  final ValueChanged<double> onProgressChanged;

  final VoidCallback onCompleted;

  final bool forcePaused;

  @override
  State<_StoryVoicePlayer> createState() => _StoryVoicePlayerState();
}

class _StoryVoicePlayerState extends State<_StoryVoicePlayer> {
  final AudioPlayer _player = AudioPlayer();

  StreamSubscription<void>? _completeSubscription;

  StreamSubscription<Duration>? _positionSubscription;

  StreamSubscription<Duration>? _durationSubscription;

  bool _playing = false;

  bool _loading = true;

  bool _error = false;

  bool _completed = false;

  //===================================================
  // FORCED ACTIVITY PAUSE
  //===================================================

  bool _wasPlayingBeforeForcedPause = false;

  Duration _position = Duration.zero;

  Duration _duration = Duration.zero;
  //===================================================
  // STORY VOICE CHANGED / FORCED PAUSE
  //===================================================

  @override
  void didUpdateWidget(covariant _StoryVoicePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.url != widget.url) {
      unawaited(_restartVoice());

      return;
    }

    if (oldWidget.forcePaused != widget.forcePaused) {
      unawaited(_syncForcedVoicePause());
    }
  }
  //===================================================
  // SYNC ACTIVITY VOICE PAUSE
  //===================================================

  Future<void> _syncForcedVoicePause() async {
    if (widget.forcePaused) {
      if (_playing) {
        _wasPlayingBeforeForcedPause = true;

        await _player.pause();

        if (mounted) {
          setState(() {
            _playing = false;
          });
        }
      }

      return;
    }

    if (_wasPlayingBeforeForcedPause && !_completed) {
      _wasPlayingBeforeForcedPause = false;

      await _player.resume();

      if (mounted) {
        setState(() {
          _playing = true;
        });
      }
    }
  }
  //===================================================
  // RESTART VOICE
  //===================================================

  Future<void> _restartVoice() async {
    await _player.stop();

    if (!mounted) {
      return;
    }

    setState(() {
      _position = Duration.zero;

      _duration = Duration(seconds: widget.fallbackDurationSeconds);

      _playing = false;

      _loading = true;

      _error = false;

      _completed = false;
    });

    await _playFromStart();
  }
  //===================================================
  // VOICE PLAYBACK AUDIO ROUTE
  //===================================================

  Future<void> _configurePlayback() async {
    try {
      await _player.setPlayerMode(PlayerMode.mediaPlayer);

      await _player.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: true,
            audioMode: AndroidAudioMode.normal,
            stayAwake: true,
            contentType: AndroidContentType.speech,
            usageType: AndroidUsageType.media,
            audioFocus: AndroidAudioFocus.gain,
          ),
        ),
      );

      await _player.setReleaseMode(ReleaseMode.stop);

      await _player.setVolume(1.0);
    } catch (error) {
      debugPrint('Story voice playback configuration error: $error');
    }
  }

  @override
  void initState() {
    super.initState();

    _duration = Duration(seconds: widget.fallbackDurationSeconds);

    _durationSubscription = _player.onDurationChanged.listen((
      Duration duration,
    ) {
      if (!mounted || duration <= Duration.zero) {
        return;
      }

      setState(() {
        _duration = duration;
      });

      _sendRealProgress();
    });

    _positionSubscription = _player.onPositionChanged.listen((
      Duration position,
    ) {
      if (!mounted) {
        return;
      }

      setState(() {
        _position = position;
      });

      _sendRealProgress();
    });

    _completeSubscription = _player.onPlayerComplete.listen((_) {
      if (!mounted || _completed) {
        return;
      }

      _completed = true;

      setState(() {
        _playing = false;

        _loading = false;

        _position = _duration;
      });

      widget.onProgressChanged(1);

      widget.onPauseChanged(false);

      widget.onCompleted();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _playFromStart();
      }
    });
  }

  void _sendRealProgress() {
    if (_completed) {
      return;
    }

    final int durationMs = _duration.inMilliseconds;

    if (durationMs <= 0) {
      widget.onProgressChanged(0);

      return;
    }

    final double progress = _position.inMilliseconds / durationMs;

    widget.onProgressChanged(progress.clamp(0.0, 1.0).toDouble());
  }
  //===================================================
  // PLAY NETWORK VOICE
  //===================================================

  Future<void> _playNetworkVoice() async {
    try {
      await _player.play(UrlSource(widget.url));
    } catch (_) {
      // Android audio focus can occasionally still
      // be changing after recording/calls/video.
      await Future<void>.delayed(const Duration(milliseconds: 250));

      await _configurePlayback();

      await _player.play(UrlSource(widget.url));
    }
  }

  Future<void> _playFromStart() async {
    if (widget.url.trim().isEmpty) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;

        _error = true;

        _playing = false;
      });

      return;
    }

    try {
      _completed = false;

      widget.onProgressChanged(0);

      if (mounted) {
        setState(() {
          _loading = true;

          _error = false;

          _position = Duration.zero;
        });
      }

      //===================================================
      // SPEAKER / MEDIA PLAYBACK
      //===================================================

      await _configurePlayback();

      await _player.stop();

      await _player.setVolume(1.0);

      await _player.setReleaseMode(ReleaseMode.stop);

      //===================================================
      // AUTOPLAY
      //===================================================

      await _playNetworkVoice();
      if (widget.forcePaused) {
        _wasPlayingBeforeForcedPause = true;

        await _player.pause();
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _playing = !widget.forcePaused;

        _loading = false;

        _error = false;
      });

      widget.onPauseChanged(false);
    } catch (error) {
      debugPrint('Voice autoplay error: $error');

      if (!mounted) {
        return;
      }

      setState(() {
        _playing = false;

        _loading = false;

        _error = true;
      });
    }
  }

  Future<void> _toggleVoice() async {
    try {
      if (_playing) {
        await _player.pause();

        if (!mounted) {
          return;
        }

        setState(() {
          _playing = false;
        });

        widget.onPauseChanged(true);

        return;
      }

      if (!_completed && _position > Duration.zero && _position < _duration) {
        await _player.resume();

        if (!mounted) {
          return;
        }

        setState(() {
          _playing = true;

          _error = false;
        });

        widget.onPauseChanged(false);

        return;
      }

      await _playFromStart();
    } catch (error) {
      debugPrint('Voice toggle error: $error');
    }
  }

  Future<void> _seekVoice(double value) async {
    if (_duration.inMilliseconds <= 0) {
      return;
    }

    final Duration target = Duration(
      milliseconds: (_duration.inMilliseconds * value).round(),
    );

    await _player.seek(target);

    if (!mounted) {
      return;
    }

    setState(() {
      _position = target;
    });

    _sendRealProgress();
  }

  double get _sliderValue {
    if (_duration.inMilliseconds <= 0) {
      return 0;
    }

    return (_position.inMilliseconds / _duration.inMilliseconds)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Color(widget.backgroundColor),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 38),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              GestureDetector(
                onTap: _toggleVoice,
                child: Container(
                  width: 112,
                  height: 112,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF29B6F6),
                      width: 3,
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Color(0xFF29B6F6),
                          ),
                        )
                      : Icon(
                          _playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 58,
                        ),
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                'Voice Story',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              const _StoryVoiceWaveform(),

              const SizedBox(height: 5),

              Slider(
                min: 0,
                max: 1,
                value: _sliderValue,
                activeColor: const Color(0xFF29B6F6),
                inactiveColor: Colors.white24,
                onChanged: _seekVoice,
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    _formatAudioDuration(_position),
                    style: const TextStyle(color: Colors.white70),
                  ),

                  Text(
                    _formatAudioDuration(_duration),
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),

              if (_error)
                TextButton.icon(
                  onPressed: _playFromStart,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _completeSubscription?.cancel();

    _positionSubscription?.cancel();

    _durationSubscription?.cancel();

    _player.stop();

    _player.dispose();

    super.dispose();
  }
}

//===================================================
// VOICE WAVEFORM
//===================================================

class _StoryVoiceWaveform extends StatelessWidget {
  const _StoryVoiceWaveform();

  @override
  Widget build(BuildContext context) {
    const List<double> bars = <double>[
      14,
      26,
      19,
      35,
      22,
      39,
      26,
      31,
      17,
      36,
      22,
      30,
      18,
      34,
      24,
      38,
      17,
      29,
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: bars.map((double height) {
        return Container(
          width: 3,
          height: height,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF29B6F6),
            borderRadius: BorderRadius.circular(5),
          ),
        );
      }).toList(),
    );
  }
}

//===================================================
// AUDIO TIME
//===================================================

String _formatAudioDuration(Duration duration) {
  final int totalSeconds = duration.inSeconds.clamp(0, 3599).toInt();

  final int minutes = totalSeconds ~/ 60;

  final int seconds = totalSeconds % 60;

  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
//===================================================
// NETWORK-AWARE LAYOUT STORY
//
// PRELOAD THE LAYOUT IMAGES BEFORE STARTING THE
// STORY TIMER.
//===================================================

class _NetworkAwareStoryLayout extends StatefulWidget {
  const _NetworkAwareStoryLayout({required this.story, required this.onReady});

  final NubifyStory story;

  final VoidCallback onReady;

  @override
  State<_NetworkAwareStoryLayout> createState() =>
      _NetworkAwareStoryLayoutState();
}

class _NetworkAwareStoryLayoutState extends State<_NetworkAwareStoryLayout> {
  bool _started = false;

  bool _ready = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_started) {
      return;
    }

    _started = true;

    _preloadImages();
  }

  Future<void> _preloadImages() async {
    final List<String> urls = widget.story.mediaUrls
        .map((String url) => url.trim())
        .where((String url) => url.isNotEmpty)
        .toSet()
        .toList();

    if (urls.isNotEmpty) {
      for (final String url in urls) {
        try {
          await precacheImage(NetworkImage(url), context);
        } catch (_) {
          //============================
          // EVEN IF ONE IMAGE FAILS,
          // DON'T FREEZE STORY FOREVER.
          //============================
        }
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _ready = true;
    });

    widget.onReady();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const ColoredBox(
        color: Colors.black,

        child: Center(
          child: CircularProgressIndicator(color: Color(0xFF29B6F6)),
        ),
      );
    }

    return _StoryLayout(story: widget.story);
  }
}
//===================================================
// LAYOUT STORY
//===================================================

class _StoryLayout extends StatelessWidget {
  const _StoryLayout({required this.story});

  final NubifyStory story;

  String _url(int index) {
    if (story.mediaUrls.isEmpty) {
      return '';
    }

    return story.mediaUrls[index % story.mediaUrls.length];
  }

  Widget _slot(int index) {
    final String url = _url(index);

    return Padding(
      padding: const EdgeInsets.all(1.5),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: url.isEmpty
            ? Container(color: Colors.black)
            : Image.network(
                url,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int count = story.layoutCount.clamp(2, 4).toInt();

    final String style = story.layoutStyle;

    if (count == 2) {
      if (style == 'horizontal') {
        return Column(
          children: <Widget>[
            Expanded(child: _slot(0)),
            Expanded(child: _slot(1)),
          ],
        );
      }

      return Row(
        children: <Widget>[
          Expanded(child: _slot(0)),
          Expanded(child: _slot(1)),
        ],
      );
    }

    if (count == 3) {
      if (style == 'big_left') {
        return Row(
          children: <Widget>[
            Expanded(flex: 2, child: _slot(0)),

            Expanded(
              child: Column(
                children: <Widget>[
                  Expanded(child: _slot(1)),
                  Expanded(child: _slot(2)),
                ],
              ),
            ),
          ],
        );
      }

      if (style == 'three_vertical') {
        return Row(
          children: <Widget>[
            for (int index = 0; index < 3; index++)
              Expanded(child: _slot(index)),
          ],
        );
      }

      if (style == 'three_horizontal') {
        return Column(
          children: <Widget>[
            for (int index = 0; index < 3; index++)
              Expanded(child: _slot(index)),
          ],
        );
      }

      return Column(
        children: <Widget>[
          Expanded(flex: 2, child: _slot(0)),
          Expanded(
            child: Row(
              children: <Widget>[
                Expanded(child: _slot(1)),
                Expanded(child: _slot(2)),
              ],
            ),
          ),
        ],
      );
    }

    if (style == 'four_vertical') {
      return Row(
        children: <Widget>[
          for (int index = 0; index < 4; index++) Expanded(child: _slot(index)),
        ],
      );
    }

    if (style == 'four_horizontal') {
      return Column(
        children: <Widget>[
          for (int index = 0; index < 4; index++) Expanded(child: _slot(index)),
        ],
      );
    }

    if (style == 'big_left_three') {
      return Row(
        children: <Widget>[
          Expanded(flex: 2, child: _slot(0)),

          Expanded(
            child: Column(
              children: <Widget>[
                Expanded(child: _slot(1)),
                Expanded(child: _slot(2)),
                Expanded(child: _slot(3)),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      children: <Widget>[
        Expanded(
          child: Row(
            children: <Widget>[
              Expanded(child: _slot(0)),
              Expanded(child: _slot(1)),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: <Widget>[
              Expanded(child: _slot(2)),
              Expanded(child: _slot(3)),
            ],
          ),
        ),
      ],
    );
  }
}

//===================================================
// POLL STORY
//===================================================

class _StoryPollView extends StatefulWidget {
  const _StoryPollView({required this.story, required this.onRefresh});

  final NubifyStory story;

  final Future<void> Function() onRefresh;

  @override
  State<_StoryPollView> createState() => _StoryPollViewState();
}

class _StoryPollViewState extends State<_StoryPollView> {
  final StoryService _storyService = StoryService();

  bool _voting = false;

  @override
  Widget build(BuildContext context) {
    final StoryPoll? poll = widget.story.poll;

    if (poll == null) {
      return const ColoredBox(color: Colors.black);
    }

    final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    final bool voted = poll.votedUserIds.contains(uid);

    final int? selectedIndex = poll.userVotes[uid];

    final bool closed = widget.story.isExpired;

    int highestVotes = 0;
    final List<int> leaders = <int>[];

    for (int index = 0; index < poll.options.length; index++) {
      final int votes = poll.options[index].votes;
      if (votes > highestVotes) {
        highestVotes = votes;
        leaders
          ..clear()
          ..add(index);
      } else if (votes == highestVotes && votes > 0) {
        leaders.add(index);
      }
    }

    final int? winnerIndex = closed && leaders.length == 1
        ? leaders.first
        : null;

    return Container(
      color: Color(widget.story.backgroundColor),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: <Color>[Color(0xE6192630), Color(0xE60C1218)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white24),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Colors.black38,
              blurRadius: 24,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              poll.question,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 18),

            for (int index = 0; index < poll.options.length; index++)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: _buildPollOption(
                  poll: poll,
                  index: index,
                  voted: voted,
                  closed: closed,
                  selected: selectedIndex == index,
                  winner: winnerIndex == index,
                ),
              ),

            if (voted)
              Text(
                closed ? 'Final result' : 'Vote locked · cannot be changed',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPollOption({
    required StoryPoll poll,
    required int index,
    required bool voted,
    required bool closed,
    required bool selected,
    required bool winner,
  }) {
    final StoryPollOption option = poll.options[index];

    final double percentage = poll.totalVotes <= 0
        ? 0
        : option.votes / poll.totalVotes;

    return GestureDetector(
      onTap: voted || closed || _voting
          ? null
          : () async {
              setState(() {
                _voting = true;
              });

              try {
                await _storyService.votePoll(
                  story: widget.story,
                  optionIndex: index,
                );

                await widget.onRefresh();
              } finally {
                if (mounted) {
                  setState(() {
                    _voting = false;
                  });
                }
              }
            },
      child: Container(
        height: 52,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFF171F27),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: winner || (!closed && selected)
                ? const Color(0xFF29B6F6)
                : Colors.white24,
            width: winner || (!closed && selected) ? 1.6 : 1,
          ),
        ),
        child: Stack(
          children: <Widget>[
            if (closed)
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: percentage.clamp(0.0, 1.0).toDouble(),
                child: Container(
                  color: const Color(
                    0xFF29B6F6,
                  ).withValues(alpha: winner ? 0.88 : 0.58),
                ),
              ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: <Widget>[
                  if (!closed && selected)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF29B6F6),
                        size: 19,
                      ),
                    ),
                  Expanded(
                    child: Text(
                      option.text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  if (winner)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF29B6F6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'WINS',
                        style: TextStyle(
                          color: Color(0xFF06141B),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ),

                  if (closed)
                    Text(
                      '${(percentage * 100).round()}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

//===================================================
// RESHARED STORY
//===================================================

class _StoryReshare extends StatefulWidget {
  const _StoryReshare({required this.story, required this.onReady});

  final NubifyStory story;
  final VoidCallback onReady;

  @override
  State<_StoryReshare> createState() => _StoryReshareState();
}

class _StoryReshareState extends State<_StoryReshare> {
  bool _readyReported = false;

  void _reportReady() {
    if (_readyReported) {
      return;
    }
    _readyReported = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onReady();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final NubifyStory story = widget.story;
    if (story.sourceMediaUrl.trim().isEmpty) {
      _reportReady();
    }
    return Container(
      color: Color(story.backgroundColor),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(28),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.black45,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              story.sourceUsername.trim().isEmpty
                  ? 'Shared Story'
                  : '@${story.sourceUsername}',
              style: const TextStyle(
                color: Color(0xFF29B6F6),
                fontWeight: FontWeight.bold,
              ),
            ),

            if (story.sourceMediaUrl.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Image.network(
                    story.sourceMediaUrl,
                    height: 300,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    frameBuilder:
                        (
                          BuildContext context,
                          Widget child,
                          int? frame,
                          bool wasSynchronouslyLoaded,
                        ) {
                          if (wasSynchronouslyLoaded || frame != null) {
                            _reportReady();
                          }
                          return child;
                        },
                    errorBuilder: (_, _, _) {
                      _reportReady();
                      return const SizedBox(
                        height: 180,
                        child: Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white54,
                            size: 42,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

            if (story.sourceText.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  story.sourceText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

//===================================================
// SHARED POST
//===================================================
class _SharedPostStory extends StatelessWidget {
  const _SharedPostStory({
    required this.story,
    required this.forcePaused,
    required this.onContentReady,
    required this.onVideoProgress,
    required this.onVideoBufferingChanged,
    required this.onVideoCompleted,
    required this.onTaggedPersonTap,
  });
  final NubifyStory story;
  final bool forcePaused;
  final VoidCallback onContentReady;

  final ValueChanged<double> onVideoProgress;

  final ValueChanged<bool> onVideoBufferingChanged;

  final VoidCallback onVideoCompleted;
  final ValueChanged<StoryPerson> onTaggedPersonTap;
  //============================
  // SHARED POST READY
  //============================

  void _notifyReady() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onContentReady();
    });
  }

  @override
  Widget build(BuildContext context) {
    final String postId = story.postId.trim();
    //============================
    // EMPTY POST ID
    //============================

    if (postId.isEmpty) {
      _notifyReady();
    }

    //=============================
    // SAVED STICKER
    //=============================

    final String stickerTransform = story.textAlign.trim();

    double stickerX = 0.80;

    double stickerY = 0.14;

    //=============================
    // LOAD SAVED POSITION
    //=============================

    if (stickerTransform.startsWith('sticker:')) {
      final String positionData = stickerTransform.substring('sticker:'.length);

      final List<String> parts = positionData.split(',');

      if (parts.length == 2) {
        final double? savedX = double.tryParse(parts[0]);

        final double? savedY = double.tryParse(parts[1]);

        if (savedX != null) {
          stickerX = savedX.clamp(0.04, 0.96).toDouble();
        }

        if (savedY != null) {
          stickerY = savedY.clamp(0.04, 0.96).toDouble();
        }
      }
    }

    //=============================
    // LOAD SAVED SIZE
    //=============================

    final double stickerSize = stickerTransform.startsWith('sticker:')
        ? story.textSize.clamp(28.0, 120.0).toDouble()
        : 52.0;

    final Offset stickerPosition = Offset(stickerX, stickerY);

    return Container(
      color: Color(story.backgroundColor),
      child: Stack(
        children: <Widget>[
          //===================================================
          // LIVE SHARED POST CONTENT
          //===================================================

          Positioned.fill(
            child: Align(
              alignment: Alignment.center,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 74, 18, 130),
                child: postId.isEmpty
                    ? _sharedPostUnavailable('Shared post is unavailable.')
                    : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('posts')
                            .doc(postId)
                            .snapshots(),
                        builder:
                            (
                              BuildContext context,
                              AsyncSnapshot<
                                DocumentSnapshot<Map<String, dynamic>>
                              >
                              snapshot,
                            ) {
                              if (!snapshot.hasData) {
                                return const Center(
                                  child: CircularProgressIndicator(
                                    color: Color(0xFF29B6F6),
                                  ),
                                );
                              }

                              if (!snapshot.data!.exists ||
                                  snapshot.data!.data() == null) {
                                //============================
                                // POST FINISHED LOADING
                                // BUT DOES NOT EXIST
                                //============================

                                _notifyReady();

                                return _sharedPostUnavailable(
                                  'This post is no longer available.',
                                );
                              }
                              try {
                                final Post post = Post.fromFirestore(
                                  snapshot.data!,
                                );

                                return _sharedFullPostContent(context, post);
                              } catch (error) {
                                //============================
                                // POST DATA COULD NOT BE READ
                                //============================

                                _notifyReady();

                                return _sharedPostUnavailable(
                                  'Unable to display this shared post.',
                                );
                              }
                            },
                      ),
              ),
            ),
          ),
          //===================================================
          // STICKER
          //===================================================

          if (story.text.trim().isNotEmpty)
            Positioned.fill(
              child: IgnorePointer(
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    return Stack(
                      clipBehavior: Clip.none,
                      children: <Widget>[
                        Positioned(
                          left: (stickerPosition.dx * constraints.maxWidth)
                              .clamp(0.0, constraints.maxWidth)
                              .toDouble(),
                          top: (stickerPosition.dy * constraints.maxHeight)
                              .clamp(0.0, constraints.maxHeight)
                              .toDouble(),
                          child: Transform.translate(
                            offset: Offset(
                              -stickerSize * 0.55,
                              -stickerSize * 0.55,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                story.text.trim(),
                                style: TextStyle(
                                  fontSize: stickerSize,
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          //===================================================
          // TAGGED PEOPLE
          //===================================================

          if (story.taggedPeople.isNotEmpty)
            Positioned.fill(
              child: DraggableStoryTags(
                people: story.taggedPeople,

                editable: false,

                onPersonTap: onTaggedPersonTap,
              ),
            ),
        ],
      ),
    );
  }
  //=============================
  // FULL SHARED POST CONTENT
  //=============================

  Widget _sharedFullPostContent(BuildContext context, Post post) {
    return SharedPostStoryCard(
      post: post,

      forcePaused: forcePaused,

      maxWidth: 440,
      //============================
      // NETWORK CONTENT READY
      //============================

      onContentReady: onContentReady,
      //============================
      // REAL STORY VIDEO PROGRESS
      //============================

      storyVideoPlayback: true,

      onVideoProgress: onVideoProgress,

      onVideoBufferingChanged: onVideoBufferingChanged,

      onVideoCompleted: onVideoCompleted,

      //=============================
      // OPEN PROFILE
      //=============================
      onOpenProfile: (String uid) {
        final String cleanUid = uid.trim();

        if (cleanUid.isEmpty) {
          return;
        }

        Navigator.of(context).pushNamed('/profile', arguments: cleanUid);
      },

      //=============================
      // OPEN POST
      //=============================
      onOpenPost: (String postId) {
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => CommentsScreen(postId: postId),
          ),
        );
      },
    );
  }
  //===================================================
  // SHARED POST CONTENT
  //===================================================

  // ignore: unused_element
  Widget _sharedPostContent(BuildContext context, Post post) {
    final String displayName = post.fullName.trim().isNotEmpty
        ? post.fullName.trim()
        : post.username.trim().isNotEmpty
        ? post.username.trim()
        : 'Nubify User';

    final String quoteText = post.repostText.trim().isNotEmpty
        ? post.repostText.trim()
        : post.caption.trim();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => CommentsScreen(postId: post.postId),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 440),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white24),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.30),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(13),
              child: Row(
                children: <Widget>[
                  CircleAvatar(
                    radius: 21,
                    backgroundImage: post.photoUrl.trim().isNotEmpty
                        ? NetworkImage(post.photoUrl)
                        : null,
                    child: post.photoUrl.trim().isEmpty
                        ? const Icon(Icons.person)
                        : null,
                  ),

                  const SizedBox(width: 9),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),

                        Text(
                          '@${post.username}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (post.isNUBuzz)
                    const Icon(
                      Icons.play_circle_fill_rounded,
                      color: Color(0xFF29B6F6),
                      size: 27,
                    ),
                ],
              ),
            ),

            if (post.isRepost)
              Padding(
                padding: const EdgeInsets.fromLTRB(13, 0, 13, 8),
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.repeat_rounded,
                      size: 17,
                      color: Color(0xFF29B6F6),
                    ),

                    const SizedBox(width: 5),

                    Text(
                      post.isQuoteRepost ? 'Quote repost' : 'Reposted',
                      style: const TextStyle(
                        color: Color(0xFF29B6F6),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

            if (quoteText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(13, 0, 13, 12),
                child: Text(
                  quoteText,
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, height: 1.35),
                ),
              ),

            if (post.media.isNotEmpty)
              SizedBox(
                width: double.infinity,
                height: post.isNUBuzz ? 340 : 290,
                child: PostMediaCarousel(media: post.media),
              )
            else if (post.isRepost && post.sourcePostId.trim().isNotEmpty)
              _sharedReferencedPost(post.sourcePostId.trim()),

            Padding(
              padding: const EdgeInsets.fromLTRB(13, 10, 13, 13),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.favorite_border, size: 18),

                  const SizedBox(width: 4),

                  Text('${post.likeCount}'),

                  const SizedBox(width: 16),

                  const Icon(Icons.chat_bubble_outline, size: 17),

                  const SizedBox(width: 4),

                  Text('${post.commentCount}'),

                  const SizedBox(width: 16),

                  const Icon(Icons.repeat_rounded, size: 19),

                  const SizedBox(width: 4),

                  Text('${post.repostCount}'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  //===================================================
  // REFERENCED POST INSIDE SHARED REPOST
  //===================================================

  Widget _sharedReferencedPost(String postId) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .snapshots(),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
          ) {
            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF29B6F6),
                  ),
                ),
              );
            }

            if (!snapshot.data!.exists || snapshot.data!.data() == null) {
              return _sharedPostUnavailable('Referenced post is unavailable.');
            }

            try {
              final Post source = Post.fromFirestore(snapshot.data!);

              return Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white12),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      source.fullName.trim().isNotEmpty
                          ? source.fullName.trim()
                          : '@${source.username}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),

                    if (source.caption.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          source.caption.trim(),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                    if (source.media.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: SizedBox(
                          height: 220,
                          child: PostMediaCarousel(media: source.media),
                        ),
                      ),
                  ],
                ),
              );
            } catch (_) {
              return _sharedPostUnavailable(
                'Unable to display referenced post.',
              );
            }
          },
    );
  }

  //===================================================
  // SHARED POST UNAVAILABLE
  //===================================================

  Widget _sharedPostUnavailable(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.insert_drive_file_outlined,
            color: Colors.white70,
            size: 42,
          ),

          const SizedBox(height: 10),

          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

//===================================================
// CHAT PICKER
//===================================================

class _StoryChatPicker extends StatefulWidget {
  const _StoryChatPicker({required this.story, required this.onSend});

  final NubifyStory story;

  final Future<bool> Function(NubifyStory story, StoryPerson person) onSend;

  @override
  State<_StoryChatPicker> createState() => _StoryChatPickerState();
}

class _StoryChatPickerState extends State<_StoryChatPicker> {
  final TextEditingController _searchController = TextEditingController();

  final Set<String> _sending = <String>{};

  String _query = '';

  @override
  Widget build(BuildContext context) {
    final String currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Column(
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Text(
            'Send Story to Chat',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            onChanged: (String value) {
              setState(() {
                _query = value.trim().toLowerCase();
              });
            },
            decoration: InputDecoration(
              hintText: 'Search users...',
              hintStyle: const TextStyle(color: Colors.white54),
              prefixIcon: const Icon(Icons.search, color: Colors.white54),
              filled: true,
              fillColor: Colors.white10,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),

        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('users').snapshots(),
            builder:
                (
                  BuildContext context,
                  AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
                ) {
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF29B6F6),
                      ),
                    );
                  }

                  final List<StoryPerson> people = <StoryPerson>[];

                  for (final QueryDocumentSnapshot<Map<String, dynamic>>
                      document
                      in snapshot.data!.docs) {
                    if (document.id == currentUid) {
                      continue;
                    }

                    final StoryPerson person = StoryPerson.fromMap(
                      document.data(),
                      fallbackUid: document.id,
                    );

                    final String searchable =
                        '${person.fullName} ${person.username}'.toLowerCase();

                    if (_query.isNotEmpty && !searchable.contains(_query)) {
                      continue;
                    }

                    people.add(person);
                  }

                  if (people.isEmpty) {
                    return const Center(
                      child: Text(
                        'No users found.',
                        style: TextStyle(color: Colors.white54),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: people.length,
                    itemBuilder: (BuildContext context, int index) {
                      final StoryPerson person = people[index];

                      final bool sending = _sending.contains(person.uid);

                      return ListTile(
                        leading: _HeartAvatar(
                          photoUrl: person.photoUrl,
                          size: 44,
                        ),

                        title: Text(
                          person.displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        subtitle: person.username.trim().isEmpty
                            ? null
                            : Text(
                                '@${person.username}',
                                style: const TextStyle(color: Colors.white54),
                              ),

                        trailing: FilledButton(
                          onPressed: sending
                              ? null
                              : () async {
                                  setState(() {
                                    _sending.add(person.uid);
                                  });

                                  await widget.onSend(widget.story, person);

                                  if (!mounted) {
                                    return;
                                  }

                                  setState(() {
                                    _sending.remove(person.uid);
                                  });
                                },
                          child: sending
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Send'),
                        ),
                      );
                    },
                  );
                },
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _searchController.dispose();

    super.dispose();
  }
}

//===================================================
// OWNER ACTIVITY
//===================================================

class _StoryActivitySheet extends StatelessWidget {
  const _StoryActivitySheet({required this.story});

  final NubifyStory story;

  static const Color _blue = Color(0xFF29B6F6);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: <Widget>[
          const SizedBox(height: 8),

          const Text(
            'Story Activity',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 14),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: <Widget>[
                _ActivityCount(
                  icon: Icons.visibility_outlined,
                  label: 'Views',
                  count: story.viewCount,
                ),
                _ActivityCount(
                  icon: Icons.favorite,
                  label: 'Likes',
                  count: story.likeCount,
                  color: _blue,
                ),
                _ActivityCount(
                  icon: Icons.chat_bubble_outline,
                  label: 'Replies',
                  count: story.replyCount,
                ),
                _ActivityCount(
                  icon: Icons.send_outlined,
                  label: 'Shares',
                  count: story.shareCount,
                ),
                _ActivityCount(
                  icon: Icons.repeat,
                  label: 'Reshares',
                  count: story.reshareCount,
                ),
              ],
            ),
          ),

          const TabBar(
            indicatorColor: _blue,
            labelColor: _blue,
            unselectedLabelColor: Colors.white54,
            tabs: <Tab>[
              Tab(text: 'Viewers'),
              Tab(text: 'Replies'),
              Tab(text: 'Likes'),
            ],
          ),

          Expanded(
            child: TabBarView(
              children: <Widget>[
                _StoryViewersTab(storyId: story.storyId),
                _StoryRepliesTab(storyId: story.storyId),
                _StoryLikesTab(userIds: story.likedUserIds),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

//===================================================
// ACTIVITY COUNT
//===================================================

class _ActivityCount extends StatelessWidget {
  const _ActivityCount({
    required this.icon,
    required this.label,
    required this.count,
    this.color = Colors.white,
  });

  final IconData icon;

  final String label;

  final int count;

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: <Widget>[
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 3),
          Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 9),
          ),
        ],
      ),
    );
  }
}

//===================================================
// VIEWERS TAB
//===================================================

class _StoryViewersTab extends StatelessWidget {
  const _StoryViewersTab({required this.storyId});

  final String storyId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('stories')
          .doc(storyId)
          .collection('views')
          .orderBy('viewedAt', descending: true)
          .snapshots(),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
          ) {
            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF29B6F6)),
              );
            }

            final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
                snapshot.data!.docs;

            if (docs.isEmpty) {
              return const Center(
                child: Text(
                  'No viewers yet.',
                  style: TextStyle(color: Colors.white54),
                ),
              );
            }

            return ListView.builder(
              itemCount: docs.length,
              itemBuilder: (BuildContext context, int index) {
                final Map<String, dynamic> data = docs[index].data();

                final String uid = (data['uid'] ?? docs[index].id).toString();

                final Timestamp? viewedAt = data['viewedAt'] is Timestamp
                    ? data['viewedAt'] as Timestamp
                    : null;

                return _ActivityUserTile(
                  uid: uid,
                  trailingText: viewedAt == null
                      ? ''
                      : _activityTimeAgo(viewedAt.toDate()),
                );
              },
            );
          },
    );
  }
}

//===================================================
// REPLIES TAB
//===================================================

class _StoryRepliesTab extends StatelessWidget {
  const _StoryRepliesTab({required this.storyId});

  final String storyId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('stories')
          .doc(storyId)
          .collection('replies')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
          ) {
            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF29B6F6)),
              );
            }

            final docs = snapshot.data!.docs;

            if (docs.isEmpty) {
              return const Center(
                child: Text(
                  'No replies yet.',
                  style: TextStyle(color: Colors.white54),
                ),
              );
            }

            return ListView.builder(
              itemCount: docs.length,
              itemBuilder: (BuildContext context, int index) {
                final Map<String, dynamic> data = docs[index].data();

                final String uid = (data['uid'] ?? data['senderUid'] ?? '')
                    .toString();

                final String fullName = (data['fullName'] ?? '').toString();

                final String username = (data['username'] ?? '').toString();

                final String photoUrl = (data['photoUrl'] ?? '').toString();

                final String message = (data['text'] ?? data['message'] ?? '')
                    .toString();

                final Timestamp? createdAt = data['createdAt'] is Timestamp
                    ? data['createdAt'] as Timestamp
                    : null;

                return ListTile(
                  leading: GestureDetector(
                    onTap: uid.isEmpty
                        ? null
                        : () {
                            Navigator.of(
                              context,
                            ).pushNamed('/profile', arguments: uid);
                          },
                    child: _HeartAvatar(photoUrl: photoUrl, size: 43),
                  ),

                  title: GestureDetector(
                    onTap: uid.isEmpty
                        ? null
                        : () {
                            Navigator.of(
                              context,
                            ).pushNamed('/profile', arguments: uid);
                          },
                    child: Text(
                      fullName.isNotEmpty
                          ? fullName
                          : username.isNotEmpty
                          ? username
                          : 'Nubify User',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  subtitle: Text(
                    message,
                    style: const TextStyle(color: Colors.white70),
                  ),

                  trailing: createdAt == null
                      ? null
                      : Text(
                          _activityTimeAgo(createdAt.toDate()),
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 10,
                          ),
                        ),
                );
              },
            );
          },
    );
  }
}

//===================================================
// LIKES TAB
//===================================================

class _StoryLikesTab extends StatelessWidget {
  const _StoryLikesTab({required this.userIds});

  final List<String> userIds;

  @override
  Widget build(BuildContext context) {
    if (userIds.isEmpty) {
      return const Center(
        child: Text(
          'No reactions yet.',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return ListView.builder(
      itemCount: userIds.length,
      itemBuilder: (BuildContext context, int index) {
        return _ActivityUserTile(
          uid: userIds[index],
          trailing: const Icon(
            Icons.favorite,
            color: Color(0xFF29B6F6),
            size: 20,
          ),
        );
      },
    );
  }
}

//===================================================
// ACTIVITY USER TILE
//===================================================

class _ActivityUserTile extends StatelessWidget {
  const _ActivityUserTile({
    required this.uid,
    this.trailingText = '',
    this.trailing,
  });

  final String uid;

  final String trailingText;

  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
          ) {
            final Map<String, dynamic>? data = snapshot.data?.data();

            final String fullName = (data?['fullName'] ?? '').toString();

            final String username = (data?['username'] ?? '').toString();

            final String photoUrl = (data?['photoUrl'] ?? '').toString();

            final String displayName = fullName.isNotEmpty
                ? fullName
                : username.isNotEmpty
                ? username
                : 'Nubify User';

            return ListTile(
              onTap: uid.trim().isEmpty
                  ? null
                  : () {
                      Navigator.of(
                        context,
                      ).pushNamed('/profile', arguments: uid);
                    },

              leading: _HeartAvatar(photoUrl: photoUrl, size: 43),

              title: Text(
                displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),

              subtitle: username.isEmpty
                  ? null
                  : Text(
                      '@$username',
                      style: const TextStyle(color: Colors.white54),
                    ),

              trailing:
                  trailing ??
                  (trailingText.isEmpty
                      ? null
                      : Text(
                          trailingText,
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                          ),
                        )),
            );
          },
    );
  }
}

//===================================================
// ACTIVITY TIME
//===================================================

String _activityTimeAgo(DateTime date) {
  Duration difference = DateTime.now().difference(date);

  if (difference.isNegative) {
    difference = Duration.zero;
  }

  if (difference.inSeconds < 60) {
    return 'just now';
  }

  if (difference.inMinutes < 60) {
    return '${difference.inMinutes}m ago';
  }

  if (difference.inHours < 24) {
    return '${difference.inHours}h ago';
  }

  return '${difference.inDays}d ago';
}
