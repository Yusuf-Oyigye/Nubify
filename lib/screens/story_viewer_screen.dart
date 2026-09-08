import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../models/story.dart';
import '../services/story_service.dart';

//===================================================
// STORY VIEWER SCREEN
//===================================================

class StoryViewerScreen extends StatefulWidget {
  const StoryViewerScreen({
    super.key,
    required this.stories,
    this.initialIndex = 0,
  });

  final List<NubifyStory> stories;

  final int initialIndex;

  @override
  State<StoryViewerScreen> createState() =>
      _StoryViewerScreenState();
}

//===================================================
// STORY VIEWER STATE
//===================================================

class _StoryViewerScreenState
    extends State<StoryViewerScreen> {
  //===================================================
  // FIREBASE
  //===================================================

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  //===================================================
  // SERVICE
  //===================================================

  final StoryService _storyService =
  StoryService();

  //===================================================
  // STORIES
  //===================================================

  late List<NubifyStory> _stories;

  int _currentIndex = 0;

  //===================================================
  // PROGRESS
  //===================================================

  Timer? _progressTimer;

  Timer? _timeRefreshTimer;

  double _progress = 0;

  bool _progressPaused = false;

  bool _voiceCompletionHandled = false;

  //===================================================
  // COUNTS
  //===================================================

  bool _liked = false;

  bool _likeLoading = false;

  int _viewCount = 0;

  int _likeCount = 0;

  int _replyCount = 0;

  int _shareCount = 0;

  int _reshareCount = 0;

  //===================================================
  // REPLY
  //===================================================

  final TextEditingController _replyController =
  TextEditingController();

  final FocusNode _replyFocusNode =
  FocusNode();

  bool _sendingReply = false;

  //===================================================
  // OWNER SEEN
  //===================================================

  final Set<String> _ownerSeenStoryIds =
  <String>{};

  //===================================================
  // COLOR
  //===================================================

  static const Color _nubifyBlue =
  Color(
    0xFF29B6F6,
  );

  //===================================================
  // INIT
  //===================================================

  @override
  void initState() {
    super.initState();

    _stories =
        widget.stories
            .where(
              (
              NubifyStory story,
              ) =>
          !story.isExpired,
        )
            .toList();

    if (_stories.isNotEmpty) {
      _currentIndex =
          widget.initialIndex
              .clamp(
            0,
            _stories.length - 1,
          )
              .toInt();

      _prepareCurrentStory();
    }

    _replyFocusNode.addListener(
      _handleReplyFocus,
    );

    _timeRefreshTimer =
        Timer.periodic(
          const Duration(
            seconds: 20,
          ),
              (_) {
            _removeExpiredStories();

            if (mounted) {
              setState(() {});
            }
          },
        );
  }

  //===================================================
  // CURRENT STORY
  //===================================================

  NubifyStory? get _currentStory {
    if (_stories.isEmpty ||
        _currentIndex < 0 ||
        _currentIndex >=
            _stories.length) {
      return null;
    }

    return _stories[_currentIndex];
  }

  //===================================================
  // CURRENT UID
  //===================================================

  String get _currentUid =>
      _auth.currentUser?.uid ??
          '';

  //===================================================
  // OWNER
  //===================================================

  bool get _isOwner {
    final NubifyStory? story =
        _currentStory;

    if (story == null) {
      return false;
    }

    return _currentUid.isNotEmpty &&
        story.uid ==
            _currentUid;
  }

  //===================================================
  // OPEN STORY OWNER PROFILE
  //===================================================

  Future<void> _openStoryOwnerProfile(
      NubifyStory story,
      ) async {
    final String uid =
    story.uid.trim();

    if (uid.isEmpty ||
        !mounted) {
      return;
    }

    final bool oldPaused =
        _progressPaused;

    if (story.type !=
        'voice') {
      setState(() {
        _progressPaused =
        true;
      });
    }

    await Navigator.of(context).pushNamed(
      '/profile',
      arguments:
      uid,
    );

    if (!mounted) {
      return;
    }

    if (story.type !=
        'voice') {
      setState(() {
        _progressPaused =
            oldPaused;
      });
    }
  }

  //===================================================
  // REPLY FOCUS
  //===================================================

  void _handleReplyFocus() {
    final NubifyStory? story =
        _currentStory;

    if (!mounted ||
        story == null) {
      return;
    }

    if (story.type !=
        'voice') {
      setState(() {
        _progressPaused =
            _replyFocusNode.hasFocus;
      });
    }
  }

  //===================================================
  // PREPARE CURRENT STORY
  //===================================================

  void _prepareCurrentStory() {
    final NubifyStory? story =
        _currentStory;

    if (story == null) {
      return;
    }

    _progressTimer?.cancel();

    _progress = 0;

    _progressPaused = false;

    _voiceCompletionHandled =
    false;

    _liked =
        story.likedUserIds.contains(
          _currentUid,
        );

    _viewCount =
        story.viewCount;

    _likeCount =
        story.likeCount;

    _replyCount =
        story.replyCount;

    _shareCount =
        story.shareCount;

    _reshareCount =
        story.reshareCount;

    if (_isOwner) {
      _markOwnerStoryAsSeen(
        story,
      );
    } else {
      _recordView(
        story,
      );
    }

    //===================================================
    // VOICE USES REAL AUDIO POSITION
    //===================================================

    if (story.type !=
        'voice') {
      _startNormalProgress();
    }
  }

  //===================================================
  // OWNER SEES OWN STORY
  //
  // BORDER CAN TURN GREY
  // BUT OWNER DOES NOT ADD TO VIEW COUNT
  //===================================================

  Future<void> _markOwnerStoryAsSeen(
      NubifyStory story,
      ) async {
    final String uid =
        _currentUid;

    if (uid.isEmpty ||
        _ownerSeenStoryIds.contains(
          story.storyId,
        )) {
      return;
    }

    if (story.viewerIds.contains(
      uid,
    )) {
      _ownerSeenStoryIds.add(
        story.storyId,
      );

      return;
    }

    _ownerSeenStoryIds.add(
      story.storyId,
    );

    try {
      await _firestore
          .collection('stories')
          .doc(story.storyId)
          .update(
        <String, dynamic>{
          'viewerIds':
          FieldValue.arrayUnion(
            <String>[
              uid,
            ],
          ),
        },
      );
    } catch (error) {
      _ownerSeenStoryIds.remove(
        story.storyId,
      );

      debugPrint(
        'Owner Story seen error: $error',
      );
    }
  }

  //===================================================
  // RECORD VIEW
  //===================================================

  Future<void> _recordView(
      NubifyStory story,
      ) async {
    if (_currentUid.isEmpty) {
      return;
    }

    final bool alreadyViewed =
    story.viewerIds.contains(
      _currentUid,
    );

    try {
      await _storyService.recordView(
        story,
      );

      if (!mounted ||
          alreadyViewed) {
        return;
      }

      setState(() {
        _viewCount++;
      });
    } catch (error) {
      debugPrint(
        'Story view error: $error',
      );
    }
  }

  //===================================================
  // NORMAL STORY PROGRESS
  //
  // VOICE DOES NOT USE THIS
  //===================================================

  void _startNormalProgress() {
    _progressTimer?.cancel();

    final NubifyStory? story =
        _currentStory;

    if (story == null ||
        story.type ==
            'voice') {
      return;
    }

    final int seconds =
    story.durationSeconds
        .clamp(
      3,
      60,
    )
        .toInt();

    const int tickMilliseconds =
    100;

    final double increment =
        tickMilliseconds /
            (seconds * 1000);

    _progressTimer =
        Timer.periodic(
          const Duration(
            milliseconds:
            tickMilliseconds,
          ),
              (
              Timer timer,
              ) {
            if (!mounted ||
                _progressPaused) {
              return;
            }

            final double next =
                _progress +
                    increment;

            if (next >= 1) {
              timer.cancel();

              setState(() {
                _progress = 1;
              });

              Future<void>.delayed(
                const Duration(
                  milliseconds: 80,
                ),
                    () {
                  if (mounted) {
                    _nextStory();
                  }
                },
              );

              return;
            }

            setState(() {
              _progress =
                  next;
            });
          },
        );
  }

  //===================================================
  // VOICE PROGRESS
  //
  // ACTUAL AUDIO POSITION / DURATION
  //===================================================

  void _onVoiceProgress(
      double progress,
      ) {
    final NubifyStory? story =
        _currentStory;

    if (!mounted ||
        story == null ||
        story.type !=
            'voice' ||
        _voiceCompletionHandled) {
      return;
    }

    final double safe =
    progress
        .clamp(
      0.0,
      1.0,
    )
        .toDouble();

    setState(() {
      _progress =
          safe;
    });
  }

  //===================================================
  // VOICE COMPLETED
  //===================================================

  void _onVoiceCompleted() {
    final NubifyStory? story =
        _currentStory;

    if (!mounted ||
        story == null ||
        story.type !=
            'voice' ||
        _voiceCompletionHandled) {
      return;
    }

    _voiceCompletionHandled =
    true;

    setState(() {
      _progress = 1;
    });

    Future<void>.delayed(
      const Duration(
        milliseconds: 100,
      ),
          () {
        if (mounted) {
          _nextStory();
        }
      },
    );
  }

  //===================================================
  // MEDIA PAUSE
  //===================================================

  void _setMediaPaused(
      bool paused,
      ) {
    if (!mounted) {
      return;
    }

    setState(() {
      _progressPaused =
          paused;
    });
  }

  //===================================================
  // NEXT
  //===================================================

  void _nextStory() {
    if (_stories.isEmpty) {
      _closeViewer();

      return;
    }

    if (_currentIndex <
        _stories.length - 1) {
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
    if (_stories.isEmpty) {
      return;
    }

    final NubifyStory? story =
        _currentStory;

    if (story == null) {
      return;
    }

    if (story.type !=
        'voice' &&
        _progress >
            0.15) {
      setState(() {
        _progress = 0;
      });

      _startNormalProgress();

      return;
    }

    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });

      _prepareCurrentStory();

      return;
    }

    if (story.type !=
        'voice') {
      setState(() {
        _progress = 0;
      });

      _startNormalProgress();
    }
  }

  //===================================================
  // REMOVE EXPIRED
  //===================================================

  void _removeExpiredStories() {
    if (_stories.isEmpty) {
      return;
    }

    final String? currentId =
        _currentStory?.storyId;

    final List<NubifyStory> active =
    _stories
        .where(
          (
          NubifyStory story,
          ) =>
      !story.isExpired,
    )
        .toList();

    if (active.length ==
        _stories.length) {
      return;
    }

    if (active.isEmpty) {
      _closeViewer();

      return;
    }

    int newIndex =
    active.indexWhere(
          (
          NubifyStory story,
          ) =>
      story.storyId ==
          currentId,
    );

    if (newIndex < 0) {
      newIndex =
          _currentIndex
              .clamp(
            0,
            active.length - 1,
          )
              .toInt();
    }

    setState(() {
      _stories =
          active;

      _currentIndex =
          newIndex;
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
    final NubifyStory? story =
        _currentStory;

    if (story == null ||
        _isOwner ||
        _currentUid.isEmpty ||
        _likeLoading) {
      return;
    }

    setState(() {
      _likeLoading =
      true;
    });

    try {
      final bool liked =
      await _storyService.toggleLike(
        story,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _liked =
            liked;

        if (liked) {
          _likeCount++;
        } else if (_likeCount >
            0) {
          _likeCount--;
        }
      });
    } catch (error) {
      debugPrint(
        'Story like error: $error',
      );

      _showMessage(
        'Unable to update reaction.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _likeLoading =
          false;
        });
      }
    }
  }

  //===================================================
  // SEND REPLY
  //===================================================

  Future<void> _sendReply() async {
    final NubifyStory? story =
        _currentStory;

    if (story == null ||
        _isOwner ||
        _sendingReply) {
      return;
    }

    final String text =
    _replyController.text
        .trim();

    if (text.isEmpty) {
      return;
    }

    setState(() {
      _sendingReply =
      true;

      if (story.type !=
          'voice') {
        _progressPaused =
        true;
      }
    });

    try {
      await _storyService.replyToStory(
        story:
        story,
        message:
        text,
      );

      if (!mounted) {
        return;
      }

      _replyController.clear();

      _replyFocusNode.unfocus();

      setState(() {
        _replyCount++;
      });

      _showMessage(
        'Reply sent.',
      );
    } catch (error) {
      debugPrint(
        'Story reply error: $error',
      );

      _showMessage(
        'Unable to send reply.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _sendingReply =
          false;

          if (story.type !=
              'voice') {
            _progressPaused =
            false;
          }
        });
      }
    }
  }

  //===================================================
  // SHARE MENU
  //===================================================

  Future<void> _showShareMenu() async {
    final NubifyStory? story =
        _currentStory;

    if (story == null) {
      return;
    }

    _pauseForOverlay();

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor:
      const Color(
        0xFF171717,
      ),
      showDragHandle:
      true,
      builder: (
          BuildContext sheetContext,
          ) {
        return SafeArea(
          child: Column(
            mainAxisSize:
            MainAxisSize.min,
            children: <Widget>[
              const Padding(
                padding:
                EdgeInsets.only(
                  bottom: 8,
                ),
                child: Text(
                  'Share Story',
                  style:
                  TextStyle(
                    color:
                    Colors.white,
                    fontSize: 20,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
              ),

              if (!_isOwner)
                ListTile(
                  leading:
                  const Icon(
                    Icons
                        .add_to_photos_outlined,
                    color:
                    _nubifyBlue,
                  ),
                  title:
                  const Text(
                    'Reshare to my Story',
                    style:
                    TextStyle(
                      color:
                      Colors.white,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(
                      sheetContext,
                    );

                    await _reshareStory(
                      story,
                    );
                  },
                ),

              ListTile(
                leading:
                const Icon(
                  Icons
                      .chat_bubble_outline_rounded,
                  color:
                  _nubifyBlue,
                ),
                title:
                const Text(
                  'Send to Chat',
                  style:
                  TextStyle(
                    color:
                    Colors.white,
                  ),
                ),
                onTap: () {
                  Navigator.pop(
                    sheetContext,
                  );

                  _showChatPicker(
                    story,
                  );
                },
              ),

              ListTile(
                leading:
                const Icon(
                  Icons.share_outlined,
                  color:
                  Colors.white,
                ),
                title:
                const Text(
                  'Share to other apps',
                  style:
                  TextStyle(
                    color:
                    Colors.white,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(
                    sheetContext,
                  );

                  await _shareExternal(
                    story,
                  );
                },
              ),

              ListTile(
                leading:
                const Icon(
                  Icons.link,
                  color:
                  Colors.white,
                ),
                title:
                const Text(
                  'Copy Link',
                  style:
                  TextStyle(
                    color:
                    Colors.white,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(
                    sheetContext,
                  );

                  await _copyStoryLink(
                    story,
                  );
                },
              ),

              const SizedBox(
                height: 8,
              ),
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

  Future<void> _reshareStory(
      NubifyStory story,
      ) async {
    try {
      await _storyService.reshareStory(
        story,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _reshareCount++;
      });

      _showMessage(
        'Story added to your Story.',
      );
    } catch (error) {
      debugPrint(
        'Reshare Story error: $error',
      );

      _showMessage(
        'Unable to reshare Story.',
      );
    }
  }

  //===================================================
  // EXTERNAL SHARE
  //===================================================

  Future<void> _shareExternal(
      NubifyStory story,
      ) async {
    final String link =
        'https://nubify.app/story/${story.storyId}';

    final String text =
    story.caption.trim().isEmpty
        ? link
        : '${story.caption.trim()}\n\n$link';

    try {
      await SharePlus.instance.share(
        ShareParams(
          text:
          text,
        ),
      );

      await _storyService.incrementShare(
        story.storyId,
      );

      if (mounted) {
        setState(() {
          _shareCount++;
        });
      }
    } catch (error) {
      debugPrint(
        'Story share error: $error',
      );
    }
  }

  //===================================================
  // COPY STORY LINK
  //===================================================

  Future<void> _copyStoryLink(
      NubifyStory story,
      ) async {
    final String link =
        'https://nubify.app/story/${story.storyId}';

    await Clipboard.setData(
      ClipboardData(
        text:
        link,
      ),
    );

    try {
      await _storyService.incrementShare(
        story.storyId,
      );

      if (mounted) {
        setState(() {
          _shareCount++;
        });
      }
    } catch (_) {}

    _showMessage(
      'Story link copied.',
    );
  }

  //===================================================
  // CHAT PICKER
  //===================================================

  Future<void> _showChatPicker(
      NubifyStory story,
      ) async {
    _pauseForOverlay();

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor:
      const Color(
        0xFF101114,
      ),
      isScrollControlled:
      true,
      useSafeArea:
      true,
      builder: (
          BuildContext context,
          ) {
        return FractionallySizedBox(
          heightFactor:
          0.82,
          child: _StoryChatPicker(
            story:
            story,
            onSend:
            _sendStoryToChat,
          ),
        );
      },
    );

    _resumeAfterOverlay();
  }

  //===================================================
  // SEND STORY TO CHAT
  //===================================================

  Future<bool> _sendStoryToChat(
      NubifyStory story,
      StoryPerson person,
      ) async {
    final String senderUid =
        _currentUid;

    final String receiverUid =
    person.uid.trim();

    if (senderUid.isEmpty ||
        receiverUid.isEmpty ||
        senderUid ==
            receiverUid) {
      return false;
    }

    try {
      final List<String> users =
      <String>[
        senderUid,
        receiverUid,
      ]..sort();

      final String conversationId =
      users.join(
        '_',
      );

      final DocumentReference<
          Map<String, dynamic>>
      conversationRef =
      _firestore
          .collection(
        'conversations',
      )
          .doc(
        conversationId,
      );

      final DocumentReference<
          Map<String, dynamic>>
      messageRef =
      conversationRef
          .collection(
        'messages',
      )
          .doc();

      final Timestamp now =
      Timestamp.now();

      final WriteBatch batch =
      _firestore.batch();

      batch.set(
        conversationRef,
        <String, dynamic>{
          'conversationId':
          conversationId,
          'participants':
          users,
          'participantIds':
          users,
          'members':
          users,
          'lastMessage':
          'Shared a Story',
          'lastMessageType':
          'story',
          'lastStoryId':
          story.storyId,
          'lastSenderId':
          senderUid,
          'lastMessageAt':
          now,
          'updatedAt':
          now,
        },
        SetOptions(
          merge: true,
        ),
      );

      batch.set(
        messageRef,
        <String, dynamic>{
          'messageId':
          messageRef.id,
          'conversationId':
          conversationId,
          'senderId':
          senderUid,
          'senderUid':
          senderUid,
          'receiverId':
          receiverUid,
          'recipientId':
          receiverUid,
          'type':
          'story',
          'messageType':
          'story',
          'storyId':
          story.storyId,
          'sharedStoryId':
          story.storyId,
          'storyOwnerId':
          story.uid,
          'storyUsername':
          story.username,
          'storyType':
          story.type,
          'storyMediaUrl':
          story.mediaUrl,
          'storyMediaUrls':
          story.mediaUrls,
          'storyText':
          story.text,
          'text':
          'Shared a Story',
          'createdAt':
          now,
          'timestamp':
          now,
          'isRead':
          false,
          'seenBy':
          <String>[
            senderUid,
          ],
        },
      );

      await batch.commit();

      try {
        await _storyService.incrementShare(
          story.storyId,
        );
      } catch (_) {}

      if (mounted) {
        setState(() {
          _shareCount++;
        });

        _showMessage(
          'Story sent to @${person.username}.',
        );
      }

      return true;
    } catch (error) {
      debugPrint(
        'Send Story chat error: $error',
      );

      _showMessage(
        'Unable to send Story.',
      );

      return false;
    }
  }

  //===================================================
  // OWNER ACTIVITY
  //===================================================

  Future<void> _showOwnerActivity() async {
    final NubifyStory? story =
        _currentStory;

    if (story == null ||
        !_isOwner) {
      return;
    }

    _pauseForOverlay();

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor:
      const Color(
        0xFF101114,
      ),
      useSafeArea:
      true,
      isScrollControlled:
      true,
      builder: (
          BuildContext context,
          ) {
        return FractionallySizedBox(
          heightFactor:
          0.86,
          child: _StoryActivitySheet(
            story:
            story,
          ),
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
    final NubifyStory? story =
        _currentStory;

    if (story == null) {
      return;
    }

    try {
      final NubifyStory? updated =
      await _storyService.getStory(
        story.storyId,
      );

      if (updated == null ||
          !mounted) {
        return;
      }

      setState(() {
        _stories[_currentIndex] =
            updated;

        _liked =
            updated.likedUserIds.contains(
              _currentUid,
            );

        _viewCount =
            updated.viewCount;

        _likeCount =
            updated.likeCount;

        _replyCount =
            updated.replyCount;

        _shareCount =
            updated.shareCount;

        _reshareCount =
            updated.reshareCount;
      });
    } catch (error) {
      debugPrint(
        'Story refresh error: $error',
      );
    }
  }

  //===================================================
  // MORE MENU
  //===================================================

  Future<void> _showMoreMenu() async {
    final NubifyStory? story =
        _currentStory;

    if (story == null) {
      return;
    }

    _pauseForOverlay();

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor:
      const Color(
        0xFF171717,
      ),
      showDragHandle:
      true,
      builder: (
          BuildContext sheetContext,
          ) {
        return SafeArea(
          child: Column(
            mainAxisSize:
            MainAxisSize.min,
            children: <Widget>[
              if (_isOwner)
                ListTile(
                  leading:
                  const Icon(
                    Icons
                        .delete_outline_rounded,
                    color:
                    Colors.redAccent,
                  ),
                  title:
                  const Text(
                    'Delete Story',
                    style:
                    TextStyle(
                      color:
                      Colors.redAccent,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(
                      sheetContext,
                    );

                    _deleteStory(
                      story,
                    );
                  },
                )
              else
                ListTile(
                  leading:
                  const Icon(
                    Icons.flag_outlined,
                    color:
                    Colors.white,
                  ),
                  title:
                  const Text(
                    'Report Story',
                    style:
                    TextStyle(
                      color:
                      Colors.white,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(
                      sheetContext,
                    );

                    _reportStory(
                      story,
                    );
                  },
                ),

              ListTile(
                leading:
                const Icon(
                  Icons.link,
                  color:
                  Colors.white,
                ),
                title:
                const Text(
                  'Copy Link',
                  style:
                  TextStyle(
                    color:
                    Colors.white,
                  ),
                ),
                onTap: () {
                  Navigator.pop(
                    sheetContext,
                  );

                  _copyStoryLink(
                    story,
                  );
                },
              ),

              const SizedBox(
                height: 8,
              ),
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

  Future<void> _deleteStory(
      NubifyStory story,
      ) async {
    final bool? confirmed =
    await showDialog<bool>(
      context: context,
      builder: (
          BuildContext dialogContext,
          ) {
        return AlertDialog(
          title:
          const Text(
            'Delete Story?',
          ),
          content:
          const Text(
            'This Story will be permanently removed.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child:
              const Text(
                'Cancel',
              ),
            ),

            FilledButton(
              style:
              FilledButton.styleFrom(
                backgroundColor:
                Colors.red,
              ),
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child:
              const Text(
                'Delete',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _storyService.deleteStory(
        story,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _stories.removeWhere(
              (
              NubifyStory item,
              ) =>
          item.storyId ==
              story.storyId,
        );

        if (_stories.isNotEmpty &&
            _currentIndex >=
                _stories.length) {
          _currentIndex =
              _stories.length -
                  1;
        }
      });

      if (_stories.isEmpty) {
        _closeViewer();

        return;
      }

      _prepareCurrentStory();
    } catch (error) {
      debugPrint(
        'Delete Story error: $error',
      );

      _showMessage(
        'Unable to delete Story.',
      );
    }
  }

  //===================================================
  // REPORT STORY
  //===================================================

  Future<void> _reportStory(
      NubifyStory story,
      ) async {
    try {
      await _firestore
          .collection('reports')
          .add(
        <String, dynamic>{
          'type':
          'story',
          'storyId':
          story.storyId,
          'reportedStoryOwnerId':
          story.uid,
          'reportedBy':
          _currentUid,
          'reason':
          'Reported from Story viewer',
          'status':
          'pending',
          'createdAt':
          FieldValue.serverTimestamp(),
        },
      );

      _showMessage(
        'Story reported.',
      );
    } catch (error) {
      debugPrint(
        'Report Story error: $error',
      );

      _showMessage(
        'Unable to report Story.',
      );
    }
  }

  //===================================================
  // PAUSE FOR OVERLAY
  //===================================================

  void _pauseForOverlay() {
    final NubifyStory? story =
        _currentStory;

    if (!mounted ||
        story == null) {
      return;
    }

    if (story.type !=
        'voice') {
      setState(() {
        _progressPaused =
        true;
      });
    }
  }

  //===================================================
  // RESUME
  //===================================================

  void _resumeAfterOverlay() {
    final NubifyStory? story =
        _currentStory;

    if (!mounted ||
        story == null) {
      return;
    }

    if (story.type !=
        'voice') {
      setState(() {
        _progressPaused =
        false;
      });
    }
  }

  //===================================================
  // TIME AGO
  //===================================================

  String _timeAgo(
      DateTime createdAt,
      ) {
    Duration difference =
    DateTime.now().difference(
      createdAt,
    );

    if (difference.isNegative) {
      difference =
          Duration.zero;
    }

    if (difference.inSeconds <
        60) {
      return 'just now';
    }

    if (difference.inMinutes <
        60) {
      return '${difference.inMinutes}m ago';
    }

    if (difference.inHours <
        24) {
      return '${difference.inHours}h ago';
    }

    return '24h ago';
  }

  //===================================================
  // BUILD
  //===================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    final NubifyStory? story =
        _currentStory;

    if (story == null) {
      return const Scaffold(
        backgroundColor:
        Colors.black,
        body:
        Center(
          child: Text(
            'Story unavailable',
            style:
            TextStyle(
              color:
              Colors.white,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor:
      Colors.black,
      resizeToAvoidBottomInset:
      true,
      body: Stack(
        fit:
        StackFit.expand,
        children: <Widget>[
          _StoryContent(
            key:
            ValueKey<String>(
              story.storyId,
            ),
            story:
            story,
            onPauseChanged:
            _setMediaPaused,
            onVoiceProgress:
            _onVoiceProgress,
            onVoiceCompleted:
            _onVoiceCompleted,
            onRefresh:
            _refreshCurrentStory,
          ),

          //===================================================
          // TOP GRADIENT
          //===================================================

          IgnorePointer(
            child: Align(
              alignment:
              Alignment.topCenter,
              child: Container(
                height:
                155,
                decoration:
                const BoxDecoration(
                  gradient:
                  LinearGradient(
                    begin:
                    Alignment.topCenter,
                    end:
                    Alignment.bottomCenter,
                    colors:
                    <Color>[
                      Color(
                        0xC0000000,
                      ),
                      Colors.transparent,
                    ],
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
              alignment:
              Alignment.bottomCenter,
              child: Container(
                height:
                180,
                decoration:
                const BoxDecoration(
                  gradient:
                  LinearGradient(
                    begin:
                    Alignment.bottomCenter,
                    end:
                    Alignment.topCenter,
                    colors:
                    <Color>[
                      Color(
                        0xD0000000,
                      ),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: <Widget>[
                _buildProgressBars(),

                _buildHeader(
                  story,
                ),

                const Spacer(),

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
            width:
            MediaQuery.of(
              context,
            )
                .size
                .width *
                0.20,
            child: GestureDetector(
              behavior:
              HitTestBehavior.translucent,
              onTap:
              _previousStory,
            ),
          ),

          Positioned(
            right: 0,
            top: 105,
            bottom: 120,
            width:
            MediaQuery.of(
              context,
            )
                .size
                .width *
                0.20,
            child: GestureDetector(
              behavior:
              HitTestBehavior.translucent,
              onTap:
              _nextStory,
            ),
          ),
        ],
      ),
    );
  }

  //===================================================
  // PROGRESS BARS
  //===================================================

  Widget _buildProgressBars() {
    return Padding(
      padding:
      const EdgeInsets.fromLTRB(
        8,
        7,
        8,
        4,
      ),
      child: Row(
        children:
        List<Widget>.generate(
          _stories.length,
              (
              int index,
              ) {
            double value = 0;

            if (index <
                _currentIndex) {
              value = 1;
            } else if (index ==
                _currentIndex) {
              value =
                  _progress;
            }

            return Expanded(
              child: Container(
                height:
                3.2,
                margin:
                const EdgeInsets.symmetric(
                  horizontal: 2,
                ),
                clipBehavior:
                Clip.antiAlias,
                decoration:
                BoxDecoration(
                  color:
                  Colors.white30,
                  borderRadius:
                  BorderRadius.circular(
                    20,
                  ),
                ),
                child:
                FractionallySizedBox(
                  alignment:
                  Alignment.centerLeft,
                  widthFactor:
                  value
                      .clamp(
                    0.0,
                    1.0,
                  )
                      .toDouble(),
                  child: Container(
                    color:
                    Colors.white,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  //===================================================
  // HEADER
  //===================================================

  Widget _buildHeader(
      NubifyStory story,
      ) {
    final String displayName =
    story.fullName.trim().isNotEmpty
        ? story.fullName.trim()
        : story.username.trim();

    return Padding(
      padding:
      const EdgeInsets.fromLTRB(
        12,
        5,
        4,
        0,
      ),
      child: Row(
        children: <Widget>[
          //===================================================
          // HEART PROFILE -> PROFILE PAGE
          //===================================================

          GestureDetector(
            behavior:
            HitTestBehavior.opaque,
            onTap: () {
              _openStoryOwnerProfile(
                story,
              );
            },
            child: _HeartAvatar(
              photoUrl:
              story.photoUrl,
              size:
              45,
            ),
          ),

          const SizedBox(
            width: 10,
          ),

          //===================================================
          // NAME / USERNAME -> PROFILE PAGE
          //===================================================

          Expanded(
            child: GestureDetector(
              behavior:
              HitTestBehavior.opaque,
              onTap: () {
                _openStoryOwnerProfile(
                  story,
                );
              },
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          displayName,
                          maxLines:
                          1,
                          overflow:
                          TextOverflow.ellipsis,
                          style:
                          const TextStyle(
                            color:
                            Colors.white,
                            fontSize:
                            14,
                            fontWeight:
                            FontWeight.w700,
                          ),
                        ),
                      ),

                      const SizedBox(
                        width: 7,
                      ),

                      Text(
                        _timeAgo(
                          story.createdAt,
                        ),
                        style:
                        const TextStyle(
                          color:
                          Colors.white70,
                          fontSize:
                          11,
                        ),
                      ),
                    ],
                  ),

                  if (story.username
                      .trim()
                      .isNotEmpty)
                    Text(
                      '@${story.username.trim()}',
                      maxLines:
                      1,
                      overflow:
                      TextOverflow.ellipsis,
                      style:
                      const TextStyle(
                        color:
                        Colors.white60,
                        fontSize:
                        11,
                      ),
                    ),
                ],
              ),
            ),
          ),

          IconButton(
            onPressed:
            _showMoreMenu,
            icon:
            const Icon(
              Icons.more_vert,
              color:
              Colors.white,
            ),
          ),

          IconButton(
            onPressed:
            _closeViewer,
            icon:
            const Icon(
              Icons.close,
              color:
              Colors.white,
              size:
              28,
            ),
          ),
        ],
      ),
    );
  }

  //===================================================
  // VIEWER BOTTOM BAR
  //===================================================

  Widget _buildViewerBottomBar() {
    return Padding(
      padding:
      EdgeInsets.fromLTRB(
        12,
        8,
        12,
        MediaQuery.of(
          context,
        ).viewInsets.bottom >
            0
            ? 8
            : 12,
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: TextField(
              controller:
              _replyController,
              focusNode:
              _replyFocusNode,
              minLines:
              1,
              maxLines:
              3,
              textInputAction:
              TextInputAction.send,
              style:
              const TextStyle(
                color:
                Colors.white,
              ),
              onSubmitted: (_) {
                _sendReply();
              },
              decoration:
              InputDecoration(
                hintText:
                'Send a message...',
                hintStyle:
                const TextStyle(
                  color:
                  Colors.white54,
                ),
                contentPadding:
                const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                enabledBorder:
                OutlineInputBorder(
                  borderRadius:
                  BorderRadius.circular(
                    25,
                  ),
                  borderSide:
                  const BorderSide(
                    color:
                    Colors.white30,
                  ),
                ),
                focusedBorder:
                OutlineInputBorder(
                  borderRadius:
                  BorderRadius.circular(
                    25,
                  ),
                  borderSide:
                  const BorderSide(
                    color:
                    _nubifyBlue,
                    width:
                    1.5,
                  ),
                ),
                suffixIcon:
                _sendingReply
                    ? const Padding(
                  padding:
                  EdgeInsets.all(
                    13,
                  ),
                  child:
                  SizedBox(
                    width:
                    16,
                    height:
                    16,
                    child:
                    CircularProgressIndicator(
                      strokeWidth:
                      2,
                      color:
                      _nubifyBlue,
                    ),
                  ),
                )
                    : IconButton(
                  onPressed:
                  _sendReply,
                  icon:
                  const Icon(
                    Icons.send,
                    color:
                    _nubifyBlue,
                    size:
                    20,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(
            width: 10,
          ),

          GestureDetector(
            behavior:
            HitTestBehavior.opaque,
            onTap:
            _toggleLike,
            child: Padding(
              padding:
              const EdgeInsets.symmetric(
                horizontal: 3,
              ),
              child: Column(
                mainAxisSize:
                MainAxisSize.min,
                children: <Widget>[
                  _likeLoading
                      ? const SizedBox(
                    width:
                    29,
                    height:
                    29,
                    child:
                    CircularProgressIndicator(
                      strokeWidth:
                      2,
                      color:
                      _nubifyBlue,
                    ),
                  )
                      : Icon(
                    _liked
                        ? Icons.favorite
                        : Icons
                        .favorite_border,
                    color:
                    _liked
                        ? _nubifyBlue
                        : Colors.white,
                    size:
                    30,
                  ),

                  if (_likeCount >
                      0)
                    Text(
                      '$_likeCount',
                      style:
                      const TextStyle(
                        color:
                        Colors.white,
                        fontSize:
                        10,
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(
            width: 12,
          ),

          GestureDetector(
            behavior:
            HitTestBehavior.opaque,
            onTap:
            _showShareMenu,
            child: Padding(
              padding:
              const EdgeInsets.symmetric(
                horizontal: 3,
              ),
              child: Column(
                mainAxisSize:
                MainAxisSize.min,
                children: <Widget>[
                  const Icon(
                    Icons.send_outlined,
                    color:
                    Colors.white,
                    size:
                    29,
                  ),

                  if (_shareCount >
                      0)
                    Text(
                      '$_shareCount',
                      style:
                      const TextStyle(
                        color:
                        Colors.white,
                        fontSize:
                        10,
                      ),
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
      padding:
      const EdgeInsets.fromLTRB(
        12,
        8,
        12,
        12,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: GestureDetector(
              onTap:
              _showOwnerActivity,
              child: Container(
                height:
                50,
                padding:
                const EdgeInsets.symmetric(
                  horizontal: 12,
                ),
                decoration:
                BoxDecoration(
                  color:
                  Colors.black45,
                  borderRadius:
                  BorderRadius.circular(
                    25,
                  ),
                  border:
                  Border.all(
                    color:
                    Colors.white30,
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons
                          .visibility_outlined,
                      color:
                      Colors.white,
                      size:
                      20,
                    ),

                    const SizedBox(
                      width: 5,
                    ),

                    Text(
                      '$_viewCount',
                      style:
                      const TextStyle(
                        color:
                        Colors.white,
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                      width: 13,
                    ),

                    const Icon(
                      Icons.favorite,
                      color:
                      _nubifyBlue,
                      size:
                      19,
                    ),

                    const SizedBox(
                      width: 4,
                    ),

                    Text(
                      '$_likeCount',
                      style:
                      const TextStyle(
                        color:
                        Colors.white,
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                      width: 13,
                    ),

                    const Icon(
                      Icons
                          .chat_bubble_outline,
                      color:
                      Colors.white,
                      size:
                      18,
                    ),

                    const SizedBox(
                      width: 4,
                    ),

                    Text(
                      '$_replyCount',
                      style:
                      const TextStyle(
                        color:
                        Colors.white,
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),

                    const Spacer(),

                    const Text(
                      'Activity',
                      style:
                      TextStyle(
                        color:
                        Colors.white,
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),

                    const Icon(
                      Icons.keyboard_arrow_up,
                      color:
                      Colors.white,
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(
            width: 10,
          ),

          GestureDetector(
            onTap:
            _showShareMenu,
            child:
            const Padding(
              padding:
              EdgeInsets.all(
                7,
              ),
              child: Icon(
                Icons.send_outlined,
                color:
                Colors.white,
                size:
                29,
              ),
            ),
          ),
        ],
      ),
    );
  }

  //===================================================
  // MESSAGE
  //===================================================

  void _showMessage(
      String message,
      ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content:
        Text(
          message,
        ),
      ),
    );
  }

  //===================================================
  // DISPOSE
  //===================================================

  @override
  void dispose() {
    _progressTimer?.cancel();

    _timeRefreshTimer?.cancel();

    _replyFocusNode.removeListener(
      _handleReplyFocus,
    );

    _replyController.dispose();

    _replyFocusNode.dispose();

    super.dispose();
  }
}

//===================================================
// HEART AVATAR
//===================================================

class _HeartAvatar extends StatelessWidget {
  const _HeartAvatar({
    required this.photoUrl,
    required this.size,
  });

  final String photoUrl;

  final double size;

  @override
  Widget build(
      BuildContext context,
      ) {
    return SizedBox(
      width:
      size,
      height:
      size,
      child: Stack(
        fit:
        StackFit.expand,
        children: <Widget>[
          CustomPaint(
            painter:
            _HeartBorderPainter(
              color:
              const Color(
                0xFF29B6F6,
              ),
              strokeWidth:
              3.2,
            ),
          ),

          Padding(
            padding:
            const EdgeInsets.all(
              4.5,
            ),
            child: ClipPath(
              clipper:
              _HeartClipper(),
              child: Container(
                color:
                Colors.grey.shade800,
                child:
                photoUrl.trim().isNotEmpty
                    ? Image.network(
                  photoUrl,
                  fit:
                  BoxFit.cover,
                  errorBuilder:
                      (
                      BuildContext context,
                      Object error,
                      StackTrace? stackTrace,
                      ) {
                    return const Icon(
                      Icons.person,
                      color:
                      Colors.white70,
                    );
                  },
                )
                    : const Icon(
                  Icons.person,
                  color:
                  Colors.white70,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

//===================================================
// HEART CLIPPER
//===================================================

class _HeartClipper
    extends CustomClipper<Path> {
  @override
  Path getClip(
      Size size,
      ) {
    return _heartPath(
      size,
      0,
    );
  }

  @override
  bool shouldReclip(
      covariant CustomClipper<Path>
      oldClipper,
      ) {
    return false;
  }
}

//===================================================
// HEART BORDER
//===================================================

class _HeartBorderPainter
    extends CustomPainter {
  const _HeartBorderPainter({
    required this.color,
    required this.strokeWidth,
  });

  final Color color;

  final double strokeWidth;

  @override
  void paint(
      Canvas canvas,
      Size size,
      ) {
    final Path path =
    _heartPath(
      size,
      strokeWidth / 2 +
          0.5,
    );

    final Paint paint =
    Paint()
      ..color =
          color
      ..style =
          PaintingStyle.stroke
      ..strokeWidth =
          strokeWidth
      ..strokeJoin =
          StrokeJoin.round
      ..strokeCap =
          StrokeCap.round
      ..isAntiAlias =
      true;

    canvas.drawPath(
      path,
      paint,
    );
  }

  @override
  bool shouldRepaint(
      covariant _HeartBorderPainter
      oldDelegate,
      ) {
    return oldDelegate.color !=
        color ||
        oldDelegate.strokeWidth !=
            strokeWidth;
  }
}

//===================================================
// HEART PATH
//===================================================

Path _heartPath(
    Size size,
    double inset,
    ) {
  final double left =
      inset;

  final double top =
      inset;

  final double width =
      size.width -
          inset * 2;

  final double height =
      size.height -
          inset * 2;

  final double centerX =
      left +
          width / 2;

  final Path path =
  Path();

  path.moveTo(
    centerX,
    top +
        height * 0.96,
  );

  path.cubicTo(
    left +
        width * 0.40,
    top +
        height * 0.82,
    left +
        width * 0.05,
    top +
        height * 0.60,
    left +
        width * 0.05,
    top +
        height * 0.34,
  );

  path.cubicTo(
    left +
        width * 0.05,
    top +
        height * 0.12,
    left +
        width * 0.22,
    top +
        height * 0.03,
    left +
        width * 0.37,
    top +
        height * 0.03,
  );

  path.cubicTo(
    left +
        width * 0.46,
    top +
        height * 0.03,
    centerX,
    top +
        height * 0.12,
    centerX,
    top +
        height * 0.20,
  );

  path.cubicTo(
    centerX,
    top +
        height * 0.12,
    left +
        width * 0.54,
    top +
        height * 0.03,
    left +
        width * 0.63,
    top +
        height * 0.03,
  );

  path.cubicTo(
    left +
        width * 0.78,
    top +
        height * 0.03,
    left +
        width * 0.95,
    top +
        height * 0.12,
    left +
        width * 0.95,
    top +
        height * 0.34,
  );

  path.cubicTo(
    left +
        width * 0.95,
    top +
        height * 0.60,
    left +
        width * 0.60,
    top +
        height * 0.82,
    centerX,
    top +
        height * 0.96,
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
    required this.onPauseChanged,
    required this.onVoiceProgress,
    required this.onVoiceCompleted,
    required this.onRefresh,
  });

  final NubifyStory story;

  final ValueChanged<bool>
  onPauseChanged;

  final ValueChanged<double>
  onVoiceProgress;

  final VoidCallback
  onVoiceCompleted;

  final Future<void> Function()
  onRefresh;

  @override
  Widget build(
      BuildContext context,
      ) {
    switch (story.type) {
      case 'image':
        return _StoryImage(
          url:
          story.mediaUrl,
        );

      case 'video':
        return _StoryVideo(
          url:
          story.mediaUrl,
          onPauseChanged:
          onPauseChanged,
        );

      case 'voice':
        return _StoryVoicePlayer(
          url:
          story.mediaUrl,
          backgroundColor:
          story.backgroundColor,
          fallbackDurationSeconds:
          story.durationSeconds,
          onPauseChanged:
          onPauseChanged,
          onProgressChanged:
          onVoiceProgress,
          onCompleted:
          onVoiceCompleted,
        );

      case 'layout':
        return _StoryLayout(
          story:
          story,
        );

      case 'poll':
        return _StoryPollView(
          story:
          story,
          onRefresh:
          onRefresh,
        );

      case 'reshare':
        return _StoryReshare(
          story:
          story,
        );

      case 'postShare':
      case 'post_share':
      case 'videoShare':
      case 'video_share':
        return _SharedPostStory(
          story:
          story,
        );

      case 'text':
      default:
        return _StoryText(
          story:
          story,
        );
    }
  }
}

//===================================================
// IMAGE STORY
//===================================================

class _StoryImage extends StatelessWidget {
  const _StoryImage({
    required this.url,
  });

  final String url;

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      color:
      Colors.black,
      alignment:
      Alignment.center,
      child:
      url.trim().isEmpty
          ? const Icon(
        Icons
            .broken_image_outlined,
        color:
        Colors.white54,
        size:
        60,
      )
          : Image.network(
        url,
        width:
        double.infinity,
        height:
        double.infinity,
        fit:
        BoxFit.contain,
        errorBuilder:
            (
            BuildContext context,
            Object error,
            StackTrace? stackTrace,
            ) {
          return const Icon(
            Icons
                .broken_image_outlined,
            color:
            Colors.white54,
            size:
            60,
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
  const _StoryText({
    required this.story,
  });

  final NubifyStory story;

  @override
  Widget build(
      BuildContext context,
      ) {
    TextAlign align =
        TextAlign.center;

    if (story.textAlign ==
        'left') {
      align =
          TextAlign.left;
    } else if (story.textAlign ==
        'right') {
      align =
          TextAlign.right;
    }

    return Container(
      color:
      Color(
        story.backgroundColor,
      ),
      alignment:
      Alignment.center,
      padding:
      const EdgeInsets.symmetric(
        horizontal: 28,
      ),
      child: Text(
        story.text,
        textAlign:
        align,
        style: TextStyle(
          color:
          Color(
            story.textColor,
          ),
          fontSize:
          story.textSize,
          fontWeight:
          story.textStyle ==
              'bold'
              ? FontWeight.w800
              : FontWeight.w500,
          fontStyle:
          story.textStyle ==
              'italic'
              ? FontStyle.italic
              : FontStyle.normal,
          fontFamily:
          story.textStyle ==
              'mono'
              ? 'monospace'
              : null,
        ),
      ),
    );
  }
}

//===================================================
// VIDEO STORY
//===================================================

class _StoryVideo
    extends StatefulWidget {
  const _StoryVideo({
    required this.url,
    required this.onPauseChanged,
  });

  final String url;

  final ValueChanged<bool>
  onPauseChanged;

  @override
  State<_StoryVideo> createState() =>
      _StoryVideoState();
}

class _StoryVideoState
    extends State<_StoryVideo> {
  VideoPlayerController? _controller;

  bool _loading = true;

  bool _error = false;

  @override
  void initState() {
    super.initState();

    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final VideoPlayerController controller =
      VideoPlayerController.networkUrl(
        Uri.parse(
          widget.url,
        ),
      );

      await controller.initialize();

      await controller.setLooping(
        true,
      );

      await controller.setVolume(
        1,
      );

      await controller.play();

      if (!mounted) {
        await controller.dispose();

        return;
      }

      setState(() {
        _controller =
            controller;

        _loading =
        false;
      });
    } catch (error) {
      debugPrint(
        'Story video error: $error',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _loading =
        false;

        _error =
        true;
      });
    }
  }

  Future<void> _toggleVideo() async {
    final VideoPlayerController? controller =
        _controller;

    if (controller == null) {
      return;
    }

    if (controller.value.isPlaying) {
      await controller.pause();

      widget.onPauseChanged(
        true,
      );
    } else {
      await controller.play();

      widget.onPauseChanged(
        false,
      );
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    final VideoPlayerController? controller =
        _controller;

    if (_loading) {
      return const Center(
        child:
        CircularProgressIndicator(
          color:
          Colors.white,
        ),
      );
    }

    if (_error ||
        controller == null ||
        !controller.value.isInitialized) {
      return const Center(
        child: Text(
          'Unable to play video',
          style:
          TextStyle(
            color:
            Colors.white,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap:
      _toggleVideo,
      child: Container(
        color:
        Colors.black,
        alignment:
        Alignment.center,
        child: Stack(
          alignment:
          Alignment.center,
          children: <Widget>[
            SizedBox.expand(
              child: FittedBox(
                fit:
                BoxFit.contain,
                child: SizedBox(
                  width:
                  controller
                      .value
                      .size
                      .width,
                  height:
                  controller
                      .value
                      .size
                      .height,
                  child:
                  VideoPlayer(
                    controller,
                  ),
                ),
              ),
            ),

            if (!controller
                .value
                .isPlaying)
              Container(
                width:
                70,
                height:
                70,
                decoration:
                const BoxDecoration(
                  color:
                  Colors.black54,
                  shape:
                  BoxShape.circle,
                ),
                child:
                const Icon(
                  Icons.play_arrow,
                  color:
                  Colors.white,
                  size:
                  44,
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();

    super.dispose();
  }
}

//===================================================
// VOICE STORY
//
// REAL AUDIO CONTROLS TOP PROGRESS BAR
//===================================================

class _StoryVoicePlayer
    extends StatefulWidget {
  const _StoryVoicePlayer({
    required this.url,
    required this.backgroundColor,
    required this.fallbackDurationSeconds,
    required this.onPauseChanged,
    required this.onProgressChanged,
    required this.onCompleted,
  });

  final String url;

  final int backgroundColor;

  final int fallbackDurationSeconds;

  final ValueChanged<bool>
  onPauseChanged;

  final ValueChanged<double>
  onProgressChanged;

  final VoidCallback
  onCompleted;

  @override
  State<_StoryVoicePlayer> createState() =>
      _StoryVoicePlayerState();
}

class _StoryVoicePlayerState
    extends State<_StoryVoicePlayer> {
  final AudioPlayer _player =
  AudioPlayer();

  StreamSubscription<void>?
  _completeSubscription;

  StreamSubscription<Duration>?
  _positionSubscription;

  StreamSubscription<Duration>?
  _durationSubscription;

  bool _playing = false;

  bool _loading = true;

  bool _error = false;

  bool _completed = false;

  Duration _position =
      Duration.zero;

  Duration _duration =
      Duration.zero;

  @override
  void initState() {
    super.initState();

    _duration =
        Duration(
          seconds:
          widget.fallbackDurationSeconds,
        );

    _durationSubscription =
        _player.onDurationChanged.listen(
              (
              Duration duration,
              ) {
            if (!mounted ||
                duration <=
                    Duration.zero) {
              return;
            }

            setState(() {
              _duration =
                  duration;
            });

            _sendRealProgress();
          },
        );

    _positionSubscription =
        _player.onPositionChanged.listen(
              (
              Duration position,
              ) {
            if (!mounted) {
              return;
            }

            setState(() {
              _position =
                  position;
            });

            _sendRealProgress();
          },
        );

    _completeSubscription =
        _player.onPlayerComplete.listen(
              (_) {
            if (!mounted ||
                _completed) {
              return;
            }

            _completed =
            true;

            setState(() {
              _playing =
              false;

              _loading =
              false;

              _position =
                  _duration;
            });

            widget.onProgressChanged(
              1,
            );

            widget.onPauseChanged(
              false,
            );

            widget.onCompleted();
          },
        );

    WidgetsBinding.instance
        .addPostFrameCallback(
          (_) {
        if (mounted) {
          _playFromStart();
        }
      },
    );
  }

  void _sendRealProgress() {
    if (_completed) {
      return;
    }

    final int durationMs =
        _duration.inMilliseconds;

    if (durationMs <= 0) {
      widget.onProgressChanged(
        0,
      );

      return;
    }

    final double progress =
        _position.inMilliseconds /
            durationMs;

    widget.onProgressChanged(
      progress
          .clamp(
        0.0,
        1.0,
      )
          .toDouble(),
    );
  }

  Future<void> _playFromStart() async {
    if (widget.url.trim().isEmpty) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading =
        false;

        _error =
        true;

        _playing =
        false;
      });

      return;
    }

    try {
      _completed =
      false;

      widget.onProgressChanged(
        0,
      );

      if (mounted) {
        setState(() {
          _loading =
          true;

          _error =
          false;

          _position =
              Duration.zero;
        });
      }

      await _player.stop();

      await _player.setVolume(
        1.0,
      );

      await _player.setReleaseMode(
        ReleaseMode.stop,
      );

      //===================================================
      // AUTOPLAY
      //===================================================

      await _player.play(
        UrlSource(
          widget.url,
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _playing =
        true;

        _loading =
        false;

        _error =
        false;
      });

      widget.onPauseChanged(
        false,
      );
    } catch (error) {
      debugPrint(
        'Voice autoplay error: $error',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _playing =
        false;

        _loading =
        false;

        _error =
        true;
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
          _playing =
          false;
        });

        widget.onPauseChanged(
          true,
        );

        return;
      }

      if (!_completed &&
          _position >
              Duration.zero &&
          _position <
              _duration) {
        await _player.resume();

        if (!mounted) {
          return;
        }

        setState(() {
          _playing =
          true;

          _error =
          false;
        });

        widget.onPauseChanged(
          false,
        );

        return;
      }

      await _playFromStart();
    } catch (error) {
      debugPrint(
        'Voice toggle error: $error',
      );
    }
  }

  Future<void> _seekVoice(
      double value,
      ) async {
    if (_duration.inMilliseconds <=
        0) {
      return;
    }

    final Duration target =
    Duration(
      milliseconds:
      (_duration.inMilliseconds *
          value)
          .round(),
    );

    await _player.seek(
      target,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _position =
          target;
    });

    _sendRealProgress();
  }

  double get _sliderValue {
    if (_duration.inMilliseconds <=
        0) {
      return 0;
    }

    return (_position.inMilliseconds /
        _duration.inMilliseconds)
        .clamp(
      0.0,
      1.0,
    )
        .toDouble();
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      color:
      Color(
        widget.backgroundColor,
      ),
      child: Center(
        child: Padding(
          padding:
          const EdgeInsets.symmetric(
            horizontal:
            38,
          ),
          child: Column(
            mainAxisSize:
            MainAxisSize.min,
            children: <Widget>[
              GestureDetector(
                onTap:
                _toggleVoice,
                child: Container(
                  width:
                  112,
                  height:
                  112,
                  alignment:
                  Alignment.center,
                  decoration:
                  BoxDecoration(
                    shape:
                    BoxShape.circle,
                    border:
                    Border.all(
                      color:
                      const Color(
                        0xFF29B6F6,
                      ),
                      width:
                      3,
                    ),
                  ),
                  child:
                  _loading
                      ? const SizedBox(
                    width:
                    32,
                    height:
                    32,
                    child:
                    CircularProgressIndicator(
                      strokeWidth:
                      3,
                      color:
                      Color(
                        0xFF29B6F6,
                      ),
                    ),
                  )
                      : Icon(
                    _playing
                        ? Icons
                        .pause_rounded
                        : Icons
                        .play_arrow_rounded,
                    color:
                    Colors.white,
                    size:
                    58,
                  ),
                ),
              ),

              const SizedBox(
                height:
                20,
              ),

              const Text(
                'Voice Story',
                style:
                TextStyle(
                  color:
                  Colors.white,
                  fontSize:
                  21,
                  fontWeight:
                  FontWeight.bold,
                ),
              ),

              const SizedBox(
                height:
                12,
              ),

              const _StoryVoiceWaveform(),

              const SizedBox(
                height:
                5,
              ),

              Slider(
                min:
                0,
                max:
                1,
                value:
                _sliderValue,
                activeColor:
                const Color(
                  0xFF29B6F6,
                ),
                inactiveColor:
                Colors.white24,
                onChanged:
                _seekVoice,
              ),

              Row(
                mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    _formatAudioDuration(
                      _position,
                    ),
                    style:
                    const TextStyle(
                      color:
                      Colors.white70,
                    ),
                  ),

                  Text(
                    _formatAudioDuration(
                      _duration,
                    ),
                    style:
                    const TextStyle(
                      color:
                      Colors.white70,
                    ),
                  ),
                ],
              ),

              if (_error)
                TextButton.icon(
                  onPressed:
                  _playFromStart,
                  icon:
                  const Icon(
                    Icons.refresh,
                  ),
                  label:
                  const Text(
                    'Try again',
                  ),
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

class _StoryVoiceWaveform
    extends StatelessWidget {
  const _StoryVoiceWaveform();

  @override
  Widget build(
      BuildContext context,
      ) {
    const List<double> bars =
    <double>[
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
      mainAxisAlignment:
      MainAxisAlignment.center,
      crossAxisAlignment:
      CrossAxisAlignment.center,
      children:
      bars.map(
            (
            double height,
            ) {
          return Container(
            width:
            3,
            height:
            height,
            margin:
            const EdgeInsets.symmetric(
              horizontal:
              2,
            ),
            decoration:
            BoxDecoration(
              color:
              const Color(
                0xFF29B6F6,
              ),
              borderRadius:
              BorderRadius.circular(
                5,
              ),
            ),
          );
        },
      ).toList(),
    );
  }
}

//===================================================
// AUDIO TIME
//===================================================

String _formatAudioDuration(
    Duration duration,
    ) {
  final int totalSeconds =
  duration.inSeconds
      .clamp(
    0,
    3599,
  )
      .toInt();

  final int minutes =
      totalSeconds ~/
          60;

  final int seconds =
      totalSeconds %
          60;

  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

//===================================================
// LAYOUT STORY
//===================================================

class _StoryLayout
    extends StatelessWidget {
  const _StoryLayout({
    required this.story,
  });

  final NubifyStory story;

  String _url(
      int index,
      ) {
    if (story.mediaUrls.isEmpty) {
      return '';
    }

    return story.mediaUrls[
    index %
        story.mediaUrls.length
    ];
  }

  Widget _slot(
      int index,
      ) {
    final String url =
    _url(
      index,
    );

    return Padding(
      padding:
      const EdgeInsets.all(
        1.5,
      ),
      child: ClipRRect(
        borderRadius:
        BorderRadius.circular(
          4,
        ),
        child:
        url.isEmpty
            ? Container(
          color:
          Colors.black,
        )
            : Image.network(
          url,
          fit:
          BoxFit.cover,
          width:
          double.infinity,
          height:
          double.infinity,
        ),
      ),
    );
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    final int count =
    story.layoutCount
        .clamp(
      2,
      4,
    )
        .toInt();

    final String style =
        story.layoutStyle;

    if (count == 2) {
      if (style ==
          'horizontal') {
        return Column(
          children: <Widget>[
            Expanded(
              child:
              _slot(
                0,
              ),
            ),
            Expanded(
              child:
              _slot(
                1,
              ),
            ),
          ],
        );
      }

      return Row(
        children: <Widget>[
          Expanded(
            child:
            _slot(
              0,
            ),
          ),
          Expanded(
            child:
            _slot(
              1,
            ),
          ),
        ],
      );
    }

    if (count == 3) {
      if (style ==
          'big_left') {
        return Row(
          children: <Widget>[
            Expanded(
              flex:
              2,
              child:
              _slot(
                0,
              ),
            ),

            Expanded(
              child: Column(
                children: <Widget>[
                  Expanded(
                    child:
                    _slot(
                      1,
                    ),
                  ),
                  Expanded(
                    child:
                    _slot(
                      2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      }

      if (style ==
          'three_vertical') {
        return Row(
          children: <Widget>[
            for (int index = 0;
            index < 3;
            index++)
              Expanded(
                child:
                _slot(
                  index,
                ),
              ),
          ],
        );
      }

      if (style ==
          'three_horizontal') {
        return Column(
          children: <Widget>[
            for (int index = 0;
            index < 3;
            index++)
              Expanded(
                child:
                _slot(
                  index,
                ),
              ),
          ],
        );
      }

      return Column(
        children: <Widget>[
          Expanded(
            flex:
            2,
            child:
            _slot(
              0,
            ),
          ),
          Expanded(
            child: Row(
              children: <Widget>[
                Expanded(
                  child:
                  _slot(
                    1,
                  ),
                ),
                Expanded(
                  child:
                  _slot(
                    2,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (style ==
        'four_vertical') {
      return Row(
        children: <Widget>[
          for (int index = 0;
          index < 4;
          index++)
            Expanded(
              child:
              _slot(
                index,
              ),
            ),
        ],
      );
    }

    if (style ==
        'four_horizontal') {
      return Column(
        children: <Widget>[
          for (int index = 0;
          index < 4;
          index++)
            Expanded(
              child:
              _slot(
                index,
              ),
            ),
        ],
      );
    }

    if (style ==
        'big_left_three') {
      return Row(
        children: <Widget>[
          Expanded(
            flex:
            2,
            child:
            _slot(
              0,
            ),
          ),

          Expanded(
            child: Column(
              children: <Widget>[
                Expanded(
                  child:
                  _slot(
                    1,
                  ),
                ),
                Expanded(
                  child:
                  _slot(
                    2,
                  ),
                ),
                Expanded(
                  child:
                  _slot(
                    3,
                  ),
                ),
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
              Expanded(
                child:
                _slot(
                  0,
                ),
              ),
              Expanded(
                child:
                _slot(
                  1,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: <Widget>[
              Expanded(
                child:
                _slot(
                  2,
                ),
              ),
              Expanded(
                child:
                _slot(
                  3,
                ),
              ),
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

class _StoryPollView
    extends StatefulWidget {
  const _StoryPollView({
    required this.story,
    required this.onRefresh,
  });

  final NubifyStory story;

  final Future<void> Function()
  onRefresh;

  @override
  State<_StoryPollView> createState() =>
      _StoryPollViewState();
}

class _StoryPollViewState
    extends State<_StoryPollView> {
  final StoryService _storyService =
  StoryService();

  bool _voting = false;

  @override
  Widget build(
      BuildContext context,
      ) {
    final StoryPoll? poll =
        widget.story.poll;

    if (poll == null) {
      return const ColoredBox(
        color:
        Colors.black,
      );
    }

    final String uid =
        FirebaseAuth.instance
            .currentUser
            ?.uid ??
            '';

    final bool voted =
    poll.votedUserIds.contains(
      uid,
    );

    return Container(
      color:
      Color(
        widget.story.backgroundColor,
      ),
      alignment:
      Alignment.center,
      padding:
      const EdgeInsets.symmetric(
        horizontal:
        24,
      ),
      child: Container(
        width:
        double.infinity,
        padding:
        const EdgeInsets.all(
          18,
        ),
        decoration:
        BoxDecoration(
          color:
          Colors.black45,
          borderRadius:
          BorderRadius.circular(
            20,
          ),
          border:
          Border.all(
            color:
            Colors.white24,
          ),
        ),
        child: Column(
          mainAxisSize:
          MainAxisSize.min,
          children: <Widget>[
            Text(
              poll.question,
              textAlign:
              TextAlign.center,
              style:
              const TextStyle(
                color:
                Colors.white,
                fontSize:
                21,
                fontWeight:
                FontWeight.bold,
              ),
            ),

            const SizedBox(
              height:
              18,
            ),

            for (int index = 0;
            index <
                poll.options.length;
            index++)
              Padding(
                padding:
                const EdgeInsets.only(
                  bottom:
                  9,
                ),
                child:
                _buildPollOption(
                  poll:
                  poll,
                  index:
                  index,
                  voted:
                  voted,
                ),
              ),

            if (voted)
              const Text(
                'You have already voted. Your vote cannot be changed.',
                textAlign:
                TextAlign.center,
                style:
                TextStyle(
                  color:
                  Colors.white54,
                  fontSize:
                  11,
                ),
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
  }) {
    final StoryPollOption option =
    poll.options[index];

    final double percentage =
    poll.totalVotes <= 0
        ? 0
        : option.votes /
        poll.totalVotes;

    return GestureDetector(
      onTap:
      voted ||
          _voting
          ? null
          : () async {
        setState(() {
          _voting =
          true;
        });

        try {
          await _storyService.votePoll(
            story:
            widget.story,
            optionIndex:
            index,
          );

          await widget.onRefresh();
        } finally {
          if (mounted) {
            setState(() {
              _voting =
              false;
            });
          }
        }
      },
      child: Container(
        height:
        52,
        clipBehavior:
        Clip.antiAlias,
        decoration:
        BoxDecoration(
          color:
          Colors.white10,
          borderRadius:
          BorderRadius.circular(
            13,
          ),
          border:
          Border.all(
            color:
            Colors.white24,
          ),
        ),
        child: Stack(
          children: <Widget>[
            if (voted)
              FractionallySizedBox(
                alignment:
                Alignment.centerLeft,
                widthFactor:
                percentage
                    .clamp(
                  0.0,
                  1.0,
                )
                    .toDouble(),
                child: Container(
                  color:
                  const Color(
                    0xFF29B6F6,
                  ).withOpacity(
                    0.28,
                  ),
                ),
              ),

            Padding(
              padding:
              const EdgeInsets.symmetric(
                horizontal:
                14,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      option.text,
                      style:
                      const TextStyle(
                        color:
                        Colors.white,
                        fontWeight:
                        FontWeight.w600,
                      ),
                    ),
                  ),

                  if (voted)
                    Text(
                      '${(percentage * 100).round()}%',
                      style:
                      const TextStyle(
                        color:
                        Colors.white,
                        fontWeight:
                        FontWeight.bold,
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

class _StoryReshare
    extends StatelessWidget {
  const _StoryReshare({
    required this.story,
  });

  final NubifyStory story;

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      color:
      Color(
        story.backgroundColor,
      ),
      alignment:
      Alignment.center,
      padding:
      const EdgeInsets.all(
        28,
      ),
      child: Container(
        width:
        double.infinity,
        padding:
        const EdgeInsets.all(
          18,
        ),
        decoration:
        BoxDecoration(
          color:
          Colors.black45,
          borderRadius:
          BorderRadius.circular(
            20,
          ),
          border:
          Border.all(
            color:
            Colors.white24,
          ),
        ),
        child: Column(
          mainAxisSize:
          MainAxisSize.min,
          children: <Widget>[
            Text(
              story.sourceUsername
                  .trim()
                  .isEmpty
                  ? 'Shared Story'
                  : '@${story.sourceUsername}',
              style:
              const TextStyle(
                color:
                Color(
                  0xFF29B6F6,
                ),
                fontWeight:
                FontWeight.bold,
              ),
            ),

            if (story.sourceMediaUrl
                .trim()
                .isNotEmpty)
              Padding(
                padding:
                const EdgeInsets.only(
                  top:
                  12,
                ),
                child: ClipRRect(
                  borderRadius:
                  BorderRadius.circular(
                    15,
                  ),
                  child:
                  Image.network(
                    story.sourceMediaUrl,
                    height:
                    300,
                    width:
                    double.infinity,
                    fit:
                    BoxFit.cover,
                  ),
                ),
              ),

            if (story.sourceText
                .trim()
                .isNotEmpty)
              Padding(
                padding:
                const EdgeInsets.only(
                  top:
                  12,
                ),
                child: Text(
                  story.sourceText,
                  textAlign:
                  TextAlign.center,
                  style:
                  const TextStyle(
                    color:
                    Colors.white,
                    fontSize:
                    18,
                  ),
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

class _SharedPostStory
    extends StatelessWidget {
  const _SharedPostStory({
    required this.story,
  });

  final NubifyStory story;

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      color:
      Color(
        story.backgroundColor,
      ),
      alignment:
      Alignment.center,
      padding:
      const EdgeInsets.symmetric(
        horizontal:
        30,
      ),
      child: Container(
        padding:
        const EdgeInsets.all(
          20,
        ),
        decoration:
        BoxDecoration(
          color:
          Colors.black45,
          borderRadius:
          BorderRadius.circular(
            22,
          ),
          border:
          Border.all(
            color:
            Colors.white24,
          ),
        ),
        child: Column(
          mainAxisSize:
          MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons
                  .dynamic_feed_outlined,
              color:
              Color(
                0xFF29B6F6,
              ),
              size:
              45,
            ),

            const SizedBox(
              height:
              12,
            ),

            const Text(
              'Shared Post',
              style:
              TextStyle(
                color:
                Colors.white,
                fontSize:
                20,
                fontWeight:
                FontWeight.bold,
              ),
            ),

            if (story.caption
                .trim()
                .isNotEmpty)
              Padding(
                padding:
                const EdgeInsets.only(
                  top:
                  9,
                ),
                child: Text(
                  story.caption,
                  textAlign:
                  TextAlign.center,
                  style:
                  const TextStyle(
                    color:
                    Colors.white70,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

//===================================================
// CHAT PICKER
//===================================================

class _StoryChatPicker
    extends StatefulWidget {
  const _StoryChatPicker({
    required this.story,
    required this.onSend,
  });

  final NubifyStory story;

  final Future<bool> Function(
      NubifyStory story,
      StoryPerson person,
      )
  onSend;

  @override
  State<_StoryChatPicker> createState() =>
      _StoryChatPickerState();
}

class _StoryChatPickerState
    extends State<_StoryChatPicker> {
  final TextEditingController _searchController =
  TextEditingController();

  final Set<String> _sending =
  <String>{};

  String _query = '';

  @override
  Widget build(
      BuildContext context,
      ) {
    final String currentUid =
        FirebaseAuth.instance
            .currentUser
            ?.uid ??
            '';

    return Column(
      children: <Widget>[
        const Padding(
          padding:
          EdgeInsets.fromLTRB(
            16,
            14,
            16,
            8,
          ),
          child: Text(
            'Send Story to Chat',
            style:
            TextStyle(
              color:
              Colors.white,
              fontSize:
              20,
              fontWeight:
              FontWeight.bold,
            ),
          ),
        ),

        Padding(
          padding:
          const EdgeInsets.symmetric(
            horizontal:
            14,
          ),
          child: TextField(
            controller:
            _searchController,
            style:
            const TextStyle(
              color:
              Colors.white,
            ),
            onChanged: (
                String value,
                ) {
              setState(() {
                _query =
                    value
                        .trim()
                        .toLowerCase();
              });
            },
            decoration:
            InputDecoration(
              hintText:
              'Search users...',
              hintStyle:
              const TextStyle(
                color:
                Colors.white54,
              ),
              prefixIcon:
              const Icon(
                Icons.search,
                color:
                Colors.white54,
              ),
              filled:
              true,
              fillColor:
              Colors.white10,
              border:
              OutlineInputBorder(
                borderRadius:
                BorderRadius.circular(
                  18,
                ),
                borderSide:
                BorderSide.none,
              ),
            ),
          ),
        ),

        const SizedBox(
          height:
          8,
        ),

        Expanded(
          child: StreamBuilder<
              QuerySnapshot<
                  Map<String, dynamic>>>(
            stream:
            FirebaseFirestore
                .instance
                .collection(
              'users',
            )
                .snapshots(),
            builder: (
                BuildContext context,
                AsyncSnapshot<
                    QuerySnapshot<
                        Map<String, dynamic>>>
                snapshot,
                ) {
              if (!snapshot.hasData) {
                return const Center(
                  child:
                  CircularProgressIndicator(
                    color:
                    Color(
                      0xFF29B6F6,
                    ),
                  ),
                );
              }

              final List<StoryPerson> people =
              <StoryPerson>[];

              for (final QueryDocumentSnapshot<
                  Map<String, dynamic>>
              document
              in snapshot.data!.docs) {
                if (document.id ==
                    currentUid) {
                  continue;
                }

                final StoryPerson person =
                StoryPerson.fromMap(
                  document.data(),
                  fallbackUid:
                  document.id,
                );

                final String searchable =
                '${person.fullName} ${person.username}'
                    .toLowerCase();

                if (_query.isNotEmpty &&
                    !searchable.contains(
                      _query,
                    )) {
                  continue;
                }

                people.add(
                  person,
                );
              }

              if (people.isEmpty) {
                return const Center(
                  child: Text(
                    'No users found.',
                    style:
                    TextStyle(
                      color:
                      Colors.white54,
                    ),
                  ),
                );
              }

              return ListView.builder(
                itemCount:
                people.length,
                itemBuilder: (
                    BuildContext context,
                    int index,
                    ) {
                  final StoryPerson person =
                  people[index];

                  final bool sending =
                  _sending.contains(
                    person.uid,
                  );

                  return ListTile(
                    leading:
                    _HeartAvatar(
                      photoUrl:
                      person.photoUrl,
                      size:
                      44,
                    ),

                    title: Text(
                      person.displayName,
                      style:
                      const TextStyle(
                        color:
                        Colors.white,
                        fontWeight:
                        FontWeight.w600,
                      ),
                    ),

                    subtitle:
                    person.username
                        .trim()
                        .isEmpty
                        ? null
                        : Text(
                      '@${person.username}',
                      style:
                      const TextStyle(
                        color:
                        Colors.white54,
                      ),
                    ),

                    trailing:
                    FilledButton(
                      onPressed:
                      sending
                          ? null
                          : () async {
                        setState(() {
                          _sending.add(
                            person.uid,
                          );
                        });

                        await widget.onSend(
                          widget.story,
                          person,
                        );

                        if (!mounted) {
                          return;
                        }

                        setState(() {
                          _sending.remove(
                            person.uid,
                          );
                        });
                      },
                      child:
                      sending
                          ? const SizedBox(
                        width:
                        16,
                        height:
                        16,
                        child:
                        CircularProgressIndicator(
                          strokeWidth:
                          2,
                        ),
                      )
                          : const Text(
                        'Send',
                      ),
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

class _StoryActivitySheet
    extends StatelessWidget {
  const _StoryActivitySheet({
    required this.story,
  });

  final NubifyStory story;

  static const Color _blue =
  Color(
    0xFF29B6F6,
  );

  @override
  Widget build(
      BuildContext context,
      ) {
    return DefaultTabController(
      length:
      3,
      child: Column(
        children: <Widget>[
          const SizedBox(
            height:
            8,
          ),

          const Text(
            'Story Activity',
            style:
            TextStyle(
              color:
              Colors.white,
              fontSize:
              20,
              fontWeight:
              FontWeight.bold,
            ),
          ),

          const SizedBox(
            height:
            14,
          ),

          Padding(
            padding:
            const EdgeInsets.symmetric(
              horizontal:
              10,
            ),
            child: Row(
              children: <Widget>[
                _ActivityCount(
                  icon:
                  Icons
                      .visibility_outlined,
                  label:
                  'Views',
                  count:
                  story.viewCount,
                ),
                _ActivityCount(
                  icon:
                  Icons.favorite,
                  label:
                  'Likes',
                  count:
                  story.likeCount,
                  color:
                  _blue,
                ),
                _ActivityCount(
                  icon:
                  Icons
                      .chat_bubble_outline,
                  label:
                  'Replies',
                  count:
                  story.replyCount,
                ),
                _ActivityCount(
                  icon:
                  Icons.send_outlined,
                  label:
                  'Shares',
                  count:
                  story.shareCount,
                ),
                _ActivityCount(
                  icon:
                  Icons.repeat,
                  label:
                  'Reshares',
                  count:
                  story.reshareCount,
                ),
              ],
            ),
          ),

          const TabBar(
            indicatorColor:
            _blue,
            labelColor:
            _blue,
            unselectedLabelColor:
            Colors.white54,
            tabs:
            <Tab>[
              Tab(
                text:
                'Viewers',
              ),
              Tab(
                text:
                'Replies',
              ),
              Tab(
                text:
                'Likes',
              ),
            ],
          ),

          Expanded(
            child: TabBarView(
              children: <Widget>[
                _StoryViewersTab(
                  storyId:
                  story.storyId,
                ),
                _StoryRepliesTab(
                  storyId:
                  story.storyId,
                ),
                _StoryLikesTab(
                  userIds:
                  story.likedUserIds,
                ),
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

class _ActivityCount
    extends StatelessWidget {
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
  Widget build(
      BuildContext context,
      ) {
    return Expanded(
      child: Column(
        children: <Widget>[
          Icon(
            icon,
            color:
            color,
            size:
            20,
          ),
          const SizedBox(
            height:
            3,
          ),
          Text(
            '$count',
            style:
            const TextStyle(
              color:
              Colors.white,
              fontWeight:
              FontWeight.bold,
            ),
          ),
          Text(
            label,
            style:
            const TextStyle(
              color:
              Colors.white54,
              fontSize:
              9,
            ),
          ),
        ],
      ),
    );
  }
}

//===================================================
// VIEWERS TAB
//===================================================

class _StoryViewersTab
    extends StatelessWidget {
  const _StoryViewersTab({
    required this.storyId,
  });

  final String storyId;

  @override
  Widget build(
      BuildContext context,
      ) {
    return StreamBuilder<
        QuerySnapshot<
            Map<String, dynamic>>>(
      stream:
      FirebaseFirestore
          .instance
          .collection(
        'stories',
      )
          .doc(
        storyId,
      )
          .collection(
        'views',
      )
          .orderBy(
        'viewedAt',
        descending:
        true,
      )
          .snapshots(),
      builder: (
          BuildContext context,
          AsyncSnapshot<
              QuerySnapshot<
                  Map<String, dynamic>>>
          snapshot,
          ) {
        if (!snapshot.hasData) {
          return const Center(
            child:
            CircularProgressIndicator(
              color:
              Color(
                0xFF29B6F6,
              ),
            ),
          );
        }

        final List<
            QueryDocumentSnapshot<
                Map<String, dynamic>>>
        docs =
            snapshot.data!.docs;

        if (docs.isEmpty) {
          return const Center(
            child: Text(
              'No viewers yet.',
              style:
              TextStyle(
                color:
                Colors.white54,
              ),
            ),
          );
        }

        return ListView.builder(
          itemCount:
          docs.length,
          itemBuilder: (
              BuildContext context,
              int index,
              ) {
            final Map<String, dynamic> data =
            docs[index].data();

            final String uid =
            (data['uid'] ??
                docs[index].id)
                .toString();

            final Timestamp? viewedAt =
            data['viewedAt']
            is Timestamp
                ? data['viewedAt']
            as Timestamp
                : null;

            return _ActivityUserTile(
              uid:
              uid,
              trailingText:
              viewedAt ==
                  null
                  ? ''
                  : _activityTimeAgo(
                viewedAt.toDate(),
              ),
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

class _StoryRepliesTab
    extends StatelessWidget {
  const _StoryRepliesTab({
    required this.storyId,
  });

  final String storyId;

  @override
  Widget build(
      BuildContext context,
      ) {
    return StreamBuilder<
        QuerySnapshot<
            Map<String, dynamic>>>(
      stream:
      FirebaseFirestore
          .instance
          .collection(
        'stories',
      )
          .doc(
        storyId,
      )
          .collection(
        'replies',
      )
          .orderBy(
        'createdAt',
        descending:
        true,
      )
          .snapshots(),
      builder: (
          BuildContext context,
          AsyncSnapshot<
              QuerySnapshot<
                  Map<String, dynamic>>>
          snapshot,
          ) {
        if (!snapshot.hasData) {
          return const Center(
            child:
            CircularProgressIndicator(
              color:
              Color(
                0xFF29B6F6,
              ),
            ),
          );
        }

        final docs =
            snapshot.data!.docs;

        if (docs.isEmpty) {
          return const Center(
            child: Text(
              'No replies yet.',
              style:
              TextStyle(
                color:
                Colors.white54,
              ),
            ),
          );
        }

        return ListView.builder(
          itemCount:
          docs.length,
          itemBuilder: (
              BuildContext context,
              int index,
              ) {
            final Map<String, dynamic> data =
            docs[index].data();

            final String uid =
            (data['uid'] ??
                data['senderUid'] ??
                '')
                .toString();

            final String fullName =
            (data['fullName'] ?? '')
                .toString();

            final String username =
            (data['username'] ?? '')
                .toString();

            final String photoUrl =
            (data['photoUrl'] ?? '')
                .toString();

            final String message =
            (data['text'] ??
                data['message'] ??
                '')
                .toString();

            final Timestamp? createdAt =
            data['createdAt']
            is Timestamp
                ? data['createdAt']
            as Timestamp
                : null;

            return ListTile(
              leading:
              GestureDetector(
                onTap:
                uid.isEmpty
                    ? null
                    : () {
                  Navigator.of(
                    context,
                  ).pushNamed(
                    '/profile',
                    arguments:
                    uid,
                  );
                },
                child: _HeartAvatar(
                  photoUrl:
                  photoUrl,
                  size:
                  43,
                ),
              ),

              title:
              GestureDetector(
                onTap:
                uid.isEmpty
                    ? null
                    : () {
                  Navigator.of(
                    context,
                  ).pushNamed(
                    '/profile',
                    arguments:
                    uid,
                  );
                },
                child: Text(
                  fullName.isNotEmpty
                      ? fullName
                      : username.isNotEmpty
                      ? username
                      : 'Nubify User',
                  style:
                  const TextStyle(
                    color:
                    Colors.white,
                    fontWeight:
                    FontWeight.w600,
                  ),
                ),
              ),

              subtitle:
              Text(
                message,
                style:
                const TextStyle(
                  color:
                  Colors.white70,
                ),
              ),

              trailing:
              createdAt ==
                  null
                  ? null
                  : Text(
                _activityTimeAgo(
                  createdAt.toDate(),
                ),
                style:
                const TextStyle(
                  color:
                  Colors.white38,
                  fontSize:
                  10,
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

class _StoryLikesTab
    extends StatelessWidget {
  const _StoryLikesTab({
    required this.userIds,
  });

  final List<String> userIds;

  @override
  Widget build(
      BuildContext context,
      ) {
    if (userIds.isEmpty) {
      return const Center(
        child: Text(
          'No reactions yet.',
          style:
          TextStyle(
            color:
            Colors.white54,
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount:
      userIds.length,
      itemBuilder: (
          BuildContext context,
          int index,
          ) {
        return _ActivityUserTile(
          uid:
          userIds[index],
          trailing:
          const Icon(
            Icons.favorite,
            color:
            Color(
              0xFF29B6F6,
            ),
            size:
            20,
          ),
        );
      },
    );
  }
}

//===================================================
// ACTIVITY USER TILE
//===================================================

class _ActivityUserTile
    extends StatelessWidget {
  const _ActivityUserTile({
    required this.uid,
    this.trailingText = '',
    this.trailing,
  });

  final String uid;

  final String trailingText;

  final Widget? trailing;

  @override
  Widget build(
      BuildContext context,
      ) {
    return FutureBuilder<
        DocumentSnapshot<
            Map<String, dynamic>>>(
      future:
      FirebaseFirestore
          .instance
          .collection(
        'users',
      )
          .doc(
        uid,
      )
          .get(),
      builder: (
          BuildContext context,
          AsyncSnapshot<
              DocumentSnapshot<
                  Map<String, dynamic>>>
          snapshot,
          ) {
        final Map<String, dynamic>? data =
        snapshot.data?.data();

        final String fullName =
        (data?['fullName'] ?? '')
            .toString();

        final String username =
        (data?['username'] ?? '')
            .toString();

        final String photoUrl =
        (data?['photoUrl'] ?? '')
            .toString();

        final String displayName =
        fullName.isNotEmpty
            ? fullName
            : username.isNotEmpty
            ? username
            : 'Nubify User';

        return ListTile(
          onTap:
          uid.trim().isEmpty
              ? null
              : () {
            Navigator.of(
              context,
            ).pushNamed(
              '/profile',
              arguments:
              uid,
            );
          },

          leading:
          _HeartAvatar(
            photoUrl:
            photoUrl,
            size:
            43,
          ),

          title:
          Text(
            displayName,
            style:
            const TextStyle(
              color:
              Colors.white,
              fontWeight:
              FontWeight.w600,
            ),
          ),

          subtitle:
          username.isEmpty
              ? null
              : Text(
            '@$username',
            style:
            const TextStyle(
              color:
              Colors.white54,
            ),
          ),

          trailing:
          trailing ??
              (trailingText.isEmpty
                  ? null
                  : Text(
                trailingText,
                style:
                const TextStyle(
                  color:
                  Colors.white38,
                  fontSize:
                  11,
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

String _activityTimeAgo(
    DateTime date,
    ) {
  Duration difference =
  DateTime.now().difference(
    date,
  );

  if (difference.isNegative) {
    difference =
        Duration.zero;
  }

  if (difference.inSeconds <
      60) {
    return 'just now';
  }

  if (difference.inMinutes <
      60) {
    return '${difference.inMinutes}m ago';
  }

  if (difference.inHours <
      24) {
    return '${difference.inHours}h ago';
  }

  return '${difference.inDays}d ago';
}