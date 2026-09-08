import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../models/post.dart';
import '../screens/comment_screen.dart';
import '../screens/post_engagements_screen.dart';
import '../screens/share_post_to_story_screen.dart';
import '../services/chat_sevice.dart';
import '../services/like_service.dart';
import '../services/post_actions_service.dart';
import '../services/repost_service.dart';
import '../services/story_service.dart';
import '../utils/nubify_time.dart';
import 'post_media_carousel.dart';
import '../screens/chat_forward_screen.dart';
import 'universal_link_text.dart';

//===================================================
// POST CARD
//===================================================

class PostCard extends StatefulWidget {
  final Post post;
  final bool inCommentsScreen;
  final bool isProfileScreen;
  final bool isPinnedToProfile;
  final bool showHiddenPost;
  final bool forceMediaPaused;
  //==========================
  // NEW POST CREATED
  //==========================

  final ValueChanged<String>? onNewPostCreated;
  const PostCard({
    super.key,
    required this.post,
    this.inCommentsScreen = false,
    this.isProfileScreen = false,
    this.isPinnedToProfile = false,
    this.showHiddenPost = false,
    this.forceMediaPaused = false,
    this.onNewPostCreated,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

//===================================================
// POST CARD STATE
//===================================================

class _PostCardState extends State<PostCard> {
  //===================================================
  // FIREBASE
  //===================================================

  final FirebaseAuth _auth = FirebaseAuth.instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  //===================================================
  // SERVICES
  //===================================================

  final LikeService _likeService = LikeService();

  final PostActionsService _postActionsService = PostActionsService();

  final RepostService _repostService = RepostService();

  final StoryService _storyService = StoryService();

  final ChatService _chatService = ChatService();

  //===================================================
  // DIRECT-PARENT REPOST CHAIN
  //===================================================

  // Keep this enabled so every repost / quote repost shows only
  // the post or repost it directly came from. Example:
  // D -> C -> B -> A. D shows C only. Tap C to open C,
  // then C shows B only. Tap B to open B, then B shows A.
  final bool _directParentRepostChain = true;

  //===================================================
  // LIKE STATE
  //===================================================

  bool _isLiked = false;

  bool _isLikeLoading = false;

  int _likeCount = 0;

  int _commentCount = 0;

  int _repostCount = 0;

  int _shareCount = 0;

  bool _likeActionLocked = false;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _engagementSubscription;

  //===================================================
  // OTHER STATE
  //===================================================

  bool _isSaved = false;

  bool _showHeartAnimation = false;

  String _caption = '';

  bool _isDeleted = false;

  bool _isGloballyHidden = false;

  //===================================================
  // VIEW STATE
  //===================================================

  int _viewCount = 0;

  bool _viewRecorded = false;

  //===================================================
  // POLL STATE
  //===================================================

  bool _hasPoll = false;

  String _pollQuestion = '';

  List<Map<String, dynamic>> _pollOptions = <Map<String, dynamic>>[];

  int _pollTotalVotes = 0;

  String? _selectedPollOption;

  bool _hasVoted = false;

  bool _isVoting = false;

  bool _pollLoading = true;

  DateTime? _pollExpiresAt;

  bool _pollClosed = false;

  int? _winnerOptionIndex;

  DateTime? _pollClosedAt;

  //===================================================
  // INIT
  //===================================================

  @override
  void initState() {
    super.initState();

    _likeCount = widget.post.likeCount;

    _commentCount = widget.post.commentCount;

    _repostCount = widget.post.repostCount;

    _shareCount = widget.post.shareCount;

    _viewCount = widget.post.viewCount;

    _caption = widget.post.caption;

    _isGloballyHidden = widget.post.isHidden;

    _loadLikeStatus();

    _loadSavedStatus();

    _loadPoll();

    _recordView();

    _checkIfHidden();

    _watchEngagements();
  }

  //===================================================
  // DID UPDATE WIDGET
  //===================================================

  @override
  void didUpdateWidget(covariant PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.post.postId != widget.post.postId) {
      _likeCount = widget.post.likeCount;

      _commentCount = widget.post.commentCount;

      _repostCount = widget.post.repostCount;

      _shareCount = widget.post.shareCount;

      _viewCount = widget.post.viewCount;

      _caption = widget.post.caption;

      _isGloballyHidden = widget.post.isHidden;

      _isDeleted =
          (widget.post.isHidden || widget.post.isRootHidden) &&
          !widget.showHiddenPost;

      _viewRecorded = false;

      _loadLikeStatus();

      _loadSavedStatus();

      _loadPoll();

      _recordView();

      _checkIfHidden();

      _watchEngagements();

      return;
    }

    if (oldWidget.post.likeCount != widget.post.likeCount) {
      _likeCount = widget.post.likeCount;
    }

    if (oldWidget.post.commentCount != widget.post.commentCount) {
      _commentCount = widget.post.commentCount;
    }

    if (oldWidget.post.repostCount != widget.post.repostCount) {
      _repostCount = widget.post.repostCount;
    }

    if (oldWidget.post.shareCount != widget.post.shareCount) {
      _shareCount = widget.post.shareCount;
    }

    if (oldWidget.post.viewCount != widget.post.viewCount) {
      _viewCount = widget.post.viewCount;
    }

    if (oldWidget.post.caption != widget.post.caption) {
      _caption = widget.post.caption;
    }

    if (oldWidget.post.isHidden != widget.post.isHidden ||
        oldWidget.post.isRootHidden != widget.post.isRootHidden ||
        oldWidget.showHiddenPost != widget.showHiddenPost) {
      _isGloballyHidden = widget.post.isHidden;

      _isDeleted =
          (widget.post.isHidden || widget.post.isRootHidden) &&
          !widget.showHiddenPost;
    }
  }

  //===================================================
  // WATCH LIVE ENGAGEMENT COUNTS
  //
  // HOME / FEED NOW STAYS IN SYNC WITH FIRESTORE
  // WITHOUT WAITING FOR A FULL FEED REFRESH.
  //===================================================

  void _watchEngagements() {
    _engagementSubscription?.cancel();

    _engagementSubscription = _firestore
        .collection('posts')
        .doc(widget.post.postId)
        .snapshots()
        .listen((DocumentSnapshot<Map<String, dynamic>> snapshot) {
          if (!mounted || !snapshot.exists || snapshot.data() == null) {
            return;
          }

          final Map<String, dynamic> data = snapshot.data()!;

          final String? currentUid = _auth.currentUser?.uid;

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

            if (!_likeActionLocked && currentUid != null) {
              _isLiked =
                  likes
                      .map((dynamic item) => item.toString())
                      .contains(currentUid) ||
                  likedUserIds
                      .map((dynamic item) => item.toString())
                      .contains(currentUid);
            }
          });
        });
  }

  //===================================================
  // DISPOSE
  //===================================================

  @override
  void dispose() {
    _engagementSubscription?.cancel();

    super.dispose();
  }

  //===================================================
  // OPEN POST AUTHOR PROFILE
  //===================================================

  Future<void> _openAuthorProfile() async {
    final String uid = widget.post.uid.trim();

    if (uid.isEmpty || !mounted) {
      return;
    }

    await Navigator.of(context).pushNamed('/profile', arguments: uid);
  }

  //===================================================
  // OPEN ANY USER PROFILE
  //===================================================

  Future<void> _openProfile(String uid) async {
    final String cleanUid = uid.trim();

    if (cleanUid.isEmpty || !mounted) {
      return;
    }

    await Navigator.of(context).pushNamed('/profile', arguments: cleanUid);
  }

  //===================================================
  // OPEN EXACT POST BY ID
  //===================================================

  Future<void> _openPostById(String postId) async {
    final String cleanPostId = postId.trim();

    if (cleanPostId.isEmpty || !mounted) {
      return;
    }

    if (widget.inCommentsScreen && cleanPostId == widget.post.postId) {
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => CommentsScreen(postId: cleanPostId),
      ),
    );
  }

  //===================================================
  // OPEN CURRENT POST / REPOST BODY
  //===================================================

  Future<void> _openCurrentPost() async {
    await _openPostById(widget.post.postId);
  }

  //===================================================
  // LOAD LIKE STATUS
  //===================================================

  Future<void> _loadLikeStatus() async {
    try {
      final User? user = _auth.currentUser;

      if (user == null) {
        return;
      }

      final bool liked = await _likeService.hasLiked(widget.post.postId);

      if (!mounted) {
        return;
      }

      setState(() {
        _isLiked = liked;
      });
    } catch (error) {
      debugPrint('Error loading like status: $error');
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
    // OPTIMISTIC LIKE
    //
    // UPDATE THE HEART + COUNT BEFORE FIRESTORE WAITS.
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
        ? _likeService.unlikePost(widget.post.postId)
        : _likeService.likePost(widget.post.postId);

    unawaited(
      action
          .catchError((Object error) {
            debugPrint('Like error: $error');

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
  // DOUBLE TAP LIKE
  //===================================================

  Future<void> _doubleTapLike() async {
    setState(() {
      _showHeartAnimation = true;
    });

    if (!_isLiked && !_isLikeLoading) {
      await _toggleLike();
    }

    await Future<void>.delayed(const Duration(milliseconds: 650));

    if (!mounted) {
      return;
    }

    setState(() {
      _showHeartAnimation = false;
    });
  }

  //===================================================
  // CHECK HIDDEN STATE
  //===================================================

  Future<void> _checkIfHidden() async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('posts')
          .doc(widget.post.postId)
          .get();

      if (!mounted || !snapshot.exists || snapshot.data() == null) {
        return;
      }

      final Map<String, dynamic> data = snapshot.data()!;

      final bool hidden = data['isHidden'] == true;

      final bool rootHidden = data['isRootHidden'] == true;

      setState(() {
        _isGloballyHidden = hidden;

        _isDeleted = (hidden || rootHidden) && !widget.showHiddenPost;
      });
    } catch (error) {
      debugPrint('Check hidden post error: $error');
    }
  }

  //===================================================
  // RECORD ONE VIEW PER USER
  //===================================================

  Future<void> _recordView() async {
    if (_viewRecorded) {
      return;
    }

    final User? user = _auth.currentUser;

    if (user == null) {
      return;
    }

    _viewRecorded = true;

    try {
      final DocumentReference<Map<String, dynamic>> postRef = _firestore
          .collection('posts')
          .doc(widget.post.postId);

      final DocumentReference<Map<String, dynamic>> viewRef = postRef
          .collection('views')
          .doc(user.uid);

      final DocumentSnapshot<Map<String, dynamic>> existingView = await viewRef
          .get();

      if (existingView.exists) {
        return;
      }

      bool added = false;

      await _firestore.runTransaction((Transaction transaction) async {
        final DocumentSnapshot<Map<String, dynamic>> postSnapshot =
            await transaction.get(postRef);

        final DocumentSnapshot<Map<String, dynamic>> viewSnapshot =
            await transaction.get(viewRef);

        if (!postSnapshot.exists || viewSnapshot.exists) {
          return;
        }

        final Map<String, dynamic> data =
            postSnapshot.data() ?? <String, dynamic>{};

        final int currentViews = _toInt(data['viewCount']);

        transaction.update(postRef, <String, dynamic>{
          'viewCount': currentViews + 1,
        });

        transaction.set(viewRef, <String, dynamic>{
          'uid': user.uid,
          'viewedAt': FieldValue.serverTimestamp(),
        });

        added = true;
      });

      if (!mounted || !added) {
        return;
      }

      setState(() {
        _viewCount++;
      });
    } catch (error) {
      _viewRecorded = false;

      debugPrint('Error recording view: $error');
    }
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
          .doc(widget.post.postId)
          .get();

      if (!mounted) {
        return;
      }

      setState(() {
        _isSaved = snapshot.exists;
      });
    } catch (error) {
      debugPrint('Load saved status error: $error');
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
        .doc(widget.post.postId);

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
          'postId': widget.post.postId,
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
      debugPrint('Save post error: $error');

      _showMessage('Unable to update saved post.');
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

    if (user.uid != widget.post.uid) {
      _showMessage('Only the owner of this post can hide it.');

      return;
    }

    try {
      await _postActionsService.hidePost(widget.post.postId, user.uid);

      if (!mounted) {
        return;
      }

      setState(() {
        _isGloballyHidden = true;

        if (!widget.showHiddenPost) {
          _isDeleted = true;
        }
      });

      _showMessage('Post hidden from everyone.');
    } catch (error) {
      debugPrint('Hide post error: $error');

      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  //===================================================
  // UNHIDE POST
  //===================================================

  Future<void> _unhidePost() async {
    final User? user = _auth.currentUser;

    if (user == null) {
      _showMessage('Please log in first.');

      return;
    }

    if (user.uid != widget.post.uid) {
      _showMessage('Only the owner of this post can unhide it.');

      return;
    }

    try {
      await _postActionsService.unhidePost(widget.post.postId, user.uid);

      if (!mounted) {
        return;
      }

      setState(() {
        _isGloballyHidden = false;

        _isDeleted = false;
      });

      _showMessage('Post is visible again.');
    } catch (error) {
      debugPrint('Unhide post error: $error');

      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  //===================================================
  // COPY POST LINK
  //===================================================

  Future<void> _copyPostLink() async {
    final String link = 'https://nubify.app/post/${widget.post.postId}';

    await Clipboard.setData(ClipboardData(text: link));

    if (!mounted) {
      return;
    }

    _showMessage('Post link copied.');
  }

  //===================================================
  // SHARE TO OTHER APPS
  // THREE DOT MENU ONLY
  //===================================================

  Future<void> _sharePost() async {
    final String postLink = 'https://nubify.app/post/${widget.post.postId}';

    final String shareText = <String>[
      if (_caption.trim().isNotEmpty) _caption.trim(),
      'View this post by @${widget.post.username}:',
      postLink,
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
        await _firestore.collection('posts').doc(widget.post.postId).update(
          <String, dynamic>{'shareCount': FieldValue.increment(1)},
        );
      } catch (_) {}
    } catch (error) {
      debugPrint('Share post error: $error');

      if (mounted) {
        _showMessage('Unable to share this post.');
      }
    }
  }

  //===================================================
  // ARROW SHARE OPTIONS
  //
  // STORY + CHAT ONLY
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
                subtitle: const Text('Add this post to your Nubify Story'),
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
                title: const Text('Send to chat'),
                subtitle: const Text('Choose a Nubify user'),
                onTap: () {
                  Navigator.pop(sheetContext);

                  Future<void>.delayed(const Duration(milliseconds: 180), () {
                    if (mounted) {
                      _showPostChatPicker();
                    }
                  });
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
  // INCREMENT SHARE COUNT
  //===================================================

  Future<void> _incrementShareCount() async {
    try {
      await _firestore.collection('posts').doc(widget.post.postId).update(
        <String, dynamic>{'shareCount': FieldValue.increment(1)},
      );
    } catch (_) {}
  }

  //===================================================
  // SHARE TO STORY
  //===================================================

  Future<void> _shareToStory() async {
    final User? user = _auth.currentUser;

    if (user == null) {
      _showMessage('Please log in to share this post to your Story.');

      return;
    }

    //===================================================
    // INSTAGRAM-STYLE STORY EDIT FLOW
    //
    // DO NOT POST DIRECTLY.
    //
    // OPEN THE STORY EDITOR FIRST SO THE USER CAN:
    //
    // - ADD CAPTION
    // - ADD STICKER
    // - TAG PEOPLE
    // - CHANGE BACKGROUND
    // - OR SHARE THE POST AS-IS
    //===================================================

    final bool? shared = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => SharePostToStoryScreen(
          postId: widget.post.postId,
          isNubuzz: false,
          initialPost: widget.post,
        ),
      ),
    );

    if (!mounted || shared != true) {
      return;
    }

    _showMessage('Added to your Story.');
  }

  //===================================================
  // SEND POST TO CHAT
  //===================================================

  Future<void> _showPostChatPicker() async {
    if (_auth.currentUser == null) {
      _showMessage('Please log in to send this post.');

      return;
    }

    //===================================================
    // USE THE REAL POST COVER
    //===================================================

    String previewUrl = widget.post.thumbnailUrl.trim();

    if (previewUrl.isEmpty) {
      for (final media in widget.post.media) {
        // Prefer an uploaded video thumbnail.
        if (media.thumbnailUrl.trim().isNotEmpty) {
          previewUrl = media.thumbnailUrl.trim();
          break;
        }

        // Otherwise use a real photo.
        if (media.isImage && media.url.trim().isNotEmpty) {
          previewUrl = media.url.trim();
          break;
        }
      }
    }
    final bool? sent = await Navigator.push<bool>(
      context,

      MaterialPageRoute<bool>(
        builder: (_) => ChatForwardScreen(
          postId: widget.post.postId,

          postOwnerId: widget.post.uid,

          postUsername: widget.post.username,

          postFullName: widget.post.fullName,

          postCaption: widget.post.caption,

          postPreviewUrl: previewUrl,
        ),
      ),
    );

    if (!mounted || sent != true) {
      return;
    }

    await _incrementShareCount();

    _showMessage('Post sent.');
  }
  //===================================================
  // OPEN REPOST / QUOTE ENGAGEMENTS
  //===================================================

  Future<void> _openPostEngagements() async {
    final String rootPostId = widget.post.rootPostId;

    if (rootPostId.trim().isEmpty || !mounted) {
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => PostEngagementsScreen(postId: rootPostId),
      ),
    );
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
              const SizedBox(height: 6),

              const Text(
                'Repost',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 10),

              //===================================================
              // PLAIN REPOST
              //===================================================
              ListTile(
                leading: const Icon(Icons.repeat),
                title: const Text('Repost'),
                subtitle: const Text('Share without adding anything'),
                onTap: () async {
                  Navigator.pop(sheetContext);

                  await _repostOnly();
                },
              ),

              //===================================================
              // QUOTE REPOST
              //===================================================
              ListTile(
                leading: const Icon(Icons.format_quote),
                title: const Text('Quote Repost'),
                subtitle: const Text('Repost and add your own message'),
                onTap: () {
                  Navigator.pop(sheetContext);

                  _quoteRepost();
                },
              ),

              const Divider(),

              //===================================================
              // VIEW REPOSTS / QUOTES
              //===================================================
              ListTile(
                leading: const Icon(Icons.people_alt_outlined),
                title: const Text('View reposts and quotes'),
                subtitle: const Text('See who reposted and who added a quote'),
                onTap: () async {
                  Navigator.pop(sheetContext);

                  await _openPostEngagements();
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
  // PLAIN REPOST
  //
  // SAME EXACT POST / REPOST CAN BE PLAIN-REPOSTED
  // ONLY ONCE BY THIS USER.
  //===================================================

  Future<void> _repostOnly() async {
    final User? user = _auth.currentUser;

    if (user == null) {
      _showMessage('Please log in to repost.');

      return;
    }

    try {
      //===================================================
      // CHECK FIRST
      //===================================================

      final bool alreadyReposted = await _repostService.hasReposted(
        widget.post.postId,
      );

      if (alreadyReposted) {
        if (mounted) {
          _showMessage('You already reposted this post.');
        }

        return;
      }

      //===================================================
      // CREATE PLAIN REPOST
      //===================================================
      final String newRepostId = await _repostService.repost(
        widget.post.postId,
      );

      if (!mounted) {
        return;
      }

      //==========================
      // LOAD NEW REPOST
      //==========================

      widget.onNewPostCreated?.call(newRepostId);

      _showMessage('Reposted.');
    } catch (error) {
      debugPrint('Repost error: $error');

      if (!mounted) {
        return;
      }

      final String message = error.toString();

      if (message.contains('ALREADY_REPOSTED')) {
        _showMessage('You already reposted this post.');

        return;
      }

      _showMessage('Unable to repost.');
    }
  }
  //===================================================
  // QUOTE REPOST
  //
  // SAME EXACT POST / REPOST CAN BE QUOTE-REPOSTED
  // ONLY ONCE BY THIS USER.
  //
  // PLAIN REPOST IS SEPARATE.
  //===================================================

  Future<void> _quoteRepost() async {
    final User? user = _auth.currentUser;

    if (user == null) {
      _showMessage('Please log in to repost.');

      return;
    }

    //===================================================
    // CHECK QUOTE REPOST STATUS FIRST
    //===================================================

    try {
      final bool alreadyQuoteReposted = await _repostService.hasQuoteReposted(
        widget.post.postId,
      );

      if (alreadyQuoteReposted) {
        if (mounted) {
          _showMessage('You already quote reposted this post.');
        }

        return;
      }
    } catch (error) {
      debugPrint('Quote repost status error: $error');
    }

    //===================================================
    // QUOTE TEXT
    //===================================================

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
            keyboardType: TextInputType.multiline,
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
      //===================================================
      // CREATE QUOTE REPOST
      //===================================================

      final String newQuoteRepostId = await _repostService.quoteRepost(
        originalPostId: widget.post.postId,
        text: result,
      );

      if (!mounted) {
        return;
      }

      //==========================
      // LOAD NEW QUOTE REPOST
      //==========================

      widget.onNewPostCreated?.call(newQuoteRepostId);

      _showMessage('Quote reposted.');
    } catch (error) {
      debugPrint('Quote repost error: $error');

      if (!mounted) {
        return;
      }

      final String message = error.toString();

      if (message.contains('ALREADY_QUOTE_REPOSTED')) {
        _showMessage('You already quote reposted this post.');

        return;
      }

      _showMessage('Unable to quote repost.');
    }
  }

  //===================================================
  // EDIT POST / QUOTE
  //===================================================

  Future<void> _editPost() async {
    final User? user = _auth.currentUser;

    if (user == null || user.uid != widget.post.uid) {
      _showMessage('Only the owner can edit this post.');

      return;
    }

    //===================================================
    // EDIT QUOTE REPOST
    //===================================================

    if (widget.post.isRepost) {
      if (widget.post.repostType != 'quote') {
        _showMessage('A normal repost has no text to edit.');

        return;
      }

      String editedQuote = widget.post.repostText;

      final String? newQuote = await showDialog<String>(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('Edit Quote Repost'),
            content: TextFormField(
              initialValue: widget.post.repostText,
              maxLines: 6,
              maxLength: 5000,
              autofocus: true,
              keyboardType: TextInputType.multiline,
              onChanged: (String value) {
                editedQuote = value;
              },
              decoration: const InputDecoration(
                hintText: 'Add your message...',
                border: OutlineInputBorder(),
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(editedQuote.trim());
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );

      if (!mounted || newQuote == null) {
        return;
      }

      try {
        await _firestore
            .collection('posts')
            .doc(widget.post.postId)
            .update(<String, dynamic>{
              'repostText': newQuote,
              'repostCaption': newQuote,
              'caption': newQuote,
              'edited': true,
              'editedAt': FieldValue.serverTimestamp(),
            });

        if (!mounted) {
          return;
        }

        setState(() {
          _caption = newQuote;
        });

        _showMessage('Quote repost updated.');
      } catch (error) {
        debugPrint('Edit quote repost error: $error');

        _showMessage('Unable to edit this quote repost.');
      }

      return;
    }

    //===================================================
    // EDIT NORMAL POST
    //===================================================

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
            keyboardType: TextInputType.multiline,
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
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(editedCaption.trim());
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
          .doc(widget.post.postId)
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
      debugPrint('Edit post error: $error');

      _showMessage('Unable to edit this post.');
    }
  }

  //===================================================
  // DELETE POST / REPOST
  //===================================================

  Future<void> _deletePost() async {
    final User? user = _auth.currentUser;

    if (user == null || user.uid != widget.post.uid) {
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
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
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
      if (widget.post.isRepost) {
        await _repostService.deleteRepost(widget.post.postId);
      } else {
        await _postActionsService.deletePost(widget.post.postId);
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _isDeleted = true;
      });

      _showMessage('Post deleted.');
    } catch (error) {
      debugPrint('Delete post error: $error');

      _showMessage('Unable to delete this post.');
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

    if (user.uid == widget.post.uid) {
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
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (BuildContext context, int index) {
                return ListTile(
                  title: Text(reasons[index]),
                  onTap: () {
                    Navigator.of(dialogContext).pop(reasons[index]);
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
        'postId': widget.post.postId,
        'reportedPostOwnerId': widget.post.uid,
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
      debugPrint('Report post error: $error');

      _showMessage('Unable to submit report.');
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

    if (user.uid == widget.post.uid) {
      _showMessage('You cannot block yourself.');

      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Block User?'),
          content: Text(
            'You will no longer see posts from @${widget.post.username}.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
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
          .doc(widget.post.uid)
          .set(<String, dynamic>{
            'uid': widget.post.uid,
            'blockedAt': FieldValue.serverTimestamp(),
          });

      if (!mounted) {
        return;
      }

      setState(() {
        _isDeleted = true;
      });

      _showMessage('User blocked.');
    } catch (error) {
      debugPrint('Block user error: $error');

      _showMessage('Unable to block user.');
    }
  }

  //===================================================
  // PIN / UNPIN ON PROFILE
  //===================================================

  Future<void> _togglePinOnProfile() async {
    final User? currentUser = _auth.currentUser;

    if (currentUser == null ||
        !widget.isProfileScreen ||
        currentUser.uid != widget.post.uid ||
        widget.post.isRepost) {
      return;
    }

    final DocumentReference<Map<String, dynamic>> userRef = _firestore
        .collection('users')
        .doc(currentUser.uid);

    try {
      final bool pinned = await _firestore.runTransaction<bool>((
        Transaction transaction,
      ) async {
        final DocumentSnapshot<Map<String, dynamic>> userSnapshot =
            await transaction.get(userRef);

        final List<String> pinnedPostIds = List<String>.from(
          userSnapshot.data()?['pinnedPostIds'] ?? <String>[],
        );

        final bool alreadyPinned = pinnedPostIds.contains(widget.post.postId);

        if (alreadyPinned) {
          pinnedPostIds.remove(widget.post.postId);
        } else {
          if (pinnedPostIds.length >= 3) {
            throw Exception('You can pin only 3 posts to your profile.');
          }

          pinnedPostIds.insert(0, widget.post.postId);
        }

        transaction.set(userRef, <String, dynamic>{
          'pinnedPostIds': pinnedPostIds,
        }, SetOptions(merge: true));

        return !alreadyPinned;
      });

      if (!mounted) {
        return;
      }

      _showMessage(
        pinned ? 'Post pinned to profile.' : 'Post unpinned from profile.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  //===================================================
  // THREE DOT POST MENU
  //
  // SAVE REMAINS HERE
  // SHARE TO OTHER APPS REMAINS HERE
  //===================================================

  void _showPostMenu() {
    final User? currentUser = _auth.currentUser;

    final bool isOwner =
        currentUser != null && widget.post.uid == currentUser.uid;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        Future<void> closeThen(Future<void> Function() action) async {
          Navigator.of(sheetContext).pop();

          await Future<void>.delayed(const Duration(milliseconds: 250));

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
                //===================================================
                // SAVE / UNSAVE
                //===================================================

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

                //===================================================
                // SHARE TO OTHER APPS
                //===================================================
                ListTile(
                  leading: const Icon(Icons.share_outlined),
                  title: const Text('Share to other apps'),
                  subtitle: const Text(
                    'WhatsApp, Instagram, Telegram and more',
                  ),
                  onTap: () {
                    closeThen(_sharePost);
                  },
                ),

                //===================================================
                // COPY LINK
                //===================================================
                ListTile(
                  leading: const Icon(Icons.link),
                  title: const Text('Copy Link'),
                  onTap: () {
                    closeThen(_copyPostLink);
                  },
                ),

                //===================================================
                // HIDE / UNHIDE
                //===================================================
                if (isOwner)
                  ListTile(
                    leading: Icon(
                      _isGloballyHidden
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    title: Text(
                      _isGloballyHidden ? 'Unhide Post' : 'Hide Post',
                    ),
                    subtitle: Text(
                      _isGloballyHidden
                          ? 'Make this post visible on Home and your profile again'
                          : 'Hide this post from Home and every profile visitor',
                    ),
                    onTap: () {
                      closeThen(_isGloballyHidden ? _unhidePost : _hidePost);
                    },
                  ),

                //===================================================
                // REPORT
                //===================================================
                if (!isOwner)
                  ListTile(
                    leading: const Icon(Icons.flag_outlined),
                    title: const Text('Report'),
                    onTap: () {
                      closeThen(_reportPost);
                    },
                  ),

                //===================================================
                // BLOCK USER
                //===================================================
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

                  //===================================================
                  // PIN POST
                  //===================================================
                  if (widget.isProfileScreen && !widget.post.isRepost)
                    ListTile(
                      leading: Icon(
                        widget.isPinnedToProfile
                            ? Icons.push_pin
                            : Icons.push_pin_outlined,
                        color: widget.isPinnedToProfile
                            ? const Color(0xFF29B6F6)
                            : null,
                      ),
                      title: Text(
                        widget.isPinnedToProfile
                            ? 'Unpin Post from Profile'
                            : 'Pin Post to Profile',
                      ),
                      subtitle: const Text('You can pin up to 3 posts.'),
                      onTap: () {
                        closeThen(_togglePinOnProfile);
                      },
                    ),

                  //===================================================
                  // EDIT
                  //===================================================
                  ListTile(
                    leading: const Icon(Icons.edit_outlined),
                    title: const Text('Edit Post'),
                    onTap: () {
                      closeThen(_editPost);
                    },
                  ),

                  //===================================================
                  // DELETE
                  //===================================================
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
  // LOAD POLL
  //===================================================

  Future<void> _loadPoll() async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('posts')
          .doc(widget.post.postId)
          .get();

      if (!snapshot.exists) {
        if (!mounted) {
          return;
        }

        setState(() {
          _pollLoading = false;
        });

        return;
      }

      final Map<String, dynamic> data = snapshot.data() ?? <String, dynamic>{};

      final bool hasPoll = data['hasPoll'] == true && data['poll'] != null;

      if (!hasPoll) {
        if (!mounted) {
          return;
        }

        setState(() {
          _hasPoll = false;

          _pollLoading = false;
        });

        return;
      }

      final Map<String, dynamic> poll = Map<String, dynamic>.from(
        data['poll'] as Map,
      );

      final String question = (poll['question'] ?? '').toString();

      final List<dynamic> rawOptions = List<dynamic>.from(
        poll['options'] ?? <dynamic>[],
      );

      final List<Map<String, dynamic>> options = rawOptions.map((dynamic raw) {
        final Map<String, dynamic> item = Map<String, dynamic>.from(raw as Map);

        return <String, dynamic>{
          'text': (item['text'] ?? '').toString(),
          'votes': _toInt(item['votes']),
        };
      }).toList();

      int totalVotes = _toInt(poll['totalVotes']);

      final int calculatedVotes = options.fold<int>(0, (
        int total,
        Map<String, dynamic> option,
      ) {
        return total + _toInt(option['votes']);
      });

      if (totalVotes != calculatedVotes) {
        totalVotes = calculatedVotes;
      }

      DateTime? expiresAt = _dateFromDynamic(poll['expiresAt']);

      if (expiresAt == null) {
        final DateTime? createdAt = _dateFromDynamic(poll['createdAt']);

        if (createdAt != null) {
          expiresAt = createdAt.add(const Duration(hours: 24));
        }
      }

      bool pollClosed = poll['isClosed'] == true;

      int? winnerIndex = _nullableInt(poll['winnerOptionIndex']);

      DateTime? closedAt = _dateFromDynamic(poll['closedAt']);

      if (!pollClosed &&
          expiresAt != null &&
          !DateTime.now().isBefore(expiresAt)) {
        final PollResult result = _calculateWinner(options);

        pollClosed = true;

        winnerIndex = result.winnerIndex;

        closedAt = DateTime.now();

        await _closePollInFirestore(
          winnerIndex: winnerIndex,
          closedAt: closedAt,
        );
      }

      final User? currentUser = _auth.currentUser;

      final List<dynamic> voterIds = List<dynamic>.from(
        poll['votedUserIds'] ?? <dynamic>[],
      );

      bool hasVoted = false;

      String? selectedOption;

      if (currentUser != null) {
        for (final dynamic voter in voterIds) {
          if (voter is Map) {
            final String voterUid = (voter['uid'] ?? '').toString();

            if (voterUid == currentUser.uid) {
              hasVoted = true;

              selectedOption = voter['optionIndex']?.toString();

              break;
            }
          } else if (voter.toString() == currentUser.uid) {
            hasVoted = true;
          }
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _hasPoll = true;

        _pollQuestion = question;

        _pollOptions = options;

        _pollTotalVotes = totalVotes;

        _pollExpiresAt = expiresAt;

        _pollClosed = pollClosed;

        _winnerOptionIndex = winnerIndex;

        _pollClosedAt = closedAt;

        _hasVoted = hasVoted;

        _selectedPollOption = selectedOption;

        _pollLoading = false;
      });
    } catch (error) {
      debugPrint('Error loading poll: $error');

      if (!mounted) {
        return;
      }

      setState(() {
        _pollLoading = false;
      });
    }
  }

  //===================================================
  // DATE HELPER
  //===================================================

  DateTime? _dateFromDynamic(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }

  //===================================================
  // NULLABLE INT HELPER
  //===================================================

  int? _nullableInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '');
  }

  //===================================================
  // CLOSE POLL
  //===================================================

  Future<void> _closePollInFirestore({
    required int? winnerIndex,
    required DateTime closedAt,
  }) async {
    try {
      final DocumentReference<Map<String, dynamic>> postRef = _firestore
          .collection('posts')
          .doc(widget.post.postId);

      await _firestore.runTransaction((Transaction transaction) async {
        final DocumentSnapshot<Map<String, dynamic>> snapshot =
            await transaction.get(postRef);

        if (!snapshot.exists || snapshot.data() == null) {
          return;
        }

        final Map<String, dynamic> data = snapshot.data()!;

        if (data['poll'] == null) {
          return;
        }

        final Map<String, dynamic> poll = Map<String, dynamic>.from(
          data['poll'] as Map,
        );

        if (poll['isClosed'] == true) {
          return;
        }

        poll['isClosed'] = true;

        poll['winnerOptionIndex'] = winnerIndex;

        poll['closedAt'] = Timestamp.fromDate(closedAt);

        transaction.update(postRef, <String, dynamic>{'poll': poll});
      });
    } catch (error) {
      debugPrint('Error closing poll: $error');
    }
  }

  //===================================================
  // POLL EXPIRED
  //===================================================

  bool get _isPollExpired {
    final DateTime? expiresAt = _pollExpiresAt;

    if (expiresAt == null) {
      return false;
    }

    return !DateTime.now().isBefore(expiresAt);
  }

  //===================================================
  // VOTE POLL
  //===================================================

  Future<void> _votePoll(int optionIndex) async {
    if (_isVoting || _hasVoted || _pollClosed || _isPollExpired) {
      return;
    }

    final User? user = _auth.currentUser;

    if (user == null) {
      _showMessage('Please log in to vote.');

      return;
    }

    if (optionIndex < 0 || optionIndex >= _pollOptions.length) {
      return;
    }

    setState(() {
      _isVoting = true;
    });

    try {
      final DocumentReference<Map<String, dynamic>> postRef = _firestore
          .collection('posts')
          .doc(widget.post.postId);

      await _firestore.runTransaction((Transaction transaction) async {
        final DocumentSnapshot<Map<String, dynamic>> snapshot =
            await transaction.get(postRef);

        if (!snapshot.exists || snapshot.data() == null) {
          throw Exception('Post no longer exists.');
        }

        final Map<String, dynamic> data = snapshot.data()!;

        if (data['poll'] == null) {
          throw Exception('Poll no longer exists.');
        }

        final Map<String, dynamic> poll = Map<String, dynamic>.from(
          data['poll'] as Map,
        );

        final DateTime? expiresAt = _dateFromDynamic(poll['expiresAt']);

        if (expiresAt != null && !DateTime.now().isBefore(expiresAt)) {
          throw Exception('Voting has ended.');
        }

        if (poll['isClosed'] == true) {
          throw Exception('Voting has ended.');
        }

        final List<dynamic> rawOptions = List<dynamic>.from(
          poll['options'] ?? <dynamic>[],
        );

        final List<Map<String, dynamic>> updatedOptions = rawOptions.map((
          dynamic option,
        ) {
          return Map<String, dynamic>.from(option as Map);
        }).toList();

        if (optionIndex >= updatedOptions.length) {
          throw Exception('Invalid poll option.');
        }

        final List<dynamic> voterIds = List<dynamic>.from(
          poll['votedUserIds'] ?? <dynamic>[],
        );

        for (final dynamic voter in voterIds) {
          if (voter is Map && (voter['uid'] ?? '').toString() == user.uid) {
            throw Exception('ALREADY_VOTED');
          }

          if (voter is String && voter == user.uid) {
            throw Exception('ALREADY_VOTED');
          }
        }

        final Map<String, dynamic> selectedOption = updatedOptions[optionIndex];

        final int currentVotes = _toInt(selectedOption['votes']);

        selectedOption['votes'] = currentVotes + 1;

        voterIds.add(<String, dynamic>{
          'uid': user.uid,
          'optionIndex': optionIndex,
          'votedAt': Timestamp.now(),
        });

        final int newTotal = updatedOptions.fold<int>(0, (
          int sum,
          Map<String, dynamic> option,
        ) {
          return sum + _toInt(option['votes']);
        });

        poll['options'] = updatedOptions;

        poll['totalVotes'] = newTotal;

        poll['votedUserIds'] = voterIds;

        transaction.update(postRef, <String, dynamic>{'poll': poll});
      });

      if (!mounted) {
        return;
      }

      setState(() {
        final List<Map<String, dynamic>> newOptions = _pollOptions.map((
          Map<String, dynamic> option,
        ) {
          return Map<String, dynamic>.from(option);
        }).toList();

        final int currentVotes = _toInt(newOptions[optionIndex]['votes']);

        newOptions[optionIndex]['votes'] = currentVotes + 1;

        _pollOptions = newOptions;

        _selectedPollOption = optionIndex.toString();

        _hasVoted = true;

        _pollTotalVotes = newOptions.fold<int>(0, (
          int total,
          Map<String, dynamic> option,
        ) {
          return total + _toInt(option['votes']);
        });
      });

      _showMessage('Vote submitted successfully.');
    } catch (error) {
      debugPrint('Poll vote error: $error');

      if (!mounted) {
        return;
      }

      final String message = error.toString();

      if (message.contains('ALREADY_VOTED')) {
        await _loadPoll();

        if (mounted) {
          _showMessage('You have already voted. Your vote cannot be changed.');
        }
      } else if (message.contains('Voting has ended')) {
        await _loadPoll();

        if (mounted) {
          _showMessage('Voting has ended.');
        }
      } else {
        _showMessage('Unable to submit your vote.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isVoting = false;
        });
      }
    }
  }

  //===================================================
  // CALCULATE POLL WINNER
  //===================================================

  PollResult _calculateWinner(List<Map<String, dynamic>> options) {
    if (options.isEmpty) {
      return const PollResult(winnerIndex: null, isTie: false);
    }

    int highestVotes = -1;

    final List<int> winners = <int>[];

    for (int index = 0; index < options.length; index++) {
      final int votes = _toInt(options[index]['votes']);

      if (votes > highestVotes) {
        highestVotes = votes;

        winners
          ..clear()
          ..add(index);
      } else if (votes == highestVotes) {
        winners.add(index);
      }
    }

    if (highestVotes <= 0) {
      return const PollResult(winnerIndex: null, isTie: false);
    }

    return PollResult(winnerIndex: winners.first, isTie: winners.length > 1);
  }

  //===================================================
  // POLL PERCENTAGE
  //===================================================

  double _getPollPercentage(int votes) {
    if (_pollTotalVotes <= 0) {
      return 0;
    }

    return (votes / _pollTotalVotes).clamp(0.0, 1.0).toDouble();
  }

  int _getPollPercentageNumber(int votes) {
    return (_getPollPercentage(votes) * 100).round();
  }

  //===================================================
  // POLL TIME
  //===================================================

  String _pollTimeText() {
    if (_pollExpiresAt == null) {
      return '';
    }

    if (_isPollExpired || _pollClosed) {
      return 'Voting closed';
    }

    final Duration remaining = _pollExpiresAt!.difference(DateTime.now());

    if (remaining.isNegative) {
      return 'Voting closed';
    }

    final int hours = remaining.inHours;

    final int minutes = remaining.inMinutes % 60;

    if (hours > 0) {
      return '$hours h $minutes min left';
    }

    return '$minutes min left';
  }

  //===================================================
  // WINNER TEXT
  //===================================================

  Widget _buildWinnerText() {
    if (!_pollClosed || _pollOptions.isEmpty) {
      return const SizedBox.shrink();
    }

    final PollResult result = _calculateWinner(_pollOptions);

    if (result.winnerIndex == null) {
      return const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Text(
          'Poll ended with no votes.',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      );
    }

    if (result.isTie) {
      return const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Row(
          children: <Widget>[
            Icon(Icons.emoji_events_outlined, size: 18),
            SizedBox(width: 6),
            Text(
              'Poll ended in a tie',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    final int index = result.winnerIndex!;

    if (index < 0 || index >= _pollOptions.length) {
      return const SizedBox.shrink();
    }

    final String winner = (_pollOptions[index]['text'] ?? '').toString();

    final int percentage = _getPollPercentageNumber(
      _toInt(_pollOptions[index]['votes']),
    );

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: <Widget>[
          const Icon(Icons.emoji_events, color: Colors.amber, size: 19),

          const SizedBox(width: 6),

          Expanded(
            child: Text(
              'Winner: $winner $percentage%',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  //===================================================
  // POLL UI
  //===================================================

  Widget _buildPoll() {
    if (_pollLoading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (!_hasPoll) {
      return const SizedBox.shrink();
    }

    // Results stay private while the 24-hour voting window is open. After a
    // vote, only the option chosen by this user is highlighted. Percentages
    // are revealed for everybody only when the poll closes.
    final bool showResults = _pollClosed;

    final PollResult closedResult = _pollClosed
        ? _calculateWinner(_pollOptions)
        : const PollResult(winnerIndex: null, isTie: false);

    final int? displayedWinnerIndex = closedResult.isTie
        ? null
        : (_winnerOptionIndex ?? closedResult.winnerIndex);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8, bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade700),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          //===================================================
          // POLL HEADER
          //===================================================

          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF29B6F6).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.poll_outlined,
                  color: Color(0xFF29B6F6),
                  size: 20,
                ),
              ),

              const SizedBox(width: 8),

              const Text(
                'Poll',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),

              const Spacer(),

              if (!_pollClosed && _pollExpiresAt != null)
                Text(
                  _pollTimeText(),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 14),

          //===================================================
          // POLL QUESTION
          //===================================================
          Text(
            _pollQuestion,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
          ),

          const SizedBox(height: 14),

          //===================================================
          // POLL OPTIONS
          //===================================================
          ...List<Widget>.generate(_pollOptions.length, (int index) {
            final Map<String, dynamic> option = _pollOptions[index];

            final String text = (option['text'] ?? '').toString();

            final int votes = _toInt(option['votes']);

            final double percentage = _getPollPercentage(votes);

            final int percentageNumber = _getPollPercentageNumber(votes);

            final bool selected = _selectedPollOption == index.toString();

            final bool winner = _pollClosed && displayedWinnerIndex == index;

            final bool highlighted = _pollClosed ? winner : selected;

            return Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: InkWell(
                onTap: _pollClosed || _hasVoted || _isVoting
                    ? null
                    : () {
                        _votePoll(index);
                      },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 56,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: highlighted
                          ? const Color(0xFF29B6F6)
                          : Colors.grey.shade700,
                      width: highlighted ? 1.5 : 1,
                    ),
                  ),
                  child: Stack(
                    children: <Widget>[
                      if (showResults)
                        FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: percentage,
                          child: Container(
                            color: winner
                                ? const Color(
                                    0xFF29B6F6,
                                  ).withValues(alpha: 0.35)
                                : Colors.white.withValues(alpha: 0.08),
                          ),
                        ),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          children: <Widget>[
                            if (selected && !_pollClosed)
                              const Padding(
                                padding: EdgeInsets.only(right: 7),
                                child: Icon(
                                  Icons.check_circle,
                                  color: Color(0xFF29B6F6),
                                  size: 20,
                                ),
                              ),

                            if (winner)
                              const Padding(
                                padding: EdgeInsets.only(right: 7),
                                child: Icon(
                                  Icons.emoji_events,
                                  color: Colors.amber,
                                  size: 20,
                                ),
                              ),

                            Expanded(
                              child: Text(
                                text,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),

                            if (showResults)
                              Text(
                                '$percentageNumber%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),

          //===================================================
          // TOTAL VOTES
          //===================================================
          Text(
            '$_pollTotalVotes ${_pollTotalVotes == 1 ? 'vote' : 'votes'}',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          ),

          //===================================================
          // POLL INSTRUCTION
          //===================================================
          if (!_hasVoted && !_pollClosed && !_isVoting)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                'Tap an option to vote',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ),

          //===================================================
          // ALREADY VOTED
          //===================================================
          if (_hasVoted)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                'You have already voted. Your vote cannot be changed.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ),

          _buildWinnerText(),
        ],
      ),
    );
  }

  //===================================================
  // POST HEADER
  //
  // PROFILE PHOTO + FULL NAME OPEN PROFILE
  //===================================================

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        //===================================================
        // PROFILE PICTURE
        //===================================================

        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _openAuthorProfile,
          child: CircleAvatar(
            radius: 24,
            backgroundImage: widget.post.photoUrl.isNotEmpty
                ? NetworkImage(widget.post.photoUrl)
                : null,
            child: widget.post.photoUrl.isEmpty
                ? const Icon(Icons.person)
                : null,
          ),
        ),

        const SizedBox(width: 10),

        //===================================================
        // NAME + USERNAME + TIME
        //===================================================
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _openAuthorProfile,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  widget.post.fullName.isNotEmpty
                      ? widget.post.fullName
                      : widget.post.username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),

                const SizedBox(height: 2),

                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        '@${widget.post.username}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ),

                    if (widget.post.createdAt != null) ...<Widget>[
                      Text(
                        ' · ',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),

                      Flexible(
                        child: NubifyTimeText.fromTimestamp(
                          timestamp: widget.post.createdAt,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),

        //===================================================
        // THREE DOT MENU
        //===================================================
        IconButton(onPressed: _showPostMenu, icon: const Icon(Icons.more_vert)),
      ],
    );
  }

  //===================================================
  // POST CAPTION + UNIVERSAL LINK PREVIEW
  //===================================================

  Widget _buildCaption() {
    if (_caption.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 10),

      child: UniversalLinkText(
        text: _caption,

        style: const TextStyle(fontSize: 16, height: 1.4),
      ),
    );
  }
  //===================================================
  // SHOW TAGGED USERS
  //===================================================

  void _showTaggedUsers() {
    if (widget.post.taggedUsers.isEmpty) {
      return;
    }

    showModalBottomSheet<void>(
      context: context,

      showDragHandle: true,

      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,

            children: <Widget>[
              const Padding(
                padding: EdgeInsets.all(14),

                child: Text(
                  'Tagged users',

                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),

              ...widget.post.taggedUsers
                  .map(
                    (TaggedUser user) => ListTile(
                      leading: CircleAvatar(
                        backgroundImage: user.photoUrl.trim().isNotEmpty
                            ? NetworkImage(user.photoUrl)
                            : null,

                        child: user.photoUrl.trim().isEmpty
                            ? const Icon(Icons.person)
                            : null,
                      ),

                      title: Text('@${user.username}'),

                      onTap: () {
                        Navigator.pop(sheetContext);

                        if (user.uid.trim().isNotEmpty) {
                          Navigator.of(
                            context,
                          ).pushNamed('/profile', arguments: user.uid);
                        }
                      },
                    ),
                  )
                  .toList(),

              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
  //===================================================
  // HOME / FEED ACTIONS
  //
  // LIKE | COMMENT | REPOST | ARROW SHARE
  //
  // CLOSE TO EACH OTHER LIKE OLD NUBIFY UI
  //
  // NO SAVE ICON HERE
  //===================================================

  Widget _buildActions() {
    const double actionSlotWidth = 58;

    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          //===================================================
          // LIKE
          //===================================================

          SizedBox(
            width: actionSlotWidth,
            child: _buildCompactAction(
              onTap: _toggleLike,
              icon: _isLiked ? Icons.favorite : Icons.favorite_border,
              iconColor: _isLiked ? const Color(0xFF29B6F6) : null,
              count: _likeCount,
              loading: _isLikeLoading,
            ),
          ),

          //===================================================
          // COMMENT
          //===================================================
          SizedBox(
            width: actionSlotWidth,
            child: _buildCompactAction(
              onTap: _openCurrentPost,
              icon: Icons.chat_bubble_outline_rounded,
              count: _commentCount,
            ),
          ),

          //===================================================
          // REPOST / QUOTE REPOST
          //===================================================
          SizedBox(
            width: actionSlotWidth,
            child: _buildCompactAction(
              onTap: _showRepostOptions,
              onLongPress: _openPostEngagements,
              icon: Icons.repeat_rounded,
              count: _repostCount,
            ),
          ),

          //===================================================
          // ARROW SHARE
          //
          // OUTLINE PAPER-PLANE POINTING UPWARD / RIGHT
          //
          // SAME ICON AS YOUR OLD NUBIFY HOME FEED
          //
          // STORY + CHAT ONLY
          //===================================================
          SizedBox(
            width: 50,
            child: InkWell(
              onTap: _showShareOptions,
              borderRadius: BorderRadius.circular(30),
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.near_me_outlined, size: 27),
              ),
            ),
          ),
          //===================================================
          // SPACE BEFORE TAG ICON
          //===================================================

          const Spacer(),

          //===================================================
          // TAGGED USERS
          // ===================================================
          if (widget.post.taggedUsers.isNotEmpty)
            IconButton(
              tooltip: 'Tagged users',

              onPressed: _showTaggedUsers,

              icon: const Icon(Icons.person_pin_outlined, size: 25),
            ),
        ],
      ),
    );
  }

  //===================================================
  // COMPACT ACTION BUTTON
  //===================================================

  Widget _buildCompactAction({
    required VoidCallback onTap,
    required IconData icon,
    int? count,
    Color? iconColor,
    bool loading = false,
    bool hideZeroCount = false,
    Future<void> Function()? onLongPress,
  }) {
    final bool showCount = count != null && (!hideZeroCount || count > 0);

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress == null
          ? null
          : () {
              onLongPress();
            },
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (loading)
              const SizedBox(
                width: 21,
                height: 21,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(icon, size: 23, color: iconColor),

            if (showCount) ...<Widget>[
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  _compactCount(count),
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  //===================================================
  // COMPACT COUNT
  //===================================================

  String _compactCount(int value) {
    if (value >= 1000000000) {
      return '${(value / 1000000000).toStringAsFixed(value % 1000000000 == 0 ? 0 : 1)}B';
    }

    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(value % 1000000 == 0 ? 0 : 1)}M';
    }

    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}K';
    }

    return '$value';
  }

  //===================================================
  // VIEW COUNT
  //===================================================

  Widget _buildViews() {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 4),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.visibility_outlined,
            size: 16,
            color: Colors.grey.shade600,
          ),

          const SizedBox(width: 4),

          Text(
            '$_viewCount ${_viewCount == 1 ? 'view' : 'views'}',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
      ),
    );
  }

  //===================================================
  // LIVE REPOST / QUOTE REPOST CARD
  //===================================================

  Widget _buildLiveRepostCard({required bool quote}) {
    final String sourcePostId = widget.post.sourcePostId.trim();

    final String rootPostId = widget.post.rootPostId.trim();

    final String referencedPostId =
        sourcePostId.isNotEmpty && sourcePostId != widget.post.postId
        ? sourcePostId
        : rootPostId;

    if (referencedPostId.isEmpty || referencedPostId == widget.post.postId) {
      return _buildUnavailableRepostCard(quote: quote);
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _firestore.collection('posts').doc(referencedPostId).snapshots(),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
          ) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return _buildRepostShell(
                quote: quote,
                referenced: null,
                loading: true,
              );
            }

            if (!snapshot.hasData ||
                !snapshot.data!.exists ||
                snapshot.data!.data() == null) {
              return _buildUnavailableRepostCard(quote: quote);
            }

            final Map<String, dynamic> raw = snapshot.data!.data()!;

            if (raw['isHidden'] == true || raw['isRootHidden'] == true) {
              return _buildUnavailableRepostCard(
                quote: quote,
                message: 'Referenced post is hidden by its owner.',
              );
            }

            try {
              final Post referenced = Post.fromFirestore(snapshot.data!);

              return _buildRepostShell(quote: quote, referenced: referenced);
            } catch (error) {
              debugPrint('Referenced repost parse error: $error');

              return _buildUnavailableRepostCard(quote: quote);
            }
          },
    );
  }

  //===================================================
  // REPOST OUTER SHELL
  //
  // OUTER BODY OPENS THIS REPOST ITSELF
  //===================================================

  Widget _buildRepostShell({
    required bool quote,
    required Post? referenced,
    bool loading = false,
  }) {
    final String quoteText = widget.post.repostText.trim().isNotEmpty
        ? widget.post.repostText.trim()
        : widget.post.caption.trim();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _openCurrentPost,
      onDoubleTap: _doubleTapLike,
      child: Container(
        width: double.infinity,
        color: Theme.of(context).scaffoldBackgroundColor,
        padding: const EdgeInsets.only(top: 10, bottom: 4),
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (_isGloballyHidden && widget.showHiddenPost)
                  _buildHiddenBanner(),

                //===================================================
                // REPOSTER HEADER
                //===================================================
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _buildHeader(),
                ),

                //===================================================
                // BLUE REPOST / QUOTE REPOST LABEL
                //===================================================
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 1, 12, 8),
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.repeat_rounded,
                        size: 17,
                        color: Color(0xFF29B6F6),
                      ),

                      const SizedBox(width: 5),

                      Text(
                        quote ? 'Quote repost' : 'Reposted',
                        style: const TextStyle(
                          color: Color(0xFF29B6F6),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),

                //===================================================
                // QUOTE TEXT
                //===================================================
                if (quote && quoteText.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                    child: Text(
                      quoteText,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                //===================================================
                // REFERENCED POST LOADING
                //===================================================
                if (loading)
                  Container(
                    height: 120,
                    margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.withOpacity(0.30)),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else if (referenced != null)
                  _buildReferencedPostEmbed(referenced, depth: 0),

                //===================================================
                // REPOST ACTIONS
                //===================================================
                _buildActions(),

                _buildViews(),

                const Divider(height: 1),
              ],
            ),

            //===================================================
            // DOUBLE TAP HEART
            //===================================================
            if (_showHeartAnimation)
              IgnorePointer(
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.5, end: 1.2),
                  duration: const Duration(milliseconds: 450),
                  builder: (BuildContext context, double scale, Widget? child) {
                    return Transform.scale(
                      scale: scale,
                      child: const Icon(
                        Icons.favorite,
                        color: Color(0xFF29B6F6),
                        size: 110,
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  //===================================================
  // EMBEDDED REFERENCED POST
  //
  // BODY OPENS REFERENCED POST
  //
  // PHOTO / NAME OPEN PROFILE
  //===================================================

  Widget _buildReferencedPostEmbed(Post referenced, {required int depth}) {
    final String displayName = referenced.fullName.trim().isNotEmpty
        ? referenced.fullName.trim()
        : referenced.username.trim().isNotEmpty
        ? referenced.username.trim()
        : 'Nubify User';

    final String quoteText = referenced.repostText.trim().isNotEmpty
        ? referenced.repostText.trim()
        : referenced.caption.trim();

    final String nestedSource = referenced.sourcePostId.trim();

    final String nestedRoot = referenced.rootPostId.trim();

    final String nestedPostId =
        nestedSource.isNotEmpty && nestedSource != referenced.postId
        ? nestedSource
        : nestedRoot;

    final bool canShowNested =
        referenced.isRepost &&
        nestedPostId.isNotEmpty &&
        nestedPostId != referenced.postId &&
        depth < 6;

    final double mediaHeight = depth == 0 ? 320 : 220;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),

          //===================================================
          // TAP EMBEDDED BODY -> EXACT REFERENCED POST
          //===================================================
          onTap: () {
            _openPostById(referenced.postId);
          },

          child: Container(
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withOpacity(0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                //===================================================
                // REFERENCED AUTHOR HEADER
                //===================================================

                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      //===================================================
                      // REFERENCED PROFILE PICTURE
                      //===================================================

                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          _openProfile(referenced.uid);
                        },
                        child: CircleAvatar(
                          radius: 21,
                          backgroundImage: referenced.photoUrl.trim().isNotEmpty
                              ? NetworkImage(referenced.photoUrl)
                              : null,
                          child: referenced.photoUrl.trim().isEmpty
                              ? const Icon(Icons.person, size: 20)
                              : null,
                        ),
                      ),

                      const SizedBox(width: 9),

                      //===================================================
                      // REFERENCED NAME + USERNAME + TIME
                      //===================================================
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                _openProfile(referenced.uid);
                              },
                              child: Text(
                                displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14.5,
                                ),
                              ),
                            ),

                            Row(
                              children: <Widget>[
                                if (referenced.username.trim().isNotEmpty)
                                  Flexible(
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () {
                                        _openProfile(referenced.uid);
                                      },
                                      child: Text(
                                        '@${referenced.username.trim()}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                    ),
                                  ),

                                if (referenced.username.trim().isNotEmpty &&
                                    referenced.createdAt != null)
                                  Text(
                                    ' · ',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                    ),
                                  ),

                                if (referenced.createdAt != null)
                                  Flexible(
                                    child: NubifyTimeText.fromTimestamp(
                                      timestamp: referenced.createdAt,
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                //===================================================
                // NESTED REPOST LABEL
                //===================================================
                if (referenced.isRepost)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 7, 12, 0),
                    child: Row(
                      children: <Widget>[
                        const Icon(
                          Icons.repeat_rounded,
                          size: 15,
                          color: Color(0xFF29B6F6),
                        ),

                        const SizedBox(width: 5),

                        Text(
                          referenced.isQuoteRepost
                              ? 'Quote repost'
                              : 'Reposted',
                          style: const TextStyle(
                            color: Color(0xFF29B6F6),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),

                //===================================================
                // NORMAL REFERENCED CAPTION
                //===================================================
                if (!referenced.isRepost &&
                    referenced.caption.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Text(
                      referenced.caption.trim(),
                      style: const TextStyle(fontSize: 15, height: 1.35),
                    ),
                  ),

                //===================================================
                // REFERENCED QUOTE TEXT
                //===================================================
                if (referenced.isQuoteRepost && quoteText.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Text(
                      quoteText,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                //===================================================
                // REFERENCED POLL
                //===================================================
                if (!referenced.isRepost &&
                    referenced.hasPoll &&
                    referenced.poll != null)
                  _buildEmbeddedPoll(
                    postId: referenced.postId,
                    poll: referenced.poll!,
                  ),

                //===================================================
                // REFERENCED MEDIA
                //===================================================
                if (!referenced.isRepost && referenced.media.isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    height: mediaHeight,
                    child: PostMediaCarousel(
                      media: referenced.media,
                      forcePaused: widget.forceMediaPaused,
                    ),
                  ),

                //===================================================
                // NESTED QUOTE / REPOST CHAIN
                //===================================================
                if (!_directParentRepostChain && canShowNested)
                  _buildNestedReferencedPost(nestedPostId, depth: depth + 1)
                else if (_directParentRepostChain &&
                    referenced.isRepost &&
                    nestedPostId.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          Icons.touch_app_outlined,
                          size: 15,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            'Tap this repost to continue to its parent post.',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (referenced.isRepost &&
                    nestedPostId.isNotEmpty &&
                    depth >= 6)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    child: Text(
                      'Tap this repost to continue the repost chain.',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  //===================================================
  // NESTED REPOST / QUOTE CHAIN
  //===================================================

  Widget _buildNestedReferencedPost(String postId, {required int depth}) {
    final String cleanPostId = postId.trim();

    if (cleanPostId.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _firestore.collection('posts').doc(cleanPostId).snapshots(),
        builder:
            (
              BuildContext context,
              AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
            ) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return Container(
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: Colors.grey.withOpacity(0.25)),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }

              if (!snapshot.hasData ||
                  !snapshot.data!.exists ||
                  snapshot.data!.data() == null) {
                return _buildSmallUnavailableReference(
                  'Referenced post is no longer available.',
                );
              }

              final Map<String, dynamic> raw = snapshot.data!.data()!;

              if (raw['isHidden'] == true || raw['isRootHidden'] == true) {
                return _buildSmallUnavailableReference(
                  'Referenced post is hidden.',
                );
              }

              try {
                final Post nested = Post.fromFirestore(snapshot.data!);

                return _buildReferencedPostEmbed(nested, depth: depth);
              } catch (error) {
                debugPrint('Nested repost parse error: $error');

                return _buildSmallUnavailableReference(
                  'Unable to display this referenced post.',
                );
              }
            },
      ),
    );
  }

  //===================================================
  // SMALL UNAVAILABLE REFERENCE
  //===================================================

  Widget _buildSmallUnavailableReference(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.grey.withOpacity(0.25)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.insert_drive_file_outlined,
            size: 19,
            color: Colors.grey,
          ),

          const SizedBox(width: 8),

          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  //===================================================
  // EMBEDDED POLL INSIDE REPOST
  //===================================================

  Widget _buildEmbeddedPoll({
    required String postId,
    required Map<String, dynamic> poll,
  }) {
    final String question = (poll['question'] ?? '').toString().trim();

    final List<dynamic> rawOptions = poll['options'] is List
        ? List<dynamic>.from(poll['options'] as List)
        : <dynamic>[];

    final List<Map<String, dynamic>> options = rawOptions
        .whereType<Map>()
        .map((Map item) => Map<String, dynamic>.from(item))
        .toList();

    if (question.isEmpty && options.isEmpty) {
      return const SizedBox.shrink();
    }

    int totalVotes = _toInt(poll['totalVotes']);

    if (totalVotes <= 0) {
      totalVotes = options.fold<int>(
        0,
        (int total, Map<String, dynamic> option) =>
            total + _toInt(option['votes']),
      );
    }

    final bool pollClosed = _isEmbeddedPollClosed(poll);

    final int? selectedIndex = _embeddedPollSelectedIndex(poll);

    final bool hasVoted = _embeddedPollHasVoted(poll);

    final PollResult result = pollClosed
        ? _calculateWinner(options)
        : const PollResult(winnerIndex: null, isTie: false);

    final int? storedWinnerIndex = _nullableInt(poll['winnerOptionIndex']);

    final int? winnerIndex = result.isTie
        ? null
        : (storedWinnerIndex ?? result.winnerIndex);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: Colors.grey.withOpacity(0.30)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (question.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Text(
                  question,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),

            for (int index = 0; index < options.length; index++)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: _buildEmbeddedPollOption(
                  postId: postId,
                  option: options[index],
                  optionIndex: index,
                  totalVotes: totalVotes,
                  pollClosed: pollClosed,
                  hasVoted: hasVoted,
                  selected: selectedIndex == index,
                  winner: winnerIndex == index,
                ),
              ),

            Text(
              '$totalVotes ${totalVotes == 1 ? 'vote' : 'votes'}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmbeddedPollOption({
    required String postId,
    required Map<String, dynamic> option,
    required int optionIndex,
    required int totalVotes,
    required bool pollClosed,
    required bool hasVoted,
    required bool selected,
    required bool winner,
  }) {
    final int votes = _toInt(option['votes']);

    final double percentage = totalVotes <= 0
        ? 0
        : (votes / totalVotes).clamp(0.0, 1.0).toDouble();

    final bool highlighted = pollClosed ? winner : selected;

    return InkWell(
      onTap: pollClosed || hasVoted || _isVoting
          ? null
          : () {
              _voteEmbeddedPoll(postId: postId, optionIndex: optionIndex);
            },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 46,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: highlighted ? const Color(0xFF29B6F6) : Colors.grey.shade700,
            width: highlighted ? 1.5 : 1,
          ),
        ),
        child: Stack(
          children: <Widget>[
            if (pollClosed)
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: percentage,
                child: ColoredBox(
                  color: winner
                      ? const Color(0xFF29B6F6).withValues(alpha: 0.35)
                      : Colors.white.withValues(alpha: 0.08),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 11),
              child: Row(
                children: <Widget>[
                  if (selected && !pollClosed)
                    const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: Icon(
                        Icons.check_circle,
                        color: Color(0xFF29B6F6),
                        size: 17,
                      ),
                    ),
                  if (winner)
                    const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: Icon(
                        Icons.emoji_events,
                        color: Colors.amber,
                        size: 17,
                      ),
                    ),
                  Expanded(
                    child: Text(
                      (option['text'] ?? '').toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (pollClosed)
                    Text(
                      '${(percentage * 100).round()}%',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
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

  bool _isEmbeddedPollClosed(Map<String, dynamic> poll) {
    if (poll['isClosed'] == true) {
      return true;
    }

    DateTime? expiresAt = _dateFromDynamic(poll['expiresAt']);

    expiresAt ??= _dateFromDynamic(
      poll['createdAt'],
    )?.add(const Duration(hours: 24));

    return expiresAt != null && !DateTime.now().isBefore(expiresAt);
  }

  int? _embeddedPollSelectedIndex(Map<String, dynamic> poll) {
    final String uid = _auth.currentUser?.uid ?? '';

    if (uid.isEmpty) {
      return null;
    }

    final List<dynamic> voters = poll['votedUserIds'] is List
        ? List<dynamic>.from(poll['votedUserIds'] as List)
        : <dynamic>[];

    for (final dynamic voter in voters) {
      if (voter is Map && (voter['uid'] ?? '').toString() == uid) {
        return _nullableInt(voter['optionIndex']);
      }
    }

    return null;
  }

  bool _embeddedPollHasVoted(Map<String, dynamic> poll) {
    final String uid = _auth.currentUser?.uid ?? '';

    if (uid.isEmpty) {
      return false;
    }

    final List<dynamic> voters = poll['votedUserIds'] is List
        ? List<dynamic>.from(poll['votedUserIds'] as List)
        : <dynamic>[];

    return voters.any((dynamic voter) {
      if (voter is Map) {
        return (voter['uid'] ?? '').toString() == uid;
      }

      return voter.toString() == uid;
    });
  }

  Future<void> _voteEmbeddedPoll({
    required String postId,
    required int optionIndex,
  }) async {
    if (_isVoting) {
      return;
    }

    final User? user = _auth.currentUser;

    if (user == null) {
      _showMessage('Please log in to vote.');
      return;
    }

    setState(() {
      _isVoting = true;
    });

    try {
      final DocumentReference<Map<String, dynamic>> postRef = _firestore
          .collection('posts')
          .doc(postId);

      await _firestore.runTransaction((Transaction transaction) async {
        final DocumentSnapshot<Map<String, dynamic>> snapshot =
            await transaction.get(postRef);

        final Map<String, dynamic>? data = snapshot.data();

        if (!snapshot.exists || data == null || data['poll'] is! Map) {
          throw Exception('Poll no longer exists.');
        }

        final Map<String, dynamic> poll = Map<String, dynamic>.from(
          data['poll'] as Map,
        );

        if (_isEmbeddedPollClosed(poll)) {
          throw Exception('Voting has ended.');
        }

        final List<Map<String, dynamic>> options =
            (poll['options'] as List<dynamic>? ?? <dynamic>[])
                .whereType<Map>()
                .map((Map option) => Map<String, dynamic>.from(option))
                .toList();

        if (optionIndex < 0 || optionIndex >= options.length) {
          throw Exception('Invalid poll option.');
        }

        final List<dynamic> voters = poll['votedUserIds'] is List
            ? List<dynamic>.from(poll['votedUserIds'] as List)
            : <dynamic>[];

        final bool alreadyVoted = voters.any((dynamic voter) {
          if (voter is Map) {
            return (voter['uid'] ?? '').toString() == user.uid;
          }

          return voter.toString() == user.uid;
        });

        if (alreadyVoted) {
          throw Exception('ALREADY_VOTED');
        }

        options[optionIndex]['votes'] =
            _toInt(options[optionIndex]['votes']) + 1;

        voters.add(<String, dynamic>{
          'uid': user.uid,
          'optionIndex': optionIndex,
          'votedAt': Timestamp.now(),
        });

        poll['options'] = options;
        poll['votedUserIds'] = voters;
        poll['totalVotes'] = options.fold<int>(
          0,
          (int total, Map<String, dynamic> option) =>
              total + _toInt(option['votes']),
        );

        transaction.update(postRef, <String, dynamic>{'poll': poll});
      });

      _showMessage('Vote submitted successfully.');
    } catch (error) {
      final String message = error.toString();

      if (message.contains('ALREADY_VOTED')) {
        _showMessage('You have already voted. Your vote cannot be changed.');
      } else if (message.contains('Voting has ended')) {
        _showMessage('Voting has ended.');
      } else {
        _showMessage('Unable to submit your vote.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isVoting = false;
        });
      }
    }
  }

  //===================================================
  // UNAVAILABLE REFERENCED POST
  //===================================================

  Widget _buildUnavailableRepostCard({
    required bool quote,
    String message = 'Original post is no longer available.',
  }) {
    final String quoteText = widget.post.repostText.trim().isNotEmpty
        ? widget.post.repostText.trim()
        : widget.post.caption.trim();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _openCurrentPost,
      child: Container(
        width: double.infinity,
        color: Theme.of(context).scaffoldBackgroundColor,
        padding: const EdgeInsets.only(top: 10, bottom: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (_isGloballyHidden && widget.showHiddenPost)
              _buildHiddenBanner(),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _buildHeader(),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(12, 1, 12, 8),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.repeat_rounded,
                    size: 17,
                    color: Color(0xFF29B6F6),
                  ),

                  const SizedBox(width: 5),

                  Text(
                    quote ? 'Quote repost' : 'Reposted',
                    style: const TextStyle(
                      color: Color(0xFF29B6F6),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),

            if (quote && quoteText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: Text(
                  quoteText,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.withOpacity(0.35)),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.insert_drive_file_outlined,
                    color: Colors.grey,
                  ),

                  const SizedBox(width: 9),

                  Expanded(
                    child: Text(
                      message,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            _buildActions(),

            _buildViews(),

            const Divider(height: 1),
          ],
        ),
      ),
    );
  }

  //===================================================
  // HIDDEN POST BANNER
  //===================================================

  Widget _buildHiddenBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 2, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.40)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.visibility_off_outlined,
            size: 18,
            color: Colors.orange,
          ),

          const SizedBox(width: 7),

          const Expanded(
            child: Text(
              'Hidden from Home and profile visitors',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),

          TextButton(onPressed: _unhidePost, child: const Text('Unhide')),
        ],
      ),
    );
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
    if (_isDeleted && !widget.showHiddenPost) {
      return const SizedBox.shrink();
    }

    //===================================================
    // REPOST / QUOTE REPOST
    //===================================================

    if (widget.post.isRepost) {
      return _buildLiveRepostCard(quote: widget.post.isQuoteRepost);
    }

    final bool hasMedia = widget.post.media.isNotEmpty;

    //===================================================
    // NORMAL POST
    //===================================================

    return GestureDetector(
      behavior: HitTestBehavior.opaque,

      //===================================================
      // TAP POST BODY -> OPEN EXACT POST
      //===================================================
      onTap: _openCurrentPost,

      //===================================================
      // DOUBLE TAP MEDIA -> LIKE
      //===================================================
      onDoubleTap: hasMedia ? _doubleTapLike : null,

      child: Container(
        width: double.infinity,
        color: Theme.of(context).scaffoldBackgroundColor,
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                //===================================================
                // HIDDEN BANNER
                //===================================================

                if (_isGloballyHidden && widget.showHiddenPost)
                  _buildHiddenBanner(),

                //===================================================
                // HEADER
                //===================================================
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _buildHeader(),
                ),

                //===================================================
                // CAPTION
                //===================================================
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _buildCaption(),
                ),

                //===================================================
                // POLL
                //===================================================
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _buildPoll(),
                ),

                //===================================================
                // MEDIA
                //===================================================
                if (hasMedia)
                  SizedBox(
                    width: double.infinity,
                    height: 430,
                    child: PostMediaCarousel(
                      media: widget.post.media,
                      forcePaused: widget.forceMediaPaused,
                    ),
                  ),

                //===================================================
                // ACTIONS
                //===================================================
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _buildActions(),
                ),

                //===================================================
                // VIEWS
                //===================================================
                _buildViews(),

                const Divider(height: 1),
              ],
            ),

            //===================================================
            // BIG BLUE HEART ANIMATION
            //===================================================
            if (_showHeartAnimation)
              IgnorePointer(
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.5, end: 1.2),
                  duration: const Duration(milliseconds: 450),
                  builder: (BuildContext context, double scale, Widget? child) {
                    return Transform.scale(
                      scale: scale,
                      child: const Icon(
                        Icons.favorite,
                        color: Color(0xFF29B6F6),
                        size: 110,
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

//===================================================
// POLL RESULT
//===================================================

class PollResult {
  final int? winnerIndex;

  final bool isTie;

  const PollResult({required this.winnerIndex, required this.isTie});
}
