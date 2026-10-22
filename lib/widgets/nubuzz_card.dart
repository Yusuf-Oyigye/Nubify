import 'dart:async';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../models/nubuzz_post.dart';
import '../screens/comment_screen.dart';
import '../screens/share_post_to_story_screen.dart';
import '../services/like_service.dart';
import '../services/nubuzz_service.dart';
import '../services/repost_service.dart';
import '../services/story_service.dart';
import '../utils/nubify_time.dart';
import '../screens/chat_forward_screen.dart';
import 'universal_link_text.dart';

//===================================================
// NUBUZZ CARD
//===================================================

class NubuzzCard extends StatefulWidget {
  final NubuzzVideo video;
  final bool isActive;
  final bool isMuted;
  final VoidCallback? onRemoved;

  const NubuzzCard({
    super.key,
    required this.video,
    required this.isActive,
    required this.isMuted,
    this.onRemoved,
  });

  @override
  State<NubuzzCard> createState() => _NubuzzCardState();
}

//===================================================
// NUBUZZ CARD STATE
//===================================================

class _NubuzzCardState extends State<NubuzzCard>
    with SingleTickerProviderStateMixin {
  //===================================================
  // FIREBASE
  //===================================================

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  //===================================================
  // SERVICES
  //===================================================

  final LikeService _likeService = LikeService();

  final RepostService _repostService = RepostService();

  // Retained for the dormant share-to-story action.
  // ignore: unused_field
  final StoryService _storyService = StoryService();

  //===================================================
  // VIDEO
  //===================================================

  VideoPlayerController? _controller;

  bool _isLoading = true;
  bool _hasError = false;

  //===================================================
  // HEART ANIMATION
  //===================================================

  late final AnimationController _heartAnimationController;

  Timer? _heartTimer;

  bool _showHeart = false;

  //===================================================
  // POST STATE
  //===================================================

  bool _isLiked = false;
  bool _isSaved = false;
  bool _isReposted = false;
  bool _isLikeLoading = false;
  bool _likeActionLocked = false;
  bool _viewRecordedLocally = false;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _engagementSubscription;

  late int _likeCount;
  late int _commentCount;
  late int _repostCount;
  // Synced for the dormant share-count presentation.
  // ignore: unused_field
  late int _shareCount;
  late int _viewCount;

  late String _caption;

  //===================================================
  // INIT
  //===================================================

  @override
  void initState() {
    super.initState();

    _likeCount = widget.video.likeCount;

    _commentCount = widget.video.commentCount;

    _repostCount = widget.video.repostCount;

    _shareCount = widget.video.shareCount;

    _viewCount = widget.video.viewCount;

    _caption = widget.video.caption;

    _heartAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );

    _initializeVideo();
    _loadLikeStatus();
    _loadSavedStatus();
    _loadRepostStatus();
    _watchEngagements();
  }

  //===================================================
  // WATCH LIVE ENGAGEMENT COUNTS
  //===================================================

  void _watchEngagements() {
    _engagementSubscription?.cancel();

    _engagementSubscription = _firestore
        .collection('posts')
        .doc(widget.video.postId)
        .snapshots()
        .listen((DocumentSnapshot<Map<String, dynamic>> snapshot) {
          if (!mounted || !snapshot.exists || snapshot.data() == null) {
            return;
          }

          final Map<String, dynamic> data = snapshot.data()!;

          final String? uid = _auth.currentUser?.uid;

          final List<dynamic> likes = data['likes'] is List
              ? List<dynamic>.from(data['likes'] as List)
              : <dynamic>[];

          final List<dynamic> likedUserIds = data['likedUserIds'] is List
              ? List<dynamic>.from(data['likedUserIds'] as List)
              : <dynamic>[];

          setState(() {
            if (!_likeActionLocked) {
              _likeCount = _toInt(data['likeCount']);
            }

            _commentCount = _toInt(data['commentCount']);

            _repostCount = _toInt(data['repostCount']);

            _shareCount = _toInt(data['shareCount']);

            _viewCount = _toInt(data['viewCount']);

            if (!_likeActionLocked && uid != null) {
              _isLiked =
                  likes.map((dynamic item) => item.toString()).contains(uid) ||
                  likedUserIds
                      .map((dynamic item) => item.toString())
                      .contains(uid);
            }
          });
        });
  }

  //===================================================
  // INITIALIZE VIDEO
  //===================================================

  Future<void> _initializeVideo() async {
    try {
      final VideoPlayerController controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.video.videoUrl),
      );

      _controller = controller;

      await controller.initialize();

      //===================================================
      // CURRENT VIDEO LOOPS
      //===================================================

      await controller.setLooping(true);

      await controller.setVolume(widget.isMuted ? 0 : 1);

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _isLoading = false;
        _hasError = false;
      });

      if (widget.isActive) {
        await _playVideo();
      }
    } catch (error) {
      debugPrint('NUBuzz video initialize error: $error');

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  //===================================================
  // RETRY VIDEO
  //===================================================

  Future<void> _retryVideo() async {
    final VideoPlayerController? oldController = _controller;

    _controller = null;

    if (oldController != null) {
      await oldController.dispose();
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    await _initializeVideo();
  }

  //===================================================
  // PLAY / PAUSE
  //===================================================

  Future<void> _togglePlayPause() async {
    final VideoPlayerController? controller = _controller;

    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.setVolume(widget.isMuted ? 0 : 1);

      await controller.play();

      await _recordViewOnce();
    }

    if (mounted) {
      setState(() {});
    }
  }

  //===================================================
  // PLAY VIDEO
  //===================================================

  Future<void> _playVideo() async {
    final VideoPlayerController? controller = _controller;

    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    await controller.setVolume(widget.isMuted ? 0 : 1);

    await controller.play();

    if (mounted) {
      setState(() {});
    }

    await _recordViewOnce();
  }

  //===================================================
  // PAUSE VIDEO
  //===================================================

  Future<void> _pauseVideo() async {
    final VideoPlayerController? controller = _controller;

    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    await controller.pause();

    if (mounted) {
      setState(() {});
    }
  }

  //===================================================
  // ACTIVE / MUTE CHANGE
  //===================================================

  @override
  void didUpdateWidget(covariant NubuzzCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.video.postId != widget.video.postId) {
      _likeCount = widget.video.likeCount;

      _commentCount = widget.video.commentCount;

      _repostCount = widget.video.repostCount;

      _shareCount = widget.video.shareCount;

      _viewCount = widget.video.viewCount;

      _caption = widget.video.caption;

      _viewRecordedLocally = false;

      _watchEngagements();

      _loadLikeStatus();

      _loadSavedStatus();

      _loadRepostStatus();
    }

    //===================================================
    // VOLUME CHANGED
    //===================================================

    if (oldWidget.isMuted != widget.isMuted) {
      final VideoPlayerController? controller = _controller;

      if (controller != null && controller.value.isInitialized) {
        unawaited(controller.setVolume(widget.isMuted ? 0 : 1));
      }
    }

    //===================================================
    // USER SWIPED TO / AWAY FROM VIDEO
    //===================================================

    if (oldWidget.isActive != widget.isActive) {
      if (widget.isActive) {
        unawaited(_playVideo());
      } else {
        unawaited(_pauseVideo());
      }
    }
  }

  //===================================================
  // OPEN AUTHOR PROFILE
  //===================================================

  Future<void> _openAuthorProfile() async {
    final String uid = widget.video.uid.trim();

    if (uid.isEmpty || !mounted) {
      return;
    }

    final VideoPlayerController? controller = _controller;

    final bool wasPlaying =
        controller != null &&
        controller.value.isInitialized &&
        controller.value.isPlaying;

    if (wasPlaying) {
      await controller.pause();
    }

    if (!mounted) {
      return;
    }

    await Navigator.of(context).pushNamed('/profile', arguments: uid);

    if (!mounted) {
      return;
    }

    if (wasPlaying &&
        widget.isActive &&
        controller.value.isInitialized) {
      await controller.setVolume(widget.isMuted ? 0 : 1);

      await controller.play();
    }
  }

  //===================================================
  // RECORD VIEW
  //
  // ONE USER = ONE VIEW
  //===================================================

  Future<void> _recordViewOnce() async {
    if (_viewRecordedLocally) {
      return;
    }

    _viewRecordedLocally = true;

    try {
      final bool added = await NubuzzService.instance.recordView(
        widget.video.postId,
      );

      if (!mounted) {
        return;
      }

      if (added) {
        setState(() {
          _viewCount++;
        });
      }
    } catch (error) {
      _viewRecordedLocally = false;

      debugPrint('NUBuzz view error: $error');
    }
  }

  //===================================================
  // LOAD LIKE STATUS
  //===================================================

  Future<void> _loadLikeStatus() async {
    try {
      final bool liked = await _likeService.hasLiked(widget.video.postId);

      if (!mounted) {
        return;
      }

      setState(() {
        _isLiked = liked;
      });
    } catch (error) {
      debugPrint('NUBuzz load-like error: $error');
    }
  }

  //===================================================
  // LIKE / UNLIKE
  //===================================================

  Future<void> _toggleLike() async {
    if (_likeActionLocked) {
      return;
    }

    final User? user = _auth.currentUser;

    if (user == null) {
      _showMessage('Please log in to like this post.');

      return;
    }

    final bool oldLiked = _isLiked;

    final int oldCount = _likeCount;

    _likeActionLocked = true;

    //===================================================
    // OPTIMISTIC NUBUZZ LIKE
    //===================================================

    setState(() {
      _isLikeLoading = false;

      _isLiked = !oldLiked;

      if (_isLiked) {
        _likeCount = oldCount + 1;
      } else {
        _likeCount = oldCount > 0 ? oldCount - 1 : 0;
      }
    });

    final Future<void> action = oldLiked
        ? _likeService.unlikePost(widget.video.postId)
        : _likeService.likePost(widget.video.postId);

    unawaited(
      action
          .catchError((Object error) {
            debugPrint('NUBuzz like error: $error');

            if (!mounted) {
              return;
            }

            setState(() {
              _isLiked = oldLiked;

              _likeCount = oldCount;
            });

            _showMessage('Unable to update like.');
          })
          .whenComplete(() {
            _likeActionLocked = false;
          }),
    );
  }

  //===================================================
  // DOUBLE TAP HEART
  //===================================================

  Future<void> _handleDoubleTap() async {
    _showBigHeart();

    if (!_isLiked && !_isLikeLoading) {
      await _toggleLike();
    }
  }

  //===================================================
  // SHOW BIG HEART
  //===================================================

  void _showBigHeart() {
    _heartTimer?.cancel();

    _heartAnimationController.forward(from: 0);

    if (mounted) {
      setState(() {
        _showHeart = true;
      });
    }

    _heartTimer = Timer(const Duration(milliseconds: 760), () {
      if (!mounted) {
        return;
      }

      setState(() {
        _showHeart = false;
      });
    });
  }

  //===================================================
  // OPEN COMMENTS
  //===================================================

  Future<void> _openComments() async {
    final VideoPlayerController? controller = _controller;

    final bool wasPlaying =
        controller != null &&
        controller.value.isInitialized &&
        controller.value.isPlaying;

    if (wasPlaying) {
      await controller.pause();
    }

    if (!mounted) {
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) {
          return CommentsScreen(postId: widget.video.postId);
        },
      ),
    );

    if (!mounted) {
      return;
    }

    await _reloadCounts();

    if (wasPlaying &&
        widget.isActive &&
        controller.value.isInitialized) {
      await controller.setVolume(widget.isMuted ? 0 : 1);

      await controller.play();
    }
  }
  //===================================================
  // LOAD REPOST STATUS
  //===================================================

  Future<void> _loadRepostStatus() async {
    try {
      final bool reposted = await _repostService.hasReposted(
        widget.video.postId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isReposted = reposted;
      });
    } catch (_) {}
  }
  //===================================================
  // REPOST OPTIONS
  //===================================================

  void _showRepostOptions() {
    showModalBottomSheet<void>(
      context: context,

      showDragHandle: true,

      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,

            children: <Widget>[
              const SizedBox(height: 8),

              ListTile(
                leading: Icon(
                  Icons.repeat_rounded,

                  color: _isReposted ? const Color(0xFF29B6F6) : null,
                ),

                title: const Text('Repost'),

                trailing: _isReposted
                    ? const Icon(Icons.check_rounded, color: Color(0xFF29B6F6))
                    : null,

                onTap: () async {
                  Navigator.pop(sheetContext);

                  if (_isReposted) {
                    _showMessage('You already reposted this NUBuzz.');

                    return;
                  }

                  await _repostOnly();

                  await _loadRepostStatus();
                },
              ),

              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
  //===================================================
  // REPOST
  //===================================================

  Future<void> _repostOnly() async {
    final User? user = _auth.currentUser;

    if (user == null) {
      _showMessage('Please log in to repost.');

      return;
    }

    try {
      await _repostService.repost(widget.video.postId);

      await _reloadCounts();

      if (mounted) {
        _showMessage('Reposted.');
      }
    } catch (error) {
      debugPrint('NUBuzz repost error: $error');

      if (mounted) {
        _showMessage('Unable to repost.');
      }
    }
  }

  //===================================================
  // QUOTE REPOST
  //===================================================

  // ignore: unused_element
  Future<void> _quoteRepost() async {
    final User? user = _auth.currentUser;

    if (user == null) {
      _showMessage('Please log in to repost.');

      return;
    }

    String text = '';

    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Quote Repost'),
          content: TextField(
            autofocus: true,
            maxLines: 5,
            maxLength: 5000,
            onChanged: (String value) {
              text = value;
            },
            decoration: const InputDecoration(
              hintText: 'Add your message...',
              border: OutlineInputBorder(),
            ),
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
                Navigator.pop(dialogContext, text.trim());
              },
              child: const Text('Repost'),
            ),
          ],
        );
      },
    );

    if (!mounted || result == null) {
      return;
    }

    try {
      await _repostService.quoteRepost(
        originalPostId: widget.video.postId,
        text: result,
      );

      await _reloadCounts();

      if (mounted) {
        _showMessage('Quote reposted.');
      }
    } catch (error) {
      debugPrint('NUBuzz quote repost error: $error');

      if (mounted) {
        _showMessage('Unable to quote repost.');
      }
    }
  }

  //===================================================
  // POST LINK
  //===================================================

  String get _postLink => 'https://nubify.app/post/${widget.video.postId}';

  //===================================================
  // COPY LINK
  //===================================================

  Future<void> _copyPostLink() async {
    await Clipboard.setData(ClipboardData(text: _postLink));

    if (mounted) {
      _showMessage('Post link copied.');
    }
  }

  //===================================================
  // SHARE NUBUZZ TO STORY
  //===================================================

  Future<void> _shareToStory() async {
    final User? user = _auth.currentUser;

    if (user == null) {
      _showMessage('Please log in to share this NUBuzz to your Story.');

      return;
    }

    //===================================================
    // OPEN STORY EDITOR FIRST
    //
    // USER CAN ADD:
    // - CAPTION
    // - STICKER
    // - TAGS
    // - BACKGROUND
    //
    // THEN CONFIRM "ADD TO STORY".
    //===================================================

    final bool? shared = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) =>
            SharePostToStoryScreen(postId: widget.video.postId, isNubuzz: true),
      ),
    );

    if (!mounted || shared != true) {
      return;
    }

    await _reloadCounts();

    _showMessage('Added to your Story.');
  }

  //===================================================
  // EXTERNAL SHARE
  //===================================================

  // ignore: unused_element
  Future<void> _sharePost() async {
    final String shareText = <String>[
      if (_caption.trim().isNotEmpty) _caption.trim(),
      'View this post by @${widget.video.username}:',
      _postLink,
    ].join('\n\n');

    try {
      await SharePlus.instance.share(
        ShareParams(
          text: shareText,
          title: 'Share post',
          subject: 'Post from Nubify',
        ),
      );

      try {
        await NubuzzService.instance.recordShare(widget.video.postId);

        if (mounted) {
          setState(() {
            _shareCount++;
          });
        }
      } catch (error) {
        debugPrint('NUBuzz share-count error: $error');
      }
    } catch (error) {
      debugPrint('NUBuzz share error: $error');

      if (mounted) {
        _showMessage('Unable to share this post.');
      }
    }
  }
  //===================================================
  // SEND NUBUZZ TO CHAT
  //===================================================

  Future<void> _sendNubuzzToChat() async {
    final bool? sent = await Navigator.push<bool>(
      context,

      MaterialPageRoute<bool>(
        builder: (_) => ChatForwardScreen(
          postId: widget.video.postId,

          postOwnerId: widget.video.uid,

          postUsername: widget.video.username,

          postFullName: widget.video.fullName,

          postCaption: widget.video.caption,

          postPreviewUrl: '',
        ),
      ),
    );

    if (!mounted || sent != true) {
      return;
    }

    try {
      await NubuzzService.instance.recordShare(widget.video.postId);
    } catch (_) {}

    if (mounted) {
      setState(() {
        _shareCount++;
      });
    }

    _showMessage('Sent to chat.');
  }
  //===================================================
  // SHARE OPTIONS
  //===================================================

  void _showShareOptions() {
    showModalBottomSheet<void>(
      context: context,

      showDragHandle: true,

      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,

            children: <Widget>[
              const SizedBox(height: 6),

              const Text(
                'Share',

                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 10),

              //===================================================
              // SHARE TO STORY
              //===================================================
              ListTile(
                leading: const Icon(Icons.add_to_photos_outlined),

                title: const Text('Share to Story'),

                onTap: () async {
                  Navigator.pop(sheetContext);

                  await _shareToStory();
                },
              ),

              //===================================================
              // SEND TO CHAT
              //===================================================
              ListTile(
                leading: const Icon(Icons.send_outlined),

                title: const Text('Send to Chat'),

                onTap: () {
                  Navigator.pop(sheetContext);

                  _sendNubuzzToChat();
                },
              ),

              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }
  //===================================================
  // LOAD SAVED STATUS
  //===================================================

  Future<void> _loadSavedStatus() async {
    final User? user = _auth.currentUser;

    if (user == null) {
      return;
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('savedPosts')
          .doc(widget.video.postId)
          .get();

      if (!mounted) {
        return;
      }

      setState(() {
        _isSaved = snapshot.exists;
      });
    } catch (error) {
      debugPrint('NUBuzz saved-status error: $error');
    }
  }

  //===================================================
  // SAVE / UNSAVE
  //===================================================

  Future<void> _toggleSave() async {
    final User? user = _auth.currentUser;

    if (user == null) {
      _showMessage('Please log in to save posts.');

      return;
    }

    final DocumentReference<Map<String, dynamic>> ref = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('savedPosts')
        .doc(widget.video.postId);

    try {
      if (_isSaved) {
        await ref.delete();

        if (!mounted) {
          return;
        }

        setState(() {
          _isSaved = false;
        });

        _showMessage('Post unsaved.');
      } else {
        await ref.set(<String, dynamic>{
          'postId': widget.video.postId,
          'savedAt': FieldValue.serverTimestamp(),
        });

        if (!mounted) {
          return;
        }

        setState(() {
          _isSaved = true;
        });

        _showMessage('Post saved.');
      }
    } catch (error) {
      debugPrint('NUBuzz save error: $error');

      if (mounted) {
        _showMessage('Unable to update saved post.');
      }
    }
  }

  //===================================================
  // HIDE POST
  //===================================================

  Future<void> _hidePost() async {
    final User? user = _auth.currentUser;

    if (user == null) {
      _showMessage('Please log in first.');

      return;
    }

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('hiddenPosts')
          .doc(widget.video.postId)
          .set(<String, dynamic>{
            'postId': widget.video.postId,
            'hiddenAt': FieldValue.serverTimestamp(),
          });

      if (!mounted) {
        return;
      }

      widget.onRemoved?.call();

      _showMessage('Post hidden.');
    } catch (error) {
      debugPrint('NUBuzz hide error: $error');

      if (mounted) {
        _showMessage('Unable to hide post.');
      }
    }
  }

  //===================================================
  // REPORT POST
  //===================================================

  Future<void> _reportPost() async {
    final User? user = _auth.currentUser;

    if (user == null) {
      _showMessage('Please log in to report a post.');

      return;
    }

    if (user.uid == widget.video.uid) {
      _showMessage('You cannot report your own post.');

      return;
    }

    const List<String> reasons = <String>[
      'Spam',
      'Harassment or bullying',
      'Hate or abusive content',
      'Violence or dangerous content',
      'Sexual content',
      'False or misleading information',
      'Scam or fraud',
      'Other',
    ];

    final String? reason = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Report Post'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: reasons.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (BuildContext context, int index) {
                return ListTile(
                  title: Text(reasons[index]),
                  onTap: () {
                    Navigator.pop(dialogContext, reasons[index]);
                  },
                );
              },
            ),
          ),
        );
      },
    );

    if (!mounted || reason == null) {
      return;
    }

    try {
      await _firestore.collection('reports').add(<String, dynamic>{
        'postId': widget.video.postId,
        'reportedPostOwnerId': widget.video.uid,
        'reportedBy': user.uid,
        'reason': reason,
        'createdAt': FieldValue.serverTimestamp(),
        'type': 'post',
        'status': 'pending',
      });

      if (!mounted) {
        return;
      }

      _showMessage('Report submitted. Thank you.');
    } catch (error) {
      debugPrint('NUBuzz report error: $error');

      if (mounted) {
        _showMessage('Unable to submit report.');
      }
    }
  }

  //===================================================
  // BLOCK USER
  //===================================================

  Future<void> _blockUser() async {
    final User? user = _auth.currentUser;

    if (user == null) {
      _showMessage('Please log in first.');

      return;
    }

    if (user.uid == widget.video.uid) {
      _showMessage('You cannot block yourself.');

      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Block User?'),
          content: Text(
            'You will no longer see posts from @${widget.video.username}.',
          ),
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
              child: const Text('Block'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) {
      return;
    }

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('blockedUsers')
          .doc(widget.video.uid)
          .set(<String, dynamic>{
            'uid': widget.video.uid,
            'blockedAt': FieldValue.serverTimestamp(),
          });

      if (!mounted) {
        return;
      }

      widget.onRemoved?.call();

      _showMessage('User blocked.');
    } catch (error) {
      debugPrint('NUBuzz block error: $error');

      if (mounted) {
        _showMessage('Unable to block user.');
      }
    }
  }

  //===================================================
  // EDIT NUBUZZ POST
  //===================================================

  Future<void> _editPost() async {
    final User? user = _auth.currentUser;

    if (user == null || user.uid != widget.video.uid) {
      _showMessage('Only the owner can edit this post.');

      return;
    }

    String editedCaption = _caption;

    final String? newCaption = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Edit Post'),
          content: TextFormField(
            initialValue: _caption,
            maxLines: 6,
            maxLength: 5000,
            autofocus: true,
            onChanged: (String value) {
              editedCaption = value;
            },
            decoration: const InputDecoration(
              hintText: 'Write a caption...',
              border: OutlineInputBorder(),
            ),
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
                Navigator.pop(dialogContext, editedCaption.trim());
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (!mounted || newCaption == null) {
      return;
    }

    try {
      await _firestore
          .collection('posts')
          .doc(widget.video.postId)
          .update(<String, dynamic>{
            'caption': newCaption,
            'edited': true,
            'editedAt': FieldValue.serverTimestamp(),
          });

      if (!mounted) {
        return;
      }

      setState(() {
        _caption = newCaption;
      });

      _showMessage('Post updated.');
    } catch (error) {
      debugPrint('NUBuzz edit error: $error');

      if (mounted) {
        _showMessage('Unable to edit this post.');
      }
    }
  }

  //===================================================
  // DELETE NUBUZZ POST
  //===================================================

  Future<void> _deletePost() async {
    final User? user = _auth.currentUser;

    if (user == null || user.uid != widget.video.uid) {
      _showMessage('Only the owner can delete this post.');

      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete Post?'),
          content: const Text(
            'This post will be permanently deleted. This action cannot be undone.',
          ),
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

    if (!mounted || confirmed != true) {
      return;
    }

    try {
      await _firestore.collection('posts').doc(widget.video.postId).delete();

      if (!mounted) {
        return;
      }

      widget.onRemoved?.call();

      _showMessage('Post deleted.');
    } catch (error) {
      debugPrint('NUBuzz delete error: $error');

      if (mounted) {
        _showMessage('Unable to delete this post.');
      }
    }
  }

  //===================================================
  // THREE-DOT MENU
  //===================================================

  void _showPostMenu() {
    final User? currentUser = _auth.currentUser;

    final bool isOwner =
        currentUser != null && currentUser.uid == widget.video.uid;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        Future<void> closeThen(Future<void> Function() action) async {
          Navigator.pop(sheetContext);

          await Future<void>.delayed(const Duration(milliseconds: 220));

          if (!mounted) {
            return;
          }

          await action();
        }

        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ListTile(
                  leading: Icon(
                    _isSaved ? Icons.bookmark : Icons.bookmark_border,

                    color: _isSaved ? const Color(0xFF29B6F6) : null,
                  ),
                  title: Text(_isSaved ? 'Unsave Post' : 'Save Post'),
                  onTap: () {
                    closeThen(_toggleSave);
                  },
                ),

                ListTile(
                  leading: const Icon(Icons.share_outlined),
                  title: const Text('Share'),
                  onTap: () {
                    closeThen(() async {
                      _showShareOptions();
                    });
                  },
                ),

                ListTile(
                  leading: const Icon(Icons.link),
                  title: const Text('Copy Link'),
                  onTap: () {
                    closeThen(_copyPostLink);
                  },
                ),

                ListTile(
                  leading: const Icon(Icons.visibility_off_outlined),
                  title: const Text('Hide Post'),
                  onTap: () {
                    closeThen(_hidePost);
                  },
                ),

                if (!isOwner)
                  ListTile(
                    leading: const Icon(Icons.flag_outlined),
                    title: const Text('Report'),
                    onTap: () {
                      closeThen(_reportPost);
                    },
                  ),

                if (!isOwner)
                  ListTile(
                    leading: const Icon(Icons.block_outlined),
                    title: const Text('Block User'),
                    onTap: () {
                      closeThen(_blockUser);
                    },
                  ),

                if (isOwner) ...<Widget>[
                  const Divider(),

                  ListTile(
                    leading: const Icon(Icons.edit_outlined),
                    title: const Text('Edit Post'),
                    onTap: () {
                      closeThen(_editPost);
                    },
                  ),

                  ListTile(
                    leading: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                    ),
                    title: const Text(
                      'Delete Post',
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () {
                      closeThen(_deletePost);
                    },
                  ),
                ],

                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  //===================================================
  // RELOAD COUNTS
  //===================================================

  Future<void> _reloadCounts() async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('posts')
          .doc(widget.video.postId)
          .get();

      if (!snapshot.exists || !mounted) {
        return;
      }

      final Map<String, dynamic> data = snapshot.data() ?? <String, dynamic>{};

      setState(() {
        _likeCount = _toInt(data['likeCount']);

        _commentCount = _toInt(data['commentCount']);

        _repostCount = _toInt(data['repostCount']);

        _shareCount = _toInt(data['shareCount']);

        _viewCount = _toInt(data['viewCount']);

        if (data.containsKey('caption')) {
          _caption = (data['caption'] ?? '').toString();
        }
      });
    } catch (error) {
      debugPrint('NUBuzz count refresh error: $error');
    }
  }

  //===================================================
  // INT HELPER
  //===================================================

  int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  //===================================================
  // COUNT FORMAT
  //===================================================

  String _formatCount(int count) {
    if (count >= 1000000) {
      final double value = count / 1000000;

      return '${value.toStringAsFixed(value >= 10 ? 0 : 1)}M';
    }

    if (count >= 1000) {
      final double value = count / 1000;

      return '${value.toStringAsFixed(value >= 10 ? 0 : 1)}K';
    }

    return count.toString();
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

  //===================================================
  // BUILD
  //===================================================

  @override
  Widget build(BuildContext context) {
    final VideoPlayerController? controller = _controller;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _togglePlayPause,
      onDoubleTap: _handleDoubleTap,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          //===================================================
          // VIDEO
          //===================================================

          _buildVideo(controller),

          //===================================================
          // GRADIENT
          //===================================================
          _buildGradient(),

          //===================================================
          // PLAY ICON WHEN PAUSED
          //===================================================
          if (controller != null &&
              controller.value.isInitialized &&
              !controller.value.isPlaying)
            const Center(
              child: IgnorePointer(
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 82,
                ),
              ),
            ),

          //===================================================
          // DOUBLE-TAP BLUE HEART
          //===================================================
          if (_showHeart)
            Center(
              child: IgnorePointer(
                child: ScaleTransition(
                  scale: CurvedAnimation(
                    parent: _heartAnimationController,
                    curve: Curves.elasticOut,
                  ),
                  child: const Icon(
                    Icons.favorite,
                    color: Color(0xFF29B6F6),
                    size: 125,
                  ),
                ),
              ),
            ),

          //===================================================
          // PROFILE + CAPTION
          //===================================================
          Positioned(
            left: 14,
            right: 84,
            bottom: 20,
            child: SafeArea(top: false, child: _buildUserInfo()),
          ),

          //===================================================
          // ACTION BUTTONS
          //===================================================
          Positioned(
            right: 8,
            bottom: 18,
            child: SafeArea(top: false, child: _buildActions()),
          ),
        ],
      ),
    );
  }

  //===================================================
  // VIDEO DISPLAY
  //===================================================

  Widget _buildVideo(VideoPlayerController? controller) {
    if (_hasError) {
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.white,
              size: 50,
            ),

            const SizedBox(height: 12),

            const Text(
              'Unable to play this video',
              style: TextStyle(color: Colors.white),
            ),

            const SizedBox(height: 14),

            ElevatedButton(onPressed: _retryVideo, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_isLoading || controller == null || !controller.value.isInitialized) {
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(color: Color(0xFF29B6F6)),
      );
    }

    final Size videoSize = controller.value.size;

    if (videoSize.width <= 0 || videoSize.height <= 0) {
      return const ColoredBox(color: Colors.black);
    }

    final double sourceAspectRatio = videoSize.width / videoSize.height;

    const double reelAspectRatio = 9 / 16;

    final bool isReelLikeVertical =
        (sourceAspectRatio - reelAspectRatio).abs() <= 0.06;

    //===================================================
    // NORMAL 9:16 VIDEO
    //===================================================

    if (isReelLikeVertical) {
      return ColoredBox(
        color: Colors.black,
        child: Center(
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: videoSize.width,
              height: videoSize.height,
              child: VideoPlayer(controller),
            ),
          ),
        ),
      );
    }

    //===================================================
    // LANDSCAPE / SQUARE / OTHER RATIO
    //
    // BLURRED BACKGROUND + UNCROPPED MAIN VIDEO
    //===================================================

    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Positioned.fill(
            child: ClipRect(
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Transform.scale(
                  scale: 1.12,
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: videoSize.width,
                      height: videoSize.height,
                      child: VideoPlayer(controller),
                    ),
                  ),
                ),
              ),
            ),
          ),

          Positioned.fill(
            child: ColoredBox(color: Colors.black.withValues(alpha: 0.32)),
          ),

          Positioned.fill(
            child: Center(
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: videoSize.width,
                  height: videoSize.height,
                  child: VideoPlayer(controller),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  //===================================================
  // GRADIENT
  //===================================================

  Widget _buildGradient() {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Colors.black.withValues(alpha: 0.18),
              Colors.transparent,
              Colors.black.withValues(alpha: 0.78),
            ],
            stops: const <double>[0, 0.52, 1],
          ),
        ),
      ),
    );
  }

  //===================================================
  // USER INFO
  //===================================================

  Widget _buildUserInfo() {
    final String displayName = widget.video.fullName.trim().isNotEmpty
        ? widget.video.fullName.trim()
        : widget.video.username;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            //===================================================
            // PROFILE PICTURE
            //===================================================

            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _openAuthorProfile,
              child: CircleAvatar(
                radius: 22,
                backgroundColor: Colors.white24,
                backgroundImage: widget.video.photoUrl.trim().isNotEmpty
                    ? NetworkImage(widget.video.photoUrl)
                    : null,
                child: widget.video.photoUrl.trim().isEmpty
                    ? const Icon(Icons.person, color: Colors.white)
                    : null,
              ),
            ),

            const SizedBox(width: 9),

            //===================================================
            // FULL NAME / USERNAME
            //===================================================
            Flexible(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _openAuthorProfile,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    if (widget.video.username.trim().isNotEmpty)
                      Text(
                        '@${widget.video.username}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),

                    NubifyTimeText(
                      dateTime: widget.video.createdAt,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        //============================
        // VIEW COUNT UNDER PROFILE
        //============================

        const SizedBox(height: 6),

        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.visibility_outlined,
              color: Colors.white70,
              size: 15,
            ),

            const SizedBox(width: 4),

            Text(
              '${_formatCount(_viewCount)} ${_viewCount == 1 ? 'view' : 'views'}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        if (_caption.trim().isNotEmpty) ...<Widget>[
          const SizedBox(height: 9),

          UniversalLinkText(
            text: _caption,

            compactPreview: true,

            maxLines: 3,

            overflow: TextOverflow.ellipsis,

            style: const TextStyle(
              color: Colors.white,

              fontSize: 14,

              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }

  //===================================================
  // ACTION BUTTONS
  //===================================================

  Widget _buildActions() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        //===================================================
        // LIKE
        //===================================================

        _actionButton(
          icon: _isLiked ? Icons.favorite : Icons.favorite_border,
          color: _isLiked ? const Color(0xFF29B6F6) : Colors.white,
          count: _formatCount(_likeCount),
          onTap: _toggleLike,
          loading: _isLikeLoading,
        ),

        const SizedBox(height: 13),

        //===================================================
        // COMMENT
        //===================================================
        _actionButton(
          icon: Icons.chat_bubble_outline,
          count: _formatCount(_commentCount),
          onTap: _openComments,
        ),

        const SizedBox(height: 13),

        //===================================================
        // REPOST
        //===================================================
        _actionButton(
          icon: Icons.repeat,

          color: _isReposted ? const Color(0xFF29B6F6) : Colors.white,

          count: _formatCount(_repostCount),

          onTap: _showRepostOptions,
        ),

        const SizedBox(height: 10),

        //===================================================
        // SHARE ARROW
        //===================================================
        _actionButton(
          icon: Icons.near_me_outlined,
          count: '',
          onTap: _showShareOptions,
          iconSize: 28,
        ),

        const SizedBox(height: 10),

        //===================================================
        // SAVE / UNSAVE
        //===================================================
        _actionButton(
          icon: _isSaved ? Icons.bookmark : Icons.bookmark_border,

          color: _isSaved ? const Color(0xFF29B6F6) : Colors.white,

          count: '',

          onTap: _toggleSave,
        ),

        const SizedBox(height: 10),
        //===================================================
        // THREE DOT
        //===================================================

        _actionButton(
          icon: Icons.more_vert,
          count: '',
          onTap: _showPostMenu,
          iconSize: 28,
        ),
      ],
    );
  }

  //===================================================
  // ACTION BUTTON
  //===================================================

  Widget _actionButton({
    required IconData icon,
    required String count,
    required VoidCallback onTap,
    Color color = Colors.white,
    double iconSize = 27,
    bool loading = false,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: loading ? null : onTap,
      child: Column(
        children: <Widget>[
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.36),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: loading
                ? const SizedBox(
                    width: 21,
                    height: 21,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(icon, color: color, size: iconSize),
          ),

          if (count.isNotEmpty) ...<Widget>[
            const SizedBox(height: 3),

            Text(
              count,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  //===================================================
  // DISPOSE
  //===================================================

  @override
  void dispose() {
    _heartTimer?.cancel();

    _engagementSubscription?.cancel();

    _heartAnimationController.dispose();

    _controller?.dispose();

    super.dispose();
  }
}
